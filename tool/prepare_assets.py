#!/usr/bin/env python3
"""Turns the delivered artwork into the runtime asset set.

Source sets are 2x2 grids on a transparent background, so each item is cut by
its own alpha bounding box rather than by fixed grid maths. Photographic
backgrounds are stored as JPEG (no alpha needed), cut-outs stay PNG.

Run from the project root:  python3 tool/prepare_assets.py
"""

from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets"
ADD = SRC / "Featherpeak_Fury_APPLICATION_additional_assets"
GAME = SRC / "Featherpeak_Fury_APPLICATION_gameplay_assets"
SND = SRC / "Featherpeak_Fury_APPLICATION_sounds_assets"

OUT_IMG = ROOT / "assets" / "images"
OUT_SND = ROOT / "assets" / "sounds"
OUT_ICON = ROOT / "assets" / "icon"

# Quadrant order for every 2x2 sheet: top-left, top-right, bottom-left, bottom-right.
SETS: dict[str, tuple[str, str, str, str]] = {
    "featherpeak_chicken_set_asset.webp": (
        "chicken_standing",
        "chicken_walking",
        "chicken_packed",
        "chicken_resting",
    ),
    "egg_set_asset.webp": ("egg_single", "egg_pair", "egg_large", "egg_golden"),
    "coin_set_asset.webp": ("coin_single", "coin_stack", "coin_column", "coin_pile"),
    "feather_set_asset.webp": (
        "feather_white",
        "feather_cream",
        "feather_brown",
        "feather_green",
    ),
    "feather_load_categories_set_asset.webp": (
        "category_health",
        "category_clothing",
        "category_electronics",
        "category_food",
    ),
    "hiking_gear_set_asset.webp": (
        "gear_backpack",
        "gear_bottle",
        "gear_compass",
        "gear_flashlight",
    ),
    "fury_zones_set_asset.webp": (
        "fury_steep_sign",
        "fury_heavy_pack",
        "fury_long_duration",
        "fury_rocky_sign",
    ),
    "mountain_peaks_set_asset.webp": (
        "peak_green",
        "peak_snow",
        "peak_rock",
        "peak_golden",
    ),
    "route_markers_set_asset.webp": (
        "marker_flag",
        "marker_ascent_sign",
        "marker_cairn",
        "marker_summit_post",
    ),
    "terrain_set_asset.webp": (
        "terrain_rock",
        "terrain_grass",
        "terrain_snow",
        "terrain_sand",
    ),
    "weather_symbols_set_asset.webp": (
        "weather_sun",
        "weather_cloud",
        "weather_rain",
        "weather_snow",
    ),
    "additional_weather_set_asset.webp": (
        "weather_wind",
        "weather_fog",
        "weather_storm",
        "weather_partly",
    ),
}

SINGLES: dict[str, str] = {
    "empty_state_new_trip_asset.webp": "empty_new_trip",
    "empty_state_no_route_data_asset.webp": "empty_no_route_data",
    "empty_state_no_saved_trips_asset.webp": "empty_no_saved_trips",
}

SOUNDS: dict[str, str] = {
    "button_tap_asset.mp3": "button_tap.mp3",
    "menu_open_asset.mp3": "menu_open.mp3",
    "menu_close_asset.mp3": "menu_close.mp3",
    "screen_open_asset.mp3": "screen_open.mp3",
    "screen_back_asset.mp3": "screen_back.mp3",
    "add_item_asset.mp3": "add_item.mp3",
    "remove_item_asset.mp3": "remove_item.mp3",
    "save_trip_asset.mp3": "save_trip.mp3",
    "calculation_complete_asset.mp3": "calculation_complete.mp3",
    "successful_action_asset.mp3": "successful_action.mp3",
    "warning_asset.mp3": "warning.mp3",
    "error_asset.mp3": "error.mp3",
}

