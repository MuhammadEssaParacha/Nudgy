"""
Nudge Penguin Icon Generator v2 — Professional Bezier Character
===============================================================
Uses pycairo for proper vector graphics: bezier curves, gradients,
shadows, anti-aliased compositing.

Follows nudge-penguin-spec.md exactly.
Renders at 4x (4096) and downsamples to 1024 for crisp anti-aliasing.

Output: 3 iOS icon variants → Xcode asset catalog
"""

import cairo
import math
import os

# ---- Dimensions ----
RENDER_SIZE = 4096        # 4x supersample
OUTPUT_SIZE = 1024        # Final icon size
S = RENDER_SIZE / 1024.0  # Scale factor

# ---- Paths ----
OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "Nudge", "Nudge", "Assets.xcassets", "AppIcon.appiconset"
)

# ---- Colors (from penguin spec) ----
def rgb(r, g, b):
    return (r / 255.0, g / 255.0, b / 255.0)

def rgba(r, g, b, a):
    return (r / 255.0, g / 255.0, b / 255.0, a)

# Penguin palette
PLUMAGE_DARK = rgb(26, 26, 46)       # #1A1A2E
PLUMAGE_HIGHLIGHT = rgb(42, 42, 66)  # #2A2A42
PLUMAGE_EDGE = rgb(52, 52, 80)       # subtle edge light
BELLY_YELLOW = rgb(255, 224, 102)     # #FFE066 — new warm yellow top
BELLY_WARM   = rgb(255, 240, 176)    # #FFF0B0 — warm midtone
BELLY_TOP = rgb(245, 245, 247)       # #F5F5F7 — fades to white at bottom
BELLY_BOTTOM = rgb(232, 232, 236)    # #E8E8EC
ACCENT_BLUE = rgb(0, 122, 255)       # #007AFF
ACCENT_BLUE_DARK = rgb(0, 85, 204)   # #0055CC
ACCENT_BLUE_LIGHT = rgb(51, 153, 255)# #3399FF
EYE_BLACK = rgb(10, 10, 14)
EYE_WHITE = rgb(255, 255, 255)
BLUSH = rgba(255, 107, 138, 0.12)    # #FF6B8A at 12%
SCARF_SHADOW = rgba(0, 60, 150, 0.3)

# Background palette
BG_LIGHT = rgb(17, 17, 22)           # #111116
BG_DARK = rgb(0, 0, 0)              # #000000


def s(val):
    """Scale a value."""
    return val * S


def create_surface():
    """Create a Cairo ARGB surface at render size."""
    return cairo.ImageSurface(cairo.FORMAT_ARGB32, RENDER_SIZE, RENDER_SIZE)


def draw_background(ctx, variant="dark"):
    """Draw the icon background with radial glow."""
    cx, cy = RENDER_SIZE / 2, RENDER_SIZE / 2

    if variant == "tinted":
        # Transparent background
        ctx.set_source_rgba(0, 0, 0, 0)
        ctx.paint()
        return

    # Solid background
    bg = BG_DARK if variant == "dark" else BG_LIGHT
    ctx.set_source_rgb(*bg)
    ctx.paint()

    # Radial glow behind penguin
    glow_intensity = 0.30 if variant == "dark" else 0.40
    glow_radius = s(420)
    glow_cy = cy + s(20)

    pat = cairo.RadialGradient(cx, glow_cy, 0, cx, glow_cy, glow_radius)
    pat.add_color_stop_rgba(0.0, 0/255, 122/255, 255/255, glow_intensity * 0.6)
    pat.add_color_stop_rgba(0.4, 0/255, 100/255, 220/255, glow_intensity * 0.3)
    pat.add_color_stop_rgba(0.7, 0/255, 60/255, 160/255, glow_intensity * 0.1)
    pat.add_color_stop_rgba(1.0, 0, 0, 0, 0)
    ctx.set_source(pat)
    ctx.paint()


