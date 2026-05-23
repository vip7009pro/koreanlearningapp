import sys
import os
import argparse
import re
import numpy as np
import torch
import soundfile as sf
from transformers import VitsModel, AutoTokenizer
import uroman

loaded_models = {}
loaded_tokenizers = {}
uroman_instance = None

def get_uroman():
    global uroman_instance
    if uroman_instance is None:
        uroman_instance = uroman.Uroman()
    return uroman_instance

def get_model_and_tokenizer(model_name, device):
    if model_name not in loaded_models:
        print(f"Loading model '{model_name}' on device '{device}'...", file=sys.stderr)
        try:
            model = VitsModel.from_pretrained(model_name).to(device)
            tokenizer = AutoTokenizer.from_pretrained(model_name)
            loaded_models[model_name] = model
            loaded_tokenizers[model_name] = tokenizer
        except Exception as e:
            print(f"Error loading model {model_name}: {e}", file=sys.stderr)
            sys.exit(1)
    return loaded_models[model_name], loaded_tokenizers[model_name]

def parse_dialogue(text):
    text = text.strip()
    pattern = r'([a-zA-Z0-9ㄱ-ㅎㅏ-ㅣ가-힣]+)\s*:\s*'
    matches = list(re.finditer(pattern, text))
    
    if not matches:
        return [{"speaker": "default", "text": text}]
        
    segments = []
    for i in range(len(matches)):
        start_idx = matches[i].end()
        end_idx = matches[i+1].start() if i + 1 < len(matches) else len(text)
        
        speaker = matches[i].group(1).strip()
        segment_text = text[start_idx:end_idx].strip()
        
        if segment_text:
            segments.append({"speaker": speaker, "text": segment_text})
            
    return segments

def get_speaker_config(speaker_name, index, default_speaker, pitch_female, pitch_male):
    name = speaker_name.lower().strip()
    if name == "default":
        name = default_speaker.lower().strip()
        
    is_female = name in ["여", "여성", "여자", "female", "girl", "woman", "여교사", "여학생", "a"]
    is_male = name in ["남", "남성", "남자", "male", "boy", "man", "남교사", "남학생", "b"]
    
    # Check common prefixes or sub-strings just in case
    if not is_female and not is_male:
        if any(f in name for f in ["여", "female", "woman", "girl"]):
            is_female = True
        elif any(m in name for m in ["남", "male", "man", "boy"]):
            is_male = True
            
    # Alternating fallback
    if not is_female and not is_male:
        is_female = (index % 2 == 0)
        is_male = not is_female
        
    if is_female:
        # Use mms-tts-kss for high-quality real female voice
        # Since it is a real female voice, we keep pitch close to 1.0 (no distortion)
        # If user adjusted pitch_female away from default 0.85, we can adjust it relatively
        relative_pitch = 1.0
        if abs(pitch_female - 0.85) > 0.01:
            relative_pitch = 1.0 + (pitch_female - 0.85)
        return "facebook/mms-tts-kss", relative_pitch, True
    else:
        # Use mms-tts-kor for male voice (with pitch shifting if configured)
        return "facebook/mms-tts-kor", pitch_male, False

def main():
    parser = argparse.ArgumentParser(description="Local Korean TTS synthesis using VITS with KSS real female voice")
    parser.add_argument("--text", type=str, help="Text to synthesize")
    parser.add_argument("--file", type=str, help="Path to file containing text to synthesize")
    parser.add_argument("--output", type=str, required=True, help="Output WAV file path")
    parser.add_argument("--speaker", type=str, default="default", help="Default speaker name/gender")
    parser.add_argument("--pitch_female", type=float, default=0.85, help="Female pitch ratio (0.85 default)")
    parser.add_argument("--pitch_male", type=float, default=1.15, help="Male pitch ratio (1.15 default)")
    parser.add_argument("--speed", type=float, default=1.0, help="Speech speed factor (smaller = slower)")
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
    
    # 0.5 seconds of silence between speakers (both models use 16000Hz sampling rate)
    sampling_rate = 16000
    silence_len = int(sampling_rate * 0.5)
    silence_chunk = np.zeros(silence_len, dtype=np.float32)

    for idx, seg in enumerate(segments):
        sp = seg["speaker"]
        txt = seg["text"]
        
        # Resolve speaker config
        model_name, pitch_ratio, is_kss = get_speaker_config(
            sp, idx, args.speaker, args.pitch_female, args.pitch_male
        )
        
        try:
            model, tokenizer = get_model_and_tokenizer(model_name, device)
            
            # For mms-tts-kss, we must romanize using uroman before passing to the tokenizer
            if is_kss:
                u = get_uroman()
                processed_text = u.romanize_string(txt)
            else:
                processed_text = txt
                
            inputs = tokenizer(processed_text, return_tensors="pt")
            inputs = {k: v.to(device) for k, v in inputs.items()}
            
            # Combine pitch ratio with user-defined speed factor
            # speaking_rate = pitch_ratio * speed
            model.config.speaking_rate = pitch_ratio * args.speed
            
            with torch.no_grad():
                output = model(**inputs)
            
            # Extract waveform tensor and move to CPU
            waveform = output.waveform[0].cpu()
            
            # If pitch shifting is required (pitch_ratio != 1.0)
            if abs(pitch_ratio - 1.0) > 0.01:
                T = len(waveform)
                new_T = int(T * pitch_ratio)
                
                # Perform linear interpolation to pitch shift while restoring speed
                waveform_3d = waveform.unsqueeze(0).unsqueeze(0)
                resampled_3d = torch.nn.functional.interpolate(
                    waveform_3d, 
                    size=new_T, 
                    mode='linear', 
                    align_corners=False
                )
                chunk = resampled_3d[0, 0].numpy()
            else:
                chunk = waveform.numpy()
                
            audio_chunks.append(chunk)
            
            # Add silence between segments
            if idx < len(segments) - 1:
                audio_chunks.append(silence_chunk)
        except Exception as e:
            print(f"Error synthesizing segment '{txt}' for speaker '{sp}' using model '{model_name}': {e}", file=sys.stderr)
            if idx < len(segments) - 1:
                audio_chunks.append(silence_chunk)

    if not audio_chunks:
        print("Error: No audio generated", file=sys.stderr)
        sys.exit(1)

    try:
        final_audio = np.concatenate(audio_chunks)
        os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
        sf.write(args.output, final_audio, samplerate=sampling_rate)
        print(f"Successfully generated: {args.output}")
    except Exception as e:
        print(f"Error saving file: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
