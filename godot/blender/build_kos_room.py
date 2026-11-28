import os
import sys
import math
import numpy as np
import bpy
import bmesh
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from tex_utils import (
    add_galon_dispenser_hd,
    add_layered_broadleaf_plant,
    add_magic_com_hd,
    add_open_standing_fan_hd,
    ensure_uv0,
    export_room_glb,
    generate_fabric_weave_texture,
    generate_foliage_texture,
    generate_laptop_ui,
    generate_plaster_ao_texture,
    generate_rattan_textures,
    generate_sajadah_texture,
    generate_tile_textures,
    generate_tv_weather_texture,
    generate_wall_art_padi,
    generate_wood_texture,
    generate_woven_rug_texture,
    make_pbr_material,
    polish_scene_textures_1024,
    spin_profile,
)

GODOT_DIR = os.path.dirname(SCRIPT_DIR)
TEX_DIR = os.path.join(GODOT_DIR, "assets", "textures")
UNPACKED_DIR = os.path.join(GODOT_DIR, "assets", "raw", "unpacked")
OUT_GLB = os.path.join(GODOT_DIR, "assets", "models", "kos_room.glb")
OUT_LM = os.path.join(GODOT_DIR, "assets", "lightmaps", "kos_room_lightmap.png")


def make_solid_mat(name, rgb, roughness=0.78, metallic=0.0, emission=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.blend_method = 'BLEND'
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def rebuild_kenney_pbr_material(mat):
    if not mat:
        return
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (300, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (0, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    mname = mat.name.lower()
    if "wooddark" in mname:
        color, roughness, metallic = (0.24, 0.14, 0.08, 1.0), 0.62, 0.0
    elif "wood" in mname:
        color, roughness, metallic = (0.44, 0.26, 0.14, 1.0), 0.62, 0.0
    elif "metaldark" in mname:
        color, roughness, metallic = (0.16, 0.17, 0.19, 1.0), 0.45, 0.65
    elif "metallight" in mname or "metal" in mname:
        color, roughness, metallic = (0.74, 0.76, 0.79, 1.0), 0.35, 0.85
    elif "glass" in mname:
        color, roughness, metallic = (0.65, 0.80, 0.86, 1.0), 0.15, 0.05
    elif "carpet" in mname:
        color, roughness, metallic = (0.72, 0.34, 0.26, 1.0), 0.88, 0.0
    elif "leaf" in mname or "foliage" in mname or "leaves" in mname or "plant" in mname:
        color, roughness, metallic = (0.20, 0.48, 0.20, 1.0), 0.72, 0.0
    elif "trunk" in mname or "bark" in mname:
        color, roughness, metallic = (0.34, 0.22, 0.14, 1.0), 0.88, 0.0
    elif "white" in mname or "ceramic" in mname:
        color, roughness, metallic = (0.90, 0.89, 0.86, 1.0), 0.38, 0.0
    else:
        color, roughness, metallic = (0.72, 0.68, 0.62, 1.0), 0.65, 0.0

    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic


def import_kenney_glb(prefix, filename, loc, rot_z=0.0, scale=1.85, target_height=None, center_xy=False):
    filepath = os.path.join(UNPACKED_DIR, filename)
    if not os.path.exists(filepath):
        raise FileNotFoundError(filepath)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=filepath)
    imported = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in imported if o.type == 'MESH']

    for o in meshes:
        for slot in o.material_slots:
            if slot.material:
                rebuild_kenney_pbr_material(slot.material)

    parent = bpy.data.objects.new(prefix, None)
    bpy.context.collection.objects.link(parent)
    for o in imported:
        if o.parent is None:
            o.parent = parent

    bpy.context.view_layer.update()
    all_pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    if all_pts:
        min_x, max_x = min(p.x for p in all_pts), max(p.x for p in all_pts)
        min_y, max_y = min(p.y for p in all_pts), max(p.y for p in all_pts)
        min_z, max_z = min(p.z for p in all_pts), max(p.z for p in all_pts)
        h = max(0.01, max_z - min_z)
        s = (target_height / h) if target_height else scale
        parent.scale = (s, s, s)
        bpy.context.view_layer.update()
        cx = (min_x + max_x) * 0.5 * s if center_xy else 0.0
        cy = (min_y + max_y) * 0.5 * s if center_xy else 0.0
        parent.location = (loc[0] - cx, loc[1] - cy, loc[2] - min_z * s)
    else:
        parent.scale = (scale, scale, scale)
        parent.location = loc

    parent.rotation_euler = (0.0, 0.0, rot_z)
    return parent


def add_beveled_box(name, size, loc, mat, bevel=0.022, rot=(0.0, 0.0, 0.0), cuts=0, use_wn=True, reset_uv=False):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        bev = obj.modifiers.new("Bevel", 'BEVEL')
        bev.width = bevel
        bev.segments = 3 if use_wn else 2
        bpy.ops.object.modifier_apply(modifier="Bevel")
    if cuts > 0:
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.subdivide(number_cuts=cuts)
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.shade_smooth()
    obj.data.use_auto_smooth = True
    obj.data.auto_smooth_angle = math.radians(42)
    if bevel > 0 and use_wn:
        wn = obj.modifiers.new("WeightedNormal", 'WEIGHTED_NORMAL')
        wn.keep_sharp = True
        bpy.ops.object.modifier_apply(modifier="WeightedNormal")
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    if reset_uv:
        bpy.ops.uv.reset()
    else:
        bpy.ops.uv.cube_project(cube_size=max(size) * 0.6)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.materials.append(mat)
    return obj


def add_cylinder(name, radius, depth, loc, mat, rot=(0.0, 0.0, 0.0), vertices=16, smooth=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    if smooth:
        bpy.ops.object.shade_smooth()
    obj.data.materials.append(mat)
    return obj


def bake_cycles_lightmap(out_png_path: str, size: int = 1024, samples: int = 14):
    """Bake Cycles 2-tone GI + soft shadows into UV2 (LightmapUV), excluding foliage/glass/tiny micro-props."""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 3
    scene.cycles.diffuse_bounces = 2
    scene.cycles.bake_type = 'DIFFUSE'
    scene.render.bake.use_pass_direct = True
    scene.render.bake.use_pass_indirect = True
    scene.render.bake.use_pass_color = False
    scene.render.bake.target = 'IMAGE_TEXTURES'
    scene.render.bake.use_clear = True
    scene.render.bake.margin = 4

    world = bpy.data.worlds.new("BakeWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.34, 0.46, 0.72, 1.0)
    bg.inputs["Strength"].default_value = 0.92

    bpy.ops.object.light_add(type='SUN', location=(0.6, 5.0, 3.6))
    sun_obj = bpy.context.active_object
    sun_obj.name = "_BakeSun"
    sun_obj.data.energy = 3.4
    sun_obj.data.color = (1.0, 0.78, 0.44)
    sun_obj.data.angle = math.radians(4.5)
    sun_obj.rotation_euler = (math.radians(-48), math.radians(14), math.radians(-22))

    bpy.ops.object.light_add(type='POINT', location=(-0.60, 1.98, 0.78))
    lamp_obj = bpy.context.active_object
    lamp_obj.name = "_BakeBedLamp"
    lamp_obj.data.energy = 26.0
    lamp_obj.data.color = (1.0, 0.66, 0.28)
    lamp_obj.data.shadow_soft_size = 0.16

    bpy.ops.object.light_add(type='POINT', location=(0.24, 1.92, 1.12))
    desk_lamp_obj = bpy.context.active_object
    desk_lamp_obj.name = "_BakeDeskLamp"
    desk_lamp_obj.data.energy = 14.0
    desk_lamp_obj.data.color = (1.0, 0.72, 0.36)
    desk_lamp_obj.data.shadow_soft_size = 0.12

    exclude_prefixes = (
        "WinSky", "WinLouver", "Succulent", "Pen_", "StickyNote", "Pin_",
        "CordSeg", "OutletPin", "Saklar", "Sandal", "PlantLeaf", "CombTooth",
        "PlantBlade_", "FanSpoke_", "FanHubBadge", "FanBtn_", "ClockTick_",
        "RugFringe", "MagicComLED", "Kerupuk", "LaundryMound_", "GalonTap",
        "GalonAquaBottle", "GalonWaterFill", "GalonLabelBand", "GalonCap", "KerupukGlass",
    )
    hidden_for_bake = []
    for o in bpy.data.objects:
        if o.type == 'MESH' and not o.hide_render:
            if any(o.name.startswith(p) for p in exclude_prefixes):
                o.hide_render = True
                hidden_for_bake.append(o)

    mesh_objs = [o for o in bpy.data.objects if o.type == 'MESH' and not o.hide_render]
    for o in mesh_objs:
        if not o.data.uv_layers:
            o.data.uv_layers.new(name="UVMap")
        lm_uv = o.data.uv_layers.get("LightmapUV") or o.data.uv_layers.new(name="LightmapUV")
        o.data.uv_layers.active = lm_uv

    bpy.ops.object.select_all(action='DESELECT')
    for o in mesh_objs:
        o.select_set(True)
    if mesh_objs:
        bpy.context.view_layer.objects.active = mesh_objs[0]
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.012)
        bpy.ops.object.mode_set(mode='OBJECT')

    lm_img = bpy.data.images.new("KosLightmapBake", width=size, height=size, alpha=False, float_buffer=True)
    bake_mat = bpy.data.materials.new("_BakeWhiteDiffuse")
    bake_mat.use_nodes = True
    nt = bake_mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.94, 0.94, 0.94, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.90
    tex_node = nt.nodes.new("ShaderNodeTexImage")
    tex_node.image = lm_img
    nt.nodes.active = tex_node

    saved_mats = {}
    for o in mesh_objs:
        saved_mats[o.name] = list(o.data.materials)
        o.data.materials.clear()
        o.data.materials.append(bake_mat)

    bpy.ops.object.bake(type='DIFFUSE')

    arr = np.array(lm_img.pixels[:], dtype=np.float32).reshape(size, size, 4)
    rgb = arr[:, :, :3]
    for _ in range(2):
        p = np.pad(rgb, ((1, 1), (1, 1), (0, 0)), mode='edge')
        rgb = (
            p[1:-1, 1:-1] * 4.0
            + (p[:-2, 1:-1] + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:]) * 2.0
            + (p[:-2, :-2] + p[:-2, 2:] + p[2:, :-2] + p[2:, 2:]) * 1.0
        ) / 16.0
    rgb = np.clip(rgb, 0.0, 1.8)
    rgb = np.clip(0.36 + 0.64 * (rgb / max(0.85, float(np.percentile(rgb, 96)))), 0.36, 1.0)
    out_rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)

    os.makedirs(os.path.dirname(out_png_path), exist_ok=True)
    out_img = bpy.data.images.new("KosLightmapOut", width=size, height=size, alpha=True, float_buffer=False)
    out_img.pixels.foreach_set(out_rgba.reshape(-1).tolist())
    out_img.filepath_raw = out_png_path
    out_img.file_format = 'PNG'
    out_img.save()

    for o in mesh_objs:
        o.data.materials.clear()
        for m in saved_mats.get(o.name, []):
            o.data.materials.append(m)
        o.data.uv_layers.active_index = 0
    for o in hidden_for_bake:
        o.hide_render = False
    for tmp in (sun_obj, lamp_obj, desk_lamp_obj):
        bpy.data.objects.remove(tmp, do_unlink=True)
    print("BAKED CYCLES LIGHTMAP:", out_png_path)


