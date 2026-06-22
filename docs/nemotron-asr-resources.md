# Nemotron ASR Resources

`NemotronASRProvider` loads its models from `Bundle.module`, so the files in
`Sources/RenJistrolySystemBridge/Resources/NemotronASR` are runtime resources,
not disposable build output.

## Current Payload

- Path: `Sources/RenJistrolySystemBridge/Resources/NemotronASR`
- Files: 301
- Size: about 2.4 GB
- Main models: `pre_encode.onnx`, `conformer.onnx`, `decoder.onnx`, `prompt.onnx`, `joint.onnx`
- External ONNX data: `onnx__*`, `layers.*`, `Constant_*`
- Small metadata: `model_info.json`, `preprocessor.json`, `prompts.json`, `tokenizer.json`, `tokens.txt`

The `conformer.onnx` export uses ONNX external data because the model is too
large to keep fully embedded in one ONNX protobuf. The `.onnx` file and its
external data siblings must be kept together in the same directory.

## Storage Policy

Large model files are tracked through Git LFS via `.gitattributes`:

- `*.onnx`
- `onnx__*`
- `layers.*`
- `Constant_*`

Small metadata files can remain ordinary Git files.

Before staging the model payload on a machine, install and initialize Git LFS:

```bash
git lfs install
git lfs track "Sources/RenJistrolySystemBridge/Resources/NemotronASR/*.onnx"
git lfs track "Sources/RenJistrolySystemBridge/Resources/NemotronASR/onnx__*"
git lfs track "Sources/RenJistrolySystemBridge/Resources/NemotronASR/layers.*"
git lfs track "Sources/RenJistrolySystemBridge/Resources/NemotronASR/Constant_*"
```

Then verify before committing:

```bash
git check-attr filter -- Sources/RenJistrolySystemBridge/Resources/NemotronASR/conformer.onnx
git lfs status
Scripts/verify_lfs_assets.sh
```

## Regeneration

The current exporter is `Scripts/export_nemotron_onnx.py`. It exports the model
into the resource directory above and removes stale external-data files before
writing a fresh payload.

Keep the source `.nemo` model outside the repository. Pass the local model path
explicitly, or set `NEMOTRON_NEMO_PATH`:

```bash
python3 Scripts/export_nemotron_onnx.py \
  --model-path /path/to/nemotron-3.5-asr-streaming-0.6b.nemo
```

The expected source model is:

`nvidia/nemotron-3.5-asr-streaming-0.6b`

## Release Notes

Packaging must include the full `NemotronASR` resource directory. If the payload
is moved out of Git in the future, the app should either download it into a
known application support directory or disable the offline ASR provider until
the payload is installed.

Run `Scripts/verify_lfs_assets.sh` before packaging or staging model resources.
