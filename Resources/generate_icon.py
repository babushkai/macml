#!/usr/bin/env python3
"""Generate Performant3 app icon."""

import subprocess
import os
import math
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError:
    print("Installing Pillow...")
    subprocess.check_call(["pip3", "install", "Pillow"])
    from PIL import Image, ImageDraw, ImageFont, ImageFilter


def create_icon(size: int) -> Image.Image:
    """Create the Performant3 icon at the specified size."""
    # Create high-res version for quality
    scale = 4
    s = size * scale

    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Rounded rectangle background with gradient
    corner_radius = int(s * 0.22)  # macOS-style rounded corners

    # Create gradient background (deep blue to purple - ML/AI colors)
    for y in range(s):
        ratio = y / s
        # Gradient from deep blue (#1a1a2e) to purple (#4a1a6b) to accent (#6b21a8)
        r = int(26 + (74 - 26) * ratio + (107 - 74) * max(0, ratio - 0.5) * 2)
        g = int(26 + (26 - 26) * ratio + (33 - 26) * max(0, ratio - 0.5) * 2)
        b = int(46 + (107 - 46) * ratio + (168 - 107) * max(0, ratio - 0.5) * 2)
        draw.line([(0, y), (s, y)], fill=(r, g, b, 255))

    # Create mask for rounded corners
    mask = Image.new('L', (s, s), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([(0, 0), (s-1, s-1)], radius=corner_radius, fill=255)

    # Apply mask
    img.putalpha(mask)

    # Draw neural network / performance visualization
    center_x, center_y = s // 2, s // 2

    # Draw stylized "P3" or neural network nodes
    # Main circle (representing a node)
    node_radius = int(s * 0.18)

    # Glow effect
    glow_img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_img)

    # Draw connection lines (neural network style)
    line_color = (255, 255, 255, 60)
    line_width = max(2, int(s * 0.015))

    # Nodes positions
    nodes = [
        (center_x, center_y),  # Center
        (center_x - int(s * 0.25), center_y - int(s * 0.2)),  # Top left
        (center_x + int(s * 0.25), center_y - int(s * 0.2)),  # Top right
        (center_x - int(s * 0.25), center_y + int(s * 0.2)),  # Bottom left
        (center_x + int(s * 0.25), center_y + int(s * 0.2)),  # Bottom right
    ]

    # Draw connections
    for i, (nx, ny) in enumerate(nodes[1:], 1):
        draw.line([(center_x, center_y), (nx, ny)], fill=line_color, width=line_width)

    # Draw outer nodes (smaller)
    small_radius = int(s * 0.06)
    for nx, ny in nodes[1:]:
        # Glow
        for r in range(small_radius + 10, small_radius, -2):
            alpha = int(30 * (1 - (r - small_radius) / 10))
            glow_draw.ellipse(
                [(nx - r, ny - r), (nx + r, ny + r)],
                fill=(100, 200, 255, alpha)
            )
        # Node
        draw.ellipse(
            [(nx - small_radius, ny - small_radius), (nx + small_radius, ny + small_radius)],
            fill=(80, 180, 255, 255)
        )
        # Inner highlight
        highlight_r = int(small_radius * 0.6)
        draw.ellipse(
            [(nx - highlight_r, ny - highlight_r + 1), (nx + highlight_r, ny + highlight_r + 1)],
            fill=(150, 220, 255, 200)
        )

    # Draw center node (larger, with "3" or performance indicator)
    # Glow effect for center
    for r in range(node_radius + 20, node_radius, -2):
        alpha = int(50 * (1 - (r - node_radius) / 20))
        glow_draw.ellipse(
            [(center_x - r, center_y - r), (center_x + r, center_y + r)],
            fill=(120, 100, 255, alpha)
        )

    # Composite glow
    img = Image.alpha_composite(img, glow_img)
    draw = ImageDraw.Draw(img)

    # Center node background
    draw.ellipse(
        [(center_x - node_radius, center_y - node_radius),
         (center_x + node_radius, center_y + node_radius)],
        fill=(100, 80, 200, 255)
    )

    # Inner gradient circle
    inner_radius = int(node_radius * 0.85)
    draw.ellipse(
        [(center_x - inner_radius, center_y - inner_radius),
         (center_x + inner_radius, center_y + inner_radius)],
        fill=(130, 100, 220, 255)
    )

    # Draw "3" in the center
    try:
        # Try to use SF Pro or system font
        font_size = int(s * 0.22)
        try:
            font = ImageFont.truetype("/System/Library/Fonts/SFNSDisplay.ttf", font_size)
        except:
            try:
                font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
            except:
                font = ImageFont.load_default()
    except:
        font = ImageFont.load_default()

    # Draw "3" with shadow
    text = "3"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    text_x = center_x - text_w // 2
    text_y = center_y - text_h // 2 - int(s * 0.02)

    # Shadow
    draw.text((text_x + 2, text_y + 2), text, fill=(50, 30, 100, 150), font=font)
    # Main text
    draw.text((text_x, text_y), text, fill=(255, 255, 255, 255), font=font)

    # Add subtle speed lines / performance indicator
    for i in range(3):
        line_y = center_y + int(s * 0.32) + i * int(s * 0.04)
        line_start = center_x - int(s * 0.15) + i * int(s * 0.03)
        line_end = center_x + int(s * 0.15) - i * int(s * 0.03)
        alpha = 150 - i * 40
        draw.line(
            [(line_start, line_y), (line_end, line_y)],
            fill=(255, 255, 255, alpha),
            width=max(2, int(s * 0.012))
        )

    # Resize to target size with high quality
    img = img.resize((size, size), Image.Resampling.LANCZOS)

    return img


def create_iconset(output_dir: Path):
    """Create iconset with all required sizes."""
    iconset_dir = output_dir / "AppIcon.iconset"
    iconset_dir.mkdir(parents=True, exist_ok=True)

    # macOS icon sizes
    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    print("Generating icon sizes...")
    for size, filename in sizes:
        print(f"  {filename} ({size}x{size})")
        icon = create_icon(size)
        icon.save(iconset_dir / filename, "PNG")

    return iconset_dir


def create_icns(iconset_dir: Path, output_path: Path):
    """Convert iconset to icns using iconutil."""
    print(f"Creating {output_path.name}...")
    subprocess.run([
        "iconutil", "-c", "icns",
        "-o", str(output_path),
        str(iconset_dir)
    ], check=True)
    print(f"Created {output_path}")


def main():
    script_dir = Path(__file__).parent
    resources_dir = script_dir

    # Create iconset
    iconset_dir = create_iconset(resources_dir)

    # Convert to icns
    icns_path = resources_dir / "AppIcon.icns"
    create_icns(iconset_dir, icns_path)

    # Cleanup iconset directory (optional, keep for debugging)
    # import shutil
    # shutil.rmtree(iconset_dir)

    print("\nDone! Icon created at:", icns_path)


if __name__ == "__main__":
    main()
