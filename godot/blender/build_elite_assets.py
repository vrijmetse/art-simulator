import os
import sys
import math
import bpy
import numpy as np
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from tex_utils import (
    generate_asphalt_textures,
    generate_batu_alam_texture,
    generate_fabric_weave_texture,
    generate_plaster_ao_texture,
    generate_sidewalk_concrete_texture,
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
OUT_ELITE_LIVING = os.path.join(GODOT_DIR, "assets", "models", "room_elite_living.glb")
OUT_ELITE_STREET = os.path.join(GODOT_DIR, "assets", "models", "cluster_elite_street.glb")


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
        roughness = 0.60
        metallic = 0.0
    elif "wood" in mname:
        color = (0.44, 0.26, 0.14, 1.0)
        roughness = 0.58
        metallic = 0.0
    elif "metaldark" in mname:
        color = (0.16, 0.17, 0.19, 1.0)
        roughness = 0.42
        metallic = 0.70
    elif "metallight" in mname or "metal" in mname:
        color = (0.78, 0.80, 0.84, 1.0)
        roughness = 0.28
        metallic = 0.88
    elif "glass" in mname:
        color = (0.65, 0.80, 0.86, 1.0)
        roughness = 0.12
        metallic = 0.05
    elif "carpet" in mname:
        color = (0.72, 0.66, 0.58, 1.0)
        roughness = 0.88
        metallic = 0.0
    elif "leaf" in mname or "foliage" in mname or "leaves" in mname or "plant" in mname:
        color = (0.18, 0.48, 0.18, 1.0)
        roughness = 0.72
        metallic = 0.0
    elif "trunk" in mname or "bark" in mname:
        color = (0.34, 0.22, 0.14, 1.0)
        roughness = 0.88
        metallic = 0.0
    elif "white" in mname or "ceramic" in mname:
        color = (0.92, 0.91, 0.88, 1.0)
        roughness = 0.34
        metallic = 0.0
    else:
        color = (0.76, 0.73, 0.68, 1.0)
        roughness = 0.60
        metallic = 0.0

    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic


def import_kenney_glb(prefix, filename, loc, rot_z=0.0, scale=1.85, target_height=None, center_xy=True, strip_unlit=True):
    """Import a Kenney GLB, strip KHR_materials_unlit, normalize min.z=0 and center_xy, and place at loc."""
    filepath = os.path.join(UNPACKED_DIR, filename)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=filepath)
    imported = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in imported if o.type == 'MESH']

    if strip_unlit:
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
    return parent, meshes


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


def bake_cycles_ao(samples=8, ao_min=0.48, ao_max=1.0, target_objs=None):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = samples
    scene.cycles.bake_type = 'AO'
    scene.render.bake.target = 'VERTEX_COLORS'
    scene.render.bake.use_clear = True

    if target_objs is None:
        mesh_objs = [o for o in bpy.data.objects if o.type == 'MESH' and not o.hide_render]
    else:
        mesh_objs = [o for o in target_objs if o.type == 'MESH' and not o.hide_render]

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