def build_room():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(TEX_DIR, exist_ok=True)

    floor_alb, floor_nrm, floor_rgh = generate_tile_textures(TEX_DIR, "room_ceramic_hd", (0.86, 0.78, 0.66), "ceramic", use_polyhaven=False)
    wall_alb, wall_nrm, wall_rgh = generate_plaster_ao_texture(TEX_DIR, "room_plaster_hd", (0.90, 0.83, 0.72), use_polyhaven=False)
    wood_alb, wood_nrm, wood_rgh = generate_wood_texture(TEX_DIR, "room_teak_hd", (0.44, 0.24, 0.12), use_polyhaven=False)
    leaf_alb = generate_foliage_texture(TEX_DIR, "room_plant_hd", (0.14, 0.44, 0.16))
    art_img = generate_wall_art_padi(TEX_DIR, "wall_art_padi_hd")
    laptop_img = generate_laptop_ui(TEX_DIR, "laptop_ui_hd")
    tv_img = generate_tv_weather_texture(TEX_DIR, "tv_weather_hd")
    rug_img = generate_woven_rug_texture(TEX_DIR, "woven_rug_hd")
    sajadah_img = generate_sajadah_texture(TEX_DIR, "sajadah_hd")
    sheet_img = generate_fabric_weave_texture(TEX_DIR, "fabric_sheet_hd", (0.90, 0.86, 0.78))
    blanket_img = generate_fabric_weave_texture(TEX_DIR, "fabric_blanket_hd", (0.78, 0.30, 0.16))
    curtain_img = generate_fabric_weave_texture(TEX_DIR, "fabric_curtain_hd", (0.20, 0.46, 0.58))
    rattan_alb, rattan_nrm = generate_rattan_textures(TEX_DIR, "rattan_woven_hd", size=1024)

    mat_floor = make_pbr_material("RoomFloor", floor_alb, 0.34, floor_nrm, 0.28, (4.2, 4.2))
    mat_wall = make_pbr_material("RoomWall", wall_alb, 0.82, None, 0.0, (1.0, 1.0))
    mat_wood = make_pbr_material("RoomWood", wood_alb, 0.40, None, 0.0, (1.4, 1.4))
    mat_wood_dark = make_solid_mat("RoomWoodDark", (0.28, 0.15, 0.08), 0.44)
    mat_leaf = make_pbr_material("RoomPlant", leaf_alb, 0.66)
    mat_art = make_pbr_material("RoomWallArt", art_img, 0.55)
    mat_screen = make_pbr_material("LaptopScreen", laptop_img, 0.32)
    mat_tv = make_pbr_material("TvScreen", tv_img, 0.25)
    tv_bsdf = mat_tv.node_tree.nodes["Principled BSDF"]
    tv_bsdf.inputs["Emission Strength"].default_value = 0.75
    tv_bsdf.inputs["Emission Color"].default_value = (0.35, 0.62, 0.85, 1.0)
    mat_rug = make_pbr_material("WovenRug", rug_img, 0.88)
    mat_sajadah = make_pbr_material("SajadahEmerald", sajadah_img, 0.86)
    mat_cream = make_pbr_material("BedSheet", sheet_img, 0.86, None, 0.0, (2.0, 2.0))
    mat_coral = make_pbr_material("BlanketCoral", blanket_img, 0.84, None, 0.0, (2.0, 2.0))
    mat_curtain = make_pbr_material("SageCurtain", curtain_img, 0.86, None, 0.0, (1.5, 2.5))

    mat_pot = make_solid_mat("TerracottaPot", (0.68, 0.30, 0.18), 0.72)
    mat_soil = make_solid_mat("DarkSoil", (0.16, 0.11, 0.08), 0.92)
    mat_lamp = make_solid_mat("WarmShade", (0.98, 0.80, 0.44), 0.36, 0.0, 0.42)
    mat_mirror = make_solid_mat("MirrorGlass", (0.58, 0.74, 0.88), 0.08, 0.35, 0.0)
    mat_book1 = make_solid_mat("BookTeal", (0.18, 0.52, 0.50), 0.72)
    mat_book2 = make_solid_mat("BookMustard", (0.82, 0.60, 0.22), 0.72)
    mat_brass = make_solid_mat("BrassKnob", (0.82, 0.64, 0.28), 0.28, 0.85)
    mat_dark = make_solid_mat("DarkAlloy", (0.14, 0.16, 0.20), 0.38, 0.65)
    mat_metal = make_solid_mat("AlloyChrome", (0.74, 0.76, 0.80), 0.25, 0.85)
    mat_wicker = make_solid_mat("WickerTan", (0.78, 0.66, 0.48), 0.84)
    mat_sky = make_solid_mat("WindowSky", (1.0, 0.76, 0.40), 0.22, 0.0, 0.85)
    mat_terracotta_red = make_solid_mat("TermosRed", (0.84, 0.18, 0.16), 0.34, 0.12)
    mat_aqua = make_solid_mat("AquaGalonBlue", (0.24, 0.64, 0.92), 0.14, 0.05, alpha=0.82)
    mat_white_plastic = make_solid_mat("WhitePlastic", (0.94, 0.94, 0.92), 0.36)
    mat_glass_jar = make_solid_mat("KerupukGlass", (0.88, 0.95, 0.98), 0.08, 0.05, alpha=0.22)
    mat_glass_jar.blend_method = 'BLEND'
    mat_kerupuk = make_solid_mat("KerupukSnack", (0.92, 0.78, 0.52), 0.82)
    mat_rattan = make_pbr_material("WovenRattan", rattan_alb, 0.78, rattan_nrm, 0.55, (2.5, 2.0))
    mat_wainscot = make_solid_mat("WainscotPlaster", (0.91, 0.88, 0.82), 0.84)
    mat_cork = make_solid_mat("CorkBoard", (0.64, 0.46, 0.28), 0.88)
    mat_sandal = make_solid_mat("SandalBlue", (0.16, 0.46, 0.76), 0.72)
    mat_tote = make_solid_mat("CanvasTote", (0.92, 0.86, 0.74), 0.88)

    # 1. Grounded Outer Courtyard + Room Shell & Trim (Skirt, Crown, Wainscot, Dado)
    mat_yard = make_solid_mat("KosOuterYard", (0.26, 0.24, 0.21), 0.90)
    mat_yard_patio = make_solid_mat("KosYardPatio", (0.58, 0.52, 0.44), 0.86)
    add_beveled_box("OuterYard", (16.0, 16.0, 0.12), (0.0, 0.0, -0.24), mat_yard, 0.0, use_wn=False)
    add_beveled_box("YardPatio", (6.6, 6.6, 0.10), (0.0, 0.0, -0.17), mat_yard_patio, 0.02, use_wn=False)
    add_beveled_box("YardFenceBack", (10.0, 0.20, 1.35), (0.0, 4.4, 0.45), mat_wainscot, 0.02, use_wn=False)
    add_beveled_box("YardFenceLeft", (0.20, 10.0, 1.35), (-4.4, 0.0, 0.45), mat_wainscot, 0.02, use_wn=False)

    add_beveled_box("FloorSlab", (4.8, 4.8, 0.16), (0.0, 0.0, -0.08), mat_floor, 0.015, cuts=2, use_wn=False)
    add_beveled_box("WallBack", (4.8, 0.14, 2.75), (0.0, 2.38, 1.375), mat_wall, 0.008, cuts=2, use_wn=False)
    add_beveled_box("WallLeft", (0.14, 4.8, 2.75), (-2.38, 0.0, 1.375), mat_wall, 0.008, cuts=2, use_wn=False)
    add_beveled_box("SkirtBack", (4.76, 0.045, 0.08), (0.0, 2.29, 0.04), mat_wood, 0.008, use_wn=False)
    add_beveled_box("SkirtLeft", (0.045, 4.76, 0.08), (-2.29, 0.0, 0.04), mat_wood, 0.008, use_wn=False)
    add_beveled_box("CrownBack", (4.76, 0.08, 0.08), (0.0, 2.29, 2.70), mat_wood, 0.010, use_wn=False)
    add_beveled_box("CrownLeft", (0.08, 4.76, 0.08), (-2.29, 0.0, 2.70), mat_wood, 0.010, use_wn=False)
    add_beveled_box("WainscotBack", (4.74, 0.025, 0.85), (0.0, 2.298, 0.43), mat_wainscot, 0.006, use_wn=False)
    add_beveled_box("WainscotLeft", (0.025, 4.74, 0.85), (-2.298, 0.0, 0.43), mat_wainscot, 0.006, use_wn=False)
    add_beveled_box("DadoRailBack", (4.74, 0.04, 0.04), (0.0, 2.29, 0.85), mat_wood, 0.006, use_wn=False)
    add_beveled_box("DadoRailLeft", (0.04, 4.74, 0.04), (-2.29, 0.0, 0.85), mat_wood, 0.006, use_wn=False)

    import_kenney_glb("ExtPlantWindow", "pottedPlant.glb", (0.35, 2.72, 0.65), rot_z=0.5, target_height=1.15, center_xy=True)
    import_kenney_glb("ExtPlantCorner", "pottedPlant.glb", (-2.68, -1.65, -0.10), rot_z=1.1, target_height=1.25, center_xy=True)

    add_beveled_box("IndoorAC", (0.86, 0.22, 0.26), (0.35, 2.20, 2.42), mat_white_plastic, 0.03)
    add_beveled_box("IndoorACVent", (0.76, 0.04, 0.04), (0.35, 2.09, 2.33), mat_dark, 0.008)

    # 2. Wooden Window Casing + Venetian Louvers + Succulent + Curtains
    add_beveled_box("WinFrame", (1.36, 0.09, 1.06), (0.35, 2.28, 1.58), mat_wood, 0.018)
    add_beveled_box("WinCasingTop", (1.46, 0.11, 0.06), (0.35, 2.25, 2.11), mat_wood_dark, 0.012)
    add_beveled_box("WinSill", (1.48, 0.18, 0.05), (0.35, 2.22, 1.04), mat_wood, 0.012)
    add_beveled_box("WinSky", (1.16, 0.04, 0.86), (0.35, 2.245, 1.58), mat_sky, 0.0)
    add_beveled_box("WinBarV", (0.04, 0.05, 0.86), (0.35, 2.215, 1.58), mat_wood, 0.008)
    for lz in range(6):
        add_beveled_box(f"WinLouver_{lz}", (1.14, 0.035, 0.012), (0.35, 2.22, 1.24 + lz * 0.13), mat_cream, 0.003, rot=(math.radians(22), 0, 0))
    add_cylinder("SucculentPot", 0.055, 0.09, (0.68, 2.18, 1.11), mat_pot, vertices=12)
    add_cylinder("SucculentSoil", 0.048, 0.02, (0.68, 2.18, 1.15), mat_soil, vertices=10)
    for s_i in range(6):
        ang = s_i * math.pi / 3.0
        add_beveled_box(f"SucculentLeaf_{s_i}", (0.028, 0.055, 0.014), (0.68 + math.cos(ang) * 0.028, 2.18 + math.sin(ang) * 0.028, 1.17), mat_leaf, 0.005, rot=(0.35, 0.0, ang))

    add_beveled_box("CurtainRod", (1.76, 0.04, 0.04), (0.35, 2.21, 2.18), mat_wood, 0.01)
    for side_x in (-0.38, 1.08):
        for p in range(4):
            px = side_x + (p - 1.5) * 0.065
            py = 2.21 - (0.018 if p % 2 == 0 else 0.0)
            add_beveled_box(f"CurtainPleat_{side_x}_{p}", (0.068, 0.04, 1.24), (px, py, 1.56), mat_curtain, 0.015)

    # 3. Wall Shelf + Books + Wall Art + Mirror + Corkboard + Clock + Rug + Sajadah
    add_beveled_box("WallShelf", (1.10, 0.26, 0.05), (-1.20, 2.16, 1.72), mat_wood, 0.012)
    shelf_books = import_kenney_glb("ShelfBooks", "books.glb", (-1.20, 2.16, 1.745), rot_z=0.0, target_height=0.26, center_xy=True)
    book_mats = [mat_book1, mat_book2, mat_terracotta_red, mat_curtain]
    book_idx = 0
    for child in shelf_books.children_recursive:
        if child.type == 'MESH' and child.data.materials:
            for s_i in range(len(child.data.materials)):
                child.data.materials[s_i] = book_mats[book_idx % 4]
                book_idx += 1
    for b_i, b_mat in enumerate(book_mats):
        add_beveled_box(f"ShelfBook_{b_i}", (0.042, 0.16, 0.22 - (b_i % 2) * 0.025), (-0.88 + b_i * 0.048, 2.16, 1.855 - (b_i % 2) * 0.012), b_mat, 0.005)

    add_beveled_box("WallArtFrame", (0.05, 0.82, 0.66), (-2.285, -0.35, 1.58), mat_wood, 0.015)
    add_beveled_box("WallArtMat", (0.03, 0.72, 0.56), (-2.26, -0.35, 1.58), mat_cream, 0.005)
    art_canvas = add_beveled_box("WallArtCanvas", (0.02, 0.60, 0.44), (-2.24, -0.35, 1.58), mat_art, 0.0, reset_uv=True)
    uv_layer = art_canvas.data.uv_layers.active
    for poly in art_canvas.data.polygons:
        for loop_idx in poly.loop_indices:
            v_co = art_canvas.data.vertices[art_canvas.data.loops[loop_idx].vertex_index].co
            uv_layer.data[loop_idx].uv = ((v_co.y / 0.60) + 0.5, (v_co.z / 0.44) + 0.5)

    add_beveled_box("SaklarPlate", (0.025, 0.09, 0.12), (-2.285, -1.05, 1.15), mat_white_plastic, 0.005)
    add_beveled_box("SaklarRocker", (0.03, 0.04, 0.06), (-2.275, -1.05, 1.15), mat_cream, 0.003)
    add_beveled_box("StopKontakPlate", (0.025, 0.09, 0.09), (0.35, 2.29, 0.34), mat_white_plastic, 0.005)
    add_cylinder("OutletPin1", 0.008, 0.02, (0.33, 2.275, 0.34), mat_dark, rot=(math.pi * 0.5, 0, 0), vertices=8)
    add_cylinder("OutletPin2", 0.008, 0.02, (0.37, 2.275, 0.34), mat_dark, rot=(math.pi * 0.5, 0, 0), vertices=8)

    add_beveled_box("WallMirrorFrame", (0.05, 0.50, 0.94), (-2.28, -1.55, 1.42), mat_wood_dark, 0.018)
    add_beveled_box("WallMirrorGlass", (0.02, 0.38, 0.82), (-2.255, -1.55, 1.42), mat_mirror, 0.004)
    add_beveled_box("CosmeticShelf", (0.16, 0.52, 0.032), (-2.22, -1.55, 0.88), mat_wood, 0.008)
    add_cylinder("SkincareBottle1", 0.024, 0.11, (-2.20, -1.68, 0.95), mat_cream, vertices=12)
    add_cylinder("SkincarePump1", 0.008, 0.03, (-2.20, -1.68, 1.02), mat_white_plastic, vertices=8)
    add_cylinder("SkincareBottle2", 0.022, 0.09, (-2.21, -1.58, 0.94), mat_book1, vertices=12)
    add_cylinder("SkincarePump2", 0.007, 0.025, (-2.21, -1.58, 0.995), mat_white_plastic, vertices=8)
    add_beveled_box("CombSpine", (0.015, 0.14, 0.012), (-2.20, -1.42, 0.902), mat_coral, 0.003)

    add_beveled_box("WallCorkFrame", (0.035, 0.66, 0.48), (-2.285, 0.95, 1.48), mat_wood, 0.01)
    add_beveled_box("WallCorkboard", (0.02, 0.60, 0.42), (-2.265, 0.95, 1.48), mat_cork, 0.004)
    add_beveled_box("StickyNote1", (0.01, 0.12, 0.12), (-2.25, 0.80, 1.54), mat_book2, 0.002)
    add_beveled_box("StickyNote2", (0.01, 0.11, 0.11), (-2.25, 0.96, 1.46), mat_coral, 0.002)
    add_beveled_box("StickyNote3", (0.01, 0.12, 0.10), (-2.25, 1.12, 1.52), mat_book1, 0.002)
    add_cylinder("Pin_1", 0.008, 0.015, (-2.24, 0.80, 1.59), mat_terracotta_red, rot=(0, math.pi * 0.5, 0), vertices=8)
    add_cylinder("Pin_2", 0.008, 0.015, (-2.24, 0.96, 1.50), mat_brass, rot=(0, math.pi * 0.5, 0), vertices=8)

    add_cylinder("ClockRim", 0.18, 0.04, (-2.27, 0.45, 1.74), mat_wood, rot=(0, math.pi * 0.5, 0), vertices=20)
    add_cylinder("ClockFace", 0.15, 0.03, (-2.25, 0.45, 1.74), mat_cream, rot=(0, math.pi * 0.5, 0), vertices=20)
    for ti in range(12):
        tang = ti * (math.pi / 6.0)
        add_beveled_box(f"ClockTick_{ti}", (0.012, 0.008, 0.016 if ti % 3 == 0 else 0.010), (-2.233, 0.45 + math.sin(tang) * 0.125, 1.74 + math.cos(tang) * 0.125), mat_brass if ti % 3 == 0 else mat_dark, 0.001, rot=(tang, 0.0, 0.0))
    add_beveled_box("ClockHandH", (0.02, 0.018, 0.09), (-2.23, 0.45, 1.77), mat_dark, 0.002)
    add_beveled_box("ClockHandM", (0.02, 0.11, 0.018), (-2.23, 0.49, 1.74), mat_dark, 0.002)

    add_beveled_box("CozyRug", (1.95, 1.45, 0.024), (-0.12, -0.35, 0.014), mat_rug, 0.012, reset_uv=True)
    add_beveled_box("RugFringeL", (0.055, 1.41, 0.008), (-1.115, -0.35, 0.006), mat_cream, 0.002)
    add_beveled_box("RugFringeR", (0.055, 1.41, 0.008), (0.875, -0.35, 0.006), mat_cream, 0.002)
    add_beveled_box("SajadahBase", (0.68, 1.06, 0.014), (1.20, -0.95, 0.009), mat_sajadah, 0.006, reset_uv=True)

    add_beveled_box("WallCalendar", (0.28, 0.02, 0.40), (1.24, 2.28, 1.62), mat_cream, 0.004)
    add_beveled_box("WallCalendarHeader", (0.26, 0.024, 0.12), (1.24, 2.275, 1.75), mat_book1, 0.003)

    # 4. Bed + Pillows + Guling + Sculpted Overhang Quilt
    import_kenney_glb("BedSingle", "bedSingle.glb", (-1.55, 1.25, 0.0), rot_z=0.0, target_height=0.72, center_xy=True)
    add_beveled_box("BedPillow1", (0.36, 0.24, 0.09), (-1.70, 1.84, 0.53), mat_cream, 0.035, rot=(0.18, 0.0, 0.08))
    add_beveled_box("BedPillow2", (0.34, 0.22, 0.085), (-1.38, 1.82, 0.53), mat_cream, 0.035, rot=(0.15, 0.0, -0.06))
    add_cylinder("GulingBody", 0.085, 0.68, (-1.42, 1.28, 0.56), mat_cream, rot=(math.pi * 0.5, 0, 0), vertices=16)
    add_cylinder("GulingPipeTop", 0.088, 0.02, (-1.42, 1.62, 0.56), mat_book1, rot=(math.pi * 0.5, 0, 0), vertices=16)
    add_cylinder("GulingPipeBot", 0.088, 0.02, (-1.42, 0.94, 0.56), mat_book1, rot=(math.pi * 0.5, 0, 0), vertices=16)

    quilt_mesh = bpy.data.meshes.new("BedQuiltDrape")
    quilt_obj = bpy.data.objects.new("BedQuiltDrape", quilt_mesh)
    bpy.context.collection.objects.link(quilt_obj)
    q_bm = bmesh.new()
    nx, ny = 24, 14
    q_grid = []
    for iy in range(ny + 1):
        vy = iy / float(ny)
        y_pos = 0.42 + vy * 0.52
        row = []
        for ix in range(nx + 1):
            ux = ix / float(nx)
            if ux < 0.24:
                t_side = (0.24 - ux) / 0.24
                x_pos = -2.06 - 0.045 * math.sin(t_side * math.pi * 0.5)
                z_pos = 0.505 - t_side * 0.30 + 0.010 * math.cos(vy * 18.0) * t_side
            elif ux > 0.76:
                t_side = (ux - 0.76) / 0.24
                x_pos = -1.04 + 0.045 * math.sin(t_side * math.pi * 0.5)
                z_pos = 0.505 - t_side * 0.30 + 0.010 * math.cos(vy * 18.0) * t_side
            else:
                t_top = (ux - 0.24) / 0.52
                x_pos = -2.06 + t_top * 1.02
                z_pos = 0.505 + 0.009 * math.cos(t_top * 14.0) + 0.006 * math.cos(vy * 16.0)
            row.append(q_bm.verts.new((x_pos, y_pos, z_pos)))
        q_grid.append(row)
    for iy in range(ny):
        for ix in range(nx):
            q_bm.faces.new((q_grid[iy][ix], q_grid[iy][ix + 1], q_grid[iy + 1][ix + 1], q_grid[iy + 1][ix]))
    bmesh.ops.recalc_face_normals(q_bm, faces=q_bm.faces[:])
    q_bm.to_mesh(quilt_mesh)
    q_bm.free()
    bpy.context.view_layer.objects.active = quilt_obj
    sol = quilt_obj.modifiers.new("Solidify", 'SOLIDIFY')
    sol.thickness = 0.010
    bpy.ops.object.modifier_apply(modifier="Solidify")
    sub = quilt_obj.modifiers.new("Subsurf", 'SUBSURF')
    sub.levels = 1
    sub.render_levels = 1
    bpy.ops.object.modifier_apply(modifier="Subsurf")
    bpy.ops.object.shade_smooth()
    quilt_obj.data.materials.append(mat_coral)
    ensure_uv0(quilt_obj, mode='SMART')

    add_beveled_box("EntryMat", (0.56, 0.38, 0.016), (-0.62, 0.85, 0.008), mat_wicker, 0.006)
    for idx, sx in enumerate((-0.71, -0.53)):
        add_beveled_box(f"SandalSole_{idx}", (0.095, 0.23, 0.022), (sx, 0.85, 0.025), mat_sandal, 0.01)
        add_beveled_box(f"SandalStrapL_{idx}", (0.018, 0.11, 0.016), (sx - 0.02, 0.88, 0.042), mat_white_plastic, 0.005, rot=(0.2, 0, -0.35))
        add_beveled_box(f"SandalStrapR_{idx}", (0.018, 0.11, 0.016), (sx + 0.02, 0.88, 0.042), mat_white_plastic, 0.005, rot=(0.2, 0, 0.35))

    add_beveled_box("Nightstand", (0.48, 0.46, 0.52), (-0.60, 2.02, 0.26), mat_wood, 0.02)
    add_beveled_box("NightDrawer", (0.40, 0.04, 0.16), (-0.60, 1.78, 0.38), mat_wood, 0.01)
    add_beveled_box("NightKnob", (0.04, 0.04, 0.04), (-0.60, 1.75, 0.38), mat_brass, 0.01)
    add_beveled_box("NightBook", (0.20, 0.15, 0.03), (-0.52, 1.92, 0.54), mat_book2, 0.006)
    import_kenney_glb("NightLamp", "lampRoundTable.glb", (-0.60, 2.02, 0.52), rot_z=0.0, target_height=0.34, center_xy=True)

    # 5. Study Desk & Micro-Props
    import_kenney_glb("StudyDesk", "desk.glb", (0.72, 1.88, 0.0), rot_z=0.0, target_height=0.76, center_xy=True)
    import_kenney_glb("StudyChair", "chairDesk.glb", (0.72, 1.26, 0.0), rot_z=math.pi, target_height=0.88, center_xy=True)
    import_kenney_glb("DeskTrashcan", "trashcan.glb", (1.36, 1.55, 0.0), rot_z=0.0, target_height=0.38, center_xy=True)

    add_beveled_box("LaptopBase", (0.36, 0.25, 0.02), (0.72, 1.86, 0.78), mat_dark, 0.008)
    add_beveled_box("LaptopLid", (0.36, 0.02, 0.24), (0.72, 1.98, 0.89), mat_dark, 0.008, (math.radians(-15), 0, 0))
    add_beveled_box("LaptopScreen", (0.32, 0.01, 0.20), (0.72, 1.968, 0.89), mat_screen, 0.0, (math.radians(-15), 0, 0))
    add_beveled_box("Mousepad", (0.20, 0.18, 0.008), (1.03, 1.84, 0.774), mat_dark, 0.003)
    add_beveled_box("DeskMouse", (0.055, 0.09, 0.028), (1.03, 1.84, 0.79), mat_white_plastic, 0.012)

    add_beveled_box("DeskBook1", (0.22, 0.16, 0.028), (0.40, 1.80, 0.784), mat_book1, 0.005)
    add_beveled_box("DeskBook2", (0.20, 0.15, 0.024), (0.40, 1.80, 0.810), mat_book2, 0.005, rot=(0, 0, 0.18))

    add_cylinder("PenCup", 0.036, 0.095, (1.22, 1.96, 0.818), mat_book1, vertices=12)
    add_cylinder("Pen_1", 0.005, 0.13, (1.21, 1.95, 0.85), mat_terracotta_red, rot=(0.12, 0.08, 0), vertices=8)
    add_cylinder("Pen_2", 0.005, 0.125, (1.23, 1.96, 0.85), mat_book2, rot=(-0.10, -0.06, 0), vertices=8)
    add_cylinder("Pen_3", 0.005, 0.135, (1.22, 1.97, 0.855), mat_aqua, rot=(0.05, -0.12, 0), vertices=8)

    jar_prof = [
        (0.001, 0.0), (0.060, 0.0), (0.064, 0.015), (0.064, 0.145),
        (0.056, 0.162), (0.056, 0.175), (0.052, 0.175), (0.052, 0.158),
        (0.058, 0.142), (0.058, 0.012), (0.001, 0.012),
    ]
    spin_profile("KerupukGlass", jar_prof, (0.14, 1.92, 0.77), mat_glass_jar, steps=24, uv_mode='SMART')
    for k_i in range(5):
        kz = 0.798 + k_i * 0.024
        kx = 0.14 + (0.012 if k_i % 2 == 0 else -0.012)
        ky = 1.92 + (0.010 if k_i % 3 == 0 else -0.010)
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.024, minor_radius=0.0085, major_segments=16, minor_segments=8,
            location=(kx, ky, kz), rotation=(0.32 * k_i, 0.22 * (k_i + 1), 0.7 * k_i)
        )
        kp = bpy.context.active_object
        kp.name = f"Kerupuk_{k_i}"
        bpy.ops.object.shade_smooth()
        kp.data.materials.append(mat_kerupuk)
        ensure_uv0(kp, mode='CUBE')
    add_cylinder("KerupukLid", 0.062, 0.028, (0.14, 1.92, 0.95), mat_terracotta_red, vertices=20)

    add_cylinder("DeskLampBase", 0.065, 0.02, (0.24, 2.02, 0.78), mat_dark, vertices=14)
    add_cylinder("DeskLampArm1", 0.010, 0.24, (0.24, 2.02, 0.90), mat_metal, rot=(0.2, 0, 0), vertices=8)
    add_cylinder("DeskLampArm2", 0.009, 0.20, (0.24, 1.96, 1.06), mat_metal, rot=(-0.5, 0, 0), vertices=8)
    add_cylinder("DeskLampShade", 0.055, 0.09, (0.24, 1.88, 1.08), mat_lamp, rot=(0.4, 0, 0), vertices=14)

    add_beveled_box("PowerStrip", (0.22, 0.055, 0.028), (1.06, 2.04, 0.784), mat_white_plastic, 0.006, rot=(0, 0, -0.15))
    for c_i in range(4):
        add_cylinder(f"CordSeg_{c_i}", 0.006, 0.06, (1.18 + c_i * 0.02, 2.06, 0.776), mat_dark, rot=(0, math.pi * 0.5, c_i * 0.4), vertices=8)

    # 6. Wardrobe + Tote + Sapu + Laundry Hamper + Standing Fan + Layered Plant
    add_beveled_box("WardrobeBody", (0.86, 0.56, 1.92), (1.92, 1.98, 0.96), mat_wood, 0.025)
    for dx in (1.71, 2.13):
        add_beveled_box(f"WardDoorRecess_{dx}", (0.36, 0.02, 1.68), (dx, 1.695, 0.96), mat_wood_dark, 0.006)
        add_beveled_box(f"WardRailTop_{dx}", (0.38, 0.03, 0.06), (dx, 1.685, 1.78), mat_wood, 0.006)
        add_beveled_box(f"WardRailBot_{dx}", (0.38, 0.03, 0.06), (dx, 1.685, 0.14), mat_wood, 0.006)
        add_beveled_box(f"WardRailL_{dx}", (0.045, 0.03, 1.68), (dx - 0.165, 1.685, 0.96), mat_wood, 0.006)
        add_beveled_box(f"WardRailR_{dx}", (0.045, 0.03, 1.68), (dx + 0.165, 1.685, 0.96), mat_wood, 0.006)
    add_beveled_box("WardHandleL", (0.025, 0.04, 0.14), (1.87, 1.66, 0.98), mat_brass, 0.005)
    add_beveled_box("WardHandleR", (0.025, 0.04, 0.14), (1.97, 1.66, 0.98), mat_brass, 0.005)
    add_beveled_box("WardKeyholePlate", (0.022, 0.015, 0.055), (1.89, 1.675, 0.86), mat_brass, 0.003)

    add_beveled_box("WardPegRail", (0.03, 0.36, 0.06), (1.48, 1.98, 1.48), mat_wood_dark, 0.006)
    add_cylinder("WardPeg1", 0.014, 0.06, (1.45, 1.90, 1.48), mat_brass, rot=(0, math.pi * 0.5, 0), vertices=10)
    add_beveled_box("WardToteBag", (0.07, 0.24, 0.30), (1.44, 1.90, 1.24), mat_tote, 0.022)

    add_cylinder("BroomHandle", 0.018, 1.18, (1.40, 1.95, 0.65), mat_wood, rot=(0, math.radians(-8), 0), vertices=8)
    add_beveled_box("BroomHead", (0.24, 0.05, 0.16), (1.32, 1.95, 0.08), mat_dark, 0.01)

    basket_prof = [
        (0.001, 0.0), (0.155, 0.0), (0.162, 0.02), (0.215, 0.42),
        (0.232, 0.44), (0.232, 0.46), (0.210, 0.46), (0.200, 0.42),
        (0.148, 0.02), (0.001, 0.02),
    ]
    spin_profile("LaundryBasket", basket_prof, (1.68, -0.70, 0.0), mat_rattan, steps=24, uv_mode='SMART')
    mound_specs = [
        (1.63, -0.74, 0.43, (0.12, 0.10, 0.055), (0.15, -0.10, 0.3), mat_book1),
        (1.73, -0.66, 0.44, (0.11, 0.11, 0.050), (-0.12, 0.18, 0.9), mat_cream),
        (1.67, -0.68, 0.47, (0.10, 0.09, 0.045), (0.20, 0.12, 1.4), mat_coral),
    ]
    for m_i, (mx, my, mz, m_scale, m_rot, m_mat) in enumerate(mound_specs):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0, location=(mx, my, mz))
        m_obj = bpy.context.active_object
        m_obj.name = f"LaundryMound_{m_i}"
        m_obj.scale = m_scale
        m_obj.rotation_euler = m_rot
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        for v in m_obj.data.vertices:
            fold = 0.010 * math.sin(v.co.x * 55.0 + m_i) * math.cos(v.co.y * 48.0) + 0.006 * math.sin((v.co.x + v.co.y) * 90.0)
            v.co.z += fold
            v.co.x += fold * 0.35
        bpy.ops.object.shade_smooth()
        m_obj.data.materials.append(m_mat)
        ensure_uv0(m_obj, mode='CUBE')

    add_open_standing_fan_hd(1.90, 0.72, mat_dark, mat_book1, mat_metal)
    add_layered_broadleaf_plant(-1.72, -1.05, mat_pot, mat_soil, mat_leaf, prefix="Plant")

    add_beveled_box("WardBox1", (0.38, 0.34, 0.22), (1.76, 1.98, 2.03), mat_wicker, 0.015)
    add_beveled_box("WardBox2", (0.34, 0.30, 0.18), (2.14, 1.98, 2.01), mat_book1, 0.012)
    add_beveled_box("RiceCookerStand", (0.38, 0.38, 0.42), (1.92, 0.08, 0.21), mat_wood, 0.015)
    add_magic_com_hd(1.92, 0.08, 0.42, mat_white_plastic, mat_terracotta_red, mat_metal, mat_dark)

    add_beveled_box("TvCornerShelf", (0.48, 0.34, 0.035), (1.92, 0.08, 0.90), mat_wood, 0.010, rot=(0, 0, math.radians(-55)))
    add_beveled_box("RoomTvBody", (0.44, 0.10, 0.32), (1.92, 0.08, 1.08), mat_dark, 0.015, rot=(0, 0, math.radians(-55)))
    add_beveled_box("RoomTvScreen", (0.38, 0.02, 0.25), (1.88, 0.05, 1.08), mat_tv, 0.0, rot=(0, 0, math.radians(-55)), use_wn=False, reset_uv=True)

    # 7. Wooden Stand + HD Galon Water Dispenser
    for lx in (-0.125, 0.125):
        for ly in (-0.125, 0.125):
            add_beveled_box(f"GalonLeg_{lx}_{ly}", (0.036, 0.036, 0.38), (1.92 + lx, -0.36 + ly, 0.19), mat_wood, 0.006)
    add_beveled_box("GalonStandTop", (0.32, 0.32, 0.03), (1.92, -0.36, 0.385), mat_wood, 0.008)
    add_galon_dispenser_hd(1.92, -0.36, 0.40, mat_white_plastic, mat_dark, mat_terracotta_red, mat_aqua, prefix="Galon")

    bake_cycles_lightmap(OUT_LM, size=1024, samples=14)
    polish_scene_textures_1024()
    export_room_glb(OUT_GLB, quality=88)
    print("EXPORTED HD KOS ROOM:", OUT_GLB, "bytes=", os.path.getsize(OUT_GLB))


if __name__ == "__main__":
    build_room()
