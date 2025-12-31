#!/usr/bin/env python3
"""
PyTorch Model Conversion Script for Performant3
Converts .pt/.pth files to CoreML or MLX (safetensors) format
Communicates progress via JSON-line protocol on stdout
"""

import json
import sys
import argparse
from pathlib import Path


def emit(event_type: str, **kwargs):
    """Emit a JSON event to stdout for the Swift app to consume."""
    event = {"type": event_type, **kwargs}
    print(json.dumps(event), flush=True)


def log(level: str, message: str):
    """Emit a log event."""
    emit("log", level=level, message=message)


def progress(percent: float, step: str):
    """Emit a progress event (0.0 to 1.0)."""
    emit("progress", percent=percent, step=step)


def completed(output_path: str, format: str, metadata: dict):
    """Emit conversion completed event."""
    emit("completed", outputPath=output_path, format=format, metadata=metadata)


def error(message: str, code: str = "UNKNOWN"):
    """Emit an error event."""
    emit("error", message=message, code=code)


def load_pytorch_model(model_path: str, input_shape: tuple):
    """Load and trace PyTorch model."""
    import torch

    log("info", f"Loading PyTorch model from {model_path}")
    progress(0.1, "Loading model")

    # Load the checkpoint
    try:
        checkpoint = torch.load(model_path, map_location="cpu", weights_only=False)
    except Exception as e:
        # Try with weights_only=True for newer PyTorch
        try:
            checkpoint = torch.load(model_path, map_location="cpu", weights_only=True)
        except Exception:
            raise RuntimeError(f"Failed to load model: {e}")

    progress(0.2, "Analyzing checkpoint")

    # Handle different checkpoint formats
    model = None
    state_dict = None

    if isinstance(checkpoint, dict):
        # Check for common keys
        if "model" in checkpoint:
            model = checkpoint["model"]
            log("info", "Found 'model' key in checkpoint")
        elif "state_dict" in checkpoint:
            state_dict = checkpoint["state_dict"]
            log("info", "Found 'state_dict' key (model class required)")
        elif "model_state_dict" in checkpoint:
            state_dict = checkpoint["model_state_dict"]
            log("info", "Found 'model_state_dict' key (model class required)")
        else:
            # Check if it looks like a state_dict (all values are tensors)
            if all(isinstance(v, torch.Tensor) for v in checkpoint.values()):
                state_dict = checkpoint
                log("info", "Checkpoint appears to be a state_dict")
            else:
                # Might be a wrapped model
                model = checkpoint
    else:
        # Direct model object
        model = checkpoint

    progress(0.3, "Preparing model")

    # If we only have state_dict, we can only do MLX conversion
    if model is None and state_dict is not None:
        log("warning", "Checkpoint contains only weights (state_dict)")
        log("info", "MLX conversion will proceed with raw weights")
        return None, state_dict, checkpoint

    # Set to eval mode
    if model is not None:
        model.eval()

        # Try to trace the model
        log("info", f"Tracing model with input shape: {input_shape}")
        progress(0.4, "Tracing model")

        try:
            dummy_input = torch.randn(*input_shape)
            traced_model = torch.jit.trace(model, dummy_input)
            log("info", "Model traced successfully")
            return traced_model, None, checkpoint
        except Exception as e:
            log("warning", f"Tracing failed: {e}")
            log("info", "Attempting scripting instead...")

            try:
                scripted_model = torch.jit.script(model)
                log("info", "Model scripted successfully")
                return scripted_model, None, checkpoint
            except Exception as e2:
                log("warning", f"Scripting also failed: {e2}")
                # Fall back to state_dict extraction
                if hasattr(model, "state_dict"):
                    state_dict = model.state_dict()
                    log("info", "Extracted state_dict from model")
                    return None, state_dict, checkpoint
                else:
                    raise RuntimeError(f"Cannot process model: {e}")

    raise RuntimeError("Could not extract model or state_dict from checkpoint")


