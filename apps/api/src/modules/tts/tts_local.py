import sys
import os
import argparse
import re
import numpy as np
import torch
import soundfile as sf
from transformers import VitsModel, AutoTokenizer
import torchaudio

loaded_model = None
loaded_tokenizer = None

def get_model_and_tokenizer(model_name, device):
    global loaded_model, loaded_tokenizer
    if loaded_model is None:
        print(f"Loading model '{model_name}' on device '{device}'...", file=sys.stderr)
        try:
            loaded_model = VitsModel.from_pretrained(model_name).to(device)
            loaded_tokenizer = AutoTokenizer.from_pretrained(model_name)
        except Exception as e:
            print(f"Error loading model {model_name}: {e}", file=sys.stderr)
            sys.exit(1)
    return loaded_model, loaded_tokenizer

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

def get_speaker_pitch_steps(speaker_name, index, default_speaker, pitch_female, pitch_male):
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
            
    # Alternating fallback
    if not is_female and not is_male:
        is_female = (index % 2 == 0)
        is_male = not is_female
        
    if is_female:
        # Convert pitch_female to semitones. 
        # Default pitch_female=0.85 translates to +4.0 semitones.
        # Smaller pitch_female value translates to higher pitch (more positive semitones).
        semitones = 4.0 + (0.85 - pitch_female) * 10.0
        return semitones
    else:
        # Convert pitch_male to semitones.
        # Default pitch_male=1.15 translates to -3.0 semitones.
        # Larger pitch_male value translates to lower pitch (more negative semitones).
        semitones = -3.0 + (1.15 - pitch_male) * 10.0
        return semitones

def main():
    parser = argparse.ArgumentParser(description="Local Korean TTS synthesis using VITS with high-quality torchaudio pitch-shifting")
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

    model_name = "facebook/mms-tts-kor"
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Using device: {device}", file=sys.stderr)

    segments = parse_dialogue(text)
    audio_chunks = []
    
    # 0.5 seconds of silence between speakers (16000Hz sampling rate)
    sampling_rate = 16000
    silence_len = int(sampling_rate * 0.5)
    silence_chunk = np.zeros(silence_len, dtype=np.float32)

    model, tokenizer = get_model_and_tokenizer(model_name, device)

    for idx, seg in enumerate(segments):
        sp = seg["speaker"]
        txt = seg["text"]
        
        # Calculate semitone shifts based on speaker configuration
        n_steps = get_speaker_pitch_steps(
            sp, idx, args.speaker, args.pitch_female, args.pitch_male
        )
        
        try:
            inputs = tokenizer(txt, return_tensors="pt")
            inputs = {k: v.to(device) for k, v in inputs.items()}
            
            # Apply only speaking speed factor directly to the VITS model configuration
            model.config.speaking_rate = args.speed
            
            with torch.no_grad():
                output = model(**inputs)
            
            # Extract waveform tensor and move to CPU
            waveform = output.waveform[0].cpu() # shape: [T]
            
            # Apply torchaudio high-quality pitch shift
            if abs(n_steps) > 0.1:
                # Add channel dimension: [1, T]
                waveform_2d = waveform.unsqueeze(0)
                shifted_waveform_2d = torchaudio.functional.pitch_shift(
                    waveform_2d, 
                    sample_rate=sampling_rate, 
                    n_steps=n_steps
                )
                chunk = shifted_waveform_2d[0].numpy()
            else:
                chunk = waveform.numpy()
                
            audio_chunks.append(chunk)
            
            # Add silence between segments
            if idx < len(segments) - 1:
                audio_chunks.append(silence_chunk)
        except Exception as e:
            print(f"Error synthesizing segment '{txt}' for speaker '{sp}': {e}", file=sys.stderr)
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
