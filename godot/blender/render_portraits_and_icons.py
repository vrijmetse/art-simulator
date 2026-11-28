import math
import os
import bpy
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GODOT_DIR = os.path.dirname(SCRIPT_DIR)
MODELS_DIR = os.path.join(GODOT_DIR, "assets", "models")
RAW_BUST_DIR = os.path.join(GODOT_DIR, "assets", "portraits", "_raw")
os.makedirs(RAW_BUST_DIR, exist_ok=True)

# (tag, glb_name, shirt_rgb, hijab_rgb, yaw_deg, extra_prop)
UNIQUE_MODELS = [
    ("player", "char_art.glb", (0.14, 0.46, 0.36), None, 12.0, None),
    ("player_cepol", "char_art.glb", (0.14, 0.46, 0.36), None, 12.0, None),
    ("player_hijab", "char_art_hijab.glb", (0.14, 0.46, 0.36), (0.14, 0.44, 0.34), -12.0, None),
    ("ibu_melati", "char_ibu.glb", (0.48, 0.14, 0.28), (0.58, 0.16, 0.34), 10.0, "glasses"),
    ("ibu_sari", "char_dewi.glb", (0.12, 0.46, 0.42), None, -16.0, "pearl"),
    ("ibu_citra", "char_kakak.glb", (0.76, 0.22, 0.44), None, 16.0, "glasses"),
    ("ibu_tini", "char_art_pro.glb", (0.28, 0.52, 0.20), None, -12.0, "headband"),
    ("ibu_kampung", "char_ibu.glb", (0.52, 0.24, 0.12), (0.76, 0.42, 0.18), -18.0, None),
    ("pak_budi", "char_budi.glb", None, None, 12.0, None),
    ("pak_hendra", "char_hendra.glb", None, None, -12.0, "glasses"),
    ("pak_rt", "char_pak_rt.glb", None, None, 14.0, "glasses"),
    ("pak_agus", "char_agus.glb", None, None, -15.0, None),
    ("bang_ojek", "char_ojek.glb", None, None, 14.0, None),
    ("kurir_paket", "char_kurir.glb", None, None, -14.0, None),
    ("anak_sekolah", "char_pelajar.glb", None, None, 10.0, None),
    ("adik_bima", "char_pelajar.glb", (0.78, 0.18, 0.18), None, -16.0, "cap_sd"),
    ("mbak_dewi", "char_dewi.glb", (0.78, 0.34, 0.18), None, 12.0, "headband"),
    ("kakak_nadine", "char_kakak.glb", (0.82, 0.26, 0.42), None, -14.0, "sunglasses"),
    ("kakak_maya", "char_art_pro.glb", (0.18, 0.42, 0.78), None, -8.0, "cap_blue"),
    ("mbak_rina", "char_rina.glb", (0.16, 0.46, 0.40), (0.16, 0.48, 0.42), 12.0, "glasses"),
]


def _apply_idle_pose_if_present():
    for obj in bpy.data.objects:
        if obj.type == 'ARMATURE' and obj.animation_data:
            for act in bpy.data.actions:
                if "idle" in act.name.lower():
                    obj.animation_data.action = act
                    break
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()


def _multiply_tint_bsdf(mat, rgb):
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    if not bsdf:
        return
    base_in = bsdf.inputs["Base Color"]
    if base_in.is_linked:
        orig_socket = base_in.links[0].from_socket
        for lk in list(base_in.links):
            nt.links.remove(lk)
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = 'RGBA'
        mix.blend_type = 'MULTIPLY'
        mix.inputs[0].default_value = 1.0
        nt.links.new(orig_socket, mix.inputs[6])
        mix.inputs[7].default_value = (*rgb, 1.0)
        nt.links.new(mix.outputs[2], base_in)
    else:
        base_in.default_value = (*rgb, 1.0)