def convert_to_coreml(traced_model, input_shape: tuple, output_path: str, model_name: str):
    """Convert traced PyTorch model to CoreML."""
    try:
        import coremltools as ct
    except ImportError:
        error("coremltools not installed. Run: pip install coremltools", "MISSING_PACKAGE")
        sys.exit(1)

    log("info", "Converting to CoreML format")
    progress(0.5, "Converting to CoreML")

    # Determine input type based on shape
    if len(input_shape) == 4:  # Image: (B, C, H, W)
        _, channels, height, width = input_shape
        if channels in [1, 3, 4]:
            # Image input
            input_type = ct.ImageType(
                name="input",
                shape=input_shape,
                channel_first=True,
                color_layout=ct.colorlayout.RGB if channels == 3 else ct.colorlayout.GRAYSCALE
            )
            log("info", f"Using ImageType input: {channels}ch {height}x{width}")
        else:
            input_type = ct.TensorType(name="input", shape=input_shape)
            log("info", f"Using TensorType input: {input_shape}")
    else:
        input_type = ct.TensorType(name="input", shape=input_shape)
        log("info", f"Using TensorType input: {input_shape}")

    progress(0.6, "Running coremltools conversion")

    try:
        # Convert to CoreML
        mlmodel = ct.convert(
            traced_model,
            inputs=[input_type],
            compute_units=ct.ComputeUnit.ALL,
            minimum_deployment_target=ct.target.macOS14
        )

        progress(0.8, "Optimizing model")

        # Set model metadata
        mlmodel.author = "Performant3"
        mlmodel.short_description = f"Converted from PyTorch: {model_name}"

        progress(0.9, "Saving model")

        # Save as mlpackage
        log("info", f"Saving CoreML model to {output_path}")
        mlmodel.save(output_path)

        progress(1.0, "Complete")

        # Extract metadata
        metadata = {
            "inputShape": list(input_shape),
            "format": "coreml",
            "computeUnits": "all",
            "deploymentTarget": "macOS14"
        }

        return metadata

    except Exception as e:
        error_msg = str(e)
        if "not supported" in error_msg.lower():
            error(f"Model contains unsupported operations: {error_msg}", "UNSUPPORTED_OP")
        elif "shape" in error_msg.lower():
            error(f"Shape mismatch during conversion: {error_msg}", "SHAPE_MISMATCH")
        else:
            error(f"CoreML conversion failed: {error_msg}", "CONVERSION_FAILED")
        sys.exit(1)


def convert_to_mlx(state_dict, input_shape: tuple, output_path: str, checkpoint):
    """Convert PyTorch model to MLX safetensors format."""
    try:
        import torch
        from safetensors.torch import save_file
    except ImportError:
        error("safetensors not installed. Run: pip install safetensors", "MISSING_PACKAGE")
        sys.exit(1)

    log("info", "Converting to MLX safetensors format")
    progress(0.5, "Extracting weights")

    # If state_dict is None, try to extract from checkpoint
    if state_dict is None:
        if isinstance(checkpoint, dict):
            if "state_dict" in checkpoint:
                state_dict = checkpoint["state_dict"]
            elif "model_state_dict" in checkpoint:
                state_dict = checkpoint["model_state_dict"]
            elif hasattr(checkpoint.get("model"), "state_dict"):
                state_dict = checkpoint["model"].state_dict()
            else:
                # Assume checkpoint is the state_dict
                state_dict = {k: v for k, v in checkpoint.items() if isinstance(v, torch.Tensor)}
        elif hasattr(checkpoint, "state_dict"):
            state_dict = checkpoint.state_dict()
        else:
            error("Cannot extract state_dict from checkpoint", "INVALID_CHECKPOINT")
            sys.exit(1)

    progress(0.6, "Processing tensors")

    # Convert tensors and prepare for safetensors
    tensors = {}
    layer_info = []

    for key, tensor in state_dict.items():
        # Skip non-tensor items
        if not isinstance(tensor, torch.Tensor):
            continue

        # Convert to float32 for compatibility
        if tensor.dtype in [torch.float16, torch.bfloat16]:
            tensor = tensor.float()

        # Ensure contiguous
        tensor = tensor.contiguous()
        tensors[key] = tensor

        # Record layer info for architecture inference
        layer_info.append({
            "name": key,
            "shape": list(tensor.shape),
            "dtype": str(tensor.dtype)
        })

    progress(0.8, "Saving safetensors")

    # Save as safetensors
    output_path = Path(output_path)
    log("info", f"Saving MLX model to {output_path}")
    save_file(tensors, output_path)

    progress(0.9, "Saving metadata")

    # Save metadata JSON alongside
    metadata_path = output_path.with_suffix(".json")
    metadata = {
        "inputShape": list(input_shape),
        "format": "mlx",
        "layerCount": len(layer_info),
        "layers": layer_info,
        "architectureType": infer_architecture(layer_info),
        "totalParameters": sum(
            tensor.numel() for tensor in tensors.values()
        )
    }

    with open(metadata_path, "w") as f:
        json.dump(metadata, f, indent=2)

    progress(1.0, "Complete")

    # Return simplified metadata for Swift
    return {
        "inputShape": list(input_shape),
        "format": "mlx",
        "architectureType": metadata["architectureType"],
        "layerCount": len(layer_info),
        "totalParameters": metadata["totalParameters"]
    }


