#!/usr/bin/env python3
"""从 docs/UI/记账APP图标设计.pdf 生成 App 启动图标资源。

设计要点（PDF「主图标」区）：
  - 品牌主色 #0A6E52，图形层 #FFFFFF；
  - 图形语义：环形硬币（资产）+ 上扬折线（收支趋势）+ 末端实心圆点（余额）；
  - 1024 栅格下环宽 88、折线宽 76（logo 主栅格），主体落在 80% 安全区，
    圆角率 22.49%；启动图标按「主图标」预览的实际落位生成；
  - 线性版用于浅色场景，金标版用于年度账单与会员权益（本脚本只生成
    主图标；Android 自适应图标的 foreground 同时可作为 monochrome 层复用）。

生成内容：
  - Android：
      mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png（圆角方形，API<26 用）
      mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher_round.png（圆形，API<26 用）
      mipmap-anydpi-v26/ic_launcher.xml、ic_launcher_round.xml（API 26+ 自适应，
      含 Android 13+ monochrome 主题图标图层）
      drawable/ic_launcher_foreground.xml（108dp 矢量前景）
      values/colors.xml 中补充 ic_launcher_background = #0A6E52
  - iOS：
      Runner/Assets.xcassets/AppIcon.appiconset/ 下 Contents.json 列出的全部尺寸

用法：
    python3 tool/generate_app_icons.py

依赖：PyMuPDF（读取设计 PDF）与 Pillow（合成/缩放）。
    pip install pymupdf pillow
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    import pymupdf  # type: ignore[import-not-found]
except ImportError:  # pragma: no cover - 仅开发工具链使用
    import fitz as pymupdf  # type: ignore[no-redef]

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parents[1]
DESIGN_PDF = REPO_ROOT / "docs" / "UI" / "记账APP图标设计.pdf"

ANDROID_RES = REPO_ROOT / "app" / "android" / "app" / "src" / "main" / "res"
ANDROID_MANIFEST = (
    REPO_ROOT / "app" / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
)
IOS_APPICON = (
    REPO_ROOT
    / "app"
    / "ios"
    / "Runner"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
)

# 品牌色板（PDF「品牌色板」）
BRAND_GREEN = (10, 110, 82)  # #0A6E52 主色深
FOREGROUND_WHITE = (255, 255, 255)  # #FFFFFF 图形层

# 圆角率 22.49%（PDF keyline 规格）；Android API<26 的 legacy 图标使用。
CORNER_RADIUS_RATIO = 0.2249

# 前景主栅格：2048 足够覆盖 iOS 1024 与 Android 最高 192px，再 Lanczos 下采样。
MASTER_SIZE = 2048

# Android legacy mipmap 尺寸（与 res/mipmap-*dpi 标准一致）。
ANDROID_DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def _is_white_fill(fill: tuple[float, ...] | None) -> bool:
    return bool(fill) and all(channel >= 0.95 for channel in fill)


def _split_subpaths(drawing: dict) -> list[list[tuple[str, list[tuple[float, float]]]]]:
    """把 PyMuPDF get_drawings() 的 items 拆成独立子路径。

    PyMuPDF 返回的 items 只有 'l' / 'c' 两类；子路径之间没有显式 m 指令，
    通过“下一条指令起点 != 上一条指令终点”判断新子路径。
    """
    subpaths: list[list[tuple[str, list[tuple[float, float]]]]] = []
    current: list[tuple[str, list[tuple[float, float]]]] = []
    previous_end = None

    for item in drawing["items"]:
        op = item[0]
        points = list(item[1:])

        if op == "re":  # 主图标前景没有矩形子路径；防御性跳过
            continue
        if op not in ("l", "c"):
            raise ValueError(f"未预期的 PDF path 指令: {op}")

        start = points[0]
        if current and (
            previous_end is None
            or abs(start.x - previous_end.x) > 1e-6
            or abs(start.y - previous_end.y) > 1e-6
        ):
            subpaths.append(current)
            current = []

        if op == "l":
            current.append(("L", [(points[0].x, points[0].y), (points[1].x, points[1].y)]))
            previous_end = points[1]
        else:
            current.append(
                (
                    "C",
                    [
                        (points[0].x, points[0].y),
                        (points[1].x, points[1].y),
                        (points[2].x, points[2].y),
                        (points[3].x, points[3].y),
                    ],
                )
            )
            previous_end = points[3]

    if current:
        subpaths.append(current)
    return subpaths


def extract_design_geometry(pdf_path: Path) -> tuple[dict, list[dict]]:
    """读取 PDF，返回 (主图标画布 rect, 前景路径列表)。

    前景路径坐标归一化到 0..1 的主图画布，并保留设计稿的视觉重心：
    「主图标」与桌面场景预览中，环形硬币中心比几何中心上移约 3.7%，
    这是常见的视觉重心校正（optical centering），不做几何居中。
    """
    if not pdf_path.exists():
        raise FileNotFoundError(f"设计稿不存在: {pdf_path}")

    document = pymupdf.open(pdf_path)
    page = document[0]

    # 主图预览是页面中面积最大的图片（PDF 中为 488×488）。
    image_rect = None
    largest_area = -1.0
    for image in page.get_images(full=True):
        xref = image[0]
        for rect in page.get_image_rects(xref):
            area = abs(rect.width * rect.height)
            if area > largest_area:
                largest_area = area
                image_rect = rect

    if image_rect is None:
        raise RuntimeError("PDF 中未找到主图标预览图片")

    # 主图预览内、纯白填充的矢量图形 = 环形硬币 + 上扬折线 + 圆点。
    white_drawings = []
    for drawing in page.get_drawings():
        if not _is_white_fill(drawing.get("fill")):
            continue
        rect = drawing["rect"]
        if (
            rect.x0 >= image_rect.x0 - 1
            and rect.y0 >= image_rect.y0 - 1
            and rect.x1 <= image_rect.x1 + 1
            and rect.y1 <= image_rect.y1 + 1
        ):
            white_drawings.append(drawing)

    if len(white_drawings) != 3:
        raise RuntimeError(
            f"主图预览内期望 3 个白色图形（环/折线/圆点），实际 {len(white_drawings)} 个"
        )

    paths: list[dict] = []
    for drawing in sorted(
        white_drawings,
        key=lambda d: (d["rect"].width * d["rect"].height),
        reverse=True,
    ):
        subpaths = _split_subpaths(drawing)
        normalized_subpaths: list[list[tuple[str, list[tuple[float, float]]]]] = []
        for subpath in subpaths:
            normalized_subpaths.append(
                [
                    (
                        op,
                        [
                            (
                                (x - image_rect.x0) / image_rect.width,
                                (y - image_rect.y0) / image_rect.height,
                            )
                            for x, y in points
                        ],
                    )
                    for op, points in subpath
                ]
            )
        paths.append(
            {
                "even_odd": bool(drawing.get("even_odd")),
                "subpaths": normalized_subpaths,
            }
        )

    return {"rect": image_rect}, paths


def render_foreground_alpha(paths: list[dict], size: int) -> Image.Image:
    """把前景矢量路径渲染为 size×size 的 8bit alpha 蒙版。"""
    document = pymupdf.open()
    page = document.new_page(width=size, height=size)

    for path in paths:
        shape = page.new_shape()
        for subpath in path["subpaths"]:
            for op, points in subpath:
                pixel_points = [pymupdf.Point(x * size, y * size) for x, y in points]
                if op == "L":
                    shape.draw_line(pixel_points[0], pixel_points[1])
                else:
                    shape.draw_bezier(*pixel_points)
        shape.finish(
            fill=(1, 1, 1),
            color=None,
            even_odd=bool(path["even_odd"]),
        )
        shape.commit()

    pixmap = page.get_pixmap(alpha=True)
    rgba = Image.frombytes("RGBA", (pixmap.width, pixmap.height), pixmap.samples)
    return rgba.getchannel("A")


def _shape_mask(size: int, shape: str) -> Image.Image | None:
    """返回背景形状蒙版；square 返回 None（全不透明）。"""
    if shape == "square":
        return None
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    if shape == "rounded":
        radius = max(1, int(round(size * CORNER_RADIUS_RATIO)))
        draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    elif shape == "circle":
        draw.ellipse((0, 0, size - 1, size - 1), fill=255)
    else:  # pragma: no cover - 仅内部调用
        raise ValueError(f"未知形状: {shape}")
    return mask


def build_master(
    paths: list[dict],
    size: int = MASTER_SIZE,
    shape: str = "square",
) -> Image.Image:
    """合成主图标：品牌绿底 + 白色前景。"""
    foreground = Image.new("RGBA", (size, size), (*FOREGROUND_WHITE, 0))
    foreground.putalpha(render_foreground_alpha(paths, size))

    background = Image.new("RGBA", (size, size), (*BRAND_GREEN, 255))
    mask = _shape_mask(size, shape)
    if mask is not None:
        background.putalpha(mask)

    return Image.alpha_composite(background, foreground)


def save_icon(
    master: Image.Image,
    destination: Path,
    size: int,
    *,
    with_alpha: bool,
) -> None:
    """从主图缩放输出 PNG；iOS 输出 RGB（App Store 禁止 alpha）。"""
    destination.parent.mkdir(parents=True, exist_ok=True)
    resized = master.resize((size, size), Image.LANCZOS)
    if with_alpha:
        resized.convert("RGBA").save(destination, "PNG", optimize=True)
    else:
        resized.convert("RGB").save(destination, "PNG", optimize=True)


def _format_number(value: float) -> str:
    text = f"{value:.3f}".rstrip("0").rstrip(".")
    return text if text else "0"


def _vector_path_data(path: dict, viewport: int) -> str:
    """把归一化路径转成 Android VectorDrawable pathData（viewport 坐标系）。"""
    commands: list[str] = []
    for subpath in path["subpaths"]:
        for index, (op, points) in enumerate(subpath):
            if index == 0:
                x, y = points[0]
                commands.append(f"M {_format_number(x * viewport)},{_format_number(y * viewport)}")
            if op == "L":
                x, y = points[1]
                commands.append(f"L {_format_number(x * viewport)},{_format_number(y * viewport)}")
            else:
                control_points = " ".join(
                    f"{_format_number(x * viewport)},{_format_number(y * viewport)}"
                    for x, y in points[1:]
                )
                commands.append(f"C {control_points}")
        commands.append("Z")
    return " ".join(commands)


def write_adaptive_foreground(paths: list[dict], destination: Path) -> None:
    """生成 108×108dp 自适应图标前景矢量。"""
    viewport = 108
    path_elements = []
    for path in paths:
        path_data = _vector_path_data(path, viewport)
        fill_type = ' android:fillType="evenOdd"' if path["even_odd"] else ""
        path_elements.append(
            f'    <path\n'
            f'        android:fillColor="#FFFFFF"{fill_type}\n'
            f'        android:pathData="{path_data}" />'
        )

    xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="108dp"\n'
        '    android:height="108dp"\n'
        '    android:viewportWidth="108"\n'
        '    android:viewportHeight="108">\n'
        + "\n".join(path_elements)
        + "\n</vector>\n"
    )
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(xml, encoding="utf-8")


def write_adaptive_icon_xml(destination: Path) -> None:
    xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
        '    <!-- Android 13+ 主题图标：复用同一线稿图层，由系统按壁纸取色 -->\n'
        '    <monochrome android:drawable="@drawable/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n'
    )
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(xml, encoding="utf-8")


def ensure_background_color(destination: Path) -> None:
    """在 values/colors.xml 中补充 ic_launcher_background（幂等）。"""
    destination.parent.mkdir(parents=True, exist_ok=True)
    color_line = '    <color name="ic_launcher_background">#0A6E52</color>\n'
    if destination.exists():
        content = destination.read_text(encoding="utf-8")
        if "ic_launcher_background" in content:
            return
        content = content.replace("</resources>", color_line + "</resources>")
        destination.write_text(content, encoding="utf-8")
        return

    destination.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        + color_line
        + "</resources>\n",
        encoding="utf-8",
    )


def ensure_round_icon_manifest_entry() -> None:
    """给 AndroidManifest.xml 补充 android:roundIcon（幂等）。"""
    if not ANDROID_MANIFEST.exists():
        print(f"  ! 未找到 AndroidManifest.xml，跳过 roundIcon: {ANDROID_MANIFEST}")
        return

    content = ANDROID_MANIFEST.read_text(encoding="utf-8")
    if "android:roundIcon" in content:
        return
    needle = 'android:icon="@mipmap/ic_launcher"'
    replacement = (
        'android:icon="@mipmap/ic_launcher"\n'
        '        android:roundIcon="@mipmap/ic_launcher_round"'
    )
    if needle not in content:
        print("  ! AndroidManifest.xml 未找到 android:icon 配置，跳过 roundIcon")
        return
    ANDROID_MANIFEST.write_text(content.replace(needle, replacement, 1), encoding="utf-8")


def generate_android(paths: list[dict]) -> None:
    print("Android:")
    legacy_rounded = build_master(paths, shape="rounded")
    legacy_round = build_master(paths, shape="circle")

    for density, size in ANDROID_DENSITIES.items():
        directory = ANDROID_RES / f"mipmap-{density}"
        save_icon(legacy_rounded, directory / "ic_launcher.png", size, with_alpha=True)
        save_icon(legacy_round, directory / "ic_launcher_round.png", size, with_alpha=True)
        print(f"  mipmap-{density}: ic_launcher.png / ic_launcher_round.png ({size}px)")

    anydpi = ANDROID_RES / "mipmap-anydpi-v26"
    write_adaptive_icon_xml(anydpi / "ic_launcher.xml")
    write_adaptive_icon_xml(anydpi / "ic_launcher_round.xml")
    write_adaptive_foreground(paths, ANDROID_RES / "drawable" / "ic_launcher_foreground.xml")
    ensure_background_color(ANDROID_RES / "values" / "colors.xml")
    ensure_round_icon_manifest_entry()
    print("  mipmap-anydpi-v26: ic_launcher.xml / ic_launcher_round.xml")
    print("  drawable/ic_launcher_foreground.xml (108dp vector)")
    print("  values/colors.xml: ic_launcher_background=#0A6E52")


def _ios_pixel_size(item: dict) -> int:
    width, height = item["size"].lower().split("x")
    if width != height:
        raise ValueError(f"iOS 图标要求正方形: {item}")
    scale = int(item["scale"].lower().rstrip("x"))
    return int(round(float(width) * scale))


def generate_ios(paths: list[dict]) -> None:
    print("iOS:")
    contents_path = IOS_APPICON / "Contents.json"
    if not contents_path.exists():
        print(f"  ! 未找到 {contents_path}，跳过")
        return

    master = build_master(paths, shape="square")
    contents = json.loads(contents_path.read_text(encoding="utf-8"))
    generated: set[int] = set()
    for item in contents.get("images", []):
        filename = item.get("filename")
        if not filename:
            continue
        size = _ios_pixel_size(item)
        save_icon(master, IOS_APPICON / filename, size, with_alpha=False)
        generated.add(size)
    print(f"  已生成 {len(generated)} 种像素尺寸: {sorted(generated)}")


def main() -> int:
    print(f"设计稿: {DESIGN_PDF}")
    geometry, paths = extract_design_geometry(DESIGN_PDF)
    print(
        "主图预览画布: "
        f"{geometry['rect'].width:.1f}×{geometry['rect'].height:.1f}pt；"
        "保留设计稿视觉重心（环心上移约 3.7%）"
    )

    generate_android(paths)
    generate_ios(paths)
    print("完成。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