def _tint_materials(shirt_rgb, hijab_rgb=None):
    for mat in bpy.data.materials:
        if not mat or not mat.use_nodes:
            continue
        mn = mat.name.lower()
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if not bsdf:
            continue
        if "skin" in mn:
            if "Roughness" in bsdf.inputs:
                bsdf.inputs["Roughness"].default_value = 0.72
            if "Specular IOR Level" in bsdf.inputs:
                bsdf.inputs["Specular IOR Level"].default_value = 0.22
        elif not ("eye" in mn or "iris" in mn):
            if "Roughness" in bsdf.inputs:
                bsdf.inputs["Roughness"].default_value = max(0.64, bsdf.inputs["Roughness"].default_value)
            if "Specular IOR Level" in bsdf.inputs:
                bsdf.inputs["Specular IOR Level"].default_value = 0.28

        if hijab_rgb is not None and any(k in mn for k in ("hijab", "hood", "drape", "bergo", "scarf")):
            _multiply_tint_bsdf(mat, hijab_rgb)
        elif shirt_rgb is not None and (any(k in mn for k in ("shirt", "top", "blouse", "tunic", "daster", "apron", "cardigan", "blazer")) or "image_9" in mn):
            _multiply_tint_bsdf(mat, shirt_rgb)


def _make_prop_mat(name, rgb, rough=0.32, metal=0.65):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def _attach_bust_prop(prop_kind, head_pos: Vector):
    if not prop_kind:
        return
    hx, hy, hz = head_pos.x, head_pos.y, head_pos.z
    if prop_kind == "glasses":
        gmat = _make_prop_mat("GoldFrame", (0.86, 0.68, 0.28), 0.25, 0.85)
        for sx in (-0.036, 0.036):
            bpy.ops.mesh.primitive_torus_add(
                major_radius=0.022, minor_radius=0.0032,
                major_segments=16, minor_segments=8,
                location=(hx + sx, hy - 0.105, hz + 0.004),
                rotation=(math.pi * 0.5, 0.0, 0.0),
            )
            bpy.context.active_object.data.materials.append(gmat)
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.003, depth=0.028, location=(hx, hy - 0.106, hz + 0.006), rotation=(0.0, math.pi * 0.5, 0.0))
        bpy.context.active_object.data.materials.append(gmat)
    elif prop_kind == "sunglasses":
        smat = _make_prop_mat("SunShade", (0.12, 0.10, 0.14), 0.15, 0.1)
        for sx in (-0.038, 0.038):
            bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.022, depth=0.008, location=(hx + sx, hy - 0.092, hz + 0.068), rotation=(math.radians(65), 0.0, 0.0))
            bpy.context.active_object.data.materials.append(smat)
    elif prop_kind == "headband":
        hmat = _make_prop_mat("SportBand", (0.94, 0.82, 0.28), 0.55, 0.0)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.095, minor_radius=0.012, major_segments=22, minor_segments=8, location=(hx, hy + 0.01, hz + 0.055), rotation=(math.radians(-22), 0.0, 0.0))
        bpy.context.active_object.data.materials.append(hmat)
    elif prop_kind == "pearl":
        pmat = _make_prop_mat("PearlBead", (0.98, 0.95, 0.88), 0.20, 0.15)
        for ai in range(7):
            a = -0.75 + ai * 0.25
            bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=0.009, location=(hx + math.sin(a) * 0.068, hy - math.cos(a) * 0.068, hz - 0.145))
            bpy.context.active_object.data.materials.append(pmat)
    elif prop_kind in ("cap_sd", "cap_blue"):
        cmat = _make_prop_mat("CapMat", (0.78, 0.16, 0.16) if prop_kind == "cap_sd" else (0.16, 0.44, 0.78), 0.62, 0.0)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.108, location=(hx, hy + 0.01, hz + 0.055))
        cap = bpy.context.active_object
        cap.scale = (1.0, 1.06, 0.65)
        cap.data.materials.append(cmat)
        bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.088, depth=0.014, location=(hx, hy - 0.08, hz + 0.045), rotation=(math.radians(12), 0.0, 0.0))
        brim = bpy.context.active_object
        brim.scale = (1.0, 0.72, 1.0)
        brim.data.materials.append(cmat)


