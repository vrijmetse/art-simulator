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
    generate_fabric_weave_texture,
    generate_foliage_texture,
    generate_laptop_ui,
    generate_plaster_ao_texture,
    generate_sajadah_texture,
    generate_tile_textures,
    generate_turf_texture,
    generate_tv_weather_texture,
    generate_wall_art_padi,
    generate_wood_texture,
    generate_woven_rug_texture,
    make_pbr_material,
)

GODOT_DIR = os.path.dirname(SCRIPT_DIR)
TEX_DIR = os.path.join(GODOT_DIR, "assets", "textures")
UNPACKED_DIR = os.path.join(GODOT_DIR, "assets", "raw", "unpacked")
OUT_GLB = os.path.join(GODOT_DIR, "assets", "models", "kos_room.glb")


def make_solid_mat(name, rgb, roughness=0.78, metallic=0.0, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def rebuild_kenney_pbr_material(mat):
    """Strip KHR_materials_unlit and rebuild a clean PBR Principled BSDF mapped by material name."""
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
        color = (0.24, 0.14, 0.08, 1.0)
        roughness = 0.62
        metallic = 0.0
    elif "wood" in mname:
        color = (0.44, 0.26, 0.14, 1.0)
        roughness = 0.62
        metallic = 0.0
    elif "metaldark" in mname:
        color = (0.16, 0.17, 0.19, 1.0)
        roughness = 0.45
        metallic = 0.65
    elif "metallight" in mname or "metal" in mname:
        color = (0.74, 0.76, 0.79, 1.0)
        roughness = 0.35
        metallic = 0.85
    elif "glass" in mname:
        color = (0.65, 0.80, 0.86, 1.0)
        roughness = 0.15
        metallic = 0.05
    elif "carpet" in mname:
        color = (0.72, 0.34, 0.26, 1.0)
        roughness = 0.88
        metallic = 0.0
    elif "leaf" in mname or "foliage" in mname or "leaves" in mname or "plant" in mname:
        color = (0.20, 0.48, 0.20, 1.0)
        roughness = 0.72
        metallic = 0.0
    elif "trunk" in mname or "bark" in mname:
        color = (0.34, 0.22, 0.14, 1.0)
        roughness = 0.88
        metallic = 0.0
    elif "white" in mname or "ceramic" in mname:
        color = (0.90, 0.89, 0.86, 1.0)
        roughness = 0.38
        metallic = 0.0
    else:
        color = (0.72, 0.68, 0.62, 1.0)
        roughness = 0.65
        metallic = 0.0

    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic


def import_kenney_glb(prefix, filename, loc, rot_z=0.0, scale=1.85, target_height=None, center_xy=False):
    """Import a Kenney GLB, strip KHR_materials_unlit, normalize min.z=0 (and optional center_xy), and place at loc."""
    filepath = os.path.join(UNPACKED_DIR, filename)
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
    roots = [o for o in imported if o.parent is None]
    for o in roots:
        o.parent = parent

    bpy.context.view_layer.update()

    min_x, max_x = float("inf"), float("-inf")
    min_y, max_y = float("inf"), float("-inf")
    min_z, max_z = float("inf"), float("-inf")
    for o in meshes:
        for v in o.bound_box:
            wv = o.matrix_world @ Vector(v)
            min_x, max_x = min(min_x, wv.x), max(max_x, wv.x)
            min_y, max_y = min(min_y, wv.y), max(max_y, wv.y)
            min_z, max_z = min(min_z, wv.z), max(max_z, wv.z)

    if center_xy and roots:
        cx = (min_x + max_x) * 0.5
        cy = (min_y + max_y) * 0.5
        for o in roots:
            o.location = (o.location.x - cx, o.location.y - cy, o.location.z)
        bpy.context.view_layer.update()

    cur_h = max(0.001, max_z - min_z)
    s = (target_height / cur_h) if target_height is not None else scale

    parent.scale = (s, s, s)
    parent.rotation_euler = (0.0, 0.0, rot_z)
    parent.location = (loc[0], loc[1], loc[2] - min_z * s)
    bpy.context.view_layer.update()
    return parent


def add_beveled_box(name, size, loc, mat, bevel=0.022, rot=(0.0, 0.0, 0.0), cuts=0, use_wn=True, reset_uv=False):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        b = obj.modifiers.new("Bevel", 'BEVEL')
        b.width = bevel
        b.segments = 3 if use_wn else 2
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


def bake_cycles_lightmap(out_png_path: str, size: int = 1024, samples: int = 24):
    """Bake real Cycles 2-tone GI + soft shadows + window light shafts into UV2 (LightmapUV)."""
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

    # Two-tone World ambient: cool slate-blue shadows
    world = bpy.data.worlds.new("BakeWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.34, 0.46, 0.72, 1.0)
    bg.inputs["Strength"].default_value = 0.92

    # Warm golden Sun shining diagonally through the 3D window frame & mullions
    bpy.ops.object.light_add(type='SUN', location=(0.6, 5.0, 3.6))
    sun_obj = bpy.context.active_object
    sun_obj.name = "_BakeSun"
    sun_obj.data.energy = 3.4
    sun_obj.data.color = (1.0, 0.78, 0.44)
    sun_obj.data.angle = math.radians(4.5)
    sun_obj.rotation_euler = (math.radians(-48), math.radians(14), math.radians(-22))

    # Warm cozy bedside lamp pool
    bpy.ops.object.light_add(type='POINT', location=(-0.60, 1.98, 0.78))
    lamp_obj = bpy.context.active_object
    lamp_obj.name = "_BakeBedLamp"
    lamp_obj.data.energy = 26.0
    lamp_obj.data.color = (1.0, 0.66, 0.28)
    lamp_obj.data.shadow_soft_size = 0.16

    # Let sunlight pass cleanly through window glass during bake
    win_sky = bpy.data.objects.get("WinSky")
    if win_sky:
        win_sky.hide_render = True

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

    # Smooth 3x3 Gaussian blur + safe [0.50..1.00] lift to prevent double-darkening in Godot
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
    rgb = np.clip(0.34 + 0.66 * (rgb / max(0.85, float(np.percentile(rgb, 96)))), 0.34, 1.0)
    out_rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)

    out_img = bpy.data.images.new("KosLightmapOut", width=size, height=size, alpha=True, float_buffer=False)
    out_img.pixels.foreach_set(out_rgba.reshape(-1).tolist())
    out_img.filepath_raw = out_png_path
    out_img.file_format = 'PNG'
    out_img.save()

    # Restore original materials & primary UVMap (index 0) before glTF export
    for o in mesh_objs:
        o.data.materials.clear()
        for m in saved_mats.get(o.name, []):
            o.data.materials.append(m)
        o.data.uv_layers.active_index = 0
    if win_sky:
        win_sky.hide_render = False
    for tmp in (sun_obj, lamp_obj):
        bpy.data.objects.remove(tmp, do_unlink=True)
    print("BAKED CYCLES LIGHTMAP:", out_png_path)


def add_curved_monstera_plant(x, y, pot_mat, soil_mat, stem_mat, leaf_mat):
    bpy.ops.mesh.primitive_cone_add(vertices=14, radius1=0.17, radius2=0.22, depth=0.36, location=(x, y, 0.18))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(pot_mat)
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.23, depth=0.055, location=(x, y, 0.35))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(pot_mat)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.19, depth=0.03, location=(x, y, 0.335))
    bpy.context.active_object.data.materials.append(soil_mat)

    bm = bmesh.new()
    for k in range(9):
        ang = (k / 9.0) * math.pi * 2.0 + 0.3
        ca, sa = math.cos(ang), math.sin(ang)
        nx, ny = -sa, ca
        stem_h = 0.22 + (k % 3) * 0.08
        sx, sy, sz = ca * 0.14, sa * 0.14, 0.34 + stem_h
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=6, radius=0.012, depth=stem_h,
            location=(x + sx * 0.5, y + sy * 0.5, 0.34 + stem_h * 0.5),
            rotation=(-sa * 0.4, ca * 0.4, 0.0),
        )
        bpy.context.active_object.data.materials.append(stem_mat)

        blen = 0.26 + (k % 2) * 0.05
        bwid = 0.12
        p0 = bm.verts.new((sx, sy, sz))
        p1 = bm.verts.new((sx + ca * blen * 0.45 + nx * bwid, sy + sa * blen * 0.45 + ny * bwid, sz + 0.06))
        p2 = bm.verts.new((sx + ca * blen * 0.45 - nx * bwid, sy + sa * blen * 0.45 - ny * bwid, sz + 0.06))
        p3 = bm.verts.new((sx + ca * blen * 0.50, sy + sa * blen * 0.50, sz + 0.09))
        p4 = bm.verts.new((sx + ca * blen, sy + sa * blen, sz - 0.04))
        bm.faces.new((p0, p1, p3))
        bm.faces.new((p0, p3, p2))
        bm.faces.new((p1, p4, p3))
        bm.faces.new((p3, p4, p2))
    mesh = bpy.data.meshes.new("MonsteraLeaves")
    bm.to_mesh(mesh)
    bm.free()
    leaves = bpy.data.objects.new("MonsteraLeaves", mesh)
    leaves.location = (x, y, 0.0)
    bpy.context.collection.objects.link(leaves)
    leaves.data.materials.append(leaf_mat)


