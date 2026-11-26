import os
import sys
import math
import bpy
import bmesh

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from tex_utils import (
    generate_asphalt_textures,
    generate_foliage_texture,
    generate_plaster_ao_texture,
    generate_terracotta_textures,
    generate_tile_textures,
    generate_wood_texture,
    make_pbr_material,
)

GODOT_DIR = os.path.dirname(SCRIPT_DIR)
TEX_DIR = os.path.join(GODOT_DIR, "assets", "textures")
OUT_GLB = os.path.join(GODOT_DIR, "assets", "models", "kampung_street.glb")


def add_box(name, size, loc, mat, bevel_width=0.025, uv_scale=(1.0, 1.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel_width > 0:
        bev = obj.modifiers.new(name="Bevel", type='BEVEL')
        bev.width = bevel_width
        bev.segments = 2
        bev.limit_method = 'ANGLE'
        bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_smooth()
    if obj.data.polygons:
        obj.data.use_auto_smooth = True
        obj.data.auto_smooth_angle = math.radians(42)
    # Box-project clean UVs
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.cube_project(cube_size=max(size) * 0.65)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.materials.append(mat)
    return obj


def add_pitched_roof(name, width, depth, height, loc, mat, ridge_mat):
    bm = bmesh.new()
    hw = width * 0.5
    hd = depth * 0.5
    inset = hw * 0.25
    # Base eave ring
    v0 = bm.verts.new((-hw, -hd, 0.0))
    v1 = bm.verts.new((hw, -hd, 0.0))
    v2 = bm.verts.new((hw, hd, 0.0))
    v3 = bm.verts.new((-hw, hd, 0.0))
    # Ridge line
    r0 = bm.verts.new((-hw + inset, 0.0, height))
    r1 = bm.verts.new((hw - inset, 0.0, height))
    bm.faces.new((v0, v1, r1, r0))
    bm.faces.new((v1, v2, r1))
    bm.faces.new((v2, v3, r0, r1))
    bm.faces.new((v3, v0, r0))
    bm.faces.new((v0, v3, v2, v1))

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    bev = obj.modifiers.new("Bevel", 'BEVEL')
    bev.width = 0.03
    bev.segments = 2
    bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_smooth()
    obj.data.use_auto_smooth = True
    obj.data.auto_smooth_angle = math.radians(45)

    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.cube_project(cube_size=1.8)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.materials.append(mat)

    # Rounded ridge cap beam
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12,
        radius=0.07,
        depth=(width - inset * 2.0 + 0.14),
        location=(loc[0], loc[1], loc[2] + height + 0.02),
        rotation=(0.0, math.pi * 0.5, 0.0),
    )
    ridge = bpy.context.active_object
    ridge.name = f"{name}_ridge"
    bpy.ops.object.shade_smooth()
    ridge.data.materials.append(ridge_mat)


def add_indonesian_house(idx, cx, wall_mat, roof_mat, wood_mat, tile_mat, iron_mat, glass_mat):
    # Blender -Y maps to Godot +Z (toward camera at +Z), Blender +Y maps to Godot -Z (back)
    # Main house body at Blender y = +2.65 -> Godot z = -2.65
    add_box(f"House_{idx}_Body", (3.1, 2.2, 2.35), (cx, 2.65, 1.18), wall_mat, 0.03)
    # Pitched genteng roof with deep eaves
    add_pitched_roof(f"House_{idx}_Roof", 3.65, 2.85, 1.15, (cx, 2.65, 2.30), roof_mat, wood_mat)

    # Porch canopy + tiled terrace + rounded stone pillars facing camera (+Z = Blender -Y)
    add_box(f"House_{idx}_Terrace", (3.25, 1.15, 0.14), (cx, 1.05, 0.07), tile_mat, 0.02)
    add_box(f"House_{idx}_PorchRoof", (3.35, 1.25, 0.09), (cx, 1.08, 1.72), roof_mat, 0.02)
    for px in (-1.35, 1.35):
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.075, depth=1.62, location=(cx + px, 0.55, 0.92))
        pil = bpy.context.active_object
        pil.name = f"House_{idx}_Pillar_{px}"
        bpy.ops.object.shade_smooth()
        pil.data.materials.append(wall_mat)

    # Wooden front door + frame + window + glass facing camera (Blender y = 1.54 -> Godot z = -1.54)
    add_box(f"House_{idx}_DoorFrame", (0.76, 0.10, 1.48), (cx - 0.55, 1.54, 0.82), wood_mat, 0.015)
    add_box(f"House_{idx}_Door", (0.64, 0.08, 1.38), (cx - 0.55, 1.51, 0.80), wood_mat, 0.01)
    add_box(f"House_{idx}_WinFrame", (1.05, 0.10, 0.78), (cx + 0.62, 1.54, 1.16), wood_mat, 0.015)
    add_box(f"House_{idx}_WinGlass", (0.90, 0.05, 0.64), (cx + 0.62, 1.50, 1.16), glass_mat, 0.005)

    # Front fence pillars + wrought-iron gate bars at Blender y = 0.25 -> Godot z = -0.25
    for fx in (-1.52, -0.45, 0.45, 1.52):
        add_box(f"House_{idx}_GatePillar_{fx}", (0.22, 0.22, 0.95), (cx + fx, 0.25, 0.48), wall_mat, 0.02)
    for side_x in (-0.98, 0.98):
        add_box(f"House_{idx}_FenceWall_{side_x}", (0.95, 0.14, 0.48), (cx + side_x, 0.25, 0.24), wall_mat, 0.018)
        for bx in (-0.30, -0.10, 0.10, 0.30):
            bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.016, depth=0.45, location=(cx + side_x + bx, 0.25, 0.68))
            bar = bpy.context.active_object
            bar.data.materials.append(iron_mat)


