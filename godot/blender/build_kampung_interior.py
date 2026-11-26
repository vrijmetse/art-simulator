import os
import sys
import math
import bpy
import numpy as np
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from tex_utils import (
    generate_fabric_weave_texture,
    generate_plaster_ao_texture,
    generate_tile_textures,
    generate_turf_texture,
    generate_wall_art_padi,
    generate_wood_texture,
    generate_woven_rug_texture,
    make_pbr_material,
    save_rgba_png,
)

GODOT_DIR = os.path.dirname(SCRIPT_DIR)
TEX_DIR = os.path.join(GODOT_DIR, "assets", "textures")
UNPACKED_DIR = os.path.join(GODOT_DIR, "assets", "raw", "unpacked")
OUT_GLB = os.path.join(GODOT_DIR, "assets", "models", "room_kampung_house.glb")


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


def import_kenney_glb(prefix, filename, loc, rot_z=0.0, scale=1.85, target_height=None, center_xy=True):
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
    for o in imported:
        if o.parent is None:
            o.parent = parent

    bpy.context.view_layer.update()

    min_x = min_y = min_z = float("inf")
    max_x = max_y = max_z = float("-inf")
    for o in meshes:
        for v in o.bound_box:
            wv = o.matrix_world @ Vector(v)
            min_x = min(min_x, wv.x)
            max_x = max(max_x, wv.x)
            min_y = min(min_y, wv.y)
            max_y = max(max_y, wv.y)
            min_z = min(min_z, wv.z)
            max_z = max(max_z, wv.z)

    cur_h = max(0.001, max_z - min_z)
    s = (target_height / cur_h) if target_height is not None else scale

    cx = (min_x + max_x) * 0.5 if center_xy else 0.0
    cy = (min_y + max_y) * 0.5 if center_xy else 0.0
    cos_r, sin_r = math.cos(rot_z), math.sin(rot_z)
    ox = (cx * cos_r - cy * sin_r) * s
    oy = (cx * sin_r + cy * cos_r) * s

    parent.scale = (s, s, s)
    parent.rotation_euler = (0.0, 0.0, rot_z)
    parent.location = (loc[0] - ox, loc[1] - oy, loc[2] - min_z * s)
    bpy.context.view_layer.update()
    return parent


def add_beveled_box(name, size, loc, mat, bevel=0.020, rot=(0.0, 0.0, 0.0), cuts=0):
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


def bake_cycles_ao(samples=8, ao_min=0.48, ao_max=1.0):
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