def infer_architecture(layer_info: list) -> str:
    """Attempt to infer architecture type from layer names."""
    layer_names = [l["name"].lower() for l in layer_info]
    layer_names_str = " ".join(layer_names)

    # Check for common patterns
    if "resnet" in layer_names_str or any("layer" in n and "conv" in n for n in layer_names):
        if any("downsample" in n or "shortcut" in n for n in layer_names):
            return "ResNet"

    if any("conv" in n for n in layer_names):
        if any("bn" in n or "batch" in n for n in layer_names):
            return "CNN"
        return "CNN"

    if any("attention" in n or "transformer" in n or "encoder" in n for n in layer_names):
        return "Transformer"

    if any("vit" in n or "patch_embed" in n for n in layer_names):
        return "Transformer"

    if all("fc" in n or "linear" in n or "weight" in n or "bias" in n for n in layer_names):
        return "MLP"

    if any("yolo" in n or "detect" in n for n in layer_names):
        return "YOLOv8"

    return "Custom"


def main():
    parser = argparse.ArgumentParser(description="Convert PyTorch model to CoreML or MLX")
    parser.add_argument("--input", required=True, help="Path to .pt/.pth file")
    parser.add_argument("--output", required=True, help="Output path")
    parser.add_argument("--format", required=True, choices=["coreml", "mlx"],
                        help="Target format")
    parser.add_argument("--input-shape", required=True,
                        help="Input shape as comma-separated values, e.g., 1,3,224,224")
    parser.add_argument("--name", default="Converted Model",
                        help="Model name for metadata")

    args = parser.parse_args()

    try:
        # Parse input shape
        input_shape = tuple(map(int, args.input_shape.split(",")))
        log("info", f"Input shape: {input_shape}")

        if len(input_shape) < 2:
            error("Input shape must have at least 2 dimensions", "INVALID_SHAPE")
            sys.exit(1)

        # Load model
        traced_model, state_dict, checkpoint = load_pytorch_model(args.input, input_shape)

        # Convert based on target format
        if args.format == "coreml":
            if traced_model is None:
                error("CoreML conversion requires a traceable model. This checkpoint only contains weights (state_dict). Try MLX format instead.", "STATE_DICT_ONLY")
                sys.exit(1)
            metadata = convert_to_coreml(traced_model, input_shape, args.output, args.name)
        else:  # mlx
            metadata = convert_to_mlx(state_dict, input_shape, args.output, checkpoint)

        completed(args.output, args.format, metadata)

    except KeyboardInterrupt:
        log("warning", "Conversion cancelled by user")
        sys.exit(0)
    except Exception as e:
        error(str(e), code="CONVERSION_FAILED")
        sys.exit(1)


if __name__ == "__main__":
    main()