def draw_drop_shadow(ctx, draw_func):
    """Draw a soft drop shadow by rendering the shape offset and blurred."""
    # We'll do a simple multi-pass offset shadow
    ctx.save()
    for i in range(8):
        ctx.save()
        offset = s(2 + i * 0.5)
        ctx.translate(0, offset)
        ctx.set_source_rgba(0, 0, 0, 0.03)
        draw_func(ctx, shadow=True)
        ctx.restore()
    ctx.restore()


def draw_body_shape(ctx, cx, cy, psize, shadow=False):
    """
    Draw the penguin body — smooth egg/pear shape using bezier curves.
    No neck — head flows directly into body.
    """
    # Body dimensions
    body_w = psize * 0.44   # half-width
    body_h = psize * 0.48   # half-height
    body_cy = cy + psize * 0.08

    # Egg shape: wider at bottom, narrower at top where head connects
    ctx.new_path()

    # Start at top-center (where head overlaps)
    top_x = cx
    top_y = body_cy - body_h * 0.85

    # Right side curve — goes from top, bulges out, comes to bottom
    ctx.move_to(top_x, top_y)
    ctx.curve_to(
        cx + body_w * 0.6, top_y,                    # control 1: gentle start
        cx + body_w * 1.1, body_cy - body_h * 0.15,  # control 2: max width point
        cx + body_w * 0.95, body_cy + body_h * 0.5   # end: lower right
    )
    ctx.curve_to(
        cx + body_w * 0.85, body_cy + body_h * 0.85,  # control 1
        cx + body_w * 0.4, body_cy + body_h * 1.0,    # control 2
        cx, body_cy + body_h * 0.95                    # end: bottom center
    )

    # Left side (mirror)
    ctx.curve_to(
        cx - body_w * 0.4, body_cy + body_h * 1.0,
        cx - body_w * 0.85, body_cy + body_h * 0.85,
        cx - body_w * 0.95, body_cy + body_h * 0.5
    )
    ctx.curve_to(
        cx - body_w * 1.1, body_cy - body_h * 0.15,
        cx - body_w * 0.6, top_y,
        top_x, top_y
    )
    ctx.close_path()

    if shadow:
        ctx.fill()
        return

    # Body gradient: dark plumage with subtle highlight at edges
    pat = cairo.LinearGradient(cx - body_w, body_cy, cx + body_w, body_cy)
    pat.add_color_stop_rgb(0.0, *PLUMAGE_EDGE)
    pat.add_color_stop_rgb(0.15, *PLUMAGE_DARK)
    pat.add_color_stop_rgb(0.85, *PLUMAGE_DARK)
    pat.add_color_stop_rgb(1.0, *PLUMAGE_EDGE)
    ctx.set_source(pat)
    ctx.fill()


def draw_belly_oval(ctx, cx, belly_cy, belly_w, belly_h):
    """Helper: draw an ellipse path for the belly."""
    kappa = 0.5522848
    ctx.new_path()
    ctx.move_to(cx, belly_cy - belly_h)
    ctx.curve_to(cx + belly_w * kappa, belly_cy - belly_h, cx + belly_w, belly_cy - belly_h * kappa, cx + belly_w, belly_cy)
    ctx.curve_to(cx + belly_w, belly_cy + belly_h * kappa, cx + belly_w * kappa, belly_cy + belly_h, cx, belly_cy + belly_h)
    ctx.curve_to(cx - belly_w * kappa, belly_cy + belly_h, cx - belly_w, belly_cy + belly_h * kappa, cx - belly_w, belly_cy)
    ctx.curve_to(cx - belly_w, belly_cy - belly_h * kappa, cx - belly_w * kappa, belly_cy - belly_h, cx, belly_cy - belly_h)
    ctx.close_path()