def build_kampung_house():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    floor_alb, floor_nrm, floor_rgh = generate_tile_textures(TEX_DIR, "kampung_ceramic_v1", (0.78, 0.62, 0.48), "ceramic")
    arr = np.array(floor_alb.pixels[:], dtype=np.float32).reshape((floor_alb.size[1], floor_alb.size[0], 4))
    arr[..., :3] = arr[..., :3] * 0.45 + np.array([0.80, 0.65, 0.50], dtype=np.float32) * 0.55
    floor_alb = save_rgba_png("kampung_ceramic_soft_v19", arr, TEX_DIR)

    wall_alb, wall_nrm, wall_rgh = generate_plaster_ao_texture(TEX_DIR, "kampung_mint_plaster_v1", (0.76, 0.86, 0.78))
    dado_alb, dado_nrm, dado_rgh = generate_plaster_ao_texture(TEX_DIR, "kampung_terracotta_v1", (0.78, 0.48, 0.34))
    wood_alb, wood_nrm, wood_rgh = generate_wood_texture(TEX_DIR, "kampung_teak_v1", (0.40, 0.23, 0.12))
    grass_alb, grass_nrm, grass_rgh = generate_turf_texture(TEX_DIR, "kampung_grass_v1", (0.24, 0.48, 0.20))
    tikar_img = generate_woven_rug_texture(TEX_DIR, "kampung_tikar_v1")
    art_img = generate_wall_art_padi(TEX_DIR, "kampung_art_padi_v1")
    cream_img = generate_fabric_weave_texture(TEX_DIR, "kampung_cream_v1", (0.88, 0.84, 0.76))

    mat_floor = make_pbr_material("KampungFloor", floor_alb, 0.50, floor_nrm, 0.50, (4.2, 3.6), floor_rgh)
    mat_wall = make_pbr_material("KampungWallMint", wall_alb, 0.88, wall_nrm, 0.45, (1.8, 1.5), wall_rgh)
    mat_dado = make_pbr_material("KampungDadoTerra", dado_alb, 0.85, dado_nrm, 0.40, (1.8, 1.0), dado_rgh)
    mat_wood = make_pbr_material("KampungWood", wood_alb, 0.62, wood_nrm, 0.45, (1.5, 1.5), wood_rgh)
    mat_grass = make_pbr_material("YardGrass", grass_alb, 0.92, grass_nrm, 0.55, (5.0, 5.0), grass_rgh)
    mat_tikar = make_pbr_material("PandanTikar", tikar_img, 0.88)
    mat_art = make_pbr_material("KampungWallArt", art_img, 0.55)
    mat_cream = make_pbr_material("CreamFabric", cream_img, 0.88, None, 0.0, (2.0, 2.0))

    mat_patio = make_solid_mat("YardPatio", (0.60, 0.56, 0.50), 0.88)
    mat_dark = make_solid_mat("DarkAlloy", (0.14, 0.16, 0.20), 0.38, 0.65)
    mat_metal = make_solid_mat("AlloyChrome", (0.76, 0.78, 0.82), 0.22, 0.88)
    mat_lpg_green = make_solid_mat("LPGMelonGreen", (0.24, 0.62, 0.28), 0.45, 0.20)
    mat_banana = make_solid_mat("BananaLeaf", (0.22, 0.52, 0.18), 0.72)
    mat_coral = make_solid_mat("AccentCoral", (0.76, 0.34, 0.24), 0.72)
    mat_teal = make_solid_mat("AccentTeal", (0.18, 0.52, 0.50), 0.70)
    mat_ceramic_w = make_solid_mat("CeramicWhite", (0.92, 0.91, 0.88), 0.30)
    mat_aqua_blue = make_solid_mat("AquaGalonBlue", (0.18, 0.52, 0.86), 0.20, 0.05)
    mat_glass = make_solid_mat("WindowGlass", (0.72, 0.86, 0.92), 0.08, 0.05, alpha=0.20)

    # Diorama base: 5.0m x 4.4m modest kampung house + sunny backyard greenery
    add_beveled_box("OuterYard", (15.0, 15.0, 0.12), (0.0, 0.0, -0.24), mat_grass, 0.0)
    add_beveled_box("YardPatio", (5.8, 5.2, 0.10), (0.0, 0.0, -0.17), mat_patio, 0.02)

    # Outdoor banana & garden greenery visible through krepyak window
    import_kenney_glb("GardenTree1", "common-tree-1.glb", (0.95, 3.35, -0.18), rot_z=0.3, target_height=2.45)
    import_kenney_glb("GardenBush1", "bush-common-flowers.glb", (1.65, 2.95, -0.18), rot_z=0.5, target_height=0.72)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.055, depth=1.15, location=(1.85, 3.10, 0.40))
    bpy.context.active_object.data.materials.append(mat_banana)
    for fi in range(6):
        ang = fi * (math.pi * 2.0 / 6.0)
        add_beveled_box(
            f"BananaFrond_{fi}",
            (0.65, 0.20, 0.022),
            (1.85 + math.cos(ang) * 0.30, 3.10 + math.sin(ang) * 0.30, 1.05),
            mat_banana,
            0.006,
            (0.0, math.radians(22), ang),
        )

    # Room shell: 5.0m x 4.4m (x=[-2.5..2.5], y=[-2.2..2.2])
    add_beveled_box("FloorSlab", (5.0, 4.4, 0.16), (0.0, 0.0, -0.08), mat_floor, 0.025, cuts=6)
    add_beveled_box("WallLeft", (0.14, 4.4, 2.65), (-2.43, 0.0, 1.325), mat_wall, 0.02, cuts=6)

    # WallBack with krepyak window opening at x=[0.65..1.85], z=[1.15..2.05]
    add_beveled_box("WallBack_Left", (3.15, 0.14, 2.65), (-0.925, 2.13, 1.325), mat_wall, 0.02, cuts=6)
    add_beveled_box("WallBack_Right", (0.65, 0.14, 2.65), (2.175, 2.13, 1.325), mat_wall, 0.02, cuts=4)
    add_beveled_box("WallBack_Bot", (1.20, 0.14, 1.15), (1.25, 2.13, 0.575), mat_wall, 0.015, cuts=4)
    add_beveled_box("WallBack_Top", (1.20, 0.14, 0.60), (1.25, 2.13, 2.35), mat_wall, 0.015, cuts=4)

    # Warm terracotta dado + wooden skirting & crown
    add_beveled_box("DadoBack_Left", (3.13, 0.03, 0.85), (-0.925, 2.05, 0.425), mat_dado, 0.008)
    add_beveled_box("DadoBack_Mid", (1.20, 0.03, 0.85), (1.25, 2.05, 0.425), mat_dado, 0.008)
    add_beveled_box("DadoBack_Right", (0.63, 0.03, 0.85), (2.175, 2.05, 0.425), mat_dado, 0.008)
    add_beveled_box("DadoLeft", (0.03, 4.36, 0.85), (-2.35, 0.0, 0.425), mat_dado, 0.008)
    add_beveled_box("SkirtBack", (4.96, 0.05, 0.12), (0.0, 2.04, 0.06), mat_wood, 0.01)
    add_beveled_box("SkirtLeft", (0.05, 4.36, 0.12), (-2.34, 0.0, 0.06), mat_wood, 0.01)
    add_beveled_box("CrownBack", (4.96, 0.07, 0.07), (0.0, 2.04, 2.61), mat_wood, 0.01)
    add_beveled_box("CrownLeft", (0.07, 4.36, 0.07), (-2.34, 0.0, 2.61), mat_wood, 0.01)

    # Wooden Krepyak Window (frame + glass + slatted louver shutters)
    add_beveled_box("WinFrameTop", (1.34, 0.08, 0.06), (1.25, 2.08, 2.08), mat_wood, 0.01)
    add_beveled_box("WinFrameL", (0.06, 0.08, 0.96), (0.62, 2.08, 1.60), mat_wood, 0.01)
    add_beveled_box("WinFrameR", (0.06, 0.08, 0.96), (1.88, 2.08, 1.60), mat_wood, 0.01)
    add_beveled_box("WinSill", (1.42, 0.14, 0.05), (1.25, 2.05, 1.13), mat_wood, 0.01)
    add_beveled_box("WinGlass", (1.20, 0.015, 0.90), (1.25, 2.10, 1.60), mat_glass, 0.0)
    for sx in (0.42, 2.08):
        add_beveled_box(f"KrepyakFrame_{sx}", (0.34, 0.04, 0.92), (sx, 2.02, 1.60), mat_wood, 0.008)
        for li in range(7):
            lz = 1.24 + li * 0.11
            add_beveled_box(f"KrepyakSlat_{sx}_{li}", (0.28, 0.05, 0.022), (sx, 2.00, lz), mat_wood, 0.004, (math.radians(28), 0, 0))

    # Wall art & round clock
    add_beveled_box("WallArtFrame", (0.76, 0.04, 0.56), (-1.25, 2.04, 1.55), mat_wood, 0.012)
    add_beveled_box("WallArtCanvas", (0.62, 0.02, 0.42), (-1.25, 2.01, 1.55), mat_art, 0.0)

    # Woven pandan mat (tikar) in living zone
    add_beveled_box("LivingTikar", (2.10, 1.55, 0.018), (-1.15, 0.45, 0.010), mat_tikar, 0.008)

    # Curated CC0 Kenney Furniture: Living & Dining
    import_kenney_glb("Sofa", "loungeSofa.glb", (-1.15, 1.52, 0.0), rot_z=0.0, scale=1.65)
    import_kenney_glb("DiningTable", "tableRound.glb", (-1.15, 0.18, 0.0), rot_z=0.0, scale=1.55)
    import_kenney_glb("DiningChair1", "chair.glb", (-1.82, 0.18, 0.0), rot_z=math.pi * 0.5, scale=1.65)
    import_kenney_glb("DiningChair2", "chair.glb", (-0.48, 0.18, 0.0), rot_z=-math.pi * 0.5, scale=1.65)
    import_kenney_glb("LivingPlant", "pottedPlant.glb", (-2.12, 1.68, 0.0), rot_z=0.2, scale=1.55)

    # Curated CC0 Kenney Furniture: Compact Kitchenette
    import_kenney_glb("KitchenSink", "kitchenSink.glb", (0.72, 1.76, 0.0), rot_z=0.0, target_height=0.88)
    import_kenney_glb("KitchenStove", "kitchenStove.glb", (1.52, 1.76, 0.0), rot_z=0.0, target_height=0.88)
    import_kenney_glb("TrashCan", "trashcan.glb", (2.15, 1.25, 0.0), rot_z=0.0, scale=1.65)

    # Green 3kg LPG Canister (Tabung Gas Melon) beside stove
    bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=12, radius=0.155, location=(2.15, 1.78, 0.19))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(mat_lpg_green)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.105, depth=0.08, location=(2.15, 1.78, 0.35))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(mat_lpg_green)

    # Indonesian Water Dispenser + Blue Aqua Galon Jug
    add_beveled_box("DispenserBody", (0.32, 0.32, 0.88), (2.12, -0.45, 0.44), mat_ceramic_w, 0.018)
    add_beveled_box("DispenserTapHot", (0.03, 0.03, 0.05), (1.94, -0.39, 0.70), mat_coral, 0.005)
    add_beveled_box("DispenserTapCold", (0.03, 0.03, 0.05), (1.94, -0.51, 0.70), mat_teal, 0.005)
    bpy.ops.mesh.primitive_cylinder_add(vertices=18, radius=0.13, depth=0.33, location=(2.12, -0.45, 1.05))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(mat_aqua_blue)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.048, depth=0.08, location=(2.12, -0.45, 1.24))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(mat_aqua_blue)

    bake_cycles_ao(samples=8, ao_min=0.48, ao_max=1.0)

    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB,
        export_format='GLB',
        export_apply=False,
        export_image_format='JPEG',
        export_jpeg_quality=75,
    )
    print("EXPORTED KAMPUNG HOUSE:", OUT_GLB, "bytes=", os.path.getsize(OUT_GLB))


if __name__ == "__main__":
    build_kampung_house()
