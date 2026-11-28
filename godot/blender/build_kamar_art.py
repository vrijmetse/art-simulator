import os
import sys
import math
import bpy
import numpy as np
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from tex_utils import (
    add_layered_broadleaf_plant,
    add_open_standing_fan_hd,
    bake_scene_lightmap_uv2,
    export_room_glb,
    generate_fabric_weave_texture,
    generate_foliage_texture,
    generate_laptop_ui,
    generate_plaster_ao_texture,
    generate_rattan_textures,
    generate_sajadah_texture,
    generate_tile_textures,
    generate_turf_texture,
    generate_wall_art_padi,
    generate_wood_texture,
    generate_woven_rug_texture,
    make_pbr_material,
    polish_scene_textures_1024,
    save_rgba_png,
    spin_profile,
)

GODOT_DIR = os.path.dirname(SCRIPT_DIR)
TEX_DIR = os.path.join(GODOT_DIR, "assets", "textures")
UNPACKED_DIR = os.path.join(GODOT_DIR, "assets", "raw", "unpacked")
OUT_SMALL = os.path.join(GODOT_DIR, "assets", "models", "kamar_art_small.glb")
OUT_LARGE = os.path.join(GODOT_DIR, "assets", "models", "kamar_art_large.glb")


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
    """Strip KHR_materials_unlit/emission while preserving BSDF_PRINCIPLED + ImageTexture + Alpha CLIP trees."""
    if not mat:
        return
    if mat.use_nodes and mat.node_tree:
        bsdf_ex = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        has_tex = any(n.type == 'TEX_IMAGE' and n.image is not None for n in mat.node_tree.nodes)
        if bsdf_ex is not None and has_tex:
            mname = mat.name.lower()
            if "metal" not in mname and "glass" not in mname:
                bsdf_ex.inputs["Roughness"].default_value = max(0.58, float(bsdf_ex.inputs["Roughness"].default_value))
                bsdf_ex.inputs["Metallic"].default_value = 0.0
            if "Emission Strength" in bsdf_ex.inputs:
                bsdf_ex.inputs["Emission Strength"].default_value = 0.0
            return
    saved_img = None
    saved_col = None
    if mat.use_nodes and mat.node_tree:
        for n in mat.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image is not None:
                saved_img = n.image
                break
            if n.type == 'BSDF_PRINCIPLED':
                c = n.inputs["Base Color"].default_value
                if tuple(round(x, 3) for x in c[:3]) not in ((0.8, 0.8, 0.8), (1.0, 1.0, 1.0), (0.0, 0.0, 0.0)):
                    saved_col = tuple(c)
            elif n.type in ('EMISSION', 'BACKGROUND') and "Color" in n.inputs:
                c = n.inputs["Color"].default_value
                if tuple(round(x, 3) for x in c[:3]) not in ((0.8, 0.8, 0.8), (1.0, 1.0, 1.0), (0.0, 0.0, 0.0)):
                    saved_col = tuple(c)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (300, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (0, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    if saved_img is not None:
        tex_n = nt.nodes.new("ShaderNodeTexImage")
        tex_n.location = (-280, 0)
        tex_n.image = saved_img
        nt.links.new(tex_n.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.62
        bsdf.inputs["Metallic"].default_value = 0.0
        return

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
        color = saved_col if saved_col is not None else (0.72, 0.68, 0.62, 1.0)
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


def add_beveled_box(name, size, loc, mat, bevel=0.022, rot=(0.0, 0.0, 0.0), cuts=0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        b = obj.modifiers.new("Bevel", 'BEVEL')
        b.width = bevel
        b.segments = 2
        bpy.ops.object.modifier_apply(modifier="Bevel")
    if cuts > 0:
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.subdivide(number_cuts=cuts)
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.shade_smooth()
    obj.data.use_auto_smooth = True
    obj.data.auto_smooth_angle = math.radians(42)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.cube_project(cube_size=max(size) * 0.6)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.materials.append(mat)
    return obj


def bake_cycles_ao(samples=10, ao_min=0.48, ao_max=1.0):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = samples
    scene.cycles.bake_type = 'AO'
    scene.render.bake.target = 'VERTEX_COLORS'
    scene.render.bake.use_clear = True

    mesh_objs = [o for o in bpy.data.objects if o.type == 'MESH' and not o.hide_render]
    for obj in mesh_objs:
        mesh = obj.data
        if not mesh.color_attributes:
            col = mesh.color_attributes.new(name="Col", type='BYTE_COLOR', domain='CORNER')
        else:
            col = mesh.color_attributes.get("Col") or mesh.color_attributes[0]
            col.name = "Col"
        mesh.color_attributes.active_color = col
        idx = list(mesh.color_attributes).index(col)
        mesh.color_attributes.render_color_index = idx

        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        try:
            bpy.ops.object.bake(type='AO')
        except Exception as e:
            print(f"AO bake skipped for {obj.name}: {e}")
            continue

        for item in col.data:
            r = max(ao_min, min(ao_max, item.color[0]))
            g = max(ao_min, min(ao_max, item.color[1]))
            b = max(ao_min, min(ao_max, item.color[2]))
            item.color = (r, g, b, 1.0)


def add_open_standing_fan(x, y, dark_mat, teal_mat, metal_mat, scale=1.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.17 * scale, depth=0.045, location=(x, y, 0.022))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(dark_mat)
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.022 * scale, depth=0.95 * scale, location=(x, y, 0.50 * scale))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(dark_mat)

    hz = 1.02 * scale
    yaw = math.radians(-35)
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.18 * scale, minor_radius=0.014 * scale,
        major_segments=22, minor_segments=8,
        location=(x, y, hz), rotation=(math.radians(82), 0, yaw),
    )
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(metal_mat)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.05 * scale, location=(x, y, hz))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(dark_mat)

    for b in range(4):
        ang = b * math.pi * 0.5 + 0.35
        bx = x + math.cos(yaw) * math.cos(ang) * 0.09 * scale
        by = y + math.sin(yaw) * math.cos(ang) * 0.09 * scale
        bz = hz + math.sin(ang) * 0.09 * scale
        add_beveled_box(
            f"FanBlade_{b}",
            (0.12 * scale, 0.014, 0.05 * scale),
            (bx, by, bz),
            teal_mat,
            0.005,
            (math.radians(22), ang, yaw),
        )


def build_kamar_art_small():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    floor_alb, floor_nrm, floor_rgh = generate_tile_textures(TEX_DIR, "art_small_ceramic_v1", (0.76, 0.72, 0.64), "ceramic")
    arr = np.array(floor_alb.pixels[:], dtype=np.float32).reshape((floor_alb.size[1], floor_alb.size[0], 4))
    arr[..., :3] = arr[..., :3] * 0.45 + np.array([0.86, 0.81, 0.72], dtype=np.float32) * 0.55
    floor_alb = save_rgba_png("art_small_ceramic_soft_v19", arr, TEX_DIR)
    wall_alb, wall_nrm, wall_rgh = generate_plaster_ao_texture(TEX_DIR, "art_small_plaster_v1", (0.80, 0.77, 0.70))
    wood_alb, wood_nrm, wood_rgh = generate_wood_texture(TEX_DIR, "art_small_wood_v1", (0.38, 0.22, 0.12))
    grass_alb, grass_nrm, grass_rgh = generate_turf_texture(TEX_DIR, "art_small_grass_v1", (0.24, 0.46, 0.20))
    sheet_img = generate_fabric_weave_texture(TEX_DIR, "art_small_sheet_v1", (0.80, 0.78, 0.72))
    art_img = generate_wall_art_padi(TEX_DIR, "art_small_padi_v1")
    rug_img = generate_woven_rug_texture(TEX_DIR, "art_small_rug_v1")
    saj_img = generate_sajadah_texture(TEX_DIR, "art_small_sajadah_v1")

    mat_floor = make_pbr_material("SmallFloor", floor_alb, 0.56, floor_nrm, 0.50, (4.6, 4.4), floor_rgh)
    mat_wall = make_pbr_material("SmallWall", wall_alb, 0.90, wall_nrm, 0.45, (1.4, 1.4), wall_rgh)
    mat_wood = make_pbr_material("SmallWood", wood_alb, 0.66, wood_nrm, 0.45, (1.5, 1.5), wood_rgh)
    mat_grass = make_pbr_material("YardGrass", grass_alb, 0.92, grass_nrm, 0.55, (4.5, 4.5), grass_rgh)
    mat_patio = make_solid_mat("YardPatio", (0.62, 0.58, 0.52), 0.88)
    mat_cream = make_pbr_material("BedSheet", sheet_img, 0.88, None, 0.0, (2.0, 2.0))
    mat_art = make_pbr_material("SmallWallArt", art_img, 0.55)
    mat_rug = make_pbr_material("SmallRug", rug_img, 0.90)
    mat_sajadah = make_pbr_material("SmallSajadah", saj_img, 0.90)
    mat_teal = make_solid_mat("AccentTeal", (0.18, 0.52, 0.50), 0.76)
    mat_dark = make_solid_mat("DarkAlloy", (0.16, 0.18, 0.22), 0.42, 0.65)
    mat_metal = make_solid_mat("AlloyChrome", (0.72, 0.74, 0.78), 0.25, 0.85)
    mat_wicker = make_solid_mat("WickerTan", (0.76, 0.64, 0.46), 0.88)
    mat_glass = make_solid_mat("WindowGlass", (0.72, 0.86, 0.92), 0.08, 0.05, alpha=0.22)

    # 3.2m x 3.2m compact Tipe 45/90 back ART room
    add_beveled_box("OuterYard", (14.0, 14.0, 0.12), (0.0, 0.0, -0.24), mat_grass, 0.0)
    add_beveled_box("YardFenceBack", (10.0, 0.24, 1.45), (0.0, 4.2, 0.45), mat_wall, 0.02)
    add_beveled_box("YardFenceLeft", (0.24, 10.0, 1.45), (-4.2, 0.0, 0.45), mat_wall, 0.02)
    add_beveled_box("YardPatio", (4.2, 4.2, 0.10), (0.0, 0.0, -0.17), mat_patio, 0.02)

    # Subdivided floor & walls + skirting/molding (8 cuts for smooth Cycles AO)
    add_beveled_box("FloorSlab", (3.2, 3.2, 0.16), (0.0, 0.0, -0.08), mat_floor, 0.03, cuts=8)
    add_beveled_box("WallBack", (3.2, 0.14, 2.65), (0.0, 1.58, 1.325), mat_wall, 0.025, cuts=8)
    add_beveled_box("WallLeft", (0.14, 3.2, 2.65), (-1.58, 0.0, 1.325), mat_wall, 0.025, cuts=8)
    add_beveled_box("SmallSkirtBack", (3.16, 0.04, 0.10), (0.0, 1.49, 0.05), mat_wood, 0.008)
    add_beveled_box("SmallSkirtLeft", (0.04, 3.16, 0.10), (-1.49, 0.0, 0.05), mat_wood, 0.008)

    # Woven Rug & Emerald Sajadah prayer mat at (0.65, -0.95)
    add_beveled_box("SmallRug", (1.45, 1.15, 0.018), (0.20, -0.15, 0.010), mat_rug, 0.008)
    add_beveled_box("SmallSajadah", (0.66, 0.98, 0.014), (0.65, -0.95, 0.010), mat_sajadah, 0.005)

    # Tiny louvered high window (krepyak) on WallBack
    add_beveled_box("LouverFrame", (0.76, 0.08, 0.46), (0.55, 1.50, 2.08), mat_wood, 0.015)
    add_beveled_box("LouverGlass", (0.64, 0.02, 0.34), (0.55, 1.48, 2.08), mat_glass, 0.0)
    for lz in (1.96, 2.04, 2.12, 2.20):
        add_beveled_box(f"LouverSlat_{lz}", (0.64, 0.05, 0.02), (0.55, 1.46, lz), mat_wood, 0.004, (math.radians(28), 0, 0))

    # Curated CC0 Kenney Furniture: Single Bed, Small Desk, Chair, Lamp, Plant, Books, Trashcan (all centered!)
    import_kenney_glb("SmallBed", "bedSingle.glb", (-0.92, 0.52, 0.0), rot_z=0.0, scale=1.65, center_xy=True)
    import_kenney_glb("SmallDesk", "desk.glb", (0.62, 1.18, 0.0), rot_z=0.0, scale=1.55, center_xy=True)
    import_kenney_glb("SmallChair", "chairDesk.glb", (0.62, 0.62, 0.0), rot_z=math.pi, scale=1.55, center_xy=True)
    import_kenney_glb("SmallLamp", "lampRoundTable.glb", (0.25, 1.22, 0.595), rot_z=0.0, scale=1.40, center_xy=True)
    import_kenney_glb("SmallBooks", "books.glb", (0.95, 1.22, 0.595), rot_z=0.25, scale=1.45, center_xy=True)
    import_kenney_glb("SmallTrash", "trashcan.glb", (1.28, 1.12, 0.0), rot_z=0.0, scale=1.55, center_xy=True)

    add_beveled_box("SmallWallFrame", (0.58, 0.03, 0.44), (-0.88, 1.49, 1.48), mat_wood, 0.01)
    add_beveled_box("SmallWallArt", (0.48, 0.02, 0.34), (-0.88, 1.475, 1.48), mat_art, 0.004)
    add_beveled_box("SmallWallLeftArtFrame", (0.03, 0.56, 0.42), (-1.49, -0.10, 1.48), mat_wood, 0.01)
    add_beveled_box("SmallWallLeftArtCanvas", (0.02, 0.46, 0.32), (-1.47, -0.10, 1.48), mat_art, 0.004)

    # Compact standing fan (HD) & layered plant (clear of exit_room/pray_mat)
    mat_pot = make_solid_mat("SmallPot", (0.68, 0.30, 0.18), 0.72)
    mat_soil = make_solid_mat("SmallSoil", (0.16, 0.11, 0.08), 0.92)
    leaf_alb = generate_foliage_texture(TEX_DIR, "small_plant_hd", (0.14, 0.44, 0.16))
    mat_leaf = make_pbr_material("SmallLeaf", leaf_alb, 0.66)
    rattan_alb, rattan_nrm = generate_rattan_textures(TEX_DIR, "small_rattan_hd", size=512)
    mat_rattan = make_pbr_material("SmallRattan", rattan_alb, 0.78, rattan_nrm, 0.50, (2.0, 2.0))
    add_open_standing_fan_hd(-1.18, -0.45, mat_dark, mat_teal, mat_metal, scale=0.82)
    add_layered_broadleaf_plant(-1.25, -1.12, mat_pot, mat_soil, mat_leaf, prefix="SmallPlant", scale=0.72)

    # Spun rattan laundry basket + sapu ijuk broom
    basket_prof = [
        (0.001, 0.0), (0.135, 0.0), (0.145, 0.02), (0.185, 0.38),
        (0.200, 0.40), (0.200, 0.42), (0.180, 0.42), (0.172, 0.38),
        (0.130, 0.02), (0.001, 0.02),
    ]
    spin_profile("LaundryBasket", basket_prof, (1.10, 0.15, 0.0), mat_rattan, steps=24, uv_mode='SMART')
    add_beveled_box("LaundryCloth", (0.22, 0.20, 0.07), (1.10, 0.15, 0.40), mat_teal, 0.025)

    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.016, depth=1.12, location=(1.38, -0.45, 0.62), rotation=(math.radians(6), 0, 0))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(mat_wood)
    add_beveled_box("BroomHead", (0.05, 0.22, 0.14), (1.38, -0.52, 0.07), mat_dark, 0.01)

    bake_scene_lightmap_uv2(
        os.path.join(GODOT_DIR, "assets", "lightmaps", "kamar_art_small_lightmap.png"),
        size=1024, samples=14,
        exclude_substrings=("tree", "bush", "flower", "planter", "glass", "window", "smallplantblade_", "fanspoke_", "fanhubbadge", "fanbtn_"),
        lift_min=0.34, sun_energy=4.2, sun_rot_deg=(48.0, 0.0, 28.0), ambient_strength=0.32,
    )
    bake_cycles_ao(samples=6, ao_min=0.86, ao_max=1.0)
    polish_scene_textures_1024()
    export_room_glb(OUT_SMALL, quality=88)
    print("EXPORTED KAMAR ART SMALL:", OUT_SMALL, "bytes=", os.path.getsize(OUT_SMALL))


