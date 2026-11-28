import os
import sys
import math
import bpy
import bmesh
import numpy as np
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from tex_utils import (
    add_galon_dispenser_hd,
    add_layered_broadleaf_plant,
    add_magic_com_hd,
    add_open_standing_fan_hd,
    bake_scene_lightmap_uv2,
    export_room_glb,
    generate_fabric_weave_texture,
    generate_foliage_texture,
    generate_plaster_ao_texture,
    generate_tile_textures,
    generate_turf_texture,
    generate_wall_art_padi,
    generate_wood_texture,
    generate_woven_rug_texture,
    make_pbr_material,
    polish_scene_textures_1024,
    save_rgba_png,
)

GODOT_DIR = os.path.dirname(SCRIPT_DIR)
TEX_DIR = os.path.join(GODOT_DIR, "assets", "textures")
UNPACKED_DIR = os.path.join(GODOT_DIR, "assets", "raw", "unpacked")
OUT_GLB = os.path.join(GODOT_DIR, "assets", "models", "room_majikan_living.glb")


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


def import_kenney_glb(prefix, filename, loc, rot_z=0.0, scale=1.85, target_height=None):
    """Import a Kenney GLB, strip KHR_materials_unlit, normalize min.z=0, and place at loc."""
    filepath = os.path.join(UNPACKED_DIR, filename)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=filepath)
    imported = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in imported if o.type == 'MESH']

    for o in meshes:
        for slot in o.material_slots:
            if slot.material:
                rebuild_kenney_pbr_material(slot.material)

    # Create parent empty at origin to transform cleanly
    parent = bpy.data.objects.new(prefix, None)
    bpy.context.collection.objects.link(parent)
    for o in imported:
        if o.parent is None:
            o.parent = parent

    bpy.context.view_layer.update()

    # Compute world-space bounding box of meshes
    min_z = float("inf")
    max_z = float("-inf")
    for o in meshes:
        for v in o.bound_box:
            wv = o.matrix_world @ Vector(v)
            min_z = min(min_z, wv.z)
            max_z = max(max_z, wv.z)

    cur_h = max(0.001, max_z - min_z)
    s = (target_height / cur_h) if target_height is not None else scale

    parent.scale = (s, s, s)
    parent.rotation_euler = (0.0, 0.0, rot_z)
    parent.location = (loc[0], loc[1], loc[2] - min_z * s)
    bpy.context.view_layer.update()
    return parent


def world_bbox(parent):
    bpy.context.view_layer.update()
    xs, ys, zs = [], [], []
    def _walk(obj):
        if obj.type == 'MESH':
            for v in obj.bound_box:
                wv = obj.matrix_world @ Vector(v)
                xs.append(wv.x); ys.append(wv.y); zs.append(wv.z)
        for ch in obj.children:
            _walk(ch)
    _walk(parent)
    return (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs))


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

        # Clamp baked AO to [ao_min, ao_max]
        for item in col.data:
            r = max(ao_min, min(ao_max, item.color[0]))
            g = max(ao_min, min(ao_max, item.color[1]))
            b = max(ao_min, min(ao_max, item.color[2]))
            item.color = (r, g, b, 1.0)


