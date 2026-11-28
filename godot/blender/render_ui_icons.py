import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GODOT_DIR = os.path.dirname(SCRIPT_DIR)
PORTRAIT_DIR = os.path.join(GODOT_DIR, "assets", "portraits")
RAW_BUST_DIR = os.path.join(PORTRAIT_DIR, "_raw")
UI_DIR = os.path.join(GODOT_DIR, "assets", "ui")
FONT_PATH = os.path.join(GODOT_DIR, "assets", "fonts", "DejaVuSans.ttf")
os.makedirs(PORTRAIT_DIR, exist_ok=True)
os.makedirs(UI_DIR, exist_ok=True)


def _font(size: int):
    if os.path.isfile(FONT_PATH):
        return ImageFont.truetype(FONT_PATH, size=size)
    return ImageFont.load_default()


def hex_rgb(h: str):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


PORTRAIT_MAP = [
    ("player", "player", "#2A4B5C", "#4E8299"),
    ("player_cepol", "player_cepol", "#2A4B5C", "#4E8299"),
    ("player_hijab", "player_hijab", "#265146", "#458875"),
    ("ibu_melati", "ibu_melati", "#542C44", "#8A4D70"),
    ("ibu_sari", "ibu_sari", "#264B3D", "#447C66"),
    ("ibu_citra", "ibu_citra", "#433259", "#745996"),
    ("ibu_tini", "ibu_tini", "#3A4E31", "#628252"),
    ("ibu_kampung", "ibu_kampung", "#6E4223", "#B5723F"),
    ("pak_budi", "pak_budi", "#453628", "#7A5E44"),
    ("pak_hendra", "pak_hendra", "#2A3D54", "#4A6B91"),
    ("pak_rt", "pak_rt", "#4C3B26", "#856742"),
    ("pak_agus", "pak_agus", "#32454E", "#567482"),
    ("bang_ojek", "bang_ojek", "#1E4D32", "#348456"),
    ("kurir_paket", "kurir_paket", "#59371E", "#995E34"),
    ("anak_sekolah", "anak_sekolah", "#2D4761", "#4C759E"),
    ("adik_bima", "adik_bima", "#5C2A34", "#9E4C5E"),
    ("mbak_dewi", "mbak_dewi", "#3A543E", "#628B68"),
    ("kakak_nadine", "kakak_nadine", "#592D40", "#964C6B"),
    ("kakak_maya", "kakak_maya", "#2A445E", "#4A749E"),
    ("mbak_rina", "mbak_rina", "#294F48", "#46867A"),
]