def add_tropical_tree(name, x, y, scale, wood_mat, leaf_mat):
    # Slightly curved tapered trunk
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.11 * scale, depth=1.8 * scale, location=(x, y, 0.9 * scale))
    trunk = bpy.context.active_object
    trunk.name = f"{name}_Trunk"
    trunk.rotation_euler = (math.radians(3.0), math.radians(-4.0), 0.0)
    bpy.ops.object.shade_smooth()
    trunk.data.materials.append(wood_mat)

    # Smooth organic foliage clusters (subdivided icospheres -> zero blocky cubes)
    clusters = [
        (0.0, 0.0, 2.05, 0.85),
        (-0.48, 0.22, 1.78, 0.62),
        (0.50, -0.18, 1.80, 0.60),
        (0.12, 0.46, 1.72, 0.56),
        (-0.15, -0.44, 1.84, 0.54),
    ]
    for ci, (ox, oy, oz, r) in enumerate(clusters):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=r * scale, location=(x + ox * scale, y + oy * scale, oz * scale))
        leaf = bpy.context.active_object
        leaf.name = f"{name}_Leaf_{ci}"
        leaf.scale = (1.1, 1.0, 0.72)
        bpy.ops.object.shade_smooth()
        leaf.data.materials.append(leaf_mat)


def add_flowering_bush(name, x, y, scale, leaf_mat, flower_mat):
    for ci, (ox, oy, oz, r) in enumerate([(0.0, 0.0, 0.24, 0.30), (-0.22, 0.08, 0.18, 0.22), (0.22, -0.06, 0.19, 0.23)]):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r * scale, location=(x + ox * scale, y + oy * scale, oz * scale))
        b = bpy.context.active_object
        b.name = f"{name}_b{ci}"
        b.scale = (1.15, 1.0, 0.78)
        bpy.ops.object.shade_smooth()
        b.data.materials.append(leaf_mat)
    for fi, (fx, fy, fz) in enumerate([(-0.12, 0.12, 0.38), (0.14, 0.06, 0.40), (0.02, -0.14, 0.35)]):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.06 * scale, location=(x + fx * scale, y + fy * scale, fz * scale))
        fl = bpy.context.active_object
        fl.data.materials.append(flower_mat)


