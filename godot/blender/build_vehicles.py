import os
import math
import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GODOT_DIR = os.path.dirname(SCRIPT_DIR)
OUT_DIR = os.path.join(GODOT_DIR, "assets", "models")
OUT_ANGKOT = os.path.join(OUT_DIR, "veh_angkot.glb")
OUT_MOTOR = os.path.join(OUT_DIR, "veh_motor.glb")


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_mat(name, rgb, roughness=0.55, metallic=0.0, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def add_box(name, loc, scale, mat, bevel=0.028):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        b = obj.modifiers.new("Bevel", 'BEVEL')
        b.width = bevel
        b.segments = 1
        bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_smooth()
    obj.data.materials.append(mat)
    return obj


def add_cyl(name, loc, radius, depth, rot_euler, mat, verts=16):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot_euler
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.shade_smooth()
    obj.data.materials.append(mat)
    return obj


def join_wheel(parts, wheel_name, axle_pos):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    w = bpy.context.active_object
    w.name = wheel_name
    # Keep mesh vertices centered around local (0, 0, 0) so Godot rotation spins cleanly around axle
    for v in w.data.vertices:
        v.co.x -= axle_pos[0]
        v.co.y -= axle_pos[1]
        v.co.z -= axle_pos[2]
    w.location = axle_pos
    return w


def join_and_export(objs, out_path, root_name, wheels=()):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    merged = bpy.context.active_object
    merged.name = root_name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    export_objs = [merged]
    for w in wheels:
        w.parent = merged
        export_objs.append(w)

    vert_count = sum(len(o.data.vertices) for o in export_objs)
    print(f"[build_vehicles] {root_name}: {vert_count} verts -> {out_path}")
    assert vert_count <= 1500, f"{root_name} exceeded 1500 verts ({vert_count})"

    bpy.ops.object.select_all(action="DESELECT")
    for o in export_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = merged
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        use_selection=True,
        export_materials="EXPORT",
    )


def build_angkot():
    clear_scene()
    mat_body = make_mat("AngkotBody", (0.11, 0.52, 0.71), roughness=0.42, metallic=0.15)
    mat_roof = make_mat("AngkotRoof", (0.92, 0.93, 0.95), roughness=0.55)
    mat_glass = make_mat("AngkotGlass", (0.10, 0.16, 0.24), roughness=0.10, metallic=0.18)
    mat_tire = make_mat("Tire", (0.09, 0.09, 0.10), roughness=0.85)
    mat_rim = make_mat("Rim", (0.72, 0.74, 0.77), roughness=0.35, metallic=0.75)
    mat_bumper = make_mat("Bumper", (0.18, 0.19, 0.21), roughness=0.65)
    mat_headlight = make_mat("Headlight", (1.0, 0.95, 0.78), roughness=0.2, emission=1.2)
    mat_taillight = make_mat("Taillight", (0.90, 0.14, 0.12), roughness=0.25, emission=0.8)

    objs = []
    # Facing +X, grounded at y=0 (in Blender Z-up, Z is vertical -> Godot Y-up)
    # Lower body
    objs.append(add_box("BodyLower", (0.0, 0.0, 0.56), (2.75, 1.24, 0.62), mat_body))
    # Upper cabin
    objs.append(add_box("CabinUpper", (-0.12, 0.0, 1.12), (2.30, 1.18, 0.56), mat_body))
    # White roof cap + route sign
    objs.append(add_box("RoofCap", (-0.12, 0.0, 1.43), (2.22, 1.12, 0.08), mat_roof))
    objs.append(add_box("RouteSign", (0.88, 0.0, 1.48), (0.18, 0.64, 0.14), mat_roof))

    # Windows (front, rear, left/right strips)
    objs.append(add_box("Windshield", (1.04, 0.0, 1.10), (0.06, 1.04, 0.40), mat_glass))
    objs.append(add_box("RearWindow", (-1.28, 0.0, 1.12), (0.06, 0.96, 0.36), mat_glass))
    objs.append(add_box("SideWindows", (-0.14, 0.0, 1.12), (1.85, 1.20, 0.36), mat_glass))

    # Bumpers & Plate
    objs.append(add_box("FrontBumper", (1.39, 0.0, 0.34), (0.10, 1.26, 0.16), mat_bumper, bevel=0.02))
    objs.append(add_box("RearBumper", (-1.39, 0.0, 0.34), (0.10, 1.26, 0.16), mat_bumper, bevel=0.02))
    objs.append(add_box("FrontPlate", (1.445, 0.0, 0.34), (0.02, 0.34, 0.10), mat_bumper, bevel=0.004))

    # Headlights & taillights
    for sy in (-0.42, 0.42):
        objs.append(add_box(f"Head_{sy}", (1.39, sy, 0.56), (0.05, 0.20, 0.12), mat_headlight, bevel=0.01))
        objs.append(add_box(f"Tail_{sy}", (-1.39, sy, 0.56), (0.05, 0.18, 0.14), mat_taillight, bevel=0.01))

    # 4 Articulated Wheels (radius 0.24 -> local axle at (0,0,0), world z=0.24)
    wheels = []
    for idx, (wx, wy) in enumerate([(-0.82, -0.60), (-0.82, 0.60), (0.84, -0.60), (0.84, 0.60)]):
        t = add_cyl(f"Tire_{idx}", (wx, wy, 0.24), 0.24, 0.16, (math.pi / 2.0, 0.0, 0.0), mat_tire, verts=16)
        r = add_cyl(f"Rim_{idx}", (wx, wy, 0.24), 0.13, 0.17, (math.pi / 2.0, 0.0, 0.0), mat_rim, verts=12)
        wheels.append(join_wheel([t, r], f"Wheel_{idx}", (wx, wy, 0.24)))

    join_and_export(objs, OUT_ANGKOT, "VehAngkot", wheels=wheels)