def draw_belly(ctx, cx, cy, psize):
    """Yellow-to-white belly patch matching new in-app Nudgy design."""
    belly_w = psize * 0.30
    belly_h = psize * 0.38
    belly_cy = cy + psize * 0.14

    draw_belly_oval(ctx, cx, belly_cy, belly_w, belly_h)

    # Yellow top → warm midtone → white bottom (matches PenguinMascot.swift exactly)
    pat = cairo.LinearGradient(cx, belly_cy - belly_h, cx, belly_cy + belly_h)
    pat.add_color_stop_rgb(0.0,  *BELLY_YELLOW)   # #FFE066
    pat.add_color_stop_rgb(0.30, *BELLY_WARM)      # #FFF0B0
    pat.add_color_stop_rgb(0.65, *BELLY_TOP)       # #F5F5F7
    pat.add_color_stop_rgb(1.0,  *BELLY_BOTTOM)    # #E8E8EC
    ctx.set_source(pat)
    ctx.fill()

    # Specular highlight — top-left key light sheen
    draw_belly_oval(ctx, cx, belly_cy, belly_w, belly_h)
    shine = cairo.RadialGradient(
        cx - belly_w * 0.35, belly_cy - belly_h * 0.35, 0,
        cx - belly_w * 0.35, belly_cy - belly_h * 0.35, belly_w * 0.5
    )
    shine.add_color_stop_rgba(0.0, 1, 1, 1, 0.20)
    shine.add_color_stop_rgba(1.0, 1, 1, 1, 0.0)
    ctx.set_source(shine)
    ctx.fill()

    # Belly button — ∩ arc (upside-down U navel), matching SwiftUI version
    r = psize * 0.028
    btn_y = belly_cy + belly_h * 0.30
    ctx.new_path()
    ctx.move_to(cx - r, btn_y)
    ctx.curve_to(cx - r * 0.6, btn_y - r * 1.3, cx + r * 0.6, btn_y - r * 1.3, cx + r, btn_y)
    ctx.set_source_rgba(0, 0, 0, 0.18)
    ctx.set_line_width(psize * 0.008)
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    ctx.stroke()


def draw_head(ctx, cx, cy, psize, shadow=False):
    """
    Large round head — slightly wider than body, sitting directly on top.
    Slight 5° rightward tilt applied via transform.
    """
    head_r = psize * 0.28   # radius
    head_cy = cy - psize * 0.22

    # Apply subtle tilt
    ctx.save()
    ctx.translate(cx, head_cy)
    ctx.rotate(math.radians(3))  # subtle tilt
    ctx.translate(-cx, -head_cy)

    # Draw circle using bezier
    kappa = 0.5522848
    rx = head_r * 1.08  # slightly wider than tall
    ry = head_r

    ctx.new_path()
    ctx.move_to(cx, head_cy - ry)
    ctx.curve_to(cx + rx * kappa, head_cy - ry, cx + rx, head_cy - ry * kappa, cx + rx, head_cy)
    ctx.curve_to(cx + rx, head_cy + ry * kappa, cx + rx * kappa, head_cy + ry, cx, head_cy + ry)
    ctx.curve_to(cx - rx * kappa, head_cy + ry, cx - rx, head_cy + ry * kappa, cx - rx, head_cy)
    ctx.curve_to(cx - rx, head_cy - ry * kappa, cx - rx * kappa, head_cy - ry, cx, head_cy - ry)
    ctx.close_path()

    if shadow:
        ctx.fill()
        ctx.restore()
        return

    # Head gradient: dark with subtle top highlight
    pat = cairo.RadialGradient(cx - head_r * 0.3, head_cy - head_r * 0.4, 0,
                                cx, head_cy, head_r * 1.2)
    pat.add_color_stop_rgb(0.0, *PLUMAGE_HIGHLIGHT)
    pat.add_color_stop_rgb(0.5, *PLUMAGE_DARK)
    pat.add_color_stop_rgb(1.0, *PLUMAGE_DARK)
    ctx.set_source(pat)
    ctx.fill()

    ctx.restore()


