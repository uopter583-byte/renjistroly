#!/usr/bin/env python3
"""
Export Nemotron 3.5 ASR to ONNX for macOS/ONNX Runtime integration.

Usage:
    export PATH="$HOME/Library/Python/3.9/bin:$PATH"
    python3 Scripts/export_nemotron_onnx.py --model-path /path/to/nemotron.nemo

Steps:
    1. Load model from .nemo (patching config for NeMo 1.21.0 compat)
    2. Export pre_encode, conformer, decoder, joint, prompt as separate ONNX files
    3. Save preprocessor config & tokenizer for Swift side

Output:
    Sources/RenJistrolySystemBridge/Resources/NemotronASR/
"""

import argparse
import copy
import json
import os
import sys
import tarfile
import tempfile
import yaml

import torch
import torch.nn as nn
from omegaconf import DictConfig

DEFAULT_OUTPUT_DIR = "Sources/RenJistrolySystemBridge/Resources/NemotronASR"
DEFAULT_MODEL_PATH = (
    "/Users/yoming/.cache/huggingface/hub/models--nvidia--nemotron-3.5-asr-streaming-0.6b/"
    "snapshots/3fc30f3e2ae5d78d462441f3ce89dda694f89bd7/nemotron-3.5-asr-streaming-0.6b.nemo"
)

OUTPUT_DIR = DEFAULT_OUTPUT_DIR
MODEL_PATH = os.environ.get("NEMOTRON_NEMO_PATH", DEFAULT_MODEL_PATH)

# ---- config patching for NeMo 1.21.0 compat ----
REMOVE_KEYS_ENCODER = [
    "use_bias",
    "dropout_pre_encoder",
    "dropout_emb",
    "dropout_att",
    "stochastic_depth_drop_prob",
    "stochastic_depth_mode",
    "stochastic_depth_start_layer",
]
REMOVE_KEYS_MODEL = [
    "interctc",
    "variational_noise",
    "aux_ctc",
    "fuse_loss_wer",
]


def patch_config(cfg: dict) -> dict:
    """Remove keys that exist in NeMo 2.x but not in 1.21.0."""
    cfg = copy.deepcopy(cfg)

    enc = cfg.get("encoder", {})
    for k in REMOVE_KEYS_ENCODER:
        enc.pop(k, None)
    cfg["encoder"] = enc

    dec = cfg.get("decoder", {})
    if "normalization_mode" in dec and dec["normalization_mode"] is None:
        dec.pop("normalization_mode", None)
    if "random_state_sampling" in dec and dec["random_state_sampling"] is False:
        dec.pop("random_state_sampling", None)
    cfg["decoder"] = dec

    for k in REMOVE_KEYS_MODEL:
        cfg.pop(k, None)

    joint = cfg.get("joint", {})
    joint.pop("fuse_loss_wer", None)
    cfg["joint"] = joint

    cfg["restore_strict"] = False
    return cfg