def build_kamar_art_large():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    floor_alb, floor_nrm, floor_rgh = generate_tile_textures(TEX_DIR, "art_large_ceramic_v1", (0.84, 0.76, 0.64), "ceramic")
    arr = np.array(floor_alb.pixels[:], dtype=np.float32).reshape((floor_alb.size[1], floor_alb.size[0], 4))
    arr[..., :3] = arr[..., :3] * 0.45 + np.array([0.86, 0.81, 0.72], dtype=np.float32) * 0.55
    floor_alb = save_rgba_png("art_large_ceramic_soft_v19", arr, TEX_DIR)
    wall_alb, wall_nrm, wall_rgh = generate_plaster_ao_texture(TEX_DIR, "art_large_plaster_v1", (0.86, 0.81, 0.72))
    wood_alb, wood_nrm, wood_rgh = generate_wood_texture(TEX_DIR, "art_large_teak_v1", (0.42, 0.24, 0.13))
    grass_alb, grass_nrm, grass_rgh = generate_turf_texture(TEX_DIR, "art_large_grass_v1", (0.24, 0.46, 0.20))
    art_img = generate_wall_art_padi(TEX_DIR, "art_large_padi_v1")
    laptop_img = generate_laptop_ui(TEX_DIR, "art_large_laptop_v1")
    rug_img = generate_woven_rug_texture(TEX_DIR, "art_large_rug_v1")
    sheet_img = generate_fabric_weave_texture(TEX_DIR, "art_large_sheet_v1", (0.86, 0.82, 0.74))
    curtain_img = generate_fabric_weave_texture(TEX_DIR, "art_large_curtain_v1", (0.33, 0.52, 0.42))
    saj_large_img = generate_sajadah_texture(TEX_DIR, "art_large_sajadah_v1")

    mat_floor = make_pbr_material("LargeFloor", floor_alb, 0.54, floor_nrm, 0.55, (4.6, 4.4), floor_rgh)
    mat_wall = make_pbr_material("LargeWall", wall_alb, 0.88, wall_nrm, 0.45, (1.6, 1.6), wall_rgh)
    mat_wood = make_pbr_material("LargeWood", wood_alb, 0.62, wood_nrm, 0.45, (1.5, 1.5), wood_rgh)
    mat_grass = make_pbr_material("YardGrass", grass_alb, 0.92, grass_nrm, 0.55, (5.0, 5.0), grass_rgh)
    mat_patio = make_solid_mat("YardPatio", (0.64, 0.60, 0.54), 0.88)
    mat_art = make_pbr_material("LargeWallArt", art_img, 0.55)
    mat_screen = make_pbr_material("LaptopScreen", laptop_img, 0.35)
    mat_rug = make_pbr_material("WovenRug", rug_img, 0.90)
    mat_sajadah = make_pbr_material("LargeSajadah", saj_large_img, 0.90)
    mat_cream = make_pbr_material("BedSheet", sheet_img, 0.88, None, 0.0, (2.0, 2.0))
    mat_curtain = make_pbr_material("SageCurtain", curtain_img, 0.88, None, 0.0, (1.5, 2.5))
    mat_gold_pill = make_solid_mat("EliteGoldPillow", (0.86, 0.68, 0.28), 0.78)

    mat_brass = make_solid_mat("BrassKnob", (0.78, 0.60, 0.26), 0.30, 0.85)
    mat_dark = make_solid_mat("DarkAlloy", (0.16, 0.18, 0.22), 0.42, 0.65)
    mat_glass = make_solid_mat("WindowGlass", (0.72, 0.86, 0.92), 0.08, 0.05, alpha=0.22)

    # 5.0m x 4.8m spacious Cluster Elite ART room
    add_beveled_box("OuterYard", (16.0, 16.0, 0.12), (0.0, 0.0, -0.24), mat_grass, 0.0)
    add_beveled_box("YardFenceBack", (12.0, 0.24, 1.45), (0.0, 5.2, 0.45), mat_wall, 0.02)
    add_beveled_box("YardFenceLeft", (0.24, 12.0, 1.45), (-5.2, 0.0, 0.45), mat_wall, 0.02)
    add_beveled_box("YardPatio", (6.0, 5.8, 0.10), (0.0, 0.0, -0.17), mat_patio, 0.02)

    # Outdoor garden trees cleanly behind WallBack window (no window clipping)
    import_kenney_glb("GardenTree1", "common-tree-1.glb", (0.15, 4.35, -0.18), rot_z=0.3, target_height=2.85, center_xy=True)
    import_kenney_glb("GardenTree2", "common-tree-2.glb", (1.45, 4.55, -0.18), rot_z=-0.5, target_height=2.55, center_xy=True)
    import_kenney_glb("GardenBush1", "bush-common-flowers.glb", (0.65, 3.65, -0.18), rot_z=0.1, target_height=0.75, center_xy=True)

    # Subdivided floor & walls (8 cuts for smooth Cycles AO)
    add_beveled_box("FloorSlab", (5.0, 4.8, 0.16), (0.0, 0.0, -0.08), mat_floor, 0.03, cuts=8)
    add_beveled_box("WallLeft", (0.14, 4.8, 2.80), (-2.48, 0.0, 1.40), mat_wall, 0.025, cuts=8)

    # WallBack with real window opening at x=[-0.17..1.07], z=[1.15..2.05]
    add_beveled_box("WallBack_Left", (2.33, 0.14, 2.80), (-1.335, 2.38, 1.40), mat_wall, 0.025, cuts=8)
    add_beveled_box("WallBack_Right", (1.43, 0.14, 2.80), (1.785, 2.38, 1.40), mat_wall, 0.025, cuts=6)
    add_beveled_box("WallBack_Bot", (1.24, 0.14, 1.15), (0.45, 2.38, 0.575), mat_wall, 0.02, cuts=4)
    add_beveled_box("WallBack_Top", (1.24, 0.14, 0.75), (0.45, 2.38, 2.425), mat_wall, 0.02, cuts=4)

    add_beveled_box("SkirtBack", (4.96, 0.06, 0.14), (0.0, 2.285, 0.07), mat_wood, 0.015)
    add_beveled_box("SkirtLeft", (0.06, 4.76, 0.14), (-2.385, 0.0, 0.07), mat_wood, 0.015)
    add_beveled_box("CrownBack", (4.96, 0.08, 0.08), (0.0, 2.29, 2.75), mat_wood, 0.015)
    add_beveled_box("CrownLeft", (0.08, 4.76, 0.08), (-2.39, 0.0, 2.75), mat_wood, 0.015)

    # Indoor AC Split Unit
    add_beveled_box("IndoorAC", (0.86, 0.22, 0.26), (0.45, 2.20, 2.44), mat_cream, 0.03)
    add_beveled_box("IndoorACVent", (0.76, 0.04, 0.04), (0.45, 2.09, 2.35), mat_dark, 0.008)

    # Large Curtained Window on WallBack (transparent glass + outdoor garden view)
    add_beveled_box("WinFrameTop", (1.42, 0.08, 0.07), (0.45, 2.32, 2.08), mat_wood, 0.015)
    add_beveled_box("WinFrameL", (0.07, 0.08, 0.98), (-0.21, 2.32, 1.60), mat_wood, 0.015)
    add_beveled_box("WinFrameR", (0.07, 0.08, 0.98), (1.11, 2.32, 1.60), mat_wood, 0.015)
    add_beveled_box("WinSill", (1.50, 0.16, 0.05), (0.45, 2.28, 1.12), mat_wood, 0.012)
    add_beveled_box("WinGlass", (1.24, 0.015, 0.90), (0.45, 2.34, 1.60), mat_glass, 0.0)
    add_beveled_box("CurtainRod", (1.84, 0.04, 0.04), (0.45, 2.21, 2.22), mat_wood, 0.01)
    for side_x in (-0.32, 1.22):
        for p in range(4):
            px = side_x + (p - 1.5) * 0.065
            py = 2.21 - (0.018 if p % 2 == 0 else 0.0)
            add_beveled_box(f"CurtainPleat_{side_x}_{p}", (0.068, 0.04, 1.28), (px, py, 1.58), mat_curtain, 0.015)

    # Framed Wall Art on WallLeft & WallBack_Left
    add_beveled_box("WallArtFrame", (0.05, 0.82, 0.66), (-2.385, -0.35, 1.58), mat_wood, 0.015)
    add_beveled_box("WallArtCanvas", (0.02, 0.64, 0.48), (-2.35, -0.35, 1.58), mat_art, 0.0)
    add_beveled_box("WallBackArtFrame", (0.78, 0.04, 0.58), (-1.35, 2.29, 1.62), mat_wood, 0.015)
    add_beveled_box("WallBackArtCanvas", (0.62, 0.02, 0.42), (-1.35, 2.26, 1.62), mat_art, 0.0)

    # Woven Rug & Emerald Sajadah prayer mat at (1.15, -0.95)
    add_beveled_box("CozyRug", (2.25, 1.65, 0.024), (0.35, -0.35, 0.014), mat_rug, 0.012)
    add_beveled_box("LargeSajadah", (0.74, 1.10, 0.016), (1.15, -0.95, 0.014), mat_sajadah, 0.006)

    # Curated CC0 Kenney Furniture: Double Bed + Dressed Duvet/Pillows, Desk, Chair, Lamp, Books, Trashcan
    bed_p = import_kenney_glb("LargeBed", "bedDouble.glb", (-1.35, 1.25, 0.0), rot_z=0.0, scale=1.85, center_xy=True)
    if bed_p:
        bpy.context.view_layer.update()
        from mathutils import Vector as _VecB
        b_pts = [o.matrix_world @ _VecB(c) for o in bed_p.children_recursive if o.type == 'MESH' for c in o.bound_box]
        if b_pts:
            bx0, bx1 = min(p.x for p in b_pts), max(p.x for p in b_pts)
            by0, by1 = min(p.y for p in b_pts), max(p.y for p in b_pts)
            bz1 = max(p.z for p in b_pts)
            bcx, bcy = (bx0 + bx1) * 0.5, (by0 + by1) * 0.5
            matt_z = bz1 * 0.62
            add_beveled_box("BedDuvet", ((bx1 - bx0) * 0.86, (by1 - by0) * 0.54, 0.09), (bcx, by0 + (by1 - by0) * 0.30, matt_z), mat_curtain, 0.03)
            add_beveled_box("BedPillowL", (0.38, 0.24, 0.09), (bcx - 0.24, by1 - 0.26, matt_z + 0.04), mat_cream, 0.03)
            add_beveled_box("BedPillowR", (0.38, 0.24, 0.09), (bcx + 0.24, by1 - 0.26, matt_z + 0.04), mat_cream, 0.03)
            add_beveled_box("BedThrowGold", (0.34, 0.14, 0.14), (bcx, by1 - 0.40, matt_z + 0.07), mat_gold_pill, 0.04, (math.radians(-18), 0.0, 0.0))
    desk_p = import_kenney_glb("LargeDesk", "desk.glb", (0.72, 1.88, 0.0), rot_z=0.0, scale=1.85, center_xy=True)
    desk_top = 0.72
    if desk_p:
        bpy.context.view_layer.update()
        from mathutils import Vector as _Vec
        d_pts = [o.matrix_world @ _Vec(c) for o in desk_p.children_recursive if o.type == 'MESH' for c in o.bound_box]
        if d_pts:
            desk_top = max(p.z for p in d_pts)
    import_kenney_glb("LargeChair", "chairDesk.glb", (0.72, 1.24, 0.0), rot_z=math.pi * 0.85, scale=1.85, center_xy=True)
    import_kenney_glb("LargeLamp", "lampRoundTable.glb", (1.25, 1.88, desk_top), rot_z=0.0, scale=1.65, center_xy=True)
    import_kenney_glb("LargeBooks", "books.glb", (0.28, 1.88, desk_top), rot_z=0.25, scale=1.55, center_xy=True)
    import_kenney_glb("LargeTrash", "trashcan.glb", (-1.58, -1.92, 0.0), rot_z=0.0, scale=1.65, center_xy=True)

    # Laptop on Desk
    add_beveled_box("LaptopBase", (0.36, 0.25, 0.02), (0.78, 1.86, desk_top + 0.01), mat_dark, 0.008)
    add_beveled_box("LaptopScreen", (0.32, 0.01, 0.20), (0.78, 1.97, desk_top + 0.12), mat_screen, 0.0, (math.radians(-15), 0, 0))

    # Full Wardrobe + Vanity Mirror + HD Fan & Layered Plant
    mat_pot = make_solid_mat("LargePot", (0.68, 0.30, 0.18), 0.72)
    mat_soil = make_solid_mat("LargeSoil", (0.16, 0.11, 0.08), 0.92)
    leaf_alb = generate_foliage_texture(TEX_DIR, "large_plant_hd", (0.14, 0.44, 0.16))
    mat_leaf = make_pbr_material("LargeLeaf", leaf_alb, 0.66)
    mat_metal = make_solid_mat("LargeMetal", (0.74, 0.76, 0.80), 0.25, 0.85)
    mat_teal = make_solid_mat("LargeTeal", (0.18, 0.52, 0.50), 0.72)
    add_open_standing_fan_hd(2.05, 1.35, mat_dark, mat_teal, mat_metal, scale=1.0)
    add_layered_broadleaf_plant(-2.05, -2.05, mat_pot, mat_soil, mat_leaf, prefix="LargePlant", scale=0.95)

    add_beveled_box("WardrobeBody", (0.56, 0.86, 1.94), (-2.02, -1.45, 0.97), mat_wood, 0.025)
    add_beveled_box("WardHandleL", (0.04, 0.025, 0.14), (-1.72, -1.40, 0.98), mat_brass, 0.005)
    add_beveled_box("WardHandleR", (0.04, 0.025, 0.14), (-1.72, -1.50, 0.98), mat_brass, 0.005)
    add_beveled_box("VanityMirrorFrame", (0.50, 0.04, 0.96), (1.85, 2.28, 1.38), mat_wood, 0.015)
    add_beveled_box("VanityMirrorGlass", (0.40, 0.02, 0.84), (1.85, 2.25, 1.38), mat_glass, 0.004)

    bake_scene_lightmap_uv2(
        os.path.join(GODOT_DIR, "assets", "lightmaps", "kamar_art_large_lightmap.png"),
        size=1024, samples=14,
        exclude_substrings=("tree", "bush", "flower", "planter", "glass", "window", "largeplantblade_", "fanspoke_", "fanhubbadge", "fanbtn_"),
        lift_min=0.34, sun_energy=4.2, sun_rot_deg=(48.0, 0.0, 28.0), ambient_strength=0.32,
    )
    bake_cycles_ao(samples=6, ao_min=0.86, ao_max=1.0)
    polish_scene_textures_1024()
    export_room_glb(OUT_LARGE, quality=88)
    print("EXPORTED KAMAR ART LARGE:", OUT_LARGE, "bytes=", os.path.getsize(OUT_LARGE))


if __name__ == "__main__":
    build_kamar_art_small()
    build_kamar_art_large()