def build_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # Generate PBR PNG textures
    genteng_a_alb, genteng_a_nrm = generate_terracotta_textures(TEX_DIR, "genteng_terra", (0.76, 0.33, 0.20))
    genteng_b_alb, genteng_b_nrm = generate_terracotta_textures(TEX_DIR, "genteng_sage", (0.35, 0.50, 0.39))
    wall_cream = generate_plaster_ao_texture(TEX_DIR, "wall_cream", (0.97, 0.93, 0.84))
    wall_warm = generate_plaster_ao_texture(TEX_DIR, "wall_peach", (0.96, 0.87, 0.77))
    wall_mint = generate_plaster_ao_texture(TEX_DIR, "wall_mint", (0.87, 0.93, 0.86))
    tile_alb, tile_nrm = generate_tile_textures(TEX_DIR, "sidewalk_tile", (0.91, 0.87, 0.79))
    asphalt_alb, asphalt_nrm = generate_asphalt_textures(TEX_DIR)
    teak_img = generate_wood_texture(TEX_DIR, "teak_wood", (0.52, 0.33, 0.19))
    leaf_img = generate_foliage_texture(TEX_DIR, "tropical_leaf", (0.25, 0.56, 0.23))
    grass_img = generate_foliage_texture(TEX_DIR, "kampung_grass", (0.43, 0.67, 0.34))

    mat_roof_terra = make_pbr_material("RoofTerra", genteng_a_alb, 0.76, genteng_a_nrm, 0.55, (1.6, 1.6))
    mat_roof_sage = make_pbr_material("RoofSage", genteng_b_alb, 0.76, genteng_b_nrm, 0.55, (1.6, 1.6))
    mat_wall_cream = make_pbr_material("WallCream", wall_cream, 0.88)
    mat_wall_warm = make_pbr_material("WallWarm", wall_warm, 0.88)
    mat_wall_mint = make_pbr_material("WallMint", wall_mint, 0.88)
    mat_tile = make_pbr_material("SidewalkTile", tile_alb, 0.82, tile_nrm, 0.4, (4.0, 2.0))
    mat_asphalt = make_pbr_material("Asphalt", asphalt_alb, 0.90, asphalt_nrm, 0.35, (3.0, 1.5))
    mat_wood = make_pbr_material("TeakWood", teak_img, 0.74)
    mat_leaf = make_pbr_material("TropicalLeaf", leaf_img, 0.82)
    mat_grass = make_pbr_material("KampungGrass", grass_img, 0.94, None, 0.0, (5.0, 4.0))

    mat_iron = bpy.data.materials.new("WroughtIron")
    mat_iron.use_nodes = True
    mat_iron.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.12, 0.14, 0.18, 1.0)
    mat_iron.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = 0.65
    mat_iron.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.42

    mat_glass = bpy.data.materials.new("WarmGlass")
    mat_glass.use_nodes = True
    mat_glass.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.58, 0.79, 0.86, 1.0)
    mat_glass.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.18

    mat_flower = bpy.data.materials.new("Bougainvillea")
    mat_flower.use_nodes = True
    mat_flower.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.90, 0.34, 0.46, 1.0)
    mat_flower.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.78

    mat_white = bpy.data.materials.new("KanstinWhite")
    mat_white.use_nodes = True
    mat_white.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.94, 0.91, 0.85, 1.0)
    mat_white.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.82

    mat_black = bpy.data.materials.new("KanstinBlack")
    mat_black.use_nodes = True
    mat_black.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.16, 0.18, 0.24, 1.0)
    mat_black.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85

    # Ground lawn strictly below road & sidewalk (top=-0.08 vs road top=-0.01 vs sidewalk top=+0.02)
    add_box("Ground_Lawn", (28.0, 18.0, 0.12), (0.0, 5.0, -0.14), mat_grass, 0.0)
    add_box("Sidewalk_Paving", (22.0, 2.65, 0.12), (0.0, -0.95, -0.04), mat_tile, 0.015)
    add_box("Road_Asphalt", (26.0, 6.8, 0.10), (0.0, -5.60, -0.06), mat_asphalt, 0.0)

    # White dashed road center line cleanly above road top (-0.01)
    for dx in range(-10, 11, 2):
        add_box(f"RoadDash_{dx}", (0.85, 0.12, 0.01), (float(dx), -4.85, -0.004), mat_white, 0.002)

    # Beveled black & white Kanstin curb blocks sitting neatly along sidewalk edge
    for i in range(30):
        kx = -8.4 + i * 0.58
        add_box(f"Kanstin_{i}", (0.56, 0.20, 0.14), (kx, -2.24, 0.02), mat_white if i % 2 == 0 else mat_black, 0.03)

    # 3 Distinct Indonesian Houses (front facing +Z camera)
    add_indonesian_house(0, -3.75, mat_wall_cream, mat_roof_terra, mat_wood, mat_tile, mat_iron, mat_glass)
    add_indonesian_house(1, 0.0, mat_wall_warm, mat_roof_sage, mat_wood, mat_tile, mat_iron, mat_glass)
    add_indonesian_house(2, 3.75, mat_wall_mint, mat_roof_terra, mat_wood, mat_tile, mat_iron, mat_glass)

    # Compact trees tucked neatly between houses + tall lush backdrop trees behind houses
    for ti, (tx, ty, ts) in enumerate([
        (-5.7, 1.2, 0.85), (-1.88, 0.65, 0.58), (1.88, 0.65, 0.60), (5.7, 1.2, 0.85),
        (-3.4, 4.8, 1.25), (0.2, 5.0, 1.35), (3.6, 4.8, 1.20),
    ]):
        add_tropical_tree(f"Tree_{ti}", tx, ty, ts, mat_wood, mat_leaf)

    for bi, (bx, by, bs) in enumerate([
        (-2.15, 0.08, 0.72), (-1.60, 0.08, 0.65), (1.60, 0.08, 0.65), (2.15, 0.08, 0.72),
        (-5.2, 0.05, 0.80), (5.2, 0.05, 0.80),
    ]):
        add_flowering_bush(f"Bush_{bi}", bx, by, bs, mat_leaf, mat_flower)

    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB', export_apply=True)
    print("EXPORTED:", OUT_GLB, "bytes=", os.path.getsize(OUT_GLB))


if __name__ == "__main__":
    build_scene()
