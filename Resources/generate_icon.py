#!/usr/bin/env python3
"""Generate Performant3 app icon - sophisticated design."""

import subprocess
import math
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError:
    print("Installing Pillow...")
    subprocess.check_call(["pip3", "install", "Pillow"])
    from PIL import Image, ImageDraw, ImageFont, ImageFilter


def create_icon(size: int) -> Image.Image:
    """Create a sophisticated Performant3 icon."""
    scale = 4
    s = size * scale

    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    corner_radius = int(s * 0.22)

    # Premium gradient: dark charcoal to deep slate blue
    for y in range(s):
        ratio = y / s
        # Dark sophisticated gradient
        r = int(18 + (28 - 18) * ratio)
        g = int(20 + (32 - 20) * ratio)
        b = int(28 + (48 - 28) * ratio)
        draw.line([(0, y), (s, y)], fill=(r, g, b, 255))

    # Create mask for rounded corners
    mask = Image.new('L', (s, s), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([(0, 0), (s-1, s-1)], radius=corner_radius, fill=255)
    img.putalpha(mask)

    center_x, center_y = s // 2, s // 2

    # Subtle grid pattern for depth
    grid_color = (255, 255, 255, 8)
    grid_spacing = int(s * 0.08)
    for i in range(0, s, grid_spacing):
        draw.line([(i, 0), (i, s)], fill=grid_color, width=1)
        draw.line([(0, i), (s, i)], fill=grid_color, width=1)

    # Performance bars - abstract rising metrics visualization
    bar_count = 5
    bar_width = int(s * 0.08)
    bar_gap = int(s * 0.04)
    total_width = bar_count * bar_width + (bar_count - 1) * bar_gap
    start_x = center_x - total_width // 2
    base_y = int(s * 0.72)

    # Bar heights creating an ascending pattern
    heights = [0.25, 0.4, 0.55, 0.45, 0.65]

    # Glow layer
    glow_img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_img)

    for i, h in enumerate(heights):
        x = start_x + i * (bar_width + bar_gap)
        bar_height = int(s * h * 0.5)
        top_y = base_y - bar_height

        # Glow effect
        for glow in range(15, 0, -3):
            alpha = int(20 * (1 - glow / 15))
            glow_draw.rounded_rectangle(
                [(x - glow, top_y - glow), (x + bar_width + glow, base_y + glow)],
                radius=int(bar_width * 0.3),
                fill=(100, 180, 255, alpha)
            )

        # Gradient fill for bars
        for by in range(top_y, base_y):
            ratio = (by - top_y) / max(1, (base_y - top_y))
            # Cyan to blue gradient
            br = int(60 + (40 - 60) * ratio)
            bg = int(200 + (140 - 200) * ratio)
            bb = int(255 + (220 - 255) * ratio)
            draw.line([(x, by), (x + bar_width, by)], fill=(br, bg, bb, 255))

        # Top rounded cap
        cap_radius = bar_width // 2
        draw.ellipse(
            [(x, top_y - cap_radius), (x + bar_width, top_y + cap_radius)],
            fill=(80, 210, 255, 255)
        )

        # Subtle highlight on left edge
        highlight_width = max(2, int(bar_width * 0.15))
        for hy in range(top_y, base_y):
            alpha = int(60 * (1 - (hy - top_y) / max(1, (base_y - top_y))))
            draw.line(
                [(x, hy), (x + highlight_width, hy)],
                fill=(255, 255, 255, alpha)
            )

    # Composite glow
    img = Image.alpha_composite(img, glow_img)
    draw = ImageDraw.Draw(img)

    # Stylized "P3" text - clean typography
    try:
        font_size = int(s * 0.18)
        try:
            font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", font_size)
        except:
            try:
                font = ImageFont.truetype("/System/Library/Fonts/SFNSDisplay.ttf", font_size)
            except:
                try:
                    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
                except:
                    font = ImageFont.load_default()
    except:
        font = ImageFont.load_default()

    text = "P3"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    text_x = center_x - text_w // 2
    text_y = int(s * 0.15)

    # Subtle shadow
    shadow_offset = max(2, int(s * 0.005))
    draw.text(
        (text_x + shadow_offset, text_y + shadow_offset),
        text,
        fill=(0, 0, 0, 80),
        font=font
    )

    # Main text with subtle gradient effect
    draw.text((text_x, text_y), text, fill=(255, 255, 255, 240), font=font)

    # Accent line under text
    line_y = text_y + text_h + int(s * 0.03)
    line_width = int(text_w * 0.8)
    line_x_start = center_x - line_width // 2
    for lx in range(line_x_start, line_x_start + line_width):
        ratio = (lx - line_x_start) / line_width
        # Gradient from cyan to blue
        lr = int(60 + (100 - 60) * ratio)
        lg = int(200 + (160 - 200) * ratio)
        lb = int(255 + (240 - 255) * ratio)
        draw.line(
            [(lx, line_y), (lx, line_y + max(2, int(s * 0.008)))],
            fill=(lr, lg, lb, 200)
        )

    # Subtle corner accent - premium detail
    accent_size = int(s * 0.06)
    accent_color = (80, 200, 255, 40)

    # Top-right corner accent
    for i in range(accent_size):
        alpha = int(40 * (1 - i / accent_size))
        draw.line(
            [(s - corner_radius - accent_size + i, corner_radius // 2),
             (s - corner_radius // 2, corner_radius // 2 + accent_size - i)],
            fill=(80, 200, 255, alpha),
            width=2
        )

    # Bottom edge glow
    for i in range(20):
        alpha = int(15 * (1 - i / 20))
        y = s - corner_radius - i
        draw.line(
            [(corner_radius, y), (s - corner_radius, y)],
            fill=(100, 200, 255, alpha)
        )

    # Resize with high quality
    img = img.resize((size, size), Image.Resampling.LANCZOS)

    return img


def create_iconset(output_dir: Path):
    """Create iconset with all required sizes."""
    iconset_dir = output_dir / "AppIcon.iconset"
    iconset_dir.mkdir(parents=True, exist_ok=True)

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

    iconset_dir = create_iconset(resources_dir)
    icns_path = resources_dir / "AppIcon.icns"
    create_icns(iconset_dir, icns_path)

    print("\nDone! Icon created at:", icns_path)


if __name__ == "__main__":
    main()