def load_model():
    """Extract, patch config, and restore the model."""
    print(f"Step 0: Loading model from {os.path.basename(MODEL_PATH)}")
    tmpdir = tempfile.mkdtemp()
    with tarfile.open(MODEL_PATH, "r") as tar:
        tar.extractall(tmpdir)

    config_path = os.path.join(tmpdir, "model_config.yaml")
    with open(config_path) as f:
        config = yaml.safe_load(f)

    patched = patch_config(config)

    patched_path = os.path.join(tmpdir, "model_config_patched.yaml")
    with open(patched_path, "w") as f:
        yaml.dump(patched, f)

    nemo_tmp = os.path.join(tmpdir, "patched.nemo")
    with tarfile.open(nemo_tmp, "w") as tar:
        tar.add(patched_path, arcname="model_config.yaml")
        tar.add(os.path.join(tmpdir, "model_weights.ckpt"), arcname="model_weights.ckpt")
        for fn in os.listdir(tmpdir):
            if fn.endswith(".model"):
                tar.add(os.path.join(tmpdir, fn), arcname=fn)
            elif fn.endswith(".txt") and "vocab" in fn:
                tar.add(os.path.join(tmpdir, fn), arcname=fn)

    from nemo.collections.asr.models.rnnt_bpe_models_prompt import EncDecRNNTBPEModelWithPrompt

    model = EncDecRNNTBPEModelWithPrompt.restore_from(
        nemo_tmp, map_location="cpu", strict=False,
    )

    ckpt = torch.load(os.path.join(tmpdir, "model_weights.ckpt"), map_location="cpu")

    # Zero out missing bias keys
    ckpt_keys = set(ckpt.keys())
    for name, param in model.named_parameters():
        if "bias" in name and name not in ckpt_keys:
            param.data.zero_()
    en_bias_zero = sum(
        1 for n, _ in model.named_parameters()
        if "bias" in n and n not in ckpt_keys
    )
    print(f"  Zeroed {en_bias_zero} missing bias params (checkpoint use_bias=False)")

    # Build prompt module from checkpoint weights
    prompt_embedding = nn.Embedding(128, 1152)
    prompt_kernel = nn.Sequential(
        nn.Linear(1152, 2048),
        nn.ReLU(),
        nn.Linear(2048, model.encoder.d_model),
    )
    pk = ckpt
    prompt_kernel[0].load_state_dict({
        "weight": pk["prompt_kernel.0.weight"],
        "bias": pk["prompt_kernel.0.bias"],
    })
    prompt_kernel[2].load_state_dict({
        "weight": pk["prompt_kernel.2.weight"],
        "bias": pk["prompt_kernel.2.bias"],
    })
    model.prompt_embedding = prompt_embedding
    model.prompt_kernel = prompt_kernel
    model.prompt_dictionary = patched.get("model_defaults", patched).get("prompt_dictionary", {})

    if hasattr(model.joint, '_fuse_loss_wer'):
        model.joint._fuse_loss_wer = False

    model.freeze()
    model.eval()
    print(f"  Model loaded: {type(model).__name__}")
    print(f"  Encoder: {type(model.encoder).__name__} (d_model={model.encoder.d_model})")
    print(f"  Decoder: {type(model.decoder).__name__} (pred_hidden={model.decoder.pred_hidden})")
    print(f"  Joint:   {type(model.joint).__name__} (hidden={model.joint.joint_hidden})")
    print(f"  Vocab:   {model.joint.num_classes_with_blank - 1} tokens + blank")
    print(f"  Prompts: Embedding(128, 1152) + MLP(1152->2048->{model.encoder.d_model})")

    _inspect_encoder(model)
    return model, tmpdir


def _inspect_encoder(model):
    """Print encoder internals for debugging."""
    enc = model.encoder
    pre = enc.pre_encode
    print(f"  pre_encode: {type(pre).__name__}")
    if hasattr(pre, '_subsampling'):
        print(f"    subsampling={pre._subsampling}, conv2d={pre.conv2d_subsampling}"
              f", sampling_num={pre._sampling_num}, feat_in={pre._feat_in}"
              f", feat_out={pre._feat_out}, conv_channels={pre._conv_channels}")
    print(f"  pos_enc: {type(enc.pos_enc).__name__}")
    print(f"  att_context_size: {getattr(enc, 'att_context_size', 'N/A')}"
          f", self_attention_model: {getattr(enc, 'self_attention_model', 'N/A')}"
          f", att_context_style: {getattr(enc, 'att_context_style', 'N/A')}")
    print(f"  n_layers: {getattr(enc, 'n_layers', len(enc.layers))}"
          f", d_model={enc.d_model}")


# ============================================================
# Export sub-components to ONNX
# ============================================================

