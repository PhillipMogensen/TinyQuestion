"""Build AppIcon.appiconset from assets/icon-source.png.

Source has a baked-in rounded-rect shape with black background outside the
rounded shape. macOS legacy multi-size asset catalogs do not auto-mask, so
we apply a rounded-rect alpha mask, square the canvas, and emit all sizes.

Run from repo root:  python3 assets/build_appicon.py
"""

from pathlib import Path
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "assets" / "icon-source.png"
OUT = REPO / "TinyQuestion" / "Assets.xcassets" / "AppIcon.appiconset"

# Apple-style rounded-rect corner radius as a fraction of the icon side.
# The source artwork's visible corner radius looks ~18% of width; using the
# same fraction keeps the mask aligned with the existing rounded shape so we
# don't double-round or leave stray black pixels.
RADIUS_FRAC = 0.18

SIZES = [16, 32, 64, 128, 256, 512, 1024]


def square_canvas(im: Image.Image) -> Image.Image:
    w, h = im.size
    side = max(w, h)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - w) // 2, (side - h) // 2))
    return canvas


def rounded_mask(side: int, radius: int) -> Image.Image:
    mask = Image.new("L", (side, side), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((0, 0, side - 1, side - 1), radius=radius, fill=255)
    return mask


def main() -> None:
    src = Image.open(SRC).convert("RGBA")
    squared = square_canvas(src)
    side = squared.size[0]
    mask = rounded_mask(side, int(side * RADIUS_FRAC))

    # Multiply the existing alpha by our rounded mask so corners go transparent.
    r, g, b, a = squared.split()
    new_alpha = Image.eval(a, lambda v: v)  # copy
    new_alpha = Image.composite(new_alpha, Image.new("L", (side, side), 0), mask)
    masked = Image.merge("RGBA", (r, g, b, new_alpha))

    # Upscale to 1024 master, then downsample for each target size.
    master = masked.resize((1024, 1024), Image.LANCZOS)

    OUT.mkdir(parents=True, exist_ok=True)
    for size in SIZES:
        out = master.resize((size, size), Image.LANCZOS)
        out.save(OUT / f"icon_{size}.png", "PNG")
        print(f"wrote icon_{size}.png")


if __name__ == "__main__":
    main()
