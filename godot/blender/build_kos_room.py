import os
import sys
import math
import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from tex_utils import (
    generate_foliage_texture,
    generate_plaster_ao_texture,
    generate_tile_textures,
    generate_wood_texture,
    make_pbr_material,
)

GODOT_DIR = os.path.dirname(SCRIPT_DIR)
TEX_DIR = os.path.join(GODOT_DIR, "assets", "textures")
OUT_GLB = os.path.join(GODOT_DIR, "assets", "models", "kos_room.glb")


def add_beveled_box(name, size, loc, mat, bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        b = obj.modifiers.new("Bevel", 'BEVEL')
        b.width = bevel
        b.segments = 2
        bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_smooth()
    obj.data.use_auto_smooth = True
    obj.data.auto_smooth_angle = math.radians(42)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.cube_project(cube_size=max(size) * 0.65)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.materials.append(mat)
    return obj


def build_room():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    floor_alb, floor_nrm = generate_tile_textures(TEX_DIR, "room_ceramic", (0.95, 0.90, 0.81))
    wall_alb = generate_plaster_ao_texture(TEX_DIR, "room_plaster", (0.98, 0.94, 0.87))
    wood_alb = generate_wood_texture(TEX_DIR, "room_teak", (0.58, 0.38, 0.22))
    leaf_alb = generate_foliage_texture(TEX_DIR, "room_plant", (0.24, 0.58, 0.28))

    mat_floor = make_pbr_material("RoomFloor", floor_alb, 0.72, floor_nrm, 0.35, (2.2, 2.2))
    mat_wall = make_pbr_material("RoomWall", wall_alb, 0.88)
    mat_wood = make_pbr_material("RoomWood", wood_alb, 0.68)
    mat_leaf = make_pbr_material("RoomPlant", leaf_alb, 0.80)

    mat_cream = bpy.data.materials.new("BedSheet")
    mat_cream.use_nodes = True
    mat_cream.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.96, 0.94, 0.89, 1.0)
    mat_cream.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.88

    mat_coral = bpy.data.materials.new("BlanketCoral")
    mat_coral.use_nodes = True
    mat_coral.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.88, 0.48, 0.37, 1.0)
    mat_coral.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85

    mat_sky = bpy.data.materials.new("WindowSky")
    mat_sky.use_nodes = True
    mat_sky.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.34, 0.68, 0.88, 1.0)
    mat_sky.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (0.34, 0.68, 0.88, 1.0)
    mat_sky.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 0.16

    # Floor slab + Back & Left walls + beveled skirting (Blender +Y -> Godot -Z back wall, -X -> -X left wall)
    add_beveled_box("FloorSlab", (4.8, 4.8, 0.16), (0.0, 0.0, -0.08), mat_floor, 0.03)
    add_beveled_box("WallBack", (4.8, 0.14, 2.75), (0.0, 2.38, 1.375), mat_wall, 0.025)
    add_beveled_box("WallLeft", (0.14, 4.8, 2.75), (-2.38, 0.0, 1.375), mat_wall, 0.025)
    add_beveled_box("SkirtBack", (4.76, 0.06, 0.14), (0.0, 2.29, 0.07), mat_wood, 0.015)
    add_beveled_box("SkirtLeft", (0.06, 4.76, 0.14), (-2.29, 0.0, 0.07), mat_wood, 0.015)

    # Sunlit Window with sky glass cleanly in front of frame (Blender y = 2.25 -> Godot z = -2.25)
    add_beveled_box("WinFrame", (1.35, 0.08, 1.05), (0.55, 2.29, 1.58), mat_wood, 0.02)
    add_beveled_box("WinSky", (1.16, 0.04, 0.86), (0.55, 2.255, 1.58), mat_sky, 0.0)
    add_beveled_box("WinBarV", (0.04, 0.05, 0.86), (0.55, 2.23, 1.58), mat_wood, 0.008)
    add_beveled_box("WinBarH", (1.16, 0.05, 0.04), (0.55, 2.23, 1.58), mat_wood, 0.008)

    # Cozy woven floor rug (center-right)
    add_beveled_box("CozyRug", (2.1, 1.5, 0.025), (0.45, -0.35, 0.012), mat_coral, 0.012)

    # Beveled Single Bed (back-left)
    add_beveled_box("BedFrame", (1.25, 2.05, 0.28), (-1.55, 1.25, 0.14), mat_wood, 0.03)
    add_beveled_box("BedHeadboard", (1.25, 0.10, 0.85), (-1.55, 2.22, 0.42), mat_wood, 0.025)
    add_beveled_box("Mattress", (1.14, 1.92, 0.22), (-1.55, 1.24, 0.34), mat_cream, 0.04)
    add_beveled_box("Blanket", (1.16, 1.12, 0.24), (-1.55, 0.84, 0.35), mat_coral, 0.04)
    add_beveled_box("Pillow", (0.68, 0.38, 0.14), (-1.55, 1.96, 0.50), mat_cream, 0.04)

    # Study Desk + Chair (back-right)
    add_beveled_box("DeskTop", (1.35, 0.68, 0.06), (1.25, 1.88, 0.74), mat_wood, 0.02)
    for lx in (0.65, 1.85):
        for ly in (1.60, 2.15):
            add_beveled_box(f"DeskLeg_{lx}_{ly}", (0.06, 0.06, 0.72), (lx, ly, 0.36), mat_wood, 0.01)

    # Potted Monstera Plant (front-left)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.22, depth=0.36, location=(-1.82, -1.35, 0.18))
    pot = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    pot.data.materials.append(mat_coral)
    for ox, oy, oz in [(0.0, 0.0, 0.56), (-0.14, 0.10, 0.48), (0.14, -0.08, 0.50)]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.20, location=(-1.82 + ox, -1.35 + oy, oz))
        lf = bpy.context.active_object
        lf.scale = (1.1, 1.0, 0.75)
        bpy.ops.object.shade_smooth()
        lf.data.materials.append(mat_leaf)

    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB', export_apply=True)
    print("EXPORTED:", OUT_GLB, "bytes=", os.path.getsize(OUT_GLB))


if __name__ == "__main__":
    build_room()
