import os
import sys
import math
import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from tex_utils import (
    add_layered_broadleaf_plant,
    add_open_standing_fan_hd,
    bake_scene_lightmap_uv2,
    ensure_uv0,
    export_room_glb,
    generate_fabric_weave_texture,
    generate_foliage_texture,
    generate_plaster_ao_texture,
    generate_rattan_textures,
    generate_tile_textures,
    generate_turf_texture,
    generate_wall_art_padi,
    generate_woven_rug_texture,
    generate_wood_texture,
    make_pbr_material,
    polish_scene_textures_1024,
    spin_profile,
)

GODOT_DIR = os.path.dirname(SCRIPT_DIR)
TEX_DIR = os.path.join(GODOT_DIR, "assets", "textures")
UNPACKED_DIR = os.path.join(GODOT_DIR, "assets", "raw", "unpacked")
OUT_GLB = os.path.join(GODOT_DIR, "assets", "models", "kos_neighbor_room.glb")


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
    if not mat:
        return
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    mname = mat.name.lower()
    if "wooddark" in mname:
        color, roughness, metallic = (0.24, 0.14, 0.08, 1.0), 0.62, 0.0
    elif "wood" in mname:
        color, roughness, metallic = (0.44, 0.26, 0.14, 1.0), 0.62, 0.0
    elif "metaldark" in mname:
        color, roughness, metallic = (0.16, 0.17, 0.19, 1.0), 0.45, 0.65
    elif "metal" in mname:
        color, roughness, metallic = (0.74, 0.76, 0.79, 1.0), 0.35, 0.85
    elif "carpet" in mname:
        color, roughness, metallic = (0.22, 0.56, 0.44, 1.0), 0.88, 0.0
    elif "leaf" in mname or "foliage" in mname or "plant" in mname:
        color, roughness, metallic = (0.20, 0.48, 0.20, 1.0), 0.72, 0.0
    else:
        color, roughness, metallic = (0.76, 0.72, 0.66, 1.0), 0.65, 0.0
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic


def import_kenney_glb(name, filename, loc, rot_z=0.0, target_height=None):
    glb_path = os.path.join(UNPACKED_DIR, filename)
    if not os.path.exists(glb_path):
        return None
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    added = [o for o in bpy.data.objects if o not in before]
    for o in added:
        if o.type == 'MESH' and o.data:
            for m in o.data.materials:
                rebuild_kenney_pbr_material(m)

    parent = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(parent)
    for o in added:
        if o.parent is None:
            o.parent = parent

    bpy.context.view_layer.update()
    from mathutils import Vector
    min_x = min_y = min_z = 1e9
    max_x = max_y = max_z = -1e9
    for o in added:
        if o.type != 'MESH':
            continue
        mw = o.matrix_world
        for v in o.bound_box:
            wv = mw @ Vector(v)
            min_x, max_x = min(min_x, wv.x), max(max_x, wv.x)
            min_y, max_y = min(min_y, wv.y), max(max_y, wv.y)
            min_z, max_z = min(min_z, wv.z), max(max_z, wv.z)
    cx, cy = (min_x + max_x) * 0.5, (min_y + max_y) * 0.5
    for o in added:
        if o.parent == parent:
            o.location.x -= cx
            o.location.y -= cy
    cur_h = max(0.001, max_z - min_z)
    s = (target_height / cur_h) if target_height is not None else 1.0
    parent.scale = (s, s, s)
    parent.rotation_euler = (0.0, 0.0, rot_z)
    parent.location = (loc[0], loc[1], loc[2] - min_z * s)
    bpy.context.view_layer.update()
    return parent