ITEM_MAX = 512
ILLUSTRATION_MAX = 900
ALPHA_FLOOR = 8
NOISE_FLOOR_PX = 64
NOISE_FLOOR_RATIO = 0.003


def _labelled(img: Image.Image) -> tuple[np.ndarray, np.ndarray, int]:
    mask = np.asarray(img.getchannel("A")) > ALPHA_FLOOR
    labels, count = ndimage.label(mask, structure=np.ones((3, 3), dtype=bool))
    return mask, labels, count


def _keep(labels: np.ndarray, wanted: set[int]) -> np.ndarray:
    lookup = np.zeros(int(labels.max()) + 1, dtype=bool)
    for index in wanted:
        lookup[index] = True
    return lookup[labels]


def clean(img: Image.Image) -> Image.Image:
    """Drops speckle left over from the source renders, then crops to what is
    left. Small parts that legitimately belong to an object (rain drops, loose
    coins) survive because the threshold is relative to that object's own size."""
    _, labels, count = _labelled(img)
    if count == 0:
        return img

    areas = ndimage.sum(labels > 0, labels, index=range(1, count + 1))
    biggest = float(areas.max())
    floor = max(NOISE_FLOOR_PX, biggest * NOISE_FLOOR_RATIO)
    wanted = {i + 1 for i, area in enumerate(areas) if area >= floor}

    out = img.copy()
    alpha = np.asarray(out.getchannel("A")).copy()
    alpha[~_keep(labels, wanted)] = 0
    out.putalpha(Image.fromarray(alpha))
    box = out.getchannel("A").point(lambda v: 255 if v > ALPHA_FLOOR else 0).getbbox()
    return out.crop(box) if box else out


def cut_quadrants(sheet: Image.Image) -> list[Image.Image]:
    """Splits a 2x2 sheet by assigning every connected blob to the quadrant that
    holds its centre of mass, so an object overhanging the midline is never
    sliced in half or leaked into its neighbour."""
    _, labels, count = _labelled(sheet)
    half_w, half_h = sheet.width / 2, sheet.height / 2
    indices = list(range(1, count + 1))
    areas = ndimage.sum(labels > 0, labels, index=indices)
    centres = ndimage.center_of_mass(labels > 0, labels, index=indices)

    buckets: list[dict[int, float]] = [{}, {}, {}, {}]
    for index, area, (cy, cx) in zip(indices, areas, centres):
        column = 0 if cx < half_w else 1
        row = 0 if cy < half_h else 1
        buckets[row * 2 + column][index] = float(area)

    results: list[Image.Image] = []
    for bucket in buckets:
        if not bucket:
            results.append(Image.new("RGBA", (1, 1), (0, 0, 0, 0)))
            continue
        biggest = max(bucket.values())
        floor = max(NOISE_FLOOR_PX, biggest * NOISE_FLOOR_RATIO)
        wanted = {i for i, area in bucket.items() if area >= floor}

        piece = sheet.copy()
        alpha = np.asarray(piece.getchannel("A")).copy()
        alpha[~_keep(labels, wanted)] = 0
        piece.putalpha(Image.fromarray(alpha))
        box = piece.getchannel("A").point(lambda v: 255 if v > ALPHA_FLOOR else 0).getbbox()
        results.append(piece.crop(box) if box else piece)
    return results


def fit(img: Image.Image, longest: int) -> Image.Image:
    scale = longest / max(img.size)
    if scale >= 1:
        return img
    size = (max(1, round(img.width * scale)), max(1, round(img.height * scale)))
    return img.resize(size, Image.LANCZOS)


def save_cutout(img: Image.Image, name: str) -> None:
    """Cut-outs keep their alpha channel but ship as WebP: same visual result at
    roughly a tenth of the PNG size."""
    path = OUT_IMG / f"{name}.webp"
    img.save(path, "WEBP", quality=88, method=6)
    print(f"  {path.relative_to(ROOT)}  {img.width}x{img.height}")


