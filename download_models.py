from huggingface_hub import snapshot_download
import sys

print("Downloading offline TTS models...")
try:
    print("1. Downloading Sherpa KSS ONNX model (csukuangfj/vits-mimic3-ko_KO-kss_low)...")
    snapshot_download(repo_id="csukuangfj/vits-mimic3-ko_KO-kss_low")
    
    print("2. Downloading Meta MMS Korean model (facebook/mms-tts-kor)...")
    from transformers import VitsModel, AutoTokenizer
    VitsModel.from_pretrained("facebook/mms-tts-kor")
    AutoTokenizer.from_pretrained("facebook/mms-tts-kor")
    
    print("All offline models downloaded and cached successfully!")
except Exception as e:
    print(f"Error downloading models: {e}", file=sys.stderr)
    sys.exit(1)