def build_motor():
    clear_scene()
    mat_body = make_mat("MotorBody", (0.76, 0.07, 0.12), roughness=0.38, metallic=0.2)
    mat_seat = make_mat("MotorSeat", (0.12, 0.12, 0.14), roughness=0.78)
    mat_tire = make_mat("Tire", (0.08, 0.08, 0.09), roughness=0.85)
    mat_metal = make_mat("Metal", (0.65, 0.68, 0.72), roughness=0.35, metallic=0.8)
    mat_headlight = make_mat("Headlight", (1.0, 0.95, 0.80), roughness=0.2, emission=1.2)
    mat_taillight = make_mat("Taillight", (0.90, 0.14, 0.12), roughness=0.25, emission=0.8)

    objs = []
    # Articulated Wheels (radius 0.22 -> center at z=0.22)
    wheels = []
    for idx, wx in enumerate((-0.52, 0.54)):
        t = add_cyl(f"Tire_{idx}", (wx, 0.0, 0.22), 0.22, 0.10, (math.pi / 2.0, 0.0, 0.0), mat_tire, verts=12)
        r = add_cyl(f"Rim_{idx}", (wx, 0.0, 0.22), 0.13, 0.11, (math.pi / 2.0, 0.0, 0.0), mat_metal, verts=10)
        wheels.append(join_wheel([t, r], f"Wheel_{idx}", (wx, 0.0, 0.22)))

    # Frame / Fairing
    objs.append(add_box("BodyMain", (-0.08, 0.0, 0.46), (0.86, 0.26, 0.26), mat_body))
    objs.append(add_box("FrontShield", (0.38, 0.0, 0.60), (0.20, 0.30, 0.44), mat_body))
    objs.append(add_box("Seat", (-0.18, 0.0, 0.64), (0.58, 0.24, 0.11), mat_seat))

    # Handlebars & fork + mirrors
    objs.append(add_box("Handlebar", (0.36, 0.0, 0.86), (0.07, 0.56, 0.06), mat_metal, bevel=0.015))
    objs.append(add_box("MirrorL", (0.35, -0.24, 0.96), (0.04, 0.10, 0.07), mat_seat, bevel=0.01))
    objs.append(add_box("MirrorR", (0.35, 0.24, 0.96), (0.04, 0.10, 0.07), mat_seat, bevel=0.01))
    objs.append(add_box("Headlight", (0.49, 0.0, 0.76), (0.06, 0.14, 0.10), mat_headlight, bevel=0.01))
    objs.append(add_box("Taillight", (-0.54, 0.0, 0.56), (0.05, 0.12, 0.08), mat_taillight, bevel=0.01))
    objs.append(add_cyl("Exhaust", (-0.28, -0.16, 0.24), 0.04, 0.52, (0.0, math.pi / 2.0, 0.0), mat_metal, verts=10))

    join_and_export(objs, OUT_MOTOR, "VehMotor", wheels=wheels)


if __name__ == "__main__":
    build_angkot()
    build_motor()