def save_jpg(img: Image.Image, name: str, quality: int = 86) -> None:
    path = OUT_IMG / f"{name}.jpg"
    img.convert("RGB").save(path, "JPEG", quality=quality, optimize=True, progressive=True)
    print(f"  {path.relative_to(ROOT)}  {img.width}x{img.height}")


def cut_sets() -> None:
    print("Cutting 2x2 sheets")
    for filename, names in SETS.items():
        sheet = Image.open(GAME / filename).convert("RGBA")
        for name, piece in zip(names, cut_quadrants(sheet)):
            save_cutout(fit(piece, ITEM_MAX), name)


def cut_singles() -> None:
    print("Trimming single illustrations")
    for filename, name in SINGLES.items():
        img = Image.open(GAME / filename).convert("RGBA")
        save_cutout(fit(clean(img), ILLUSTRATION_MAX), name)

    logo = Image.open(ADD / "Game_Name.webp").convert("RGBA")
    save_cutout(fit(clean(logo), 640), "wordmark")


def backgrounds() -> None:
    print("Backgrounds")
    scene = Image.open(GAME / "main_mountain_background_asset.webp").convert("RGBA")
    save_jpg(fit(scene, 1400), "mountain_backdrop")

    boot_v = Image.open(ADD / "Vertical_Loading_Screen.webp").convert("RGB")
    save_jpg(fit(boot_v, 1800), "boot_portrait", quality=84)

    boot_h = Image.open(ADD / "Horizontal_Loading_Screen.webp").convert("RGB")
    save_jpg(fit(boot_h, 1800), "boot_landscape", quality=84)


def icons() -> None:
    """iOS wants an opaque square; Android needs a background plus a foreground
    that keeps its subject inside the 66% adaptive safe zone."""
    print("Icons")
    OUT_ICON.mkdir(parents=True, exist_ok=True)

    source = Image.open(ADD / "Icon.png").convert("RGB")
    master = source.resize((1024, 1024), Image.LANCZOS)
    master.save(OUT_ICON / "app_icon.png", "PNG", optimize=True)
    print(f"  assets/icon/app_icon.png  1024x1024")

    # Adaptive background: zoom slightly so the circular/rounded mask never
    # exposes an empty edge.
    zoom = 1.18
    side = round(1024 * zoom)
    zoomed = source.resize((side, side), Image.LANCZOS)
    offset = (side - 1024) // 2
    background = zoomed.crop((offset, offset, offset + 1024, offset + 1024))
    background.save(OUT_ICON / "adaptive_background.png", "PNG", optimize=True)
    print("  assets/icon/adaptive_background.png  1024x1024")

    # Adaptive foreground: the mascot alone, centred inside the safe zone.
    sheet = Image.open(GAME / "featherpeak_chicken_set_asset.webp").convert("RGBA")
    mascot = cut_quadrants(sheet)[0]
    safe = 620  # 1024 * 0.605, comfortably inside the 66% safe zone
    mascot = fit(mascot, safe)
    foreground = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    foreground.paste(
        mascot,
        ((1024 - mascot.width) // 2, (1024 - mascot.height) // 2),
        mascot,
    )
    foreground.save(OUT_ICON / "adaptive_foreground.png", "PNG", optimize=True)
    print("  assets/icon/adaptive_foreground.png  1024x1024")


def sounds() -> None:
    print("Sounds")
    OUT_SND.mkdir(parents=True, exist_ok=True)
    for src_name, dst_name in SOUNDS.items():
        shutil.copyfile(SND / src_name, OUT_SND / dst_name)
        print(f"  assets/sounds/{dst_name}")


def main() -> None:
    OUT_IMG.mkdir(parents=True, exist_ok=True)
    cut_sets()
    cut_singles()
    backgrounds()
    icons()
    sounds()
    print("\nDone.")


if __name__ == "__main__":
    main()