def add_box(name, size, loc, mat, bevel=0.018, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        b = obj.modifiers.new("Bevel", 'BEVEL')
        b.width = bevel
        b.segments = 1
        bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_smooth()
    obj.data.use_auto_smooth = True
    obj.data.auto_smooth_angle = math.radians(42)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.cube_project(cube_size=max(size) * 0.6)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.materials.append(mat)
    return obj


def build_neighbor_room():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    floor_alb, floor_nrm, floor_rgh = generate_tile_textures(TEX_DIR, "nb_ceramic_v2", (0.66, 0.61, 0.55), "ceramic")
    wall_alb, wall_nrm, wall_rgh = generate_plaster_ao_texture(TEX_DIR, "nb_sage_plaster_v2", (0.48, 0.64, 0.52))
    wood_alb, wood_nrm, wood_rgh = generate_wood_texture(TEX_DIR, "nb_teak_v1", (0.48, 0.30, 0.16))
    grass_alb, grass_nrm, grass_rgh = generate_turf_texture(TEX_DIR, "nb_grass_v1", (0.24, 0.46, 0.20))
    art_img = generate_wall_art_padi(TEX_DIR, "nb_wall_art_v1")
    rug_img = generate_woven_rug_texture(TEX_DIR, "nb_rug_v1")
    sheet_img = generate_fabric_weave_texture(TEX_DIR, "nb_sheet_v1", (0.90, 0.88, 0.82))
    blanket_img = generate_fabric_weave_texture(TEX_DIR, "nb_blanket_v1", (0.20, 0.50, 0.44))
    curtain_img = generate_fabric_weave_texture(TEX_DIR, "nb_curtain_v1", (0.80, 0.42, 0.26))

    mat_floor = make_pbr_material("NbFloor", floor_alb, 0.56, floor_nrm, 0.45, (4.4, 4.4), floor_rgh)
    mat_wall = make_pbr_material("NbWall", wall_alb, 0.88, wall_nrm, 0.40, (1.6, 1.6), wall_rgh)
    mat_wood = make_pbr_material("NbWood", wood_alb, 0.62, wood_nrm, 0.40, (1.5, 1.5), wood_rgh)
    mat_grass = make_pbr_material("NbGrass", grass_alb, 0.92, grass_nrm, 0.45, (5.0, 5.0), grass_rgh)
    mat_patio = make_solid_mat("NbPatio", (0.56, 0.52, 0.46), 0.88)
    mat_art = make_pbr_material("NbWallArt", art_img, 0.55)
    mat_rug = make_pbr_material("NbRug", rug_img, 0.90)
    mat_sheet = make_pbr_material("NbSheet", sheet_img, 0.88)
    mat_blanket = make_pbr_material("NbBlanket", blanket_img, 0.85)
    mat_curtain = make_pbr_material("NbCurtain", curtain_img, 0.88)
    mat_cream = make_solid_mat("NbCream", (0.76, 0.74, 0.68), 0.84)
    mat_terracotta = make_solid_mat("NbTerracotta", (0.74, 0.34, 0.20), 0.74)
    mat_brass = make_solid_mat("NbBrass", (0.80, 0.62, 0.28), 0.32, 0.85)
    mat_sky = make_solid_mat("NbSky", (0.38, 0.66, 0.84), 0.28, 0.0, 0.08)
    mat_dark = make_solid_mat("NbDark", (0.18, 0.20, 0.22), 0.50)

    # Outer yard & clean room shell
    add_box("NbOuterYard", (16.0, 16.0, 0.12), (0.0, 0.0, -0.24), mat_grass, 0.0)
    add_box("NbYardPatio", (5.8, 5.8, 0.10), (0.0, 0.0, -0.17), mat_patio, 0.02)
    add_box("NbFloor", (4.8, 4.8, 0.16), (0.0, 0.0, -0.08), mat_floor, 0.02)
    add_box("NbWallBack", (4.8, 0.14, 2.75), (0.0, 2.38, 1.375), mat_wall, 0.02)
    add_box("NbWallLeft", (0.14, 4.8, 2.75), (-2.38, 0.0, 1.375), mat_wall, 0.02)
    add_box("NbSkirtBack", (4.76, 0.06, 0.14), (0.0, 2.285, 0.07), mat_wood, 0.01)
    add_box("NbSkirtLeft", (0.06, 4.76, 0.14), (-2.285, 0.0, 0.07), mat_wood, 0.01)
    add_box("NbWainscotBack", (4.74, 0.03, 0.85), (0.0, 2.295, 0.43), mat_cream, 0.01)
    add_box("NbWainscotLeft", (0.03, 4.74, 0.85), (-2.295, 0.0, 0.43), mat_cream, 0.01)

    # Window on WallBack (shifted left: x = -0.35) + Terracotta Curtains!
    add_box("NbWinFrame", (1.35, 0.08, 1.05), (-0.35, 2.28, 1.58), mat_wood, 0.015)
    add_box("NbWinSky", (1.16, 0.04, 0.86), (-0.35, 2.245, 1.58), mat_sky, 0.0)
    add_box("NbWinBarV", (0.04, 0.05, 0.86), (-0.35, 2.215, 1.58), mat_wood, 0.006)
    add_box("NbCurtainRod", (1.76, 0.04, 0.04), (-0.35, 2.21, 2.18), mat_wood, 0.008)
    for sx in (-1.08, 0.38):
        add_box(f"NbCurtain_{sx}", (0.24, 0.05, 1.24), (sx, 2.21, 1.56), mat_curtain, 0.012)

    # Left wall framed art + mirror + shelf
    add_box("NbArtFrame", (0.05, 0.82, 0.66), (-2.285, 0.20, 1.58), mat_wood, 0.012)
    add_box("NbArtCanvas", (0.02, 0.64, 0.48), (-2.25, 0.20, 1.58), mat_art, 0.0)

    # Mirrored Layout vs kos_room.glb!
    # 1. BedSingle on RIGHT back corner (Blender 1.55, 1.25 -> Godot +1.55, -1.25)
    import_kenney_glb("NbBed", "bedSingle.glb", (1.55, 1.25, 0.0), rot_z=0.0, target_height=0.72)
    add_box("NbBlanketAcc", (0.98, 0.82, 0.06), (1.55, 0.90, 0.42), mat_blanket, 0.02)
    add_box("NbNightstand", (0.48, 0.46, 0.52), (0.60, 2.02, 0.26), mat_wood, 0.015)
    import_kenney_glb("NbLamp", "lampRoundTable.glb", (0.60, 2.02, 0.52), rot_z=0.0, target_height=0.34)

    # 2. Desk & Wardrobe on LEFT back wall
    import_kenney_glb("NbDesk", "desk.glb", (-0.82, 1.88, 0.0), rot_z=0.0, target_height=0.76)
    import_kenney_glb("NbChair", "chairDesk.glb", (-0.82, 1.26, 0.0), rot_z=math.pi, target_height=0.88)
    add_box("NbWardrobe", (0.84, 0.56, 1.88), (-1.85, 1.88, 0.94), mat_wood, 0.02)
    add_box("NbWardHandle", (0.04, 0.04, 0.16), (-1.75, 1.59, 0.96), mat_brass, 0.004)

    # 3. Cozy Woven Rug center-left (-0.35, -0.35 -> Godot -0.35, +0.35) + Low Tea Table
    add_box("NbRug", (2.05, 1.50, 0.024), (-0.35, -0.35, 0.014), mat_rug, 0.01)
    add_box("NbPouf", (0.46, 0.46, 0.26), (-1.15, -0.65, 0.13), mat_terracotta, 0.04)

    # 4. Sculpted Layered Plant + Rattan Laundry Hamper + HD Standing Fan
    mat_pot = make_solid_mat("NbPot", (0.68, 0.30, 0.18), 0.72)
    mat_soil = make_solid_mat("NbSoil", (0.16, 0.11, 0.08), 0.92)
    leaf_alb = generate_foliage_texture(TEX_DIR, "nb_plant_hd", (0.14, 0.44, 0.16))
    mat_leaf = make_pbr_material("NbPlantLeaf", leaf_alb, 0.66)
    rattan_alb, rattan_nrm = generate_rattan_textures(TEX_DIR, "nb_rattan_hd", size=512)
    mat_rattan = make_pbr_material("NbRattan", rattan_alb, 0.78, rattan_nrm, 0.50, (2.0, 2.0))
    mat_metal = make_solid_mat("NbMetal", (0.74, 0.76, 0.80), 0.25, 0.85)
    mat_teal = make_solid_mat("NbTeal", (0.18, 0.52, 0.50), 0.72)

    add_layered_broadleaf_plant(1.72, -1.05, mat_pot, mat_soil, mat_leaf, prefix="NbPlant", scale=0.95)
    basket_prof = [
        (0.001, 0.0), (0.145, 0.0), (0.155, 0.02), (0.205, 0.40),
        (0.220, 0.42), (0.220, 0.44), (0.200, 0.44), (0.190, 0.40),
        (0.140, 0.02), (0.001, 0.02),
    ]
    spin_profile("NbLaundryBin", basket_prof, (-1.75, -1.05, 0.0), mat_rattan, steps=24, uv_mode='SMART')
    add_open_standing_fan_hd(-1.82, 0.78, mat_dark, mat_teal, mat_metal, scale=0.92)
    add_box("NbCrownBack", (4.76, 0.08, 0.08), (0.0, 2.29, 2.70), mat_wood, 0.01)
    add_box("NbCrownLeft", (0.08, 4.76, 0.08), (-2.29, 0.0, 2.70), mat_wood, 0.01)
    add_box("NbDadoBack", (4.74, 0.04, 0.04), (0.0, 2.29, 0.85), mat_wood, 0.006)
    add_box("NbDadoLeft", (0.04, 4.74, 0.04), (-2.29, 0.0, 0.85), mat_wood, 0.006)

    # 5. Sapu broom leaning near desk
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.018, depth=1.16, location=(-1.38, 1.86, 0.62), rotation=(0, math.radians(8), 0))
    bpy.context.active_object.data.materials.append(mat_wood)
    add_box("NbBroomHead", (0.24, 0.05, 0.16), (-1.30, 1.86, 0.08), mat_dark, 0.008)

    bake_scene_lightmap_uv2(
        os.path.join(GODOT_DIR, "assets", "lightmaps", "kos_neighbor_room_lightmap.png"),
        size=1024, samples=14,
        exclude_substrings=("tree", "bush", "flower", "planter", "glass", "window", "nbplantblade_", "fanspoke_", "fanhubbadge", "fanbtn_"),
        lift_min=0.34, sun_energy=4.2, sun_rot_deg=(48.0, 0.0, 28.0), ambient_strength=0.32,
    )
    polish_scene_textures_1024()

    total_verts = sum(len(o.data.vertices) for o in bpy.data.objects if o.type == 'MESH' and o.data)
    export_room_glb(OUT_GLB, quality=88)
    print(f"EXPORTED KOS NEIGHBOR ROOM: {OUT_GLB} verts={total_verts} bytes={os.path.getsize(OUT_GLB)}")


if __name__ == "__main__":
    build_neighbor_room()
