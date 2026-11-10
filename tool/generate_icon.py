"""Generate ResQMesh launcher icons (requires Pillow).

Run from the project root:
    python tool/generate_icon.py
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "android" / "app" / "src" / "main" / "res"
SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
BASE = 1024


def rounded_background() -> Image.Image:
    image = Image.new("RGBA", (BASE, BASE), (6, 13, 24, 255))
    draw = ImageDraw.Draw(image)
    for y in range(BASE):
        t = y / BASE
        r = int(7 + 5 * t)
        g = int(19 + 10 * t)
        b = int(33 + 14 * t)
        draw.line((0, y, BASE, y), fill=(r, g, b, 255))
    glow = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse(
        (BASE * 0.18, BASE * 0.10, BASE * 0.84, BASE * 0.78),
        fill=(36, 180, 220, 44),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(130))
    image = Image.alpha_composite(image, glow)
    return image


def mesh_icon() -> Image.Image:
    image = rounded_background()
    draw = ImageDraw.Draw(image)
    center = (BASE / 2, BASE / 2)
    radius = BASE * 0.29
    nodes = []
    for i in range(6):
        angle = math.pi / 3 * i - math.pi / 2
        nodes.append(
            (
                center[0] + math.cos(angle) * radius,
                center[1] + math.sin(angle) * radius,
            )
        )
    line_color = (52, 214, 245, 150)
    line_width = max(2, int(BASE * 0.008))
    for node in nodes:
        draw.line((center, node), fill=line_color, width=line_width)
    for i, node in enumerate(nodes):
        draw.line((node, nodes[(i + 1) % len(nodes)]), fill=line_color, width=line_width)

    # Outer ring glow.
    ring = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
    rdraw = ImageDraw.Draw(ring)
    rdraw.ellipse(
        (center[0] - radius * 1.36, center[1] - radius * 1.36,
         center[0] + radius * 1.36, center[1] + radius * 1.36),
        outline=(52, 214, 245, 80),
        width=max(2, int(BASE * 0.005)),
    )
    ring = ring.filter(ImageFilter.GaussianBlur(6))
    image = Image.alpha_composite(image, ring)
    draw = ImageDraw.Draw(image)

    # Cyan node halo.
    halo = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(halo)
    for node in nodes:
        r = BASE * 0.045
        hdraw.ellipse(
            (node[0] - r, node[1] - r, node[0] + r, node[1] + r),
            fill=(52, 214, 245, 90),
        )
    halo = halo.filter(ImageFilter.GaussianBlur(20))
    image = Image.alpha_composite(image, halo)
    draw = ImageDraw.Draw(image)

    node_radius = BASE * 0.035
    for node in nodes:
        draw.ellipse(
            (node[0] - node_radius, node[1] - node_radius,
             node[0] + node_radius, node[1] + node_radius),
            fill=(52, 214, 245, 255),
        )

    # Central SOS-red node with dark core.
    draw.ellipse(
        (center[0] - BASE * 0.135, center[1] - BASE * 0.135,
         center[0] + BASE * 0.135, center[1] + BASE * 0.135),
        fill=(255, 59, 78, 255),
    )
    draw.ellipse(
        (center[0] - BASE * 0.072, center[1] - BASE * 0.072,
         center[0] + BASE * 0.072, center[1] + BASE * 0.072),
        fill=(7, 19, 33, 255),
    )
    draw.ellipse(
        (center[0] - BASE * 0.035, center[1] - BASE * 0.035,
         center[0] + BASE * 0.035, center[1] + BASE * 0.035),
        fill=(52, 214, 245, 255),
    )

    # Rounded-square safe mask so launchers without adaptive masking still look intentional.
    mask = Image.new("L", (BASE, BASE), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle(
        (0, 0, BASE - 1, BASE - 1), radius=int(BASE * 0.22), fill=255
    )
    output = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
    output.paste(image, (0, 0), mask)
    return output


def main() -> None:
    icon = mesh_icon()
    for folder, size in SIZES.items():
        target = RES / folder / "ic_launcher.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        icon.resize((size, size), Image.LANCZOS).save(target)
        print(f"wrote {target}")
    icon.resize((512, 512), Image.LANCZOS).save(ROOT / "assets" / "icon-512.png")
    print("wrote assets/icon-512.png")


if __name__ == "__main__":
    main()