def draw_face_patch(ctx, cx, cy, psize):
    """White face area — where eyes and beak sit."""
    head_cy = cy - psize * 0.22
    face_w = psize * 0.20
    face_h = psize * 0.17
    face_cy = head_cy + psize * 0.04

    ctx.save()
    ctx.translate(cx, head_cy)
    ctx.rotate(math.radians(3))
    ctx.translate(-cx, -head_cy)

    kappa = 0.5522848
    ctx.new_path()
    ctx.move_to(cx, face_cy - face_h)
    ctx.curve_to(cx + face_w * kappa, face_cy - face_h, cx + face_w, face_cy - face_h * kappa, cx + face_w, face_cy)
    ctx.curve_to(cx + face_w, face_cy + face_h * kappa, cx + face_w * kappa, face_cy + face_h, cx, face_cy + face_h)
    ctx.curve_to(cx - face_w * kappa, face_cy + face_h, cx - face_w, face_cy + face_h * kappa, cx - face_w, face_cy)
    ctx.curve_to(cx - face_w, face_cy - face_h * kappa, cx - face_w * kappa, face_cy - face_h, cx, face_cy - face_h)
    ctx.close_path()

    ctx.set_source_rgb(1, 1, 1)
    ctx.fill()
    ctx.restore()


def draw_eyes(ctx, cx, cy, psize):
    """Large expressive eyes — right eye 5% larger for asymmetry."""
    head_cy = cy - psize * 0.22
    eye_y = head_cy + psize * 0.01
    eye_spacing = psize * 0.095

    ctx.save()
    ctx.translate(cx, head_cy)
    ctx.rotate(math.radians(3))
    ctx.translate(-cx, -head_cy)

    for side in [-1, 1]:  # -1 = left, 1 = right
        ex = cx + side * eye_spacing
        # Right eye slightly larger
        base_r = psize * 0.042
        er = base_r * (1.05 if side == 1 else 1.0)

        # Eye white (outer)
        ctx.new_path()
        ctx.arc(ex, eye_y, er * 1.15, 0, 2 * math.pi)
        ctx.set_source_rgb(*EYE_WHITE)
        ctx.fill()

        # Iris/pupil (large, fills most of eye)
        ctx.new_path()
        ctx.arc(ex, eye_y, er, 0, 2 * math.pi)
        ctx.set_source_rgb(*EYE_BLACK)
        ctx.fill()

        # Main shine (top-right, large)
        shine_r = er * 0.38
        shine_x = ex + er * 0.28
        shine_y = eye_y - er * 0.30
        ctx.new_path()
        ctx.arc(shine_x, shine_y, shine_r, 0, 2 * math.pi)
        ctx.set_source_rgba(1, 1, 1, 0.92)
        ctx.fill()

        # Secondary shine (bottom-left, small)
        shine2_r = er * 0.18
        shine2_x = ex - er * 0.22
        shine2_y = eye_y + er * 0.28
        ctx.new_path()
        ctx.arc(shine2_x, shine2_y, shine2_r, 0, 2 * math.pi)
        ctx.set_source_rgba(1, 1, 1, 0.55)
        ctx.fill()

    ctx.restore()


def draw_beak(ctx, cx, cy, psize):
    """Small downward-pointing triangular beak in accent blue."""
    head_cy = cy - psize * 0.22
    beak_cy = head_cy + psize * 0.095
    beak_w = psize * 0.042
    beak_h = psize * 0.035

    ctx.save()
    ctx.translate(cx, head_cy)
    ctx.rotate(math.radians(3))
    ctx.translate(-cx, -head_cy)

    # Rounded triangle using bezier
    ctx.new_path()
    ctx.move_to(cx, beak_cy + beak_h)  # bottom point
    ctx.curve_to(
        cx - beak_w * 0.3, beak_cy + beak_h * 0.3,  # curve in from left
        cx - beak_w, beak_cy - beak_h * 0.2,
        cx - beak_w * 0.8, beak_cy - beak_h * 0.5    # top left
    )
    ctx.curve_to(
        cx - beak_w * 0.4, beak_cy - beak_h * 0.9,
        cx + beak_w * 0.4, beak_cy - beak_h * 0.9,
        cx + beak_w * 0.8, beak_cy - beak_h * 0.5    # top right
    )
    ctx.curve_to(
        cx + beak_w, beak_cy - beak_h * 0.2,
        cx + beak_w * 0.3, beak_cy + beak_h * 0.3,
        cx, beak_cy + beak_h                          # back to bottom
    )
    ctx.close_path()

    # Blue gradient on beak
    pat = cairo.LinearGradient(cx, beak_cy - beak_h, cx, beak_cy + beak_h)
    pat.add_color_stop_rgb(0.0, *ACCENT_BLUE_LIGHT)
    pat.add_color_stop_rgb(1.0, *ACCENT_BLUE)
    ctx.set_source(pat)
    ctx.fill()

    ctx.restore()