def render_bust(tag: str, glb_name: str, shirt_rgb=None, hijab_rgb=None, yaw_deg=12.0, extra_prop=None):
    glb_path = os.path.join(MODELS_DIR, glb_name)
    out_path = os.path.join(RAW_BUST_DIR, f"{tag}.png")
    if not os.path.isfile(glb_path):
        print("MISSING GLB:", glb_path)
        return

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    _apply_idle_pose_if_present()
    _tint_materials(shirt_rgb, hijab_rgb)

    # Evaluate deformed mesh bounds (after Idle pose)
    deps = bpy.context.evaluated_depsgraph_get()
    min_v = Vector((1e9, 1e9, 1e9))
    max_v = Vector((-1e9, -1e9, -1e9))
    head_pos = None

    for obj in bpy.data.objects:
        if obj.type == 'ARMATURE':
            for bname in ("head", "Head", "mixamorig:Head"):
                pb = obj.pose.bones.get(bname)
                if pb is not None:
                    head_pos = obj.matrix_world @ ((pb.head + pb.tail) * 0.5)
                    break
        if obj.type != 'MESH' or not obj.data or not obj.data.vertices:
            continue
        ev = obj.evaluated_get(deps)
        mesh_ev = ev.to_mesh()
        mw = ev.matrix_world
        for v in mesh_ev.vertices:
            wc = mw @ v.co
            min_v.x = min(min_v.x, wc.x)
            min_v.y = min(min_v.y, wc.y)
            min_v.z = min(min_v.z, wc.z)
            max_v.x = max(max_v.x, wc.x)
            max_v.y = max(max_v.y, wc.y)
            max_v.z = max(max_v.z, wc.z)
        ev.to_mesh_clear()

    cx = head_pos.x if head_pos is not None else 0.5 * (min_v.x + max_v.x)
    cy = head_pos.y if head_pos is not None else 0.5 * (min_v.y + max_v.y)
    # Aim slightly below crown (face + chin + collar)
    target_z = (head_pos.z - 0.035) if head_pos is not None else (max_v.z - 0.16)
    _attach_bust_prop(extra_prop, Vector((cx, cy, target_z + 0.03)))

    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 28
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 2
    scene.render.film_transparent = True
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    try:
        scene.view_settings.view_transform = 'AgX'
    except Exception:
        pass
    scene.view_settings.exposure = 0.05

    world = bpy.data.worlds.new("StudioWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.48, 0.44, 0.40, 1.0)
        bg.inputs[1].default_value = 0.72
    scene.world = world

    def add_area(name, loc, target, energy, size, color):
        ldata = bpy.data.lights.new(name, type='AREA')
        ldata.energy = energy
        ldata.size = size
        ldata.color = color
        lobj = bpy.data.objects.new(name, ldata)
        bpy.context.collection.objects.link(lobj)
        lobj.location = loc
        direction = Vector(target) - Vector(loc)
        lobj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

    tgt = (cx, cy, target_z)
    add_area("KeyLight", (cx + 0.65, cy - 1.15, target_z + 0.42), tgt, 36.0, 1.2, (1.0, 0.94, 0.84))
    add_area("FillLight", (cx - 0.95, cy - 1.05, target_z + 0.15), tgt, 26.0, 1.5, (0.94, 0.96, 1.0))
    add_area("RimLight", (cx - 0.35, cy + 0.95, target_z + 0.55), tgt, 34.0, 0.9, (1.0, 0.88, 0.68))

    rad = math.radians(yaw_deg)
    dist = 0.76
    cam_data = bpy.data.cameras.new("BustCam")
    cam_data.lens = 64.0
    cam_obj = bpy.data.objects.new("BustCam", cam_data)
    bpy.context.collection.objects.link(cam_obj)
    cam_loc = Vector((cx + math.sin(rad) * dist, cy - math.cos(rad) * dist, target_z + 0.02))
    cam_obj.location = cam_loc
    cam_obj.rotation_euler = (Vector((cx, cy, target_z)) - cam_loc).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = cam_obj
    scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("RENDERED BUST:", out_path, "target_z=", round(target_z, 3))


if __name__ == "__main__":
    for tag, glb_name, shirt_rgb, hijab_rgb, yaw_deg, extra_prop in UNIQUE_MODELS:
        render_bust(tag, glb_name, shirt_rgb, hijab_rgb, yaw_deg, extra_prop)