def export_pre_encode(model, device="cpu"):
    """Export ConvSubsampling as pre_encode.onnx.

    Internally ConvSubsampling expects (B, T, C) input (time-major) because the
    encoder's forward_internal transposes (B, C, T) → (B, T, C) before calling it.
    This wrapper accepts (B, C, T), transposes internally, and returns
    (B, d_model, T') (channel-major) to match the existing pipeline expectation.

    Chain: (audio_signal: (B, feat_in, T), length: (B,))
        -> (x: (B, d_model, T'), length: (B,))
    """
    print("\nStep 1: Exporting pre_encode (ConvSubsampling) to ONNX ...")

    pre_encode = model.encoder.pre_encode
    d_model, feat_in = model.encoder.d_model, model.encoder._feat_in

    class PreEncodeExport(nn.Module):
        def __init__(self, pre_encode):
            super().__init__()
            self.pre_encode = pre_encode

        def forward(self, audio_signal, length):
            # audio_signal: (B, C, T)  — channel-first input
            # ConvSubsampling expects (B, T, C) internally
            x = audio_signal.transpose(1, 2)  # (B, C, T) → (B, T, C)
            x, length = self.pre_encode(x, length)
            # x is (B, T', d_model) — transpose back to (B, d_model, T')
            x = x.transpose(1, 2)
            return x, length

    wrapped = PreEncodeExport(pre_encode).to(device)
    wrapped.eval()

    B, C, T = 1, feat_in, 200
    dummy_features = torch.randn(B, C, T)
    dummy_lengths = torch.tensor([T])

    onnx_path = os.path.join(OUTPUT_DIR, "pre_encode.onnx")
    torch.onnx.export(
        wrapped,
        (dummy_features, dummy_lengths),
        onnx_path,
        input_names=["audio_signal", "length"],
        output_names=["encoded", "encoded_lengths"],
        dynamic_axes={
            "audio_signal": {0: "batch", 2: "time"},
            "length": {0: "batch"},
            "encoded": {0: "batch", 2: "time"},
            "encoded_lengths": {0: "batch"},
        },
        opset_version=17,
        verbose=False,
    )
    size_mb = os.path.getsize(onnx_path) / (1024 * 1024)
    print(f"  Saved pre_encode.onnx ({size_mb:.1f} MB)")
    return onnx_path


def export_conformer(model, device="cpu"):
    """Export pos_enc + ConformerLayer blocks as conformer.onnx.

    Includes the position encoder (pos_enc), mask creation, and all 24
    ConformerLayer blocks in one ONNX model for correctness.

    Chain: (x: (B, d_model, T'), length: (B,))
        -> (x: (B, d_model, T'), length: (B,))
    """
    print("\nStep 2: Exporting conformer (pos_enc + layers) to ONNX ...")

    encoder = model.encoder
    att_ctx = getattr(encoder, 'att_context_size', [-1, -1])
    att_model = getattr(encoder, 'self_attention_model', 'rel_pos')
    ctx_style = getattr(encoder, 'att_context_style', 'regular')

    class ConformerExport(nn.Module):
        def __init__(self, encoder):
            super().__init__()
            # Store submodules directly (not as "self.encoder") so that external
            # data filenames use clean paths like "layers.0.conv.*" instead of
            # "encoder.layers.0.conv.*".
            self.pos_enc = encoder.pos_enc
            self.layers = encoder.layers
            self.att_context_size = att_ctx
            self.self_attention_model = att_model
            self.att_context_style = ctx_style

        def forward(self, x, length):
            # x: (B, d_model, T')  → transpose to (B, T', d_model)
            x = x.transpose(1, 2)

            # Positional encoding
            x, pos_emb = self.pos_enc(x=x, cache_len=0)

            max_len = x.size(1)

            # Build att_mask (triangular with context window)
            if self.self_attention_model != "rel_pos_local_attn":
                am = torch.ones(1, max_len, max_len, dtype=torch.bool, device=x.device)
                ctx = self.att_context_size
                if ctx[0] >= 0:
                    am = am.triu(diagonal=-ctx[0])
                if ctx[1] >= 0:
                    am = am.tril(diagonal=ctx[1])
            else:
                am = None

            # Build pad_mask from lengths
            pm = torch.arange(0, max_len, device=x.device).expand(
                length.size(0), -1
            ) < length.unsqueeze(-1)
            pm = ~pm

            # Combine att_mask with padding mask
            if am is not None:
                pfa = pm.unsqueeze(1).repeat(1, max_len, 1)
                pfa = pfa & pfa.transpose(1, 2)
                am = am[:, :max_len, :max_len]
                am = pfa & am.to(pfa.device)
                am = ~am

            # Conformer layers
            for layer in self.layers:
                x = layer(x=x, att_mask=am, pos_emb=pos_emb, pad_mask=pm)

            # Transpose back to (B, d_model, T')
            x = x.transpose(1, 2)
            length = length.to(torch.int64)

            return x, length

    # Export in fp32. External data files are unavoidable for a 0.6B parameter
    # model — the ONNX protobuf has a 2GB limit (~0.5B fp32 params inline).
    # The Swift ONNX runtime handles external data natively.
    wrapped = ConformerExport(encoder).to(device)
    wrapped.eval()

    B, D = 1, encoder.d_model
    T_prime = 25
    dummy_x = torch.randn(B, D, T_prime)
    dummy_length = torch.tensor([T_prime])

    onnx_path = os.path.join(OUTPUT_DIR, "conformer.onnx")
    torch.onnx.export(
        wrapped,
        (dummy_x, dummy_length),
        onnx_path,
        input_names=["encoder_input", "length"],
        output_names=["encoded", "encoded_lengths"],
        dynamic_axes={
            "encoder_input": {0: "batch", 2: "time"},
            "length": {0: "batch"},
            "encoded": {0: "batch", 2: "time"},
            "encoded_lengths": {0: "batch"},
        },
        opset_version=17,
        verbose=False,
    )
    size_mb = os.path.getsize(onnx_path) / (1024 * 1024)
    print(f"  Saved conformer.onnx ({size_mb:.1f} MB)")
    return onnx_path