def draw_cheek_blush(ctx, cx, cy, psize):
    """Very subtle pink blush circles on cheeks."""
    head_cy = cy - psize * 0.22
    blush_y = head_cy + psize * 0.04
    blush_spacing = psize * 0.145
    blush_r = psize * 0.035

    ctx.save()
    ctx.translate(cx, head_cy)
    ctx.rotate(math.radians(3))
    ctx.translate(-cx, -head_cy)

    for side in [-1, 1]:
        bx = cx + side * blush_spacing
        pat = cairo.RadialGradient(bx, blush_y, 0, bx, blush_y, blush_r)
        pat.add_color_stop_rgba(0.0, 255/255, 107/255, 138/255, 0.15)
        pat.add_color_stop_rgba(0.6, 255/255, 107/255, 138/255, 0.08)
        pat.add_color_stop_rgba(1.0, 255/255, 107/255, 138/255, 0.0)
        ctx.set_source(pat)
        ctx.new_path()
        ctx.arc(bx, blush_y, blush_r, 0, 2 * math.pi)
        ctx.fill()

    ctx.restore()


def draw_wings(ctx, cx, cy, psize, shadow=False):
    """Stubby flippers angled 15° outward from body."""
    wing_h = psize * 0.22
    wing_w = psize * 0.10
    wing_y = cy + psize * 0.02

    for side in [-1, 1]:
        ctx.save()

        wing_x = cx + side * psize * 0.37
        angle = side * math.radians(15)

        ctx.translate(wing_x, wing_y - wing_h * 0.4)
        ctx.rotate(angle)

        # Teardrop/flipper shape
        ctx.new_path()
        ctx.move_to(0, -wing_h * 0.5)  # top (attached to body)
        ctx.curve_to(
            side * wing_w * 0.8, -wing_h * 0.3,
            side * wing_w * 1.2, wing_h * 0.1,
            side * wing_w * 0.6, wing_h * 0.5    # tip
        )
        ctx.curve_to(
            side * wing_w * 0.2, wing_h * 0.65,
            -side * wing_w * 0.2, wing_h * 0.2,
            0, -wing_h * 0.5                      # back to top
        )
        ctx.close_path()

        if shadow:
            ctx.fill()
        else:
            # Wing gradient
            pat = cairo.LinearGradient(0, -wing_h * 0.5, side * wing_w, wing_h * 0.5)
            pat.add_color_stop_rgb(0.0, *PLUMAGE_DARK)
            pat.add_color_stop_rgb(0.5, *PLUMAGE_DARK)
            pat.add_color_stop_rgb(1.0, *PLUMAGE_HIGHLIGHT)
            ctx.set_source(pat)
            ctx.fill()

        ctx.restore()