def add_open_standing_fan(x, y, dark_mat, teal_mat, metal_mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.18, depth=0.05, location=(x, y, 0.025))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(dark_mat)
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.024, depth=1.02, location=(x, y, 0.54))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(dark_mat)

    hz = 1.12
    yaw = math.radians(-35)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.20, minor_radius=0.015,
        major_segments=22, minor_segments=8,
        location=(x, y, hz), rotation=(math.radians(82), 0, yaw),
    )
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(metal_mat)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.055, location=(x, y, hz))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(dark_mat)

    for b in range(4):
        ang = b * math.pi * 0.5 + 0.35
        bx = x + math.cos(yaw) * math.cos(ang) * 0.10
        by = y + math.sin(yaw) * math.cos(ang) * 0.10
        bz = hz + math.sin(ang) * 0.10
        add_beveled_box(f"FanBlade_{b}", (0.14, 0.015, 0.055), (bx, by, bz), teal_mat, 0.006, (math.radians(22), ang, yaw))


def build_room():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    floor_alb, floor_nrm, floor_rgh = generate_tile_textures(TEX_DIR, "room_ceramic_v20", (0.86, 0.78, 0.66), "ceramic", use_polyhaven=False)
    wall_alb, wall_nrm, wall_rgh = generate_plaster_ao_texture(TEX_DIR, "room_plaster_v20", (0.90, 0.83, 0.72), use_polyhaven=False)
    wood_alb, wood_nrm, wood_rgh = generate_wood_texture(TEX_DIR, "room_teak_v20", (0.44, 0.24, 0.12), use_polyhaven=False)
    leaf_alb = generate_foliage_texture(TEX_DIR, "room_plant_v5", (0.14, 0.44, 0.16))
    art_img = generate_wall_art_padi(TEX_DIR, "wall_art_padi_v5")
    laptop_img = generate_laptop_ui(TEX_DIR, "laptop_ui_v5")
    tv_img = generate_tv_weather_texture(TEX_DIR, "tv_weather_v20")
    rug_img = generate_woven_rug_texture(TEX_DIR, "woven_rug_v5")
    sajadah_img = generate_sajadah_texture(TEX_DIR, "sajadah_v20")
    sheet_img = generate_fabric_weave_texture(TEX_DIR, "fabric_sheet_v5", (0.90, 0.86, 0.78))
    blanket_img = generate_fabric_weave_texture(TEX_DIR, "fabric_blanket_v5", (0.78, 0.30, 0.16))
    curtain_img = generate_fabric_weave_texture(TEX_DIR, "fabric_curtain_v5", (0.20, 0.46, 0.58))

    mat_floor = make_pbr_material("RoomFloor", floor_alb, 0.34, floor_nrm, 0.28, (4.2, 4.2))
    mat_wall = make_pbr_material("RoomWall", wall_alb, 0.82, None, 0.0, (1.0, 1.0))
    mat_wood = make_pbr_material("RoomWood", wood_alb, 0.40, None, 0.0, (1.4, 1.4))
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
    mat_lamp = make_solid_mat("WarmShade", (0.98, 0.80, 0.44), 0.32, 0.0, 1.25)
    mat_book1 = make_solid_mat("BookTeal", (0.18, 0.52, 0.50), 0.72)
    mat_book2 = make_solid_mat("BookMustard", (0.82, 0.60, 0.22), 0.72)
    mat_brass = make_solid_mat("BrassKnob", (0.82, 0.64, 0.28), 0.28, 0.85)
    mat_dark = make_solid_mat("DarkAlloy", (0.14, 0.16, 0.20), 0.38, 0.65)
    mat_metal = make_solid_mat("AlloyChrome", (0.74, 0.76, 0.80), 0.25, 0.85)
    mat_wicker = make_solid_mat("WickerTan", (0.78, 0.66, 0.48), 0.84)
    mat_sky = make_solid_mat("WindowSky", (1.0, 0.76, 0.40), 0.22, 0.0, 0.85)
    mat_terracotta_red = make_solid_mat("TermosRed", (0.84, 0.18, 0.16), 0.34, 0.12)

    # Cozy cutaway diorama (clean dark studio exterior + lush plants outside, no muddy grey yard!)
    add_beveled_box("FloorSlab", (4.8, 4.8, 0.16), (0.0, 0.0, -0.08), mat_floor, 0.015, cuts=2, use_wn=False)
    add_beveled_box("WallBack", (4.8, 0.14, 2.75), (0.0, 2.38, 1.375), mat_wall, 0.008, cuts=2, use_wn=False)
    add_beveled_box("WallLeft", (0.14, 4.8, 2.75), (-2.38, 0.0, 1.375), mat_wall, 0.008, cuts=2, use_wn=False)
    add_beveled_box("SkirtBack", (4.76, 0.06, 0.14), (0.0, 2.285, 0.07), mat_wood, 0.010, use_wn=False)
    add_beveled_box("SkirtLeft", (0.06, 4.76, 0.14), (-2.285, 0.0, 0.07), mat_wood, 0.010, use_wn=False)
    add_beveled_box("CrownBack", (4.76, 0.08, 0.08), (0.0, 2.29, 2.70), mat_wood, 0.010, use_wn=False)
    add_beveled_box("CrownLeft", (0.08, 4.76, 0.08), (-2.29, 0.0, 2.70), mat_wood, 0.010, use_wn=False)
    add_beveled_box("WainscotBack", (4.74, 0.03, 0.85), (0.0, 2.295, 0.43), mat_cream, 0.008, use_wn=False)
    add_beveled_box("WainscotLeft", (0.03, 4.74, 0.85), (-2.295, 0.0, 0.43), mat_cream, 0.008, use_wn=False)
    # Exterior tropical greenery framing the open window & left diorama edge
    import_kenney_glb("ExtPlantWindow", "pottedPlant.glb", (0.35, 2.72, 0.65), rot_z=0.5, target_height=1.15, center_xy=True)
    import_kenney_glb("ExtPlantCorner", "pottedPlant.glb", (-2.68, -1.65, -0.10), rot_z=1.1, target_height=1.25, center_xy=True)
    # Indoor Split AC unit high on WallBack + power cord
    add_beveled_box("IndoorAC", (0.86, 0.22, 0.26), (0.35, 2.20, 2.42), mat_cream, 0.03)
    add_beveled_box("IndoorACVent", (0.76, 0.04, 0.04), (0.35, 2.09, 2.33), mat_dark, 0.008)

    # Window + Sill + Succulents + Pleated Curtains
    add_beveled_box("WinFrame", (1.35, 0.08, 1.05), (0.35, 2.28, 1.58), mat_wood, 0.02)
    add_beveled_box("WinSill", (1.44, 0.16, 0.05), (0.35, 2.24, 1.04), mat_wood, 0.012)
    add_beveled_box("WinSky", (1.16, 0.04, 0.86), (0.35, 2.245, 1.58), mat_sky, 0.0)
    add_beveled_box("WinBarV", (0.04, 0.05, 0.86), (0.35, 2.215, 1.58), mat_wood, 0.008)
    add_beveled_box("WinBarH", (1.16, 0.05, 0.04), (0.35, 2.215, 1.58), mat_wood, 0.008)
    add_beveled_box("CurtainRod", (1.76, 0.04, 0.04), (0.35, 2.21, 2.18), mat_wood, 0.01)
    for side_x in (-0.38, 1.08):
        for p in range(4):
            px = side_x + (p - 1.5) * 0.065
            py = 2.21 - (0.018 if p % 2 == 0 else 0.0)
            add_beveled_box(f"CurtainPleat_{side_x}_{p}", (0.068, 0.04, 1.24), (px, py, 1.56), mat_curtain, 0.015)

    # Floating Wall Shelf + Kenney Books + Framed Indonesian Painting + Round Wall Clock + Visible Wall Pegboard!
    add_beveled_box("WallShelf", (1.10, 0.26, 0.05), (-1.20, 2.16, 1.72), mat_wood, 0.012)
    import_kenney_glb("ShelfBooks", "books.glb", (-1.20, 2.16, 1.745), rot_z=0.0, target_height=0.26, center_xy=True)

    add_beveled_box("WallArtFrame", (0.05, 0.82, 0.66), (-2.285, -0.35, 1.58), mat_wood, 0.015)
    add_beveled_box("WallArtMat", (0.03, 0.72, 0.56), (-2.26, -0.35, 1.58), mat_cream, 0.005)
    add_beveled_box("WallArtCanvas", (0.02, 0.60, 0.44), (-2.24, -0.35, 1.58), mat_art, 0.0)
    add_beveled_box("WallSwitch", (0.03, 0.10, 0.14), (-2.28, -1.05, 1.15), mat_cream, 0.006)
    # Tall framed mirror + hanging canvas tote bag on left wall
    add_beveled_box("WallMirrorFrame", (0.04, 0.48, 0.92), (-2.28, -1.55, 1.38), mat_wood, 0.015)
    add_beveled_box("WallMirrorGlass", (0.02, 0.38, 0.80), (-2.26, -1.55, 1.38), mat_sky, 0.004)
    add_beveled_box("WallToteHook", (0.06, 0.06, 0.04), (-2.26, -1.10, 1.48), mat_brass, 0.01)
    add_beveled_box("WallToteBag", (0.08, 0.24, 0.30), (-2.24, -1.10, 1.24), mat_coral, 0.025)
    add_beveled_box("WallPegboard", (0.04, 0.64, 0.46), (-2.28, 0.95, 1.48), mat_wicker, 0.01)
    add_beveled_box("PegNote1", (0.02, 0.15, 0.18), (-2.255, 0.80, 1.52), mat_book2, 0.004)
    add_beveled_box("PegNote2", (0.02, 0.16, 0.14), (-2.255, 1.08, 1.45), mat_coral, 0.004)

    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.18, depth=0.04, location=(-2.27, 0.45, 1.88), rotation=(0, math.pi * 0.5, 0))
    bpy.context.active_object.data.materials.append(mat_wood)
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.15, depth=0.03, location=(-2.25, 0.45, 1.88), rotation=(0, math.pi * 0.5, 0))
    bpy.context.active_object.data.materials.append(mat_cream)
    add_beveled_box("ClockHandH", (0.02, 0.018, 0.09), (-2.23, 0.45, 1.91), mat_dark, 0.002)
    add_beveled_box("ClockHandM", (0.02, 0.11, 0.018), (-2.23, 0.49, 1.88), mat_dark, 0.002)

    # Patterned Woven Kilim Rug + Crisp UV-mapped Emerald & Gold Sajadah Prayer Mat
    add_beveled_box("CozyRug", (1.95, 1.45, 0.024), (-0.12, -0.35, 0.014), mat_rug, 0.012, reset_uv=True)
    add_beveled_box("SajadahBase", (0.68, 1.06, 0.014), (1.20, -0.95, 0.009), mat_sajadah, 0.006, reset_uv=True)

    # Wall Calendar next to window + Red Indonesian Floral Thermos on Desk
    add_beveled_box("WallCalendar", (0.28, 0.02, 0.40), (1.24, 2.28, 1.62), mat_cream, 0.004)
    add_beveled_box("WallCalendarHeader", (0.26, 0.024, 0.12), (1.24, 2.275, 1.75), mat_book1, 0.003)

    # Kenney Single Bed + Indonesian Guling Bolster + Bedside Slippers (centered!)
    import_kenney_glb("BedSingle", "bedSingle.glb", (-1.55, 1.25, 0.0), rot_z=0.0, target_height=0.72, center_xy=True)
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.09, depth=0.72, location=(-1.42, 1.32, 0.56), rotation=(math.pi * 0.5, 0, 0))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(mat_cream)
    for sx in (-0.72, -0.52):
        add_beveled_box(f"Slipper_{sx}", (0.10, 0.24, 0.03), (sx, 0.85, 0.018), mat_book1, 0.012)

    # Nightstand Drawer + Kenney Table Lamp + Book
    add_beveled_box("Nightstand", (0.48, 0.46, 0.52), (-0.60, 2.02, 0.26), mat_wood, 0.02)
    add_beveled_box("NightDrawer", (0.40, 0.04, 0.16), (-0.60, 1.78, 0.38), mat_wood, 0.01)
    add_beveled_box("NightKnob", (0.04, 0.04, 0.04), (-0.60, 1.75, 0.38), mat_brass, 0.01)
    add_beveled_box("NightBook", (0.20, 0.15, 0.03), (-0.52, 1.92, 0.54), mat_book2, 0.006)
    import_kenney_glb("NightLamp", "lampRoundTable.glb", (-0.60, 2.02, 0.52), rot_z=0.0, target_height=0.34, center_xy=True)

    # Kenney Desk + Kenney Desk Chair + Trashcan + Laptop + Notebook + Mug (centered!)
    import_kenney_glb("StudyDesk", "desk.glb", (0.72, 1.88, 0.0), rot_z=0.0, target_height=0.76, center_xy=True)
    import_kenney_glb("StudyChair", "chairDesk.glb", (0.72, 1.26, 0.0), rot_z=math.pi, target_height=0.88, center_xy=True)
    import_kenney_glb("DeskTrashcan", "trashcan.glb", (1.36, 1.55, 0.0), rot_z=0.0, target_height=0.38, center_xy=True)

    add_beveled_box("LaptopBase", (0.36, 0.25, 0.02), (0.72, 1.86, 0.78), mat_dark, 0.008)
    add_beveled_box("LaptopLid", (0.36, 0.02, 0.24), (0.72, 1.98, 0.89), mat_dark, 0.008, (math.radians(-15), 0, 0))
    add_beveled_box("LaptopScreen", (0.32, 0.01, 0.20), (0.72, 1.968, 0.89), mat_screen, 0.0, (math.radians(-15), 0, 0))
    add_beveled_box("DeskNotebook", (0.22, 0.16, 0.025), (0.38, 1.82, 0.785), mat_book2, 0.005)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.045, depth=0.09, location=(1.02, 1.78, 0.815))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(mat_coral)
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.035, depth=0.10, location=(1.22, 1.95, 0.82))
    bpy.context.active_object.data.materials.append(mat_book1)
    # Indonesian Red Thermos
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.065, depth=0.22, location=(0.14, 1.92, 0.88))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(mat_terracotta_red)
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.052, depth=0.06, location=(0.14, 1.92, 1.01))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(mat_cream)

    # Tall Wooden Wardrobe + Sapu Ijuk Broom (ART signature!) + Laundry Basket + Standing Fan
    add_beveled_box("WardrobeBody", (0.86, 0.56, 1.92), (1.92, 1.98, 0.96), mat_wood, 0.025)
    for dx in (1.71, 2.13):
        add_beveled_box(f"WardDoor_{dx}", (0.38, 0.03, 1.72), (dx, 1.69, 0.96), mat_wood, 0.01)
    add_beveled_box("WardHandleL", (0.025, 0.04, 0.14), (1.87, 1.66, 0.98), mat_brass, 0.005)
    add_beveled_box("WardHandleR", (0.025, 0.04, 0.14), (1.97, 1.66, 0.98), mat_brass, 0.005)

    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.018, depth=1.18, location=(1.40, 1.95, 0.65), rotation=(0, math.radians(-8), 0))
    bpy.context.active_object.data.materials.append(mat_wood)
    add_beveled_box("BroomHead", (0.24, 0.05, 0.16), (1.32, 1.95, 0.08), mat_dark, 0.01)

    bpy.ops.mesh.primitive_cone_add(vertices=14, radius1=0.16, radius2=0.22, depth=0.44, location=(1.68, -0.70, 0.22))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(mat_wicker)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.22, minor_radius=0.022, major_segments=16, minor_segments=8, location=(1.68, -0.70, 0.44))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(mat_wood)
    add_beveled_box("LaundryCloth", (0.24, 0.22, 0.08), (1.68, -0.70, 0.46), mat_book1, 0.03)

    add_open_standing_fan(1.90, 0.72, mat_dark, mat_book1, mat_metal)
    import_kenney_glb("PottedPlant", "pottedPlant.glb", (-1.72, -1.05, 0.0), rot_z=0.35, target_height=0.95, center_xy=True)

    # Storage Boxes atop Wardrobe + Retro Cozy TV on corner stand
    add_beveled_box("WardBox1", (0.38, 0.34, 0.22), (1.76, 1.98, 2.03), mat_wicker, 0.015)
    add_beveled_box("WardBox2", (0.34, 0.30, 0.18), (2.14, 1.98, 2.01), mat_book1, 0.012)
    add_beveled_box("RoomTvBody", (0.44, 0.10, 0.32), (1.92, 0.08, 0.62), mat_dark, 0.015, rot=(0, 0, math.radians(-55)))
    add_beveled_box("RoomTvScreen", (0.38, 0.02, 0.25), (1.88, 0.05, 0.62), mat_tv, 0.0, rot=(0, 0, math.radians(-55)), use_wn=False, reset_uv=True)

    # Indonesian Kos Magic Com (Rice Cooker) on desk side + warm lightmap bake!
    add_beveled_box("RiceCookerStand", (0.38, 0.38, 0.42), (1.92, 0.08, 0.21), mat_wood, 0.015)

    bake_cycles_lightmap(os.path.join(GODOT_DIR, "assets", "lightmaps", "kos_room_lightmap.png"), size=1024, samples=24)

    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB', export_apply=False)
    print("EXPORTED V19 KOS ROOM:", OUT_GLB, "bytes=", os.path.getsize(OUT_GLB))


if __name__ == "__main__":
    build_room()
