import sys
import os
import argparse
import re
import numpy as np
import torch
import soundfile as sf
from transformers import VitsModel, AutoTokenizer
import torchaudio
import torchaudio.transforms as T
import sherpa_onnx
from huggingface_hub import snapshot_download
import asyncio
import edge_tts
import uuid

loaded_mms_model = None
loaded_mms_tokenizer = None
loaded_sherpa_tts = None
loaded_resampler = None

def get_mms_model_and_tokenizer(model_name, device):
    global loaded_mms_model, loaded_mms_tokenizer
    if loaded_mms_model is None:
        print(f"Loading MMS model '{model_name}' on device '{device}'...", file=sys.stderr)
        try:
            loaded_mms_model = VitsModel.from_pretrained(model_name).to(device)
            loaded_mms_tokenizer = AutoTokenizer.from_pretrained(model_name)
        except Exception as e:
            print(f"Error loading MMS model {model_name}: {e}", file=sys.stderr)
            sys.exit(1)
    return loaded_mms_model, loaded_mms_tokenizer

def get_sherpa_tts(speed_factor):
    global loaded_sherpa_tts
    if loaded_sherpa_tts is None:
        repo_id = "csukuangfj/vits-mimic3-ko_KO-kss_low"
        print(f"Loading Sherpa KSS model from Hugging Face ({repo_id})...", file=sys.stderr)
        try:
            model_dir = snapshot_download(repo_id=repo_id)
            model_path = os.path.join(model_dir, "ko_KO-kss_low.onnx")
            tokens_path = os.path.join(model_dir, "tokens.txt")
            data_dir = os.path.join(model_dir, "espeak-ng-data")
            
            length_scale = 1.0 / max(0.1, speed_factor)
            
            config = sherpa_onnx.OfflineTtsConfig(
                model=sherpa_onnx.OfflineTtsModelConfig(
                    vits=sherpa_onnx.OfflineTtsVitsModelConfig(
                        model=model_path,
                        lexicon="",
                        tokens=tokens_path,
                        data_dir=data_dir,
                        noise_scale=0.667,
                        noise_scale_w=0.8,
                        length_scale=length_scale
                    )
                )
            )
            loaded_sherpa_tts = sherpa_onnx.OfflineTts(config)
            print("Sherpa KSS model loaded successfully!", file=sys.stderr)
        except Exception as e:
            print(f"Error loading Sherpa KSS model: {e}", file=sys.stderr)
            sys.exit(1)
    return loaded_sherpa_tts

def resample_audio(audio_numpy, orig_sr, target_sr):
    global loaded_resampler
    if orig_sr == target_sr:
        return audio_numpy
    
    # Cast to float32 explicitly to avoid PyTorch Resample data type mismatch crashes
    tensor = torch.from_numpy(audio_numpy.astype(np.float32)).unsqueeze(0)
    
    if loaded_resampler is None or loaded_resampler.orig_freq != orig_sr or loaded_resampler.new_freq != target_sr:
        loaded_resampler = T.Resample(orig_freq=orig_sr, new_freq=target_sr)
        
    resampled_tensor = loaded_resampler(tensor)
    return resampled_tensor[0].numpy()

def parse_dialogue(text):
    text = text.strip()
    pattern = r'([a-zA-Z0-9ㄱ-ㅎㅏ-ㅣ가-힣]+)\s*:\s*'
    matches = list(re.finditer(pattern, text))
    
    if not matches:
        return [{"speaker": "default", "text": text}]
        
    segments = []
    
    # Extract any instruction or introductory text before the first speaker tag (e.g. 제 1번. 다음을 듣고...)
    first_match_start = matches[0].start()
    if first_match_start > 0:
        intro_text = text[0:first_match_start].strip()
        if intro_text:
            segments.append({"speaker": "default", "text": intro_text})
            
    for i in range(len(matches)):
        start_idx = matches[i].end()
        end_idx = matches[i+1].start() if i + 1 < len(matches) else len(text)
        
        speaker = matches[i].group(1).strip()
        segment_text = text[start_idx:end_idx].strip()
        
        if segment_text:
            segments.append({"speaker": speaker, "text": segment_text})
            
    return segments

def get_speaker_config(speaker_name, index, default_speaker):
    name = speaker_name.lower().strip()
    if name == "default":
        name = default_speaker.lower().strip()
        
    is_female = name in ["여", "여성", "여자", "female", "girl", "woman", "여교사", "여학생", "a"]
    is_male = name in ["남", "남성", "남자", "male", "boy", "man", "남교사", "남학생", "b"]
    
    if not is_female and not is_male:
        if any(f in name for f in ["여", "female", "woman", "girl"]):
            is_female = True
        elif any(m in name for m in ["남", "male", "man", "boy"]):
            is_male = True
            
    if not is_female and not is_male:
        is_female = (index % 2 == 0)
        is_male = not is_female
        
    return "female" if is_female else "male"

async def generate_edge_tts_chunk(text, voice, rate_str, pitch_str, output_path):
    communicate = edge_tts.Communicate(text, voice, rate=rate_str, pitch=pitch_str)
    await communicate.save(output_path)