def build_elite_living():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    floor_alb, floor_nrm, floor_rgh = generate_tile_textures(TEX_DIR, "elite_marble_v1", (0.91, 0.88, 0.82), "ceramic")
    arr = np.array(floor_alb.pixels[:], dtype=np.float32).reshape((floor_alb.size[1], floor_alb.size[0], 4))
    arr[..., :3] = arr[..., :3] * 0.35 + np.array([0.92, 0.89, 0.84], dtype=np.float32) * 0.65
    floor_alb = save_rgba_png("elite_marble_soft_v19", arr, TEX_DIR)

    wall_alb, wall_nrm, wall_rgh = generate_plaster_ao_texture(TEX_DIR, "elite_plaster_v1", (0.92, 0.90, 0.86))
    wood_alb, wood_nrm, wood_rgh = generate_wood_texture(TEX_DIR, "elite_teak_v1", (0.38, 0.22, 0.11))
    grass_alb, grass_nrm, grass_rgh = generate_turf_texture(TEX_DIR, "elite_grass_v1", (0.20, 0.48, 0.18))
    rug_img = generate_woven_rug_texture(TEX_DIR, "elite_rug_v1")
    art_img = generate_wall_art_padi(TEX_DIR, "elite_art_padi_v1")
    cream_img = generate_fabric_weave_texture(TEX_DIR, "elite_cream_v1", (0.90, 0.88, 0.84))

    mat_floor = make_pbr_material("EliteMarbleFloor", floor_alb, 0.28, floor_nrm, 0.35, (6.0, 5.0), floor_rgh)
    mat_wall = make_pbr_material("EliteWall", wall_alb, 0.86, wall_nrm, 0.40, (2.2, 1.8), wall_rgh)
    mat_wood = make_pbr_material("EliteTeak", wood_alb, 0.52, wood_nrm, 0.45, (1.6, 1.6), wood_rgh)
    mat_grass = make_pbr_material("YardGrass", grass_alb, 0.90, grass_nrm, 0.50, (6.0, 6.0), grass_rgh)
    mat_rug = make_pbr_material("EliteRug", rug_img, 0.90)
    mat_art = make_pbr_material("EliteWallArt", art_img, 0.50)
    mat_cream = make_pbr_material("CreamFabric", cream_img, 0.85, None, 0.0, (2.0, 2.0))

    mat_patio = make_solid_mat("YardPatio", (0.72, 0.69, 0.64), 0.78)
    mat_dark = make_solid_mat("DarkAlloy", (0.14, 0.15, 0.18), 0.32, 0.70)
    mat_marble_top = make_solid_mat("IslandMarbleTop", (0.95, 0.94, 0.91), 0.22)
    mat_glass = make_solid_mat("PanoramicGlass", (0.72, 0.86, 0.92), 0.06, 0.05, alpha=0.18)

    # Diorama base: 7.6m x 6.0m open-plan luxury living + island kitchen
    add_beveled_box("OuterYard", (20.0, 20.0, 0.12), (0.0, 0.0, -0.24), mat_grass, 0.0)
    add_beveled_box("YardPatio", (8.4, 6.8, 0.10), (0.0, 0.0, -0.17), mat_patio, 0.02)

    # Panoramic garden trees visible through large back window
    import_kenney_glb("GardenTree1", "common-tree-1.glb", (0.65, 4.25, -0.18), rot_z=0.4, target_height=3.10)
    import_kenney_glb("GardenTree2", "common-tree-2.glb", (2.15, 4.45, -0.18), rot_z=-0.5, target_height=2.85)
    import_kenney_glb("GardenBush1", "bush-common-flowers.glb", (1.35, 3.65, -0.18), rot_z=0.2, target_height=0.80)

    # Room shell: 7.6m x 6.0m (x=[-3.8..3.8], y=[-3.0..3.0])
    add_beveled_box("FloorSlab", (7.6, 6.0, 0.16), (0.0, 0.0, -0.08), mat_floor, 0.03, cuts=8)
    add_beveled_box("WallLeft", (0.16, 6.0, 3.00), (-3.72, 0.0, 1.50), mat_wall, 0.025, cuts=8)

    # WallBack with large panoramic garden window at x=[-0.2..2.6], z=[0.65..2.55]
    add_beveled_box("WallBack_Left", (3.60, 0.16, 3.00), (-2.00, 2.92, 1.50), mat_wall, 0.025, cuts=8)
    add_beveled_box("WallBack_Right", (1.20, 0.16, 3.00), (3.20, 2.92, 1.50), mat_wall, 0.025, cuts=4)
    add_beveled_box("WallBack_Bot", (2.80, 0.16, 0.65), (1.20, 2.92, 0.325), mat_wall, 0.02, cuts=4)
    add_beveled_box("WallBack_Top", (2.80, 0.16, 0.45), (1.20, 2.92, 2.775), mat_wall, 0.02, cuts=4)

    # Teak wood paneling accents & skirting
    add_beveled_box("TeakPanelLiving", (1.80, 0.04, 2.80), (-2.10, 2.82, 1.45), mat_wood, 0.01)
    add_beveled_box("SkirtBack", (7.56, 0.06, 0.14), (0.0, 2.82, 0.07), mat_wood, 0.015)
    add_beveled_box("SkirtLeft", (0.06, 5.96, 0.14), (-3.62, 0.0, 0.07), mat_wood, 0.015)

    # Panoramic window frame & glass
    add_beveled_box("PanoFrameTop", (2.92, 0.10, 0.08), (1.20, 2.88, 2.55), mat_dark, 0.01)
    add_beveled_box("PanoFrameBot", (2.92, 0.10, 0.08), (1.20, 2.88, 0.65), mat_dark, 0.01)
    add_beveled_box("PanoFrameL", (0.08, 0.10, 1.98), (-0.22, 2.88, 1.60), mat_dark, 0.01)
    add_beveled_box("PanoFrameR", (0.08, 0.10, 1.98), (2.62, 2.88, 1.60), mat_dark, 0.01)
    add_beveled_box("PanoMullion", (0.06, 0.08, 1.90), (1.20, 2.88, 1.60), mat_dark, 0.008)
    add_beveled_box("PanoGlass", (2.80, 0.02, 1.90), (1.20, 2.90, 1.60), mat_glass, 0.0)

    # Wall art on teak panel
    add_beveled_box("WallArtFrame", (1.05, 0.05, 0.75), (-2.10, 2.78, 1.68), mat_dark, 0.015)
    add_beveled_box("WallArtCanvas", (0.90, 0.02, 0.60), (-2.10, 2.75, 1.68), mat_art, 0.0)

    # Living Zone: Rug + L-set Sofas + TV Console + Potted Plant
    add_beveled_box("LivingRug", (3.10, 2.30, 0.024), (-1.95, 0.65, 0.014), mat_rug, 0.012)
    import_kenney_glb("SofaMain", "loungeSofa.glb", (-2.05, 2.05, 0.0), rot_z=0.0, scale=1.95)
    import_kenney_glb("SofaSide", "loungeSofa.glb", (-0.65, 0.75, 0.0), rot_z=-math.pi * 0.5, scale=1.95)
    import_kenney_glb("TVConsole", "cabinetTelevision.glb", (-3.25, 0.65, 0.0), rot_z=math.pi * 0.5, scale=1.95)
    import_kenney_glb("LivingPlant1", "pottedPlant.glb", (-3.20, 2.25, 0.0), rot_z=0.3, scale=1.95)
    import_kenney_glb("LivingPlant2", "pottedPlant.glb", (3.25, 2.25, 0.0), rot_z=-0.4, scale=1.95)

    # Dining Zone: Round Table + 4 Chairs
    import_kenney_glb("DiningTable", "tableRound.glb", (-1.35, -1.55, 0.0), rot_z=0.0, scale=1.95)
    for ci, (cx, cy, crot) in enumerate([
        (-2.38, -1.55, math.pi * 0.5),
        (-0.32, -1.55, -math.pi * 0.5),
        (-1.35, -2.58, 0.0),
        (-1.35, -0.52, math.pi),
    ]):
        import_kenney_glb(f"DiningChair_{ci}", "chair.glb", (cx, cy, 0.0), rot_z=crot, scale=1.85)

    # Open-Plan Kitchen + Island Counter
    import_kenney_glb("Fridge", "kitchenFridge.glb", (3.25, 1.55, 0.0), rot_z=-math.pi * 0.5, target_height=1.85)
    import_kenney_glb("KitchenSink", "kitchenSink.glb", (3.25, 0.55, 0.0), rot_z=-math.pi * 0.5, target_height=0.92)
    import_kenney_glb("KitchenCab", "kitchenCabinet.glb", (3.25, -0.35, 0.0), rot_z=-math.pi * 0.5, target_height=0.92)
    import_kenney_glb("KitchenStove", "kitchenStove.glb", (3.25, -1.25, 0.0), rot_z=-math.pi * 0.5, target_height=0.92)
    import_kenney_glb("CoffeeMachine", "kitchenCoffeeMachine.glb", (3.22, -0.35, 0.92), rot_z=-math.pi * 0.5, scale=1.70)

    # Kitchen Island
    add_beveled_box("IslandBase", (1.10, 2.20, 0.88), (1.45, -0.35, 0.44), mat_wood, 0.02)
    add_beveled_box("IslandTop", (1.22, 2.32, 0.06), (1.45, -0.35, 0.91), mat_marble_top, 0.015)

    bake_cycles_ao(samples=8, ao_min=0.48, ao_max=1.0)

    os.makedirs(os.path.dirname(OUT_ELITE_LIVING), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT_ELITE_LIVING,
        export_format='GLB',
        export_apply=False,
        export_image_format='JPEG',
        export_jpeg_quality=75,
    )
    print("EXPORTED ELITE LIVING:", OUT_ELITE_LIVING, "bytes=", os.path.getsize(OUT_ELITE_LIVING))