def export_decoder(model, device="cpu"):
    """Export the RNNTDecoder (prediction network + state)."""
    print("\nStep 3: Exporting decoder to ONNX ...")

    class DecoderExport(nn.Module):
        def __init__(self, decoder):
            super().__init__()
            self.decoder = decoder

        def forward(self, targets, target_length, state_h, state_c):
            states = [state_h, state_c] if state_h is not None else None
            g, tl, new_states = self.decoder(
                targets=targets, target_length=target_length, states=states
            )
            return g, new_states[0], new_states[1]

    wrapped = DecoderExport(model.decoder).to(device)
    wrapped.eval()

    B, U, D = 1, 1, model.decoder.pred_hidden
    num_layers = getattr(model.decoder, "num_layers", 2)
    dummy_targets = torch.zeros(B, U, dtype=torch.long)
    dummy_length = torch.tensor([U])
    dummy_state_h = torch.zeros(num_layers, B, D)
    dummy_state_c = torch.zeros(num_layers, B, D)

    onnx_path = os.path.join(OUTPUT_DIR, "decoder.onnx")
    torch.onnx.export(
        wrapped,
        (dummy_targets, dummy_length, dummy_state_h, dummy_state_c),
        onnx_path,
        input_names=["targets", "target_length", "state_h", "state_c"],
        output_names=["g", "new_state_h", "new_state_c"],
        dynamic_axes={
            "targets": {0: "batch", 1: "time"},
            "target_length": {0: "batch"},
            "state_h": {0: "layers", 1: "batch"},
            "state_c": {0: "layers", 1: "batch"},
            "g": {0: "batch", 2: "time"},
            "new_state_h": {1: "batch"},
            "new_state_c": {1: "batch"},
        },
        opset_version=17,
        verbose=False,
    )
    size_mb = os.path.getsize(onnx_path) / (1024 * 1024)
    print(f"  Saved decoder.onnx ({size_mb:.1f} MB)")
    return onnx_path


def export_joint(model, device="cpu"):
    """Export the RNNTJoint network."""
    print("\nStep 5: Exporting joint network to ONNX ...")

    class JointExport(nn.Module):
        def __init__(self, joint):
            super().__init__()
            self.joint = joint

        def forward(self, encoder_out, decoder_out):
            logits = self.joint(encoder_outputs=encoder_out, decoder_outputs=decoder_out)
            return logits

    wrapped = JointExport(model.joint).to(device)
    wrapped.eval()

    B, D_enc, T, D_dec, U = 1, model.encoder.d_model, 200, model.decoder.pred_hidden, 1
    dummy_enc = torch.randn(B, D_enc, T)
    dummy_dec = torch.randn(B, D_dec, U)

    onnx_path = os.path.join(OUTPUT_DIR, "joint.onnx")
    torch.onnx.export(
        wrapped,
        (dummy_enc, dummy_dec),
        onnx_path,
        input_names=["encoder_out", "decoder_out"],
        output_names=["logits"],
        dynamic_axes={
            "encoder_out": {0: "batch", 1: "d_enc", 2: "time"},
            "decoder_out": {0: "batch", 1: "d_dec", 2: "dec_time"},
            "logits": {0: "batch", 1: "time", 2: "dec_time"},
        },
        opset_version=17,
        verbose=False,
    )
    size_mb = os.path.getsize(onnx_path) / (1024 * 1024)
    print(f"  Saved joint.onnx ({size_mb:.1f} MB)")
    return onnx_path


