import sys
import os
import argparse
import re
import numpy as np
import torch
import soundfile as sf
from transformers import VitsModel, AutoTokenizer

def parse_dialogue(text):
    """
    Parses dialogue text into segments of (speaker, text).
    Example: "남: 안녕하세요. 여: 반갑습니다." ->
    [{"speaker": "남", "text": "안녕하세요."}, {"speaker": "여", "text": "반갑습니다."}]
    """
    text = text.strip()
    # Find all speaker tags like "남:", "여:", "남성:", "여성:", "A:", "B:"
    # We split by these tags but keep track of who is speaking
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

def get_pitch_ratio(speaker_name, index, pitch_female, pitch_male):
    """
    Determines the pitch ratio and speed compensation for a speaker.
    - Ratio > 1.0 shifts pitch down (deeper/male).
    - Ratio < 1.0 shifts pitch up (higher/female).
    """
    name = speaker_name.lower().strip()
    if name in ["여", "여성", "여자", "female", "girl", "woman", "여교사", "여학생", "a"]:
        return pitch_female
    if name in ["남", "남성", "남자", "male", "boy", "man", "남교사", "남학생", "b"]:
        return pitch_male
    # Alternating fallback if speaker names are neutral or arbitrary
    return pitch_female if index % 2 == 0 else pitch_male

def main():
    parser = argparse.ArgumentParser(description="Local Korean TTS synthesis using VITS with pitch-shifted voices")
    parser.add_argument("--text", type=str, help="Text to synthesize")
    parser.add_argument("--file", type=str, help="Path to file containing text to synthesize")
    parser.add_argument("--output", type=str, required=True, help="Output WAV file path")
    parser.add_argument("--speaker", type=str, default="default", help="Default speaker name/gender")
    parser.add_argument("--pitch_female", type=float, default=0.85, help="Female pitch ratio (smaller = higher pitch)")
    parser.add_argument("--pitch_male", type=float, default=1.15, help="Male pitch ratio (larger = deeper pitch)")
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
    
    try:
        # Load model and tokenizer
        model = VitsModel.from_pretrained(model_name).to(device)
        tokenizer = AutoTokenizer.from_pretrained(model_name)
        sampling_rate = model.config.sampling_rate
    except Exception as e:
        print(f"Error loading model: {e}", file=sys.stderr)
        sys.exit(1)

    segments = parse_dialogue(text)
    
    audio_chunks = []
    # 0.5 seconds of silence between speakers
    silence_len = int(sampling_rate * 0.5)
    silence_chunk = np.zeros(silence_len, dtype=np.float32)

    for idx, seg in enumerate(segments):
        sp = seg["speaker"]
        txt = seg["text"]
        
        # Determine pitch ratio based on speaker
        if sp == "default":
            pitch_ratio = get_pitch_ratio(args.speaker, idx, args.pitch_female, args.pitch_male)
        else:
            pitch_ratio = get_pitch_ratio(sp, idx, args.pitch_female, args.pitch_male)
            
        try:
            inputs = tokenizer(txt, return_tensors="pt")
            inputs = {k: v.to(device) for k, v in inputs.items()}
            
            # Combine pitch ratio with user-defined speed factor
            # speaking_rate = pitch_ratio * speed
            model.config.speaking_rate = pitch_ratio * args.speed
            
            with torch.no_grad():
                output = model(**inputs)
            
            # Extract waveform tensor and move to CPU
            waveform = output.waveform[0].cpu()
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