def build_elite_street():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    asph_alb, asph_nrm, asph_rgh = generate_asphalt_textures(TEX_DIR)
    sw_alb, sw_nrm, sw_rgh = generate_sidewalk_concrete_texture(TEX_DIR, "elite_paving_v1")
    batu_alb, batu_nrm, batu_rgh = generate_batu_alam_texture(TEX_DIR, "elite_batu_alam_v1")
    plaster_cream_alb, plaster_nrm, plaster_rgh = generate_plaster_ao_texture(TEX_DIR, "elite_cream_plaster_v1", (0.90, 0.87, 0.80))
    wood_alb, wood_nrm, wood_rgh = generate_wood_texture(TEX_DIR, "elite_teak_ext_v1", (0.38, 0.22, 0.12))
    grass_alb, grass_nrm, grass_rgh = generate_turf_texture(TEX_DIR, "elite_lawn_v1", (0.20, 0.50, 0.18))

    mat_asphalt = make_pbr_material("EliteAsphalt", asph_alb, 0.88, asph_nrm, 0.45, (6.0, 2.5), asph_rgh)
    mat_paving = make_pbr_material("ElitePaving", sw_alb, 0.78, sw_nrm, 0.40, (6.0, 2.0), sw_rgh)
    mat_batu = make_pbr_material("BatuAlam", batu_alb, 0.85, batu_nrm, 0.65, (2.0, 2.0), batu_rgh)
    mat_cream = make_pbr_material("EliteCream", plaster_cream_alb, 0.85, plaster_nrm, 0.40, (2.0, 2.0), plaster_rgh)
    mat_wood = make_pbr_material("EliteTeakExt", wood_alb, 0.58, wood_nrm, 0.45, (1.5, 1.5), wood_rgh)
    mat_grass = make_pbr_material("EliteLawn", grass_alb, 0.90, grass_nrm, 0.50, (6.0, 4.0), grass_rgh)

    mat_charcoal = make_solid_mat("EliteCharcoal", (0.18, 0.19, 0.22), 0.72)
    mat_glass = make_solid_mat("EliteGlass", (0.42, 0.62, 0.74), 0.12, 0.10, alpha=0.35)
    mat_lamp = make_solid_mat("WarmLamp", (1.0, 0.90, 0.68), 0.25, emission=1.5)

    arch_objs = []

    # Ground: Asphalt road + Sidewalk + Manicured Lawn
    arch_objs.append(add_beveled_box("Road", (22.0, 5.0, 0.12), (0.0, -3.5, -0.06), mat_asphalt, 0.0))
    arch_objs.append(add_beveled_box("Sidewalk", (22.0, 2.2, 0.16), (0.0, -0.2, 0.02), mat_paving, 0.02))
    arch_objs.append(add_beveled_box("Lawn", (22.0, 9.0, 0.14), (0.0, 5.2, 0.01), mat_grass, 0.0))

    # Two Modern 2-Story Indonesian Tropical Luxury Cluster Houses
    for hx in (-4.8, 4.8):
        # Ground floor
        arch_objs.append(add_beveled_box(f"House_{hx}_GF", (6.2, 5.0, 3.2), (hx, 4.2, 1.60), mat_cream, 0.03, cuts=4))
        # Second floor cantilevered volume
        arch_objs.append(add_beveled_box(f"House_{hx}_2F", (6.6, 5.4, 3.0), (hx, 4.0, 4.70), mat_charcoal, 0.03, cuts=4))
        # Teak wood soffit & facade slats
        arch_objs.append(add_beveled_box(f"House_{hx}_TeakAccent", (2.8, 0.12, 2.8), (hx - 1.5, 1.28, 4.70), mat_wood, 0.015))
        # Flat tropical overhang roof
        arch_objs.append(add_beveled_box(f"House_{hx}_Roof", (7.2, 6.0, 0.24), (hx, 3.9, 6.32), mat_charcoal, 0.03))
        # Large panoramic windows
        arch_objs.append(add_beveled_box(f"House_{hx}_WinGF", (2.6, 0.08, 2.2), (hx + 1.2, 1.68, 1.40), mat_glass, 0.0))
        arch_objs.append(add_beveled_box(f"House_{hx}_Win2F", (3.0, 0.08, 1.8), (hx + 1.4, 1.28, 4.70), mat_glass, 0.0))
        # Batu alam gate pillars
        for px in (hx - 3.2, hx + 3.2):
            arch_objs.append(add_beveled_box(f"GatePillar_{px}", (0.55, 0.55, 2.10), (px, 1.0, 1.05), mat_batu, 0.02))
            arch_objs.append(add_beveled_box(f"GateLamp_{px}", (0.28, 0.28, 0.16), (px, 1.0, 2.18), mat_lamp, 0.01))

    # Manicured trees, planter boxes & flowers (do NOT bake AO on Kenney foliage/cars)
    for tx, ty, th, tglb in [
        (-8.6, 1.4, 3.4, "common-tree-1.glb"),
        (0.0, 2.2, 3.6, "common-tree-2.glb"),
        (8.6, 1.4, 3.4, "common-tree-1.glb"),
    ]:
        import_kenney_glb(f"StreetTree_{tx}", tglb, (tx, ty, 0.08), rot_z=0.3, target_height=th)

    for px in (-2.4, 0.0, 2.4):
        import_kenney_glb(f"Planter_{px}", "planter.glb", (px, 0.9, 0.08), rot_z=0.0, scale=0.65)
        import_kenney_glb(f"Flower_{px}", "bush-common-flowers.glb", (px, 1.4, 0.08), rot_z=0.4, target_height=0.65)

    # Parked sedan cleanly on road edge
    import_kenney_glb("ParkedSedan", "sedan.glb", (-3.8, -2.15, 0.0), rot_z=-math.pi * 0.5, scale=0.52)

    # Bake Cycles AO on architecture only (samples=4)
    bake_cycles_ao(samples=4, ao_min=0.48, ao_max=1.0, target_objs=arch_objs)

    os.makedirs(os.path.dirname(OUT_ELITE_STREET), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT_ELITE_STREET,
        export_format='GLB',
        export_apply=False,
        export_image_format='JPEG',
        export_jpeg_quality=72,
    )
    print("EXPORTED ELITE STREET:", OUT_ELITE_STREET, "bytes=", os.path.getsize(OUT_ELITE_STREET))


if __name__ == "__main__":
    build_elite_living()
    build_elite_street()