def export_prompt(model, device="cpu"):
    """Export the prompt embedding + MLP as a single ONNX."""
    print("\nStep 4: Exporting prompt network to ONNX ...")

    class PromptExport(nn.Module):
        def __init__(self, embedding, kernel):
            super().__init__()
            self.embedding = embedding
            self.kernel = kernel

        def forward(self, prompt_idx):
            prompt = self.embedding(prompt_idx)
            prompt = self.kernel(prompt)
            return prompt

    wrapped = PromptExport(model.prompt_embedding, model.prompt_kernel).to(device)
    wrapped.eval()

    dummy_idx = torch.tensor([4], dtype=torch.long)  # (1,)

    onnx_path = os.path.join(OUTPUT_DIR, "prompt.onnx")
    torch.onnx.export(
        wrapped,
        (dummy_idx,),
        onnx_path,
        input_names=["prompt_idx"],
        output_names=["prompt_vector"],
        dynamic_axes={
            "prompt_idx": {0: "batch"},
            "prompt_vector": {0: "batch"},
        },
        opset_version=17,
        verbose=False,
    )
    size_mb = os.path.getsize(onnx_path) / (1024 * 1024)
    print(f"  Saved prompt.onnx ({size_mb:.1f} MB)")
    return onnx_path


def save_metadata(model):
    """Save preprocessor config and tokenizer for Swift."""
    print("\nStep 6: Saving metadata ...")

    cfg = model.cfg
    preproc = {
        "sample_rate": int(cfg.preprocessor.sample_rate),
        "window_size": float(cfg.preprocessor.window_size),
        "window_stride": float(cfg.preprocessor.window_stride),
        "features": int(cfg.preprocessor.features) if hasattr(cfg.preprocessor, "features") else 128,
        "n_fft": int(getattr(cfg.preprocessor, "n_fft", 512)),
        "dither": float(getattr(cfg.preprocessor, "dither", 0.0)),
        "normalize": str(getattr(cfg.preprocessor, "normalize", "NA")),
        "frame_splicing": int(getattr(cfg.preprocessor, "frame_splicing", 1)),
    }
    with open(os.path.join(OUTPUT_DIR, "preprocessor.json"), "w") as f:
        json.dump(preproc, f, indent=2)
    print(f"  Preprocessor: {preproc}")

    tok_info = {
        "vocab_size": model.joint.num_classes_with_blank,
        "blank_id": 0,
        "type": "bpe",
    }
    with open(os.path.join(OUTPUT_DIR, "tokenizer.json"), "w") as f:
        json.dump(tok_info, f, indent=2)

    if hasattr(model, "tokenizer") and model.tokenizer is not None:
        tokens = model.tokenizer.vocab
        with open(os.path.join(OUTPUT_DIR, "tokens.txt"), "w") as f:
            for t in tokens:
                f.write(f"{t}\n")
        print(f"  Vocabulary: {len(tokens)} tokens")

    pcfg = cfg.get("model_defaults", cfg)
    def _to_json_safe(v):
        if isinstance(v, (dict, DictConfig)):
            return {k: _to_json_safe(v) for k, v in v.items()}
        return v
    prompts = {
        "num_prompts": int(pcfg.get("num_prompts", 128)),
        "dictionary": _to_json_safe(pcfg.get("prompt_dictionary", {})),
    }
    with open(os.path.join(OUTPUT_DIR, "prompts.json"), "w") as f:
        json.dump(prompts, f, indent=2)
    print(f"  Language prompts: {len(prompts['dictionary'])} langs")

    model_info = {
        "name": "Nemotron 3.5 ASR",
        "version": "0.6B",
        "encoder": "FastConformer",
        "encoder_dim": model.encoder.d_model,
        "encoder_layers": model.encoder.n_layers if hasattr(model.encoder, "n_layers") else 24,
        "subsampling_factor": int(getattr(cfg.encoder, "subsampling_factor", 8)),
        "decoder_dim": model.decoder.pred_hidden,
        "joint_dim": model.joint.joint_hidden,
        "sample_rate": int(cfg.preprocessor.sample_rate),
    }
    with open(os.path.join(OUTPUT_DIR, "model_info.json"), "w") as f:
        json.dump(model_info, f, indent=2)
    print(f"  Model info saved")


