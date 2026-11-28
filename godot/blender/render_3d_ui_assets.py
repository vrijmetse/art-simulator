import math
import os
import bpy
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GODOT_DIR = os.path.dirname(SCRIPT_DIR)
UI_DIR = os.path.join(GODOT_DIR, "assets", "ui")
os.makedirs(UI_DIR, exist_ok=True)


def reset_studio(res_x=256, res_y=256, cam_loc=(0.0, -3.1, 1.15), target=(0.0, 0.0, 0.0), lens=46.0):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 28
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 3
    scene.render.film_transparent = True
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    try:
        scene.view_settings.view_transform = 'AgX'
    except Exception:
        pass
    scene.view_settings.exposure = -0.24

    world = bpy.data.worlds.new("UIStudio")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.42, 0.38, 0.34, 1.0)
        bg.inputs[1].default_value = 0.62
    scene.world = world

    def add_area(name, loc, tgt, energy, size, col):
        ld = bpy.data.lights.new(name, type='AREA')
        ld.energy = energy
        ld.size = size
        ld.color = col
        lo = bpy.data.objects.new(name, ld)
        bpy.context.collection.objects.link(lo)
        lo.location = loc
        lo.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()

    add_area("Key", (2.2, -3.2, 2.8), target, 140.0, 2.2, (1.0, 0.94, 0.84))
    add_area("Fill", (-2.6, -2.8, 1.4), target, 85.0, 2.6, (0.90, 0.95, 1.0))
    add_area("Rim", (-0.6, 2.6, 2.5), target, 110.0, 1.8, (1.0, 0.88, 0.65))

    cd = bpy.data.cameras.new("UICam")
    cd.lens = lens
    co = bpy.data.objects.new("UICam", cd)
    bpy.context.collection.objects.link(co)
    co.location = cam_loc
    co.rotation_euler = (Vector(target) - Vector(cam_loc)).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = co
    return scene


