#!/usr/bin/env python3
"""
Download PP-OCRv6 Tiny ONNX models and character dictionary.

Requirements:
    pip install huggingface_hub pyyaml

Usage:
    python3 Scripts/convert_ppocr.py
"""

import os
import sys
import shutil
import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "Sources", "RenJistrolySystemBridge", "Resources")
HF_REPOS = {
    "PPOCRv6_det": "PaddlePaddle/PP-OCRv6_tiny_det_onnx",
    "PPOCRv6_rec": "PaddlePaddle/PP-OCRv6_tiny_rec_onnx",
}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    for name, repo in HF_REPOS.items():
        dest = os.path.join(OUT_DIR, f"{name}.onnx")
        if os.path.exists(dest):
            print(f"Already exists: {dest}")
            continue
        download_onnx(repo, dest)

    export_dict()
    print("\nDone. Models saved to:", OUT_DIR)


def download_onnx(repo, dest):
    from huggingface_hub import hf_hub_download
    print(f"Downloading {repo}/inference.onnx ...")
    downloaded = hf_hub_download(repo_id=repo, filename="inference.onnx")
    shutil.copy(downloaded, dest)
    print(f"  -> {dest}")


def export_dict():
    dict_path = os.path.join(OUT_DIR, "ppocr_chars.txt")
    if os.path.exists(dict_path):
        # Verify it has the right count
        with open(dict_path, encoding="utf-8") as f:
            count = sum(1 for _ in f)
        if count == 6905:
            print(f"Dictionary OK ({count} chars): {dict_path}")
            return

    # Try to extract from PaddleOCR model config
    chars = extract_from_paddleocr()
    if chars is None:
        chars = generate_minimal_dict()

    with open(dict_path, "w", encoding="utf-8") as f:
        f.write("\n".join(chars))
    print(f"Dictionary saved ({len(chars)} chars): {dict_path}")


def extract_from_paddleocr():
    """Extract character dictionary from PaddleOCR model inference.yml."""
    model_dir = os.path.expanduser("~/.paddleocr_models/PP-OCRv6_tiny_rec")
    yml_path = os.path.join(model_dir, "inference.yml")

    if not os.path.exists(yml_path):
        # Download model config first
        from huggingface_hub import snapshot_download
        model_dir = snapshot_download("PaddlePaddle/PP-OCRv6_tiny_rec", local_dir=model_dir)
        yml_path = os.path.join(model_dir, "inference.yml")

    if os.path.exists(yml_path):
        with open(yml_path, encoding="utf-8") as f:
            config = yaml.safe_load(f)
        chars = config.get("PostProcess", {}).get("character_dict", [])
        # YAML may drop the space character; add it back after '~'
        if " " not in chars:
            for i, c in enumerate(chars):
                if c == "~":
                    chars.insert(i + 1, " ")
                    break
        print(f"Extracted {len(chars)} chars from PaddleOCR model config")
        return chars

    return None


def generate_minimal_dict():
    """Fallback: generate minimal Chinese + ASCII + Japanese dictionary."""
    chars = []
    for c in range(32, 127):
        chars.append(chr(c))
    for c in range(0x4E00, 0x9FA6):
        chars.append(chr(c))
    for c in range(0x3040, 0x3097):
        chars.append(chr(c))
    for c in range(0x30A0, 0x30FB):
        chars.append(chr(c))
    return chars


if __name__ == "__main__":
    main()