def clean_output_directory():
    """Remove stale external data files and old encoder.onnx.

    Keeps: decoder.onnx, joint.onnx, prompt.onnx, pre_encode.onnx,
           conformer.onnx, *.json, tokens.txt
    Removes: encoder.onnx, onnx__*, layers.*, pre_encode.*, Constant_*
    """
    print("\nStep 0.5: Cleaning output directory ...")
    keep_names = {
        "decoder.onnx", "joint.onnx", "prompt.onnx",
        "pre_encode.onnx", "conformer.onnx",
    }
    removed = 0
    kept = 0
    for fn in list(os.listdir(OUTPUT_DIR)):
        fpath = os.path.join(OUTPUT_DIR, fn)
        if not os.path.isfile(fpath):
            continue
        if fn in keep_names or fn.endswith(".json") or fn == "tokens.txt":
            kept += 1
            continue
        os.remove(fpath)
        removed += 1
    print(f"  Removed {removed} stale files, kept {kept} files")


def verify_onnx():
    """Verify exported ONNX files can be loaded by onnxruntime."""
    print("\nStep 7: Verifying ONNX files ...")
    try:
        import onnxruntime as ort
    except ImportError:
        print("  (onnxruntime not available - skipping verification)")
        return

    for name in ["pre_encode", "conformer", "decoder", "joint", "prompt"]:
        fpath = os.path.join(OUTPUT_DIR, f"{name}.onnx")
        if not os.path.exists(fpath):
            print(f"  WARNING: {fpath} not found!")
            continue
        try:
            session = ort.InferenceSession(fpath)
            print(f"  {name}.onnx:")
            for i, inp in enumerate(session.get_inputs()):
                print(f"    Input[{i}]:  {inp.name} {inp.shape}")
            for i, out in enumerate(session.get_outputs()):
                print(f"    Output[{i}]: {out.name} {out.shape}")
        except Exception as e:
            print(f"    FAILED: {e}")


def list_output_files():
    """Show final state of the output directory."""
    print(f"\n--- Files in {OUTPUT_DIR}/ ---")
    total_mb = 0
    for fn in sorted(os.listdir(OUTPUT_DIR)):
        fpath = os.path.join(OUTPUT_DIR, fn)
        if os.path.isfile(fpath):
            size_mb = os.path.getsize(fpath) / (1024 * 1024)
            total_mb += size_mb
            print(f"  {fn:40s} {size_mb:8.1f} MB")
    print(f"  {'TOTAL':40s} {total_mb:8.1f} MB")


# ============================================================
# Main
# ============================================================

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Export Nemotron 3.5 ASR to ONNX resources for RenJistroly."
    )
    parser.add_argument(
        "--model-path",
        default=MODEL_PATH,
        help="Path to nemotron-3.5-asr-streaming-0.6b.nemo. Defaults to NEMOTRON_NEMO_PATH or the local Hugging Face cache path.",
    )
    parser.add_argument(
        "--output-dir",
        default=OUTPUT_DIR,
        help=f"Output resource directory. Defaults to {DEFAULT_OUTPUT_DIR}.",
    )
    args = parser.parse_args()

    MODEL_PATH = args.model_path
    OUTPUT_DIR = args.output_dir
    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(
            f"Nemotron .nemo model not found: {MODEL_PATH}. "
            "Pass --model-path or set NEMOTRON_NEMO_PATH."
        )
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    model, tmpdir = load_model()
    device = "cpu"
    model = model.to(device)

    try:
        clean_output_directory()
        export_pre_encode(model, device)
        export_conformer(model, device)
        export_decoder(model, device)
        export_prompt(model, device)
        export_joint(model, device)
        save_metadata(model)
        verify_onnx()
        list_output_files()
        print(f"\nDone! Files saved to: {OUTPUT_DIR}/")
    finally:
        import shutil
        shutil.rmtree(tmpdir, ignore_errors=True)