def build_majikan_living():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    floor_alb, floor_nrm, floor_rgh = generate_tile_textures(TEX_DIR, "majikan_ceramic_v1", (0.86, 0.80, 0.70), "ceramic")
    arr = np.array(floor_alb.pixels[:], dtype=np.float32).reshape((floor_alb.size[1], floor_alb.size[0], 4))
    arr[..., :3] = arr[..., :3] * 0.45 + np.array([0.86, 0.81, 0.72], dtype=np.float32) * 0.55
    floor_alb = save_rgba_png("majikan_ceramic_soft_v19", arr, TEX_DIR)
    wall_alb, wall_nrm, wall_rgh = generate_plaster_ao_texture(TEX_DIR, "majikan_plaster_v1", (0.88, 0.84, 0.76))
    wood_alb, wood_nrm, wood_rgh = generate_wood_texture(TEX_DIR, "majikan_teak_v1", (0.42, 0.24, 0.13))
    grass_alb, grass_nrm, grass_rgh = generate_turf_texture(TEX_DIR, "majikan_grass_v1", (0.24, 0.46, 0.20))
    art_img = generate_wall_art_padi(TEX_DIR, "majikan_art_padi_v1")
    rug_img = generate_woven_rug_texture(TEX_DIR, "majikan_rug_v1")
    cream_img = generate_fabric_weave_texture(TEX_DIR, "majikan_cream_v1", (0.88, 0.84, 0.76))
    curtain_img = generate_fabric_weave_texture(TEX_DIR, "majikan_curtain_v1", (0.33, 0.52, 0.42))

    mat_floor = make_pbr_material("MajikanFloor", floor_alb, 0.48, floor_nrm, 0.55, (5.2, 4.4), floor_rgh)
    mat_wall = make_pbr_material("MajikanWall", wall_alb, 0.88, wall_nrm, 0.45, (2.0, 1.6), wall_rgh)
    mat_wood = make_pbr_material("MajikanWood", wood_alb, 0.60, wood_nrm, 0.45, (1.5, 1.5), wood_rgh)
    mat_grass = make_pbr_material("YardGrass", grass_alb, 0.92, grass_nrm, 0.55, (5.5, 5.5), grass_rgh)
    mat_patio = make_solid_mat("YardPatio", (0.64, 0.60, 0.54), 0.88)
    mat_art = make_pbr_material("MajikanWallArt", art_img, 0.55)
    mat_rug = make_pbr_material("WovenRug", rug_img, 0.90)
    mat_cream = make_pbr_material("CreamFabric", cream_img, 0.88, None, 0.0, (2.0, 2.0))
    mat_curtain = make_pbr_material("SageCurtain", curtain_img, 0.88, None, 0.0, (1.5, 2.5))

    mat_dark = make_solid_mat("DarkAlloy", (0.14, 0.16, 0.20), 0.38, 0.65)
    mat_metal = make_solid_mat("AlloyChrome", (0.76, 0.78, 0.82), 0.22, 0.88)
    mat_lpg_green = make_solid_mat("LPGMelonGreen", (0.24, 0.62, 0.28), 0.45, 0.20)
    mat_teal = make_solid_mat("AccentTeal", (0.18, 0.52, 0.50), 0.70)
    mat_coral = make_solid_mat("AccentCoral", (0.76, 0.34, 0.24), 0.72)
    mat_ceramic_w = make_solid_mat("CeramicWhite", (0.92, 0.91, 0.88), 0.30)
    mat_aqua_blue = make_solid_mat("AquaGalonBlue", (0.18, 0.52, 0.86), 0.20, 0.05)
    mat_glass = make_solid_mat("WindowGlass", (0.72, 0.86, 0.92), 0.08, 0.05, alpha=0.22)

    # Diorama base: 6.4m x 5.2m room surrounded by sunny OuterYard + Patio + Perimeter Walls
    add_beveled_box("OuterYard", (18.0, 18.0, 0.12), (0.0, 0.0, -0.24), mat_grass, 0.0)
    add_beveled_box("YardFenceBack", (14.0, 0.24, 1.50), (0.0, 5.6, 0.45), mat_wall, 0.02)
    add_beveled_box("YardFenceLeft", (0.24, 14.0, 1.50), (-6.0, 0.0, 0.45), mat_wall, 0.02)
    add_beveled_box("YardPatio", (7.4, 6.2, 0.10), (0.0, 0.0, -0.17), mat_patio, 0.02)

    # Outdoor garden trees & bushes visible through WallBack window
    import_kenney_glb("GardenTree1", "common-tree-1.glb", (1.35, 3.85, -0.18), rot_z=0.4, target_height=2.85)
    import_kenney_glb("GardenTree2", "common-tree-2.glb", (2.55, 4.15, -0.18), rot_z=-0.6, target_height=2.55)
    import_kenney_glb("GardenBush1", "bush-common-flowers.glb", (1.85, 3.35, -0.18), rot_z=0.2, target_height=0.75)

    # Room shell: L-wall open front-right (subdivided 8 cuts for smooth Cycles AO)
    add_beveled_box("FloorSlab", (6.8, 5.2, 0.16), (0.10, 0.0, -0.08), mat_floor, 0.03, cuts=8)
    add_beveled_box("WallLeft", (0.14, 5.2, 2.80), (-3.18, 0.0, 1.40), mat_wall, 0.025, cuts=8)

    # WallBack with real window opening at x=[1.04..2.46], z=[1.39..2.25]
    add_beveled_box("WallBack_Left", (4.24, 0.14, 2.80), (-1.08, 2.58, 1.40), mat_wall, 0.025, cuts=8)
    add_beveled_box("WallBack_Right", (1.04, 0.14, 2.80), (2.98, 2.58, 1.40), mat_wall, 0.025, cuts=4)
    add_beveled_box("WallBack_Bot", (1.42, 0.14, 1.39), (1.75, 2.58, 0.695), mat_wall, 0.02, cuts=4)
    add_beveled_box("WallBack_Top", (1.42, 0.14, 0.55), (1.75, 2.58, 2.525), mat_wall, 0.02, cuts=4)

    add_beveled_box("SkirtBack", (6.76, 0.06, 0.14), (0.10, 2.485, 0.07), mat_wood, 0.015)
    add_beveled_box("SkirtLeft", (0.06, 5.16, 0.14), (-3.085, 0.0, 0.07), mat_wood, 0.015)
    add_beveled_box("CrownBack", (6.76, 0.08, 0.08), (0.10, 2.49, 2.75), mat_wood, 0.015)
    add_beveled_box("CrownLeft", (0.08, 5.16, 0.08), (-3.09, 0.0, 2.75), mat_wood, 0.015)
    add_beveled_box("WainscotBack", (6.74, 0.03, 0.88), (0.10, 2.495, 0.44), mat_cream, 0.01)
    add_beveled_box("WainscotLeft", (0.03, 5.14, 0.88), (-3.095, 0.0, 0.44), mat_cream, 0.01)

    # AC Split Unit on WallBack (living zone)
    add_beveled_box("IndoorAC", (0.92, 0.22, 0.26), (-1.75, 2.40, 2.44), mat_cream, 0.03)
    add_beveled_box("IndoorACVent", (0.82, 0.04, 0.04), (-1.75, 2.29, 2.35), mat_dark, 0.008)

    # Large Curtained Window on WallBack (transparent glass + outdoor garden view)
    add_beveled_box("WinFrameTop", (1.60, 0.08, 0.07), (1.75, 2.52, 2.28), mat_wood, 0.015)
    add_beveled_box("WinFrameL", (0.07, 0.08, 0.96), (0.99, 2.52, 1.82), mat_wood, 0.015)
    add_beveled_box("WinFrameR", (0.07, 0.08, 0.96), (2.51, 2.52, 1.82), mat_wood, 0.015)
    add_beveled_box("WinSill", (1.68, 0.16, 0.05), (1.75, 2.48, 1.36), mat_wood, 0.012)
    add_beveled_box("WinGlass", (1.42, 0.015, 0.86), (1.75, 2.54, 1.82), mat_glass, 0.0)
    add_beveled_box("CurtainRod", (2.02, 0.04, 0.04), (1.75, 2.41, 2.40), mat_wood, 0.01)
    for side_x in (0.90, 2.60):
        for p in range(4):
            px = side_x + (p - 1.5) * 0.065
            py = 2.41 - (0.018 if p % 2 == 0 else 0.0)
            add_beveled_box(f"CurtainPleat_{side_x}_{p}", (0.068, 0.04, 1.18), (px, py, 1.80), mat_curtain, 0.015)

    # Framed Wall Art & Round Wall Clock
    add_beveled_box("WallArtFrame", (0.92, 0.05, 0.68), (-1.75, 2.485, 1.62), mat_wood, 0.015)
    add_beveled_box("WallArtMat", (0.82, 0.03, 0.58), (-1.75, 2.46, 1.62), mat_cream, 0.005)
    add_beveled_box("WallArtCanvas", (0.68, 0.02, 0.46), (-1.75, 2.44, 1.62), mat_art, 0.0)

    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.19, depth=0.04, location=(-0.25, 2.48, 1.92), rotation=(math.pi * 0.5, 0, 0))
    bpy.context.active_object.data.materials.append(mat_wood)
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.16, depth=0.03, location=(-0.25, 2.46, 1.92), rotation=(math.pi * 0.5, 0, 0))
    bpy.context.active_object.data.materials.append(mat_cream)
    add_beveled_box("ClockHandH", (0.018, 0.02, 0.09), (-0.25, 2.44, 1.95), mat_dark, 0.002)
    add_beveled_box("ClockHandM", (0.11, 0.02, 0.018), (-0.21, 2.44, 1.92), mat_dark, 0.002)

    # Nusantara Woven Kilim Rug in Living Zone
    add_beveled_box("LivingRug", (2.55, 1.85, 0.024), (-1.70, 0.65, 0.014), mat_rug, 0.012)

    # Curated CC0 Kenney Furniture: Living Zone + Beveled Throw Pillows (exact bbox anchored)
    sofa_p = import_kenney_glb("Sofa", "loungeSofa.glb", (-1.75, 1.85, 0.0), rot_z=0.0, scale=1.85)
    sx0, sx1, sy0, sy1, sz0, sz1 = world_bbox(sofa_p)
    scx, scy = (sx0 + sx1) * 0.5, (sy0 + sy1) * 0.5
    for pi, (px, py, pcol, prot) in enumerate([(scx - 0.36, scy + 0.06, mat_coral, 0.22), (scx + 0.36, scy + 0.06, mat_teal, -0.24)]):
        add_beveled_box(f"SofaPillow_{pi}", (0.28, 0.12, 0.28), (px, py, sz0 + 0.44), pcol, 0.04, (math.radians(-18), 0.0, prot))
    ct_p = import_kenney_glb("CoffeeTable", "tableCoffeeSquare.glb", (-1.75, 0.55, 0.0), rot_z=0.0, scale=1.85)
    cx0, cx1, cy0, cy1, cz0, cz1 = world_bbox(ct_p)
    ccx, ccy = (cx0 + cx1) * 0.5, (cy0 + cy1) * 0.5
    add_beveled_box("CoffeeTray", (0.34, 0.24, 0.025), (ccx - 0.15, ccy, cz1 + 0.012), mat_wood, 0.008)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.036, depth=0.075, location=(ccx - 0.15, ccy, cz1 + 0.055))
    bpy.context.active_object.data.materials.append(mat_ceramic_w)
    import_kenney_glb("CoffeeBooks", "books.glb", (ccx + 0.16, ccy, cz1), rot_z=0.35, scale=1.65)
    import_kenney_glb("TVConsole", "cabinetTelevision.glb", (-2.75, -0.75, 0.0), rot_z=math.pi * 0.5, scale=1.85)
    import_kenney_glb("LivingPlant", "pottedPlant.glb", (-2.65, 1.95, 0.0), rot_z=0.2, scale=1.85)

    add_beveled_box("WallLeftShelf", (0.24, 0.85, 0.04), (-2.98, 0.90, 1.55), mat_wood, 0.008)
    import_kenney_glb("ShelfPlant", "pottedPlant.glb", (-2.96, 1.12, 1.57), rot_z=0.4, scale=1.10)
    import_kenney_glb("ShelfBooks", "books.glb", (-2.96, 0.72, 1.57), rot_z=math.pi * 0.5, scale=1.25)
    add_beveled_box("WallLeftArtFrame", (0.04, 0.76, 0.58), (-3.08, -0.75, 1.55), mat_wood, 0.012)
    add_beveled_box("WallLeftArtCanvas", (0.02, 0.62, 0.44), (-3.05, -0.75, 1.55), mat_art, 0.0)

    # Curated CC0 Kenney Furniture: Dining Zone + Tableware (exact bbox anchored)
    dt_p = import_kenney_glb("DiningTable", "tableRound.glb", (1.15, -0.55, 0.0), rot_z=0.0, scale=1.85)
    dx0, dx1, dy0, dy1, dz0, dz1 = world_bbox(dt_p)
    dcx, dcy = (dx0 + dx1) * 0.5, (dy0 + dy1) * 0.5
    for dpx, dpy in [(dcx - 0.24, dcy - 0.14), (dcx + 0.24, dcy - 0.14)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.11, depth=0.018, location=(dpx, dpy, dz1 + 0.009))
        bpy.context.active_object.data.materials.append(mat_ceramic_w)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.08, location=(dcx, dcy + 0.12, dz1 + 0.055))
    tp_d = bpy.context.active_object
    tp_d.scale = (1.0, 1.0, 0.75)
    bpy.ops.object.shade_smooth()
    tp_d.data.materials.append(mat_teal)
    import_kenney_glb("DiningChair1", "chair.glb", (0.60, -1.15, 0.0), rot_z=0.35, scale=1.85)
    import_kenney_glb("DiningChair2", "chair.glb", (1.70, -1.15, 0.0), rot_z=-0.35, scale=1.85)

    # Curated CC0 Kenney Furniture: Kitchenette + Stove Pan/Pot + Dish Rack
    import_kenney_glb("Fridge", "kitchenFridge.glb", (-0.10, 2.18, 0.0), rot_z=0.0, target_height=1.70)
    import_kenney_glb("KitchenSink", "kitchenSink.glb", (0.82, 2.18, 0.0), rot_z=0.0, target_height=0.90)
    add_beveled_box("DishRack", (0.28, 0.22, 0.05), (0.62, 2.14, 0.925), mat_metal, 0.008)
    for pl in range(3):
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.085, depth=0.016, location=(0.56 + pl * 0.055, 2.14, 1.00), rotation=(0, math.radians(78), 0))
        bpy.context.active_object.data.materials.append(mat_ceramic_w)
    import_kenney_glb("KitchenCab", "kitchenCabinet.glb", (1.60, 2.18, 0.0), rot_z=0.0, target_height=0.90)
    import_kenney_glb("KitchenStove", "kitchenStove.glb", (2.36, 2.18, 0.0), rot_z=0.0, target_height=0.90)
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.12, depth=0.055, location=(2.24, 2.12, 0.94))
    bpy.context.active_object.data.materials.append(mat_dark)
    add_beveled_box("PanHandle", (0.18, 0.025, 0.018), (2.08, 2.12, 0.945), mat_dark, 0.004)
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.095, depth=0.11, location=(2.48, 2.20, 0.965))
    bpy.context.active_object.data.materials.append(mat_metal)
    import_kenney_glb("CoffeeMachine", "kitchenCoffeeMachine.glb", (1.58, 2.18, 0.90), rot_z=0.0, scale=1.65)
    import_kenney_glb("Toaster", "toaster.glb", (1.92, 2.18, 0.90), rot_z=0.15, scale=1.65)
    import_kenney_glb("TrashCan", "trashcan.glb", (2.82, 1.55, 0.0), rot_z=0.0, scale=1.85)
    # Iconic Indonesian green 3kg LPG gas canister ("Gas Melon") + Wall Calendar + Spice Jars
    mat_lpg_green = make_solid_mat("LpgMelonGreen", (0.18, 0.56, 0.26), 0.36)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.145, depth=0.34, location=(2.94, 1.88, 0.19))
    lpg = bpy.context.active_object
    lpg.name = "LPG3kg"
    bpy.ops.object.shade_smooth()
    lpg.data.materials.append(mat_lpg_green)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.08, minor_radius=0.016, major_segments=14, minor_segments=8, location=(2.94, 1.88, 0.38))
    bpy.context.active_object.data.materials.append(mat_lpg_green)
    add_beveled_box("WallCalendar", (0.34, 0.02, 0.46), (0.38, 2.48, 1.84), mat_ceramic_w, 0.005)
    add_beveled_box("WallCalendarHdr", (0.34, 0.024, 0.11), (0.38, 2.475, 2.02), mat_coral, 0.004)
    for sj in range(3):
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.032, depth=0.10, location=(1.22 + sj * 0.09, 2.16, 0.95))
        jar = bpy.context.active_object
        jar.name = f"SpiceJar_{sj}"
        bpy.ops.object.shade_smooth()
        jar.data.materials.append(mat_coral if sj % 2 == 0 else mat_aqua_blue)

    # Indonesian Signature Details (HD):
    # 1. Spun Rice Cooker (Magic Com) on Kitchen Cabinet
    add_magic_com_hd(1.28, 2.14, 0.90, mat_ceramic_w, mat_coral, mat_metal, mat_dark)

    # 2. Green 3kg LPG Canister (Tabung Gas Melon!) beside counter
    bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=12, radius=0.16, location=(3.02, 2.18, 0.20))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(mat_lpg_green)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.11, depth=0.08, location=(3.02, 2.18, 0.36))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(mat_lpg_green)

    # 3. Tall Indonesian HD Water Dispenser + Clear PET Blue Aqua Galon Jug + Layered Plant + HD Fan
    add_beveled_box("DispenserStand", (0.36, 0.36, 0.48), (2.75, -0.55, 0.24), mat_wood, 0.015)
    add_galon_dispenser_hd(2.75, -0.55, 0.48, mat_ceramic_w, mat_dark, mat_coral, mat_aqua_blue, prefix="Galon")
    mat_pot = make_solid_mat("MajikanPot", (0.68, 0.30, 0.18), 0.72)
    mat_soil = make_solid_mat("MajikanSoil", (0.16, 0.11, 0.08), 0.92)
    leaf_alb = generate_foliage_texture(TEX_DIR, "majikan_plant_hd", (0.14, 0.44, 0.16))
    mat_leaf = make_pbr_material("MajikanPlantLeaf", leaf_alb, 0.66)
    add_layered_broadleaf_plant(-2.78, -2.05, mat_pot, mat_soil, mat_leaf, prefix="MajikanPlant", scale=0.95)
    add_open_standing_fan_hd(2.80, 0.65, mat_dark, mat_teal, mat_metal, scale=0.98)

    # 4. Sandals by entry (front-right)
    for sx, sy, srot in [(2.45, -2.15, 0.15), (2.60, -2.18, 0.05)]:
        add_beveled_box(f"Sandal_{sx}", (0.10, 0.24, 0.025), (sx, sy, 0.015), mat_teal, 0.01, (0.0, 0.0, srot))
        add_beveled_box(f"SandalStrap_{sx}", (0.10, 0.06, 0.03), (sx, sy + 0.02, 0.032), mat_coral, 0.008, (0.0, 0.0, srot))

    bake_scene_lightmap_uv2(
        os.path.join(GODOT_DIR, "assets", "lightmaps", "room_majikan_living_lightmap.png"),
        size=1024, samples=14,
        exclude_substrings=("tree", "bush", "flower", "planter", "glass", "window", "majikanplantblade_", "fanspoke_", "fanhubbadge", "fanbtn_", "galonaquabottle", "galonwaterfill", "galonlabelband", "galoncap", "galontap", "magiccomled"),
        lift_min=0.34, sun_energy=4.2, sun_rot_deg=(48.0, 0.0, 28.0), ambient_strength=0.32,
    )
    # Bake subtle Cycles AO (no double-darkening with UV2 lightmap)
    bake_cycles_ao(samples=6, ao_min=0.86, ao_max=1.0)
    polish_scene_textures_1024()
    export_room_glb(OUT_GLB, quality=88)
    print("EXPORTED MAJIKAN LIVING:", OUT_GLB, "bytes=", os.path.getsize(OUT_GLB))


if __name__ == "__main__":
    build_majikan_living()
