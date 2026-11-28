import math
import os
import bpy
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GODOT_DIR = os.path.dirname(SCRIPT_DIR)
MODELS_DIR = os.path.join(GODOT_DIR, "assets", "models")
RAW_BUST_DIR = os.path.join(GODOT_DIR, "assets", "portraits", "_raw")
os.makedirs(RAW_BUST_DIR, exist_ok=True)

UNIQUE_MODELS = [
    ("player_cepol", "char_art.glb", (0.24, 0.52, 0.38), None),
    ("player_hijab", "char_art_hijab.glb", (0.24, 0.52, 0.38), (0.22, 0.46, 0.36)),
    ("ibu", "char_ibu.glb", None, None),
    ("ibu_sari", "char_ibu.glb", (0.20, 0.50, 0.44), (0.22, 0.52, 0.46)),
    ("ibu_citra", "char_ibu.glb", (0.42, 0.30, 0.58), (0.48, 0.34, 0.62)),
    ("ibu_kampung", "char_ibu.glb", (0.58, 0.36, 0.20), (0.76, 0.62, 0.42)),
    ("budi", "char_budi.glb", None, None),
    ("pak_rt", "char_pak_rt.glb", None, None),
    ("ojek", "char_ojek.glb", None, None),
    ("kurir", "char_kurir.glb", None, None),
    ("pelajar", "char_pelajar.glb", None, None),
    ("dewi", "char_dewi.glb", None, None),
    ("kakak", "char_kakak.glb", None, None),
    ("hendra", "char_hendra.glb", None, None),
    ("rina", "char_rina.glb", None, None),
    ("agus", "char_agus.glb", None, None),
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


def _tint_materials(shirt_rgb, hijab_rgb=None):
    for mat in bpy.data.materials:
        if not mat or not mat.use_nodes:
            continue
        mn = mat.name.lower()
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if not bsdf:
            continue
        if shirt_rgb is not None and (any(k in mn for k in ("shirt", "top", "blouse", "tunic", "daster")) or "image_9" in mn):
            bsdf.inputs["Base Color"].default_value = (*shirt_rgb, 1.0)
        if hijab_rgb is not None and any(k in mn for k in ("hijab", "hood", "drape", "bergo")):
            bsdf.inputs["Base Color"].default_value = (*hijab_rgb, 1.0)


def render_bust(tag: str, glb_name: str, shirt_rgb=None, hijab_rgb=None):
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
    target_z = (head_pos.z - 0.03) if head_pos is not None else (max_v.z - 0.16)

    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 24
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
    scene.view_settings.exposure = -0.10

    world = bpy.data.worlds.new("StudioWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.34, 0.32, 0.34, 1.0)
        bg.inputs[1].default_value = 0.55
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
    add_area("KeyLight", (cx + 0.70, cy - 1.15, target_z + 0.45), tgt, 38.0, 1.0, (1.0, 0.93, 0.84))
    add_area("FillLight", (cx - 0.95, cy - 0.95, target_z + 0.12), tgt, 20.0, 1.3, (0.88, 0.94, 1.0))
    add_area("RimLight", (cx - 0.45, cy + 0.95, target_z + 0.55), tgt, 32.0, 0.8, (1.0, 0.88, 0.68))

    cam_data = bpy.data.cameras.new("BustCam")
    cam_data.lens = 62.0
    cam_obj = bpy.data.objects.new("BustCam", cam_data)
    bpy.context.collection.objects.link(cam_obj)
    cam_loc = Vector((cx + 0.11, cy - 0.78, target_z + 0.02))
    cam_obj.location = cam_loc
    cam_obj.rotation_euler = (Vector((cx, cy, target_z)) - cam_loc).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = cam_obj
    scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("RENDERED BUST:", out_path, "target_z=", round(target_z, 3))


if __name__ == "__main__":
    for tag, glb_name, shirt_rgb, hijab_rgb in UNIQUE_MODELS:
        render_bust(tag, glb_name, shirt_rgb, hijab_rgb)