def composite_portraits():
    size = 256
    for pid, raw_tag, c_dark, c_light in PORTRAIT_MAP:
        raw_path = os.path.join(RAW_BUST_DIR, f"{raw_tag}.png")
        if not os.path.isfile(raw_path):
            print("Skip missing raw bust:", raw_path)
            continue
        cd = hex_rgb(c_dark)
        cl = hex_rgb(c_light)
        bg = Image.new("RGBA", (size, size), (*cd, 255))
        # Radial glow backdrop
        glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        for r in range(120, 8, -4):
            t = 1.0 - (r / 120.0)
            col = tuple(int(cd[k] * (1 - t) + cl[k] * t) for k in range(3)) + (255,)
            gd.ellipse((size // 2 - r, size // 2 - r - 12, size // 2 + r, size // 2 + r - 12), fill=col)
        bg = Image.alpha_composite(bg, glow)

        bust = Image.open(raw_path).convert("RGBA")
        # Subtle shadow behind character
        alpha = bust.split()[3]
        sh = Image.new("RGBA", (size, size), (10, 12, 16, 110))
        sh.putalpha(alpha.point(lambda a: int(a * 0.42)))
        sh = sh.filter(ImageFilter.GaussianBlur(6))
        bg.alpha_composite(sh, (3, 5))
        bg.alpha_composite(bust, (0, 0))

        # Clean full-bleed square portrait (HUD frame adds single border cleanly)
        out_p = os.path.join(PORTRAIT_DIR, f"portrait_{pid}.png")
        bg.save(out_p)
    print(f"Composited {len(PORTRAIT_MAP)} high-res 256x256 portraits.")


def _ss_canvas(size=128):
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img), s


def _finish(img: Image.Image, out_name: str, size=128):
    out = img.resize((size, size), Image.Resampling.LANCZOS)
    out.save(os.path.join(UI_DIR, out_name))


def _draw_rounded_app_tile(draw: ImageDraw.ImageDraw, s: int, c_top, c_bot, rim=(255, 255, 255, 90)):
    # Outer drop shadow
    draw.rounded_rectangle((36, 44, s - 36, s - 24), radius=96, fill=(12, 16, 24, 110))
    # Main body gradient approximation
    steps = 18
    for i in range(steps):
        t = i / max(1, steps - 1)
        col = tuple(int(c_top[k] * (1 - t) + c_bot[k] * t) for k in range(3)) + (255,)
        inset = 36
        y0 = inset + int((s - 2 * inset - 16) * (i / steps))
        y1 = s - inset - 10
        draw.rounded_rectangle((inset, y0, s - inset, y1), radius=88, fill=col)
    draw.rounded_rectangle((36, 32, s - 36, s - 40), radius=88, outline=rim, width=8)


def _draw_badge_plate(draw: ImageDraw.ImageDraw, s: int, bg_col=(246, 240, 224, 245), rim_col=(230, 178, 56, 255)):
    draw.ellipse((34, 42, s - 34, s - 22), fill=(12, 16, 24, 120))
    draw.ellipse((34, 30, s - 34, s - 34), fill=bg_col, outline=rim_col, width=14)
    # Gloss arc
    draw.arc((64, 54, s - 64, s - 80), start=205, end=335, fill=(255, 255, 255, 160), width=12)


def build_ui_icons():
    # 1. Dock: icon_phone.png
    img, d, s = _ss_canvas()
    d.rounded_rectangle((116, 48, s - 116, s - 28), radius=46, fill=(10, 14, 20, 130))
    d.rounded_rectangle((112, 32, s - 112, s - 40), radius=44, fill=(32, 42, 62, 255), outline=(245, 198, 68, 255), width=14)
    d.rounded_rectangle((140, 72, s - 140, s - 92), radius=24, fill=(52, 126, 196, 255))
    app_cols = [(72, 210, 112), (245, 188, 56), (235, 86, 82), (82, 196, 245), (190, 118, 238), (248, 144, 64)]
    for idx, col in enumerate(app_cols):
        r, c = divmod(idx, 3)
        x0 = 160 + c * 66
        y0 = 104 + r * 72
        d.rounded_rectangle((x0, y0, x0 + 50, y0 + 50), radius=14, fill=(*col, 255))
    d.ellipse((s // 2 - 16, s - 76, s // 2 + 16, s - 44), fill=(220, 228, 240, 220))
    _finish(img, "icon_phone.png")

    # 2. Dock: icon_door.png
    img, d, s = _ss_canvas()
    _draw_badge_plate(d, s, (42, 62, 54, 255), (242, 194, 68, 255))
    d.rounded_rectangle((158, 108, s - 158, s - 96), radius=20, fill=(248, 212, 104, 255))
    d.polygon([(164, 112), (312, 132), (312, s - 98), (164, s - 98)], fill=(138, 82, 42, 255), outline=(72, 42, 20, 255))
    d.ellipse((276, 248, 298, 270), fill=(248, 204, 72, 255))
    _finish(img, "icon_door.png")

    # 3. Dock: icon_broom.png
    img, d, s = _ss_canvas()
    _draw_badge_plate(d, s, (42, 86, 62, 255), (245, 198, 66, 255))
    # Handle
    d.line((344, 116, 208, 286), fill=(196, 126, 58, 255), width=26)
    d.line((340, 112, 204, 282), fill=(228, 162, 88, 255), width=10)
    # Bristles fan
    d.polygon([(176, 258), (242, 310), (164, 388), (112, 342)], fill=(238, 186, 72, 255), outline=(146, 98, 28, 255))
    d.rounded_rectangle((172, 256, 248, 306), radius=12, fill=(214, 68, 56, 255))
    # Sparkle
    d.polygon([(352, 224), (366, 256), (398, 270), (366, 284), (352, 316), (338, 284), (306, 270), (338, 256)], fill=(255, 244, 160, 255))
    _finish(img, "icon_broom.png")

    # 4. Dock: icon_career.png
    img, d, s = _ss_canvas()
    _draw_badge_plate(d, s, (48, 54, 74, 255), (245, 198, 68, 255))
    # Briefcase / Medal
    d.rounded_rectangle((132, 168, s - 132, s - 120), radius=28, fill=(184, 112, 52, 255), outline=(248, 212, 108, 255), width=10)
    d.arc((198, 116, s - 198, 206), start=180, end=360, fill=(238, 196, 96, 255), width=20)
    d.rectangle((136, 232, s - 136, 252), fill=(118, 68, 28, 255))
    d.rounded_rectangle((226, 220, s - 226, 274), radius=12, fill=(248, 204, 72, 255))
    _finish(img, "icon_career.png")

    # 5. Dock: icon_wardrobe.png
    img, d, s = _ss_canvas()
    _draw_badge_plate(d, s, (52, 46, 72, 255), (245, 198, 68, 255))
    # Shirt + apron silhouette
    d.polygon([(192, 134), (320, 134), (390, 206), (344, 246), (318, 218), (318, 376), (194, 376), (194, 218), (168, 246), (122, 206)], fill=(54, 152, 118, 255), outline=(245, 236, 212, 255))
    d.rounded_rectangle((204, 234, 308, 372), radius=14, fill=(248, 242, 224, 255))
    _finish(img, "icon_wardrobe.png")

    # 6. Dock: icon_upgrade.png
    img, d, s = _ss_canvas()
    _draw_badge_plate(d, s, (46, 56, 48, 255), (245, 198, 68, 255))
    # Roof + house
    d.polygon([(120, 234), (256, 118), (392, 234)], fill=(208, 86, 52, 255), outline=(250, 218, 128, 255))
    d.rounded_rectangle((158, 230, 354, 372), radius=12, fill=(242, 226, 192, 255))
    d.rounded_rectangle((224, 282, 288, 372), radius=10, fill=(138, 86, 44, 255))
    # Upward sparkle arrow
    d.polygon([(354, 118), (398, 174), (372, 174), (372, 228), (336, 228), (336, 174), (310, 174)], fill=(96, 226, 122, 255), outline=(255, 255, 255, 255))
    _finish(img, "icon_upgrade.png")

    # 7. App Icons (Smartphone OS 3x3 grid)
    # app_bank
    img, d, s = _ss_canvas()
    _draw_rounded_app_tile(d, s, (34, 112, 204), (22, 74, 148))
    d.polygon([(128, 196), (256, 112), (384, 196)], fill=(248, 212, 88, 255))
    for px in (160, 228, 296):
        d.rounded_rectangle((px, 210, px + 44, 342), radius=8, fill=(242, 246, 255, 255))
    d.rounded_rectangle((124, 346, 388, 384), radius=12, fill=(248, 212, 88, 255))
    _finish(img, "app_bank.png")

    # app_shop
    img, d, s = _ss_canvas()
    _draw_rounded_app_tile(d, s, (238, 134, 48), (196, 86, 28))
    d.rounded_rectangle((132, 184, 380, 388), radius=28, fill=(252, 244, 226, 255))
    d.arc((184, 112, 328, 238), start=180, end=360, fill=(252, 244, 226, 255), width=26)
    d.ellipse((194, 248, 318, 356), fill=(52, 184, 108, 255))
    _finish(img, "app_shop.png")

    # app_chat
    img, d, s = _ss_canvas()
    _draw_rounded_app_tile(d, s, (48, 198, 96), (28, 148, 68))
    d.ellipse((116, 126, 396, 352), fill=(252, 255, 252, 255))
    d.polygon([(164, 324), (132, 392), (226, 344)], fill=(252, 255, 252, 255))
    for dx in (198, 256, 314):
        d.ellipse((dx - 18, 222, dx + 18, 258), fill=(48, 178, 88, 255))
    _finish(img, "app_chat.png")

    # app_debt
    img, d, s = _ss_canvas()
    _draw_rounded_app_tile(d, s, (132, 88, 56), (86, 54, 32))
    d.rounded_rectangle((138, 112, 374, 394), radius=24, fill=(248, 236, 204, 255), outline=(228, 184, 72, 255), width=12)
    for ly in (180, 232, 284, 336):
        d.line((176, ly, 336, ly), fill=(156, 116, 76, 255), width=14)
    _finish(img, "app_debt.png")

    # app_dreams
    img, d, s = _ss_canvas()
    _draw_rounded_app_tile(d, s, (238, 176, 44), (192, 124, 24))
    pts = []
    for k in range(10):
        ang = math.radians(-90 + k * 36)
        r = 136 if k % 2 == 0 else 58
        pts.append((256 + math.cos(ang) * r, 256 + math.sin(ang) * r))
    d.polygon(pts, fill=(255, 250, 214, 255), outline=(172, 108, 18, 255))
    _finish(img, "app_dreams.png")

    # app_story
    img, d, s = _ss_canvas()
    _draw_rounded_app_tile(d, s, (118, 76, 172), (76, 48, 124))
    d.rounded_rectangle((128, 132, 252, 376), radius=18, fill=(252, 246, 232, 255))
    d.rounded_rectangle((260, 132, 384, 376), radius=18, fill=(242, 234, 218, 255))
    d.polygon([(304, 132), (344, 132), (344, 246), (324, 224), (304, 246)], fill=(238, 76, 76, 255))
    _finish(img, "app_story.png")

    # app_missions
    img, d, s = _ss_canvas()
    _draw_rounded_app_tile(d, s, (216, 62, 62), (162, 38, 38))
    d.ellipse((124, 124, 388, 388), fill=(255, 255, 255, 255))
    d.ellipse((166, 166, 346, 346), fill=(224, 62, 62, 255))
    d.ellipse((212, 212, 300, 300), fill=(248, 208, 68, 255))
    _finish(img, "app_missions.png")

    # app_map
    img, d, s = _ss_canvas()
    _draw_rounded_app_tile(d, s, (42, 156, 148), (28, 108, 104))
    d.polygon([(112, 166), (206, 138), (306, 166), (398, 138), (398, 356), (306, 384), (206, 356), (112, 384)], fill=(234, 246, 222, 255))
    d.ellipse((214, 174, 298, 258), fill=(232, 64, 58, 255), outline=(255, 255, 255, 255), width=8)
    d.polygon([(224, 238), (288, 238), (256, 316)], fill=(232, 64, 58, 255))
    _finish(img, "app_map.png")

    # app_guide
    img, d, s = _ss_canvas()
    _draw_rounded_app_tile(d, s, (62, 146, 218), (42, 98, 164))
    d.ellipse((176, 114, 336, 274), fill=(252, 224, 92, 255))
    d.rounded_rectangle((210, 266, 302, 344), radius=16, fill=(242, 244, 248, 255))
    d.rounded_rectangle((222, 348, 290, 378), radius=12, fill=(176, 184, 196, 255))
    _finish(img, "app_guide.png")

    # 8. Star Filled / Empty (64x64)
    for fname, fill_c, rim_c in [
        ("star_filled.png", (250, 204, 58, 255), (192, 124, 18, 255)),
        ("star_empty.png", (42, 48, 60, 180), (198, 174, 118, 200)),
    ]:
        img, d, s = _ss_canvas(64)
        pts = []
        for k in range(10):
            ang = math.radians(-90 + k * 36)
            r = 104 if k % 2 == 0 else 44
            pts.append((128 + math.cos(ang) * r, 128 + math.sin(ang) * r))
        d.polygon(pts, fill=fill_c, outline=rim_c)
        _finish(img, fname, 64)

    # 9. Hand pointer (96x96) — clean index-finger pointing hand (index on left, 3 curled fingers right)
    img, d, s = _ss_canvas(96)
    # Palm base
    d.rounded_rectangle((112, 168, 288, 326), radius=54, fill=(252, 248, 240, 255), outline=(28, 24, 20, 255), width=14)
    # Thumb tucked left
    d.rounded_rectangle((72, 206, 146, 274), radius=28, fill=(252, 248, 240, 255), outline=(28, 24, 20, 255), width=14)
    # Index finger pointing up-left/up cleanly
    d.rounded_rectangle((116, 48, 174, 212), radius=28, fill=(252, 248, 240, 255), outline=(28, 24, 20, 255), width=14)
    # 3 curled knuckles on right
    for kx, ky in ((176, 162), (222, 174), (266, 190)):
        d.rounded_rectangle((kx, ky, kx + 46, ky + 72), radius=20, fill=(246, 240, 230, 255), outline=(28, 24, 20, 255), width=12)
    img = img.rotate(-18, resample=Image.Resampling.BICUBIC)
    _finish(img, "icon_hand_pointer.png", 96)

    # 10. Courier Box (96x96)
    img, d, s = _ss_canvas(96)
    d.rounded_rectangle((62, 92, s - 62, s - 48), radius=28, fill=(214, 158, 92, 255), outline=(112, 72, 32, 255), width=12)
    d.rectangle((66, 156, s - 66, 198), fill=(182, 122, 62, 255))
    d.rectangle((s // 2 - 28, 96, s // 2 + 28, 236), fill=(248, 228, 158, 230))
    _finish(img, "icon_courier_box.png", 96)

    # 11. Title Logo (512x192)
    w, h = 1024, 384
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Leaf accents behind plaque
    d.ellipse((14, 52, 210, 232), fill=(58, 164, 70, 255), outline=(30, 92, 38, 255), width=10)
    d.ellipse((w - 210, 52, w - 14, 232), fill=(58, 164, 70, 255), outline=(30, 92, 38, 255), width=10)
    d.ellipse((46, 192, 178, 304), fill=(76, 184, 84, 255), outline=(30, 92, 38, 255), width=8)
    d.ellipse((w - 178, 192, w - 46, 304), fill=(76, 184, 84, 255), outline=(30, 92, 38, 255), width=8)
    # Wooden plaque shadow & board
    d.rounded_rectangle((56, 38, w - 56, h - 32), radius=58, fill=(16, 12, 8, 165))
    d.rounded_rectangle((56, 22, w - 56, h - 50), radius=58, fill=(98, 56, 28, 255), outline=(248, 204, 72, 255), width=16)
    d.rounded_rectangle((84, 46, w - 84, h - 74), radius=42, fill=(68, 40, 22, 255), outline=(156, 102, 50, 255), width=8)
    # Title text with thick warm stroke + highlight
    f_big = _font(104)
    f_sub = _font(42)
    title_txt = "ART SIMULATOR"
    sub_txt = "COZY HOMEKEEPER"
    tb = d.textbbox((0, 0), title_txt, font=f_big)
    tx = (w - (tb[2] - tb[0])) // 2
    d.text((tx + 4, 82), title_txt, font=f_big, fill=(24, 14, 6, 240), stroke_width=8, stroke_fill=(38, 20, 8, 255))
    d.text((tx, 74), title_txt, font=f_big, fill=(252, 214, 78, 255), stroke_width=4, stroke_fill=(136, 78, 16, 255))
    # Sub banner ribbon
    d.rounded_rectangle((226, 220, w - 226, 300), radius=26, fill=(34, 134, 86, 255), outline=(248, 204, 72, 255), width=8)
    sb = d.textbbox((0, 0), sub_txt, font=f_sub)
    sx = (w - (sb[2] - sb[0])) // 2
    d.text((sx, 236), sub_txt, font=f_sub, fill=(254, 250, 238, 255))
    img.resize((512, 192), Image.Resampling.LANCZOS).save(os.path.join(UI_DIR, "logo_art_simulator.png"))
    print("Generated all painterly UI icons + logo_art_simulator.png in", UI_DIR)


if __name__ == "__main__":
    composite_portraits()
