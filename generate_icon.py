"""Generate a high-quality Zill logo icon for Android splash & launcher."""
from PIL import Image, ImageDraw, ImageFont
import math

SIZE = 1024
CENTER = SIZE // 2
BG_COLOR = (255, 255, 255)  # White background
ORANGE = (230, 81, 0)       # Primary orange
DARK_ORANGE = (200, 70, 0)
BLACK = (40, 40, 40)
WHITE = (255, 255, 255)

img = Image.new('RGBA', (SIZE, SIZE), (255, 255, 255, 255))
draw = ImageDraw.Draw(img)

# ── Outer circle (orange ring) ──
outer_r = 380
inner_r = 320
draw.ellipse(
    [CENTER - outer_r, CENTER - outer_r + 40, CENTER + outer_r, CENTER + outer_r + 40],
    fill=ORANGE, outline=ORANGE
)
draw.ellipse(
    [CENTER - inner_r, CENTER - inner_r + 40, CENTER + inner_r, CENTER + inner_r + 40],
    fill=WHITE, outline=WHITE
)

# ── Shield / V shape ──
shield_points = [
    (CENTER - 240, CENTER - 160 + 40),   # top left
    (CENTER + 240, CENTER - 160 + 40),   # top right
    (CENTER, CENTER + 280 + 40),          # bottom point
]
draw.polygon(shield_points, fill=ORANGE)

# Inner V (white)
inner_shield = [
    (CENTER - 180, CENTER - 110 + 40),
    (CENTER + 180, CENTER - 110 + 40),
    (CENTER, CENTER + 220 + 40),
]
draw.polygon(inner_shield, fill=WHITE)

# Inner orange V
inner_v = [
    (CENTER - 120, CENTER - 50 + 40),
    (CENTER + 120, CENTER - 50 + 40),
    (CENTER, CENTER + 170 + 40),
]
draw.polygon(inner_v, fill=ORANGE)

# ── Pizza slice (triangle at top) ──
pizza_points = [
    (CENTER - 140, CENTER - 120 + 40),
    (CENTER + 140, CENTER - 120 + 40),
    (CENTER, CENTER - 340 + 40),
]
draw.polygon(pizza_points, fill=ORANGE)

# Pizza crust (arc at top)
draw.arc(
    [CENTER - 160, CENTER - 390 + 40, CENTER + 160, CENTER - 250 + 40],
    180, 0, fill=ORANGE, width=30
)

# Pizza dots (toppings)
dot_r = 22
dots = [
    (CENTER - 50, CENTER - 200 + 40),
    (CENTER + 50, CENTER - 200 + 40),
    (CENTER, CENTER - 260 + 40),
]
for dx, dy in dots:
    draw.ellipse([dx - dot_r, dy - dot_r, dx + dot_r, dy + dot_r], fill=ORANGE)

# ── ZILL text banner (black curved banner) ──
banner_h = 70
banner_y = CENTER - 30 + 40
draw.rounded_rectangle(
    [CENTER - 170, banner_y - banner_h // 2, CENTER + 170, banner_y + banner_h // 2],
    radius=10, fill=BLACK
)

# ZILL text
try:
    font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 52)
except:
    font = ImageFont.load_default()

bbox = draw.textbbox((0, 0), "ZILL", font=font)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]
draw.text(
    (CENTER - tw // 2, banner_y - th // 2 - 5),
    "ZILL", fill=WHITE, font=font
)

# ── Small dots below banner ──
small_dots = [
    (CENTER - 40, CENTER + 60 + 40),
    (CENTER, CENTER + 90 + 40),
    (CENTER + 40, CENTER + 60 + 40),
]
for dx, dy in small_dots:
    draw.ellipse([dx - 15, dy - 15, dx + 15, dy + 15], fill=ORANGE)

# Save
output_path = "assets/logo/zill_icon_hq.png"
# Convert to RGB for Android compatibility
img_rgb = img.convert('RGB')
img_rgb.save(output_path, 'PNG', quality=100)
print(f"Saved to {output_path} — {img_rgb.size}")

# Also show it
img_rgb.save("zill_icon_preview.png", 'PNG')
print("Preview saved as zill_icon_preview.png")