async def amain():
    parser = argparse.ArgumentParser(description="Hybrid Korean TTS (Edge Neural Online, VITS Offline Fallback)")
    parser.add_argument("--text", type=str, help="Text to synthesize")
    parser.add_argument("--file", type=str, help="Path to file containing text to synthesize")
    parser.add_argument("--output", type=str, required=True, help="Output WAV file path")
    parser.add_argument("--speaker", type=str, default="default", help="Default speaker name/gender")
    parser.add_argument("--pitch_female", type=float, default=0.85, help="Female pitch multiplier (offset in Hz for Edge)")
    parser.add_argument("--pitch_male", type=float, default=1.15, help="Male pitch multiplier (offset in Hz for Edge)")
    parser.add_argument("--speed", type=float, default=1.0, help="Speech speed factor")
    args = parser.parse_args()

    if args.file:
        with open(args.file, "r", encoding="utf-8") as f:
            text = f.read()
    elif args.text:
        text = args.text
    else:
        print("Error: Either --text or --file must be provided", file=sys.stderr)
        sys.exit(1)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Using device: {device}", file=sys.stderr)

    segments = parse_dialogue(text)
    audio_chunks = []
    
    target_sampling_rate = 16000
    silence_len = int(target_sampling_rate * 0.5)
    silence_chunk = np.zeros(silence_len, dtype=np.float32)

    for idx, seg in enumerate(segments):
        sp = seg["speaker"]
        txt = seg["text"]
        
        gender = get_speaker_config(sp, idx, args.speaker)
        chunk = None
        
        edge_voice = "ko-KR-SunHiNeural" if gender == "female" else "ko-KR-InJoonNeural"
        
        # Map parameters to Edge format
        speed_pct = int((args.speed - 1.0) * 100)
        rate_str = f"{speed_pct:+}%"
        
        pitch_val = args.pitch_female if gender == "female" else args.pitch_male
        pitch_hz = int((pitch_val - 1.0) * 50)
        pitch_str = f"{pitch_hz:+}Hz"
        
        temp_wav = os.path.join(os.path.dirname(os.path.abspath(args.output)), f"temp_edge_{uuid.uuid4()}.wav")
        
        try:
            print(f"Attempting Edge TTS for segment '{txt[:20]}...' using voice '{edge_voice}'...", file=sys.stderr)
            await generate_edge_tts_chunk(txt, edge_voice, rate_str, pitch_str, temp_wav)
            
            if os.path.exists(temp_wav):
                samples, sr = sf.read(temp_wav)
                chunk = resample_audio(samples, sr, target_sampling_rate)
                os.remove(temp_wav)
                print("Edge TTS generated successfully!", file=sys.stderr)
        except Exception as edge_err:
            print(f"Edge TTS failed ({edge_err}). Falling back to offline model...", file=sys.stderr)
            if os.path.exists(temp_wav):
                try:
                    os.remove(temp_wav)
                except:
                    pass

        # Fallback to local offline VITS
        if chunk is None:
            try:
                if gender == "female":
                    # Real female voice using Sherpa KSS model (22050Hz)
                    tts = get_sherpa_tts(args.speed)
                    audio = tts.generate(txt)
                    samples = np.array(audio.samples, dtype=np.float32)
                    chunk = resample_audio(samples, audio.sample_rate, target_sampling_rate)
                else:
                    # Male voice using Meta MMS model (16000Hz)
                    model, tokenizer = get_mms_model_and_tokenizer("facebook/mms-tts-kor", device)
                    
                    inputs = tokenizer(txt, return_tensors="pt")
                    inputs = {k: v.to(device) for k, v in inputs.items()}
                    
                    model.config.speaking_rate = args.speed
                    
                    with torch.no_grad():
                        output = model(**inputs)
                    
                    waveform = output.waveform[0].cpu()
                    
                    n_steps = -3.0 + (1.15 - args.pitch_male) * 10.0
                    if abs(n_steps) > 0.1:
                        waveform_2d = waveform.unsqueeze(0)
                        shifted_waveform_2d = torchaudio.functional.pitch_shift(
                            waveform_2d, 
                            sample_rate=target_sampling_rate, 
                            n_steps=n_steps
                        )
                        chunk = shifted_waveform_2d[0].numpy()
                    else:
                        chunk = waveform.numpy()
            except Exception as fallback_err:
                print(f"Offline fallback failed for segment '{txt}': {fallback_err}", file=sys.stderr)
                
        if chunk is not None:
            audio_chunks.append(chunk)
            if idx < len(segments) - 1:
                audio_chunks.append(silence_chunk)
        else:
            print(f"Error: Segment failed to synthesize: '{txt}'", file=sys.stderr)
            if idx < len(segments) - 1:
                audio_chunks.append(silence_chunk)

    if not audio_chunks:
        print("Error: No audio generated", file=sys.stderr)
        sys.exit(1)

    try:
        final_audio = np.concatenate(audio_chunks)
        os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
        sf.write(args.output, final_audio, samplerate=target_sampling_rate)
        print(f"Successfully generated: {args.output}")
    except Exception as e:
        print(f"Error saving file: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(amain())