def mat(name, rgb, rough=0.38, metal=0.0, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.45
    if emit > 0.0:
        b.inputs["Emission Color"].default_value = (*rgb, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    return m


def box(size, loc=(0, 0, 0), rot=(0, 0, 0), material=None, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0.0:
        bv = o.modifiers.new("Bevel", 'BEVEL')
        bv.width = bevel
        bv.segments = 3
    bpy.ops.object.shade_smooth()
    if material:
        o.data.materials.append(material)
    return o


def cyl(rad, depth, loc=(0, 0, 0), rot=(0, 0, 0), material=None, verts=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=rad, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    if material:
        o.data.materials.append(material)
    return o


def sph(rad, loc=(0, 0, 0), scale=(1, 1, 1), material=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=rad, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.shade_smooth()
    if material:
        o.data.materials.append(material)
    return o


def render_out(scene, filename):
    scene.render.filepath = os.path.join(UI_DIR, filename)
    bpy.ops.render.render(write_still=True)
    print("RENDERED 3D UI:", filename)


def render_all():
    # 1. icon_door.png — Cozy wooden kos door + cream frame + brass knob + terracotta mat
    sc = reset_studio(256, 256, (0.55, -2.75, 0.65), (0.0, 0.0, 0.05), 48.0)
    m_wood = mat("DoorWood", (0.48, 0.25, 0.12), 0.45)
    m_cream = mat("FrameCream", (0.94, 0.88, 0.76), 0.50)
    m_gold = mat("Brass", (0.95, 0.74, 0.24), 0.22, 0.88)
    m_mat = mat("WelcomeMat", (0.82, 0.34, 0.22), 0.80)
    box((0.92, 0.12, 1.38), (0.0, 0.0, 0.04), (0, 0, 0), m_cream, 0.03)
    box((0.72, 0.14, 1.24), (0.0, -0.02, 0.0), (0, 0, 0), m_wood, 0.02)
    box((0.48, 0.04, 0.44), (0.0, -0.09, 0.28), (0, 0, 0), m_cream, 0.015)
    sph(0.075, (0.24, -0.14, 0.0), (1, 1, 1), m_gold)
    box((0.78, 0.42, 0.06), (0.0, -0.26, -0.64), (0, 0, 0), m_mat, 0.02)
    render_out(sc, "icon_door.png")

    # 2. icon_broom.png — Wooden broom + blue bucket
    sc = reset_studio(256, 256, (0.35, -2.75, 0.72), (-0.02, 0.0, 0.02), 48.0)
    m_stick = mat("Stick", (0.68, 0.46, 0.22), 0.48)
    m_straw = mat("Straw", (0.92, 0.74, 0.32), 0.75)
    m_blue = mat("BucketBlue", (0.18, 0.58, 0.88), 0.30)
    m_gold = mat("RingGold", (0.95, 0.78, 0.28), 0.25, 0.7)
    cyl(0.042, 1.35, (-0.12, 0.0, 0.12), (0, math.radians(-22), 0), m_stick)
    box((0.46, 0.12, 0.32), (-0.34, 0.0, -0.44), (0, math.radians(-22), 0), m_straw, 0.03)
    box((0.48, 0.14, 0.07), (-0.28, 0.0, -0.30), (0, math.radians(-22), 0), m_gold, 0.02)
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=0.26, radius2=0.34, depth=0.56, location=(0.30, -0.08, -0.34))
    bkt = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    bkt.data.materials.append(m_blue)
    render_out(sc, "icon_broom.png")

    # 3. icon_career.png — Leather briefcase + gold star clasp
    sc = reset_studio(256, 256, (0.50, -2.55, 0.72), (0.0, 0.0, 0.0), 48.0)
    m_leather = mat("Leather", (0.42, 0.22, 0.12), 0.42)
    m_flap = mat("Flap", (0.56, 0.30, 0.16), 0.40)
    m_gold = mat("Gold", (0.96, 0.78, 0.24), 0.22, 0.88)
    box((1.06, 0.38, 0.76), (0.0, 0.0, -0.05), (0, 0, 0), m_leather, 0.06)
    box((1.08, 0.40, 0.36), (0.0, -0.02, 0.18), (0, 0, 0), m_flap, 0.05)
    box((0.36, 0.08, 0.14), (0.0, 0.0, 0.42), (0, 0, 0), m_leather, 0.03)
    box((0.18, 0.08, 0.16), (0.0, -0.22, 0.0), (0, 0, 0), m_gold, 0.03)
    render_out(sc, "icon_career.png")

    # 4. icon_wardrobe.png — Cozy 2-door wooden wardrobe (lemari) with brass handles & emerald accent
    sc = reset_studio(256, 256, (0.48, -2.80, 0.58), (0.0, 0.0, 0.02), 48.0)
    m_teak = mat("WardrobeTeak", (0.50, 0.26, 0.12), 0.42)
    m_door = mat("WardrobeDoor", (0.64, 0.36, 0.17), 0.44)
    m_gold = mat("BrassKnob", (0.98, 0.78, 0.20), 0.20, 0.88)
    m_teal = mat("InsideBatik", (0.12, 0.58, 0.46), 0.55)
    box((1.06, 0.54, 1.32), (0.0, 0.08, 0.0), (0, 0, 0), m_teak, 0.05)
    box((1.14, 0.58, 0.10), (0.0, 0.06, 0.68), (0, 0, 0), m_teak, 0.03)
    box((0.46, 0.08, 1.12), (-0.25, -0.22, 0.0), (0, 0, 0), m_door, 0.03)
    box((0.46, 0.08, 1.12), (0.28, -0.24, 0.0), (0, 0, math.radians(-12)), m_door, 0.03)
    box((0.30, 0.06, 0.88), (0.20, -0.14, 0.02), (0, 0, 0), m_teal, 0.02)
    sph(0.055, (-0.08, -0.28, 0.02), (1, 1, 1), m_gold)
    sph(0.055, (0.10, -0.31, 0.02), (1, 1, 1), m_gold)
    render_out(sc, "icon_wardrobe.png")

    # 5. icon_upgrade.png — Cozy cottage + gold up arrow
    sc = reset_studio(256, 256, (0.65, -2.85, 0.88), (0.0, 0.0, 0.04), 48.0)
    m_wall = mat("Wall", (0.96, 0.90, 0.78), 0.58)
    m_roof = mat("Roof", (0.78, 0.32, 0.20), 0.52)
    m_win = mat("WinGlow", (1.0, 0.82, 0.34), 0.25, emit=0.9)
    m_green = mat("UpGreen", (0.24, 0.82, 0.44), 0.30)
    box((0.88, 0.74, 0.64), (-0.08, 0.0, -0.18), (0, 0, 0), m_wall, 0.04)
    box((0.68, 0.68, 0.42), (-0.08, 0.0, 0.24), (0, 0, math.radians(45)), m_roof, 0.04)
    box((0.26, 0.08, 0.26), (-0.08, -0.37, -0.12), (0, 0, 0), m_win, 0.02)
    box((0.22, 0.14, 0.42), (0.50, -0.20, -0.12), (0, 0, 0), m_green, 0.03)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.28, radius2=0.01, depth=0.36, location=(0.50, -0.20, 0.24), rotation=(0, 0, math.radians(45)))
    arr = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    arr.data.materials.append(m_green)
    render_out(sc, "icon_upgrade.png")

    # 6. icon_phone.png — Tilted 3D smartphone with glowing Indonesian app grid
    sc = reset_studio(256, 256, (0.42, -2.55, 0.58), (0.0, 0.0, 0.0), 48.0)
    m_body = mat("PhoneBody", (0.14, 0.17, 0.24), 0.26, 0.72)
    m_gold = mat("PhoneTrim", (0.95, 0.78, 0.26), 0.22, 0.85)
    m_scr = mat("Screen", (0.16, 0.44, 0.76), 0.18, emit=0.45)
    box((0.80, 0.12, 1.32), (0.0, 0.0, 0.0), (math.radians(-6), 0, math.radians(10)), m_body, 0.05)
    box((0.68, 0.13, 1.12), (0.0, -0.01, 0.02), (math.radians(-6), 0, math.radians(10)), m_scr, 0.03)
    tile_cols = [(0.30, 0.84, 0.44), (0.96, 0.76, 0.24), (0.92, 0.34, 0.32), (0.32, 0.76, 0.96), (0.76, 0.48, 0.94), (0.98, 0.56, 0.26)]
    for idx, tc in enumerate(tile_cols):
        r, c = divmod(idx, 3)
        box((0.15, 0.04, 0.15), (-0.18 + c * 0.18, -0.075, 0.22 - r * 0.22), (math.radians(-6), 0, math.radians(10)), mat(f"T{idx}", tc, 0.30, emit=0.35), 0.015)
    box((0.82, 0.08, 1.34), (0.0, 0.02, 0.0), (math.radians(-6), 0, math.radians(10)), m_gold, 0.05)
    render_out(sc, "icon_phone.png")

    # 7. icon_courier_box.png — Kraft parcel + red ribbon
    sc = reset_studio(256, 256, (0.85, -2.55, 0.95), (0.0, 0.0, 0.0), 48.0)
    m_kraft = mat("Kraft", (0.76, 0.54, 0.30), 0.62)
    m_tape = mat("Tape", (0.94, 0.80, 0.48), 0.38)
    m_red = mat("TagRed", (0.86, 0.24, 0.22), 0.45)
    box((0.92, 0.92, 0.78), (0.0, 0.0, 0.0), (0, 0, 0), m_kraft, 0.04)
    box((0.94, 0.22, 0.80), (0.0, 0.0, 0.0), (0, 0, 0), m_tape, 0.015)
    box((0.28, 0.06, 0.20), (0.24, -0.46, 0.14), (0, 0, 0), m_red, 0.01)
    render_out(sc, "icon_courier_box.png")

    # 8. icon_hand_pointer.png — Clean cartoon white-gloved tapping hand + gold tap ring
    sc = reset_studio(256, 256, (0.30, -2.55, 0.42), (0.0, 0.0, 0.04), 48.0)
    m_glove = mat("GloveWhite", (0.98, 0.96, 0.92), 0.45)
    m_cuff = mat("CuffBlue", (0.20, 0.54, 0.84), 0.38)
    m_ring = mat("TapGold", (0.98, 0.78, 0.18), 0.20, 0.65, emit=0.25)
    sph(0.28, (0.0, 0.0, -0.14), (1.0, 0.68, 0.98), m_glove)
    cyl(0.085, 0.46, (-0.12, -0.02, 0.24), (0, 0, 0), m_glove)
    sph(0.086, (-0.12, -0.02, 0.48), (1, 1, 1), m_glove)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.22, minor_radius=0.032, major_segments=24, minor_segments=10, location=(-0.12, -0.02, 0.50), rotation=(math.radians(78), 0, 0))
    bpy.context.active_object.data.materials.append(m_ring)
    for fx in (0.03, 0.14, 0.24):
        cyl(0.068, 0.20, (fx, -0.06, 0.04), (math.radians(38), 0, 0), m_glove)
        sph(0.068, (fx, -0.12, 0.11), (1, 1, 1), m_glove)
    cyl(0.072, 0.26, (-0.27, -0.04, 0.0), (0, math.radians(-42), 0), m_glove)
    box((0.46, 0.34, 0.22), (0.0, 0.0, -0.46), (0, 0, 0), m_cuff, 0.05)
    render_out(sc, "icon_hand_pointer.png")

    # 9. star_filled.png & star_empty.png
    for sname, srgb, smetal, semit in [("star_filled.png", (1.0, 0.72, 0.06), 0.45, 0.18), ("star_empty.png", (0.24, 0.28, 0.36), 0.10, 0.0)]:
        sc = reset_studio(128, 128, (0.0, -2.5, 0.12), (0.0, 0.0, 0.0), 48.0)
        ms = mat("Star", srgb, 0.20 if semit > 0 else 0.45, smetal, emit=semit)
        for ai in range(5):
            ang = math.radians(ai * 72.0)
            bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.30, radius2=0.02, depth=0.68, location=(math.sin(ang) * 0.28, 0.0, math.cos(ang) * 0.28), rotation=(0.0, ang, 0.0))
            st = bpy.context.active_object
            st.scale = (1.0, 0.42, 1.0)
            bpy.ops.object.shade_smooth()
            st.data.materials.append(ms)
        sph(0.26, (0, 0, 0), (1.0, 0.48, 1.0), ms)
        render_out(sc, sname)

    # 10. 9 Claymorphic 3D Smartphone App Icons
    apps = [
        ("app_bank.png", (0.14, 0.46, 0.86), "bank"),
        ("app_shop.png", (0.92, 0.52, 0.16), "shop"),
        ("app_chat.png", (0.16, 0.68, 0.36), "chat"),
        ("app_debt.png", (0.76, 0.28, 0.24), "debt"),
        ("app_dreams.png", (0.16, 0.62, 0.72), "dreams"),
        ("app_story.png", (0.50, 0.32, 0.78), "story"),
        ("app_missions.png", (0.88, 0.30, 0.34), "missions"),
        ("app_map.png", (0.22, 0.68, 0.48), "map"),
        ("app_guide.png", (0.28, 0.36, 0.78), "guide"),
    ]
    for fname, tile_rgb, kind in apps:
        sc = reset_studio(256, 256, (0.22, -2.55, 0.28), (0.0, 0.0, 0.0), 48.0)
        m_tile = mat("Tile", tile_rgb, 0.32)
        m_w = mat("W", (0.98, 0.96, 0.92), 0.35)
        m_g = mat("G", (0.98, 0.80, 0.24), 0.22, 0.75)
        m_r = mat("R", (0.92, 0.24, 0.22), 0.35)
        box((1.22, 0.22, 1.22), (0.0, 0.12, 0.0), (0, 0, 0), m_tile, 0.16)
        if kind == "bank":
            box((0.76, 0.18, 0.14), (0, -0.06, -0.26), (0, 0, 0), m_w, 0.02)
            for cx in (-0.24, 0.0, 0.24):
                cyl(0.065, 0.38, (cx, -0.06, 0.0), (0, 0, 0), m_w)
            bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.52, radius2=0.02, depth=0.26, location=(0, -0.06, 0.32), rotation=(0, 0, math.radians(45)))
            bpy.context.active_object.data.materials.append(m_g)
        elif kind == "shop":
            m_bag = mat("ShopBag", (0.98, 0.94, 0.84), 0.42)
            m_handle = mat("BagHandle", (0.72, 0.38, 0.14), 0.35)
            m_veg = mat("ShopVeg", (0.16, 0.74, 0.30), 0.40)
            m_b = mat("ShopBtl", (0.18, 0.62, 0.92), 0.24)
            box((0.76, 0.30, 0.62), (0, -0.08, -0.18), (0, 0, 0), m_bag, 0.06)
            bpy.ops.mesh.primitive_torus_add(major_radius=0.20, minor_radius=0.046, major_segments=22, minor_segments=10, location=(0, -0.08, 0.23), rotation=(math.pi * 0.5, 0, 0))
            bpy.context.active_object.data.materials.append(m_handle)
            sph(0.14, (-0.18, -0.08, 0.20), (1.1, 0.8, 1.3), m_veg)
            cyl(0.08, 0.30, (0.19, -0.08, 0.22), (0, math.radians(-10), 0), m_b)
        elif kind == "chat":
            sph(0.38, (0, -0.08, 0.06), (1.15, 0.45, 0.88), m_w)
            bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.16, radius2=0.02, depth=0.28, location=(-0.18, -0.08, -0.22), rotation=(0, math.radians(145), 0))
            bpy.context.active_object.data.materials.append(m_w)
        elif kind == "debt":
            m_ink = mat("DebtInk", (0.28, 0.32, 0.40), 0.50)
            m_ring = mat("RingSilver", (0.82, 0.86, 0.92), 0.25, 0.75)
            box((0.68, 0.18, 0.82), (0.04, -0.05, 0.0), (0, 0, 0), m_w, 0.04)
            for ry in (-0.28, -0.09, 0.10, 0.29):
                bpy.ops.mesh.primitive_torus_add(major_radius=0.065, minor_radius=0.022, major_segments=14, minor_segments=6, location=(-0.30, -0.07, ry), rotation=(0, math.pi * 0.5, 0))
                bpy.context.active_object.data.materials.append(m_ring)
            for ly in (0.16, 0.02):
                box((0.40, 0.04, 0.055), (0.06, -0.15, ly), (0, 0, 0), m_ink, 0.01)
            cyl(0.18, 0.08, (0.10, -0.16, -0.18), (math.pi * 0.5, 0, 0), m_g)
        elif kind == "dreams":
            for ai in range(5):
                ang = math.radians(ai * 72.0)
                bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.20, radius2=0.01, depth=0.48, location=(math.sin(ang) * 0.20, -0.08, math.cos(ang) * 0.20), rotation=(0.0, ang, 0.0))
                bpy.context.active_object.data.materials.append(m_g)
            sph(0.20, (0, -0.08, 0), (1, 0.45, 1), m_g)
        elif kind == "story":
            m_cover = mat("BookCover", (0.84, 0.34, 0.18), 0.42)
            m_ink = mat("BookInk", (0.28, 0.30, 0.38), 0.55)
            box((0.92, 0.10, 0.66), (0.0, -0.02, 0.02), (0, 0, 0), m_cover, 0.03)
            box((0.40, 0.12, 0.58), (-0.22, -0.08, 0.03), (0, 0, math.radians(-12)), m_w, 0.02)
            box((0.40, 0.12, 0.58), (0.22, -0.08, 0.03), (0, 0, math.radians(12)), m_w, 0.02)
            box((0.05, 0.14, 0.56), (0.0, -0.09, 0.03), (0, 0, 0), m_ink, 0.01)
            for lx in (-0.22, 0.22):
                for ly in (0.16, 0.02, -0.12):
                    box((0.24, 0.03, 0.04), (lx, -0.15, ly), (0, 0, 0), m_ink, 0.008)
            box((0.12, 0.08, 0.26), (0.16, -0.12, -0.34), (0, 0, 0), m_g, 0.015)
        elif kind == "missions":
            cyl(0.42, 0.12, (0, -0.06, 0.0), (math.pi * 0.5, 0, 0), m_w)
            cyl(0.28, 0.14, (0, -0.07, 0.0), (math.pi * 0.5, 0, 0), m_r)
            cyl(0.14, 0.16, (0, -0.08, 0.0), (math.pi * 0.5, 0, 0), m_g)
        elif kind == "map":
            box((0.76, 0.14, 0.58), (0, -0.06, -0.06), (0, 0, 0), m_w, 0.03)
            sph(0.16, (0.04, -0.16, 0.22), (1, 0.6, 1), m_r)
            bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.14, radius2=0.01, depth=0.26, location=(0.04, -0.16, 0.02), rotation=(math.pi, 0, 0))
            bpy.context.active_object.data.materials.append(m_r)
        elif kind == "guide":
            sph(0.26, (0, -0.08, 0.14), (1, 0.7, 1.1), m_g)
            cyl(0.12, 0.24, (0, -0.08, -0.22), (0, 0, 0), m_w)
        render_out(sc, fname)

    # 11. logo_art_simulator.png — 3D Cycles wooden + gold plaque emblem
    sc = reset_studio(768, 320, (0.0, -5.2, 0.28), (0.0, 0.0, 0.0), 42.0)
    m_teak = mat("LogoTeak", (0.14, 0.06, 0.03), 0.36)
    m_gold = mat("LogoGold", (0.98, 0.74, 0.14), 0.22, 0.88)
    m_cream = mat("LogoCream", (0.99, 0.96, 0.88), 0.28, emit=0.22)
    m_teal = mat("LogoTeal", (0.05, 0.40, 0.32), 0.42)

    # Back tilted wooden shield + gold bezel (generous width, clean silhouette)
    box((3.82, 0.22, 1.48), (0.0, 0.18, 0.02), (0, math.radians(-1.5), 0), m_gold, 0.10)
    box((3.64, 0.26, 1.32), (0.0, 0.15, 0.02), (0, math.radians(-1.5), 0), m_teak, 0.08)

    # Extruded 3D text: ART SIMULATOR + COZY HOMEKEEPER pill
    bpy.ops.object.text_add(location=(0.0, -0.04, 0.14), rotation=(math.pi * 0.5, 0.0, 0.0))
    t1 = bpy.context.active_object
    t1.data.body = "ART SIMULATOR"
    t1.data.align_x = 'CENTER'
    t1.data.size = 0.36
    t1.data.extrude = 0.055
    t1.data.bevel_depth = 0.012
    t1.data.materials.append(m_gold)

    box((2.50, 0.24, 0.40), (0.0, 0.04, -0.42), (0, 0, 0), m_teal, 0.06)
    bpy.ops.object.text_add(location=(0.0, -0.10, -0.50), rotation=(math.pi * 0.5, 0.0, 0.0))
    t2 = bpy.context.active_object
    t2.data.body = "COZY HOMEKEEPER"
    t2.data.align_x = 'CENTER'
    t2.data.size = 0.22
    t2.data.extrude = 0.035
    t2.data.bevel_depth = 0.007
    t2.data.materials.append(m_cream)

    render_out(sc, "logo_art_simulator.png")


if __name__ == "__main__":
    render_all()