def draw_scarf(ctx, cx, cy, psize):
    """Blue scarf wrapping the head-body junction with a trailing tail."""
    scarf_y = cy - psize * 0.065
    scarf_h = psize * 0.035
    scarf_w = psize * 0.30

    # Main wrap
    ctx.new_path()
    ctx.move_to(cx - scarf_w, scarf_y - scarf_h)
    ctx.curve_to(
        cx - scarf_w * 0.5, scarf_y - scarf_h * 1.8,
        cx + scarf_w * 0.5, scarf_y - scarf_h * 1.8,
        cx + scarf_w, scarf_y - scarf_h
    )
    ctx.curve_to(
        cx + scarf_w * 1.05, scarf_y + scarf_h * 0.5,
        cx + scarf_w * 0.5, scarf_y + scarf_h * 2.5,
        cx + scarf_w * 0.3, scarf_y + scarf_h * 2.0
    )
    # Tail piece curves down-right
    ctx.curve_to(
        cx + scarf_w * 0.65, scarf_y + scarf_h * 4.0,
        cx + scarf_w * 0.85, scarf_y + scarf_h * 5.5,
        cx + scarf_w * 0.55, scarf_y + scarf_h * 6.5
    )
    # Tail end back up
    ctx.curve_to(
        cx + scarf_w * 0.35, scarf_y + scarf_h * 5.0,
        cx + scarf_w * 0.45, scarf_y + scarf_h * 3.5,
        cx + scarf_w * 0.15, scarf_y + scarf_h * 2.0
    )
    # Close along bottom of main wrap
    ctx.curve_to(
        cx - scarf_w * 0.3, scarf_y + scarf_h * 2.8,
        cx - scarf_w * 0.8, scarf_y + scarf_h * 1.5,
        cx - scarf_w, scarf_y - scarf_h
    )
    ctx.close_path()

    # Blue gradient
    pat = cairo.LinearGradient(cx - scarf_w, scarf_y, cx + scarf_w, scarf_y)
    pat.add_color_stop_rgb(0.0, *ACCENT_BLUE)
    pat.add_color_stop_rgb(0.5, *ACCENT_BLUE)
    pat.add_color_stop_rgb(1.0, *ACCENT_BLUE_DARK)
    ctx.set_source(pat)
    ctx.fill_preserve()

    # Thin highlight along top edge
    ctx.set_source_rgba(*ACCENT_BLUE_LIGHT, 0.5)
    ctx.set_line_width(s(2))
    ctx.stroke()


def draw_feet(ctx, cx, cy, psize):
    """Small blue feet peeking out at the bottom."""
    body_bottom = cy + psize * 0.50
    foot_w = psize * 0.065
    foot_h = psize * 0.025
    foot_spacing = psize * 0.08

    for side in [-1, 1]:
        fx = cx + side * foot_spacing
        fy = body_bottom

        ctx.new_path()
        # Rounded foot shape
        kappa = 0.5522848
        ctx.move_to(fx, fy - foot_h)
        ctx.curve_to(fx + foot_w * kappa, fy - foot_h, fx + foot_w, fy - foot_h * kappa, fx + foot_w, fy)
        ctx.curve_to(fx + foot_w, fy + foot_h * kappa, fx + foot_w * kappa, fy + foot_h, fx, fy + foot_h)
        ctx.curve_to(fx - foot_w * kappa, fy + foot_h, fx - foot_w, fy + foot_h * kappa, fx - foot_w, fy)
        ctx.curve_to(fx - foot_w, fy - foot_h * kappa, fx - foot_w * kappa, fy - foot_h, fx, fy - foot_h)
        ctx.close_path()

        ctx.set_source_rgba(0/255, 122/255, 255/255, 0.7)
        ctx.fill()


def draw_penguin_full(ctx, variant="dark"):
    """Draw the complete penguin character — zoomed-in bust composition."""
    cx = RENDER_SIZE / 2
    # Shift down so belly fills frame nicely; feet crop naturally at bottom
    cy = RENDER_SIZE / 2 + s(55)
    # 29% bigger than v1 (880 vs 680) → bust portrait, head prominent
    psize = s(880)

    if variant == "tinted":
        draw_tinted_silhouette(ctx, cx, cy, psize)
        return

    # Shadow pass
    def shadow_func(c, shadow=True):
        draw_body_shape(c, cx, cy, psize, shadow=True)
        draw_head(c, cx, cy, psize, shadow=True)
    draw_drop_shadow(ctx, shadow_func)

    # Draw order (back to front) — no scarf, matching new in-app Nudgy:
    draw_feet(ctx, cx, cy, psize)
    draw_body_shape(ctx, cx, cy, psize)
    draw_belly(ctx, cx, cy, psize)
    draw_wings(ctx, cx, cy, psize)
    # draw_scarf removed — new Nudgy has no scarf
    draw_head(ctx, cx, cy, psize)
    draw_face_patch(ctx, cx, cy, psize)
    draw_cheek_blush(ctx, cx, cy, psize)
    draw_eyes(ctx, cx, cy, psize)
    draw_beak(ctx, cx, cy, psize)


def draw_tinted_silhouette(ctx, cx, cy, psize):
    """White silhouette for tinted icon variant — no scarf."""
    ctx.set_source_rgb(1, 1, 1)

    # Body
    draw_body_shape(ctx, cx, cy, psize, shadow=True)
    # Head
    draw_head(ctx, cx, cy, psize, shadow=True)
    # Wings
    draw_wings(ctx, cx, cy, psize, shadow=True)
    # Feet (may be cropped by canvas at zoom level — that's fine)
    foot_bottom = cy + psize * 0.50
    foot_w = psize * 0.065
    foot_spacing = psize * 0.08
    for side2 in [-1, 1]:
        ctx.new_path()
        ctx.arc(cx + side2 * foot_spacing, foot_bottom, foot_w, 0, 2 * math.pi)
        ctx.fill()


def downsample(surface, from_size, to_size):
    """Downsample a Cairo surface using high-quality interpolation."""
    out = cairo.ImageSurface(cairo.FORMAT_ARGB32, to_size, to_size)
    ctx = cairo.Context(out)
    scale = to_size / from_size
    ctx.scale(scale, scale)
    ctx.set_source_surface(surface)
    # Use BEST filter for downsampling
    pattern = ctx.get_source()
    pattern.set_filter(cairo.FILTER_BEST)
    ctx.paint()
    return out


def generate_icon(variant):
    """Generate a single icon variant."""
    surface = create_surface()
    ctx = cairo.Context(surface)

    # Enable anti-aliasing
    ctx.set_antialias(cairo.ANTIALIAS_BEST)

    draw_background(ctx, variant)
    draw_penguin_full(ctx, variant)

    # Downsample 4096 → 1024
    final = downsample(surface, RENDER_SIZE, OUTPUT_SIZE)
    return final


def save_png(surface, filename):
    """Save a Cairo surface as PNG."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    path = os.path.join(OUTPUT_DIR, filename)
    surface.write_to_png(path)
    print(f"  ✅ {filename} ({OUTPUT_SIZE}×{OUTPUT_SIZE})")


def write_contents_json():
    """Write the Xcode asset catalog Contents.json."""
    json_str = '''{
  "images" : [
    {
      "filename" : "icon-light.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "icon-dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "icon-tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
'''
    path = os.path.join(OUTPUT_DIR, "Contents.json")
    with open(path, "w") as f:
        f.write(json_str)
    print(f"  ✅ Contents.json")


def main():
    print("🐧 Nudge Penguin Icon Generator v2 (Cairo)")
    print(f"   Render: {RENDER_SIZE}×{RENDER_SIZE} → {OUTPUT_SIZE}×{OUTPUT_SIZE}")
    print(f"   Output: {OUTPUT_DIR}")
    print()

    print("Generating variants...")

    light = generate_icon("light")
    save_png(light, "icon-light.png")

    dark = generate_icon("dark")
    save_png(dark, "icon-dark.png")

    tinted = generate_icon("tinted")
    save_png(tinted, "icon-tinted.png")

    write_contents_json()

    print()
    print("🎉 Done! Open in Preview or Xcode to verify.")


if __name__ == "__main__":
    main()
