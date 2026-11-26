import os
import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GODOT_DIR = os.path.dirname(SCRIPT_DIR)
RAW_DIR = os.path.join(GODOT_DIR, "assets", "raw")
MODELS_DIR = os.path.join(GODOT_DIR, "assets", "models")

CLIP_MAP = {
    "Idle": "Idle_Loop_Armature",
    "Walk": "Walk_Loop_Armature",
    "Talk": "Idle_Talking_Loop_Armature",
    "Celebrate": "Celebration_Armature",
    "Clean": "Interact_Armature",
}


def build_character(raw_filename: str, out_filename: str, shirt_tint=None, decimate_ratio: float = 0.65):
    bpy.ops.wm.read_factory_settings(use_empty=True)

    raw_path = os.path.join(RAW_DIR, raw_filename)
    ual_path = os.path.join(RAW_DIR, "UAL1.glb")

    # 1. Import target human character
    bpy.ops.import_scene.gltf(filepath=raw_path)
    target_objs = list(bpy.data.objects)
    target_arm = next(o for o in target_objs if o.type == 'ARMATURE')
    target_arm.name = "TargetArmature"
    target_meshes = [o for o in target_objs if o.type == 'MESH' and o.name != 'Icosphere']

    # Remove Icosphere helper objects if present
    for o in list(bpy.data.objects):
        if o.type == 'MESH' and o.name.startswith('Icosphere'):
            bpy.data.objects.remove(o, do_unlink=True)

    # Clear shape keys & safely decimate heavy meshes while keeping Armature modifier
    for mesh_obj in target_meshes:
        bpy.context.view_layer.objects.active = mesh_obj
        mesh_obj.select_set(True)
        if mesh_obj.data.shape_keys:
            mesh_obj.shape_key_clear()
        if decimate_ratio < 0.99 and len(mesh_obj.data.polygons) > 12000:
            dec = mesh_obj.modifiers.new(name="Decimate", type='DECIMATE')
            dec.ratio = decimate_ratio
            dec.delimit = {'UV', 'SEAM'}
            bpy.ops.object.modifier_apply(modifier="Decimate")
        bpy.ops.object.shade_smooth()

    # Optional cheerful outfit/skin material polish
    if shirt_tint is not None:
        for mat in bpy.data.materials:
            if not mat.use_nodes:
                continue
            lname = mat.name.lower()
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            if not bsdf:
                continue
            if "jacket_main" in lname or "shirt" in lname:
                bsdf.inputs["Base Color"].default_value = (*shirt_tint, 1.0)
            if "roughness" in [i.name.lower() for i in bsdf.inputs]:
                bsdf.inputs["Roughness"].default_value = max(0.72, bsdf.inputs["Roughness"].default_value)

    # 2. Import UAL1 donor armature & actions
    before_objs = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=ual_path)
    donor_objs = [o for o in bpy.data.objects if o not in before_objs]
    donor_arm = next(o for o in donor_objs if o.type == 'ARMATURE')
    donor_arm.name = "DonorArmature"

    # Build case-insensitive lookup of donor pose bones
    donor_bones = {pb.name.lower(): pb.name for pb in donor_arm.pose.bones}

    # Constrain target pose bones to donor via Copy Rotation (+ Copy Location on pelvis)
    bpy.context.view_layer.objects.active = target_arm
    target_arm.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')
    for pb in target_arm.pose.bones:
        donor_name = donor_bones.get(pb.name.lower())
        if not donor_name:
            continue
        cr = pb.constraints.new('COPY_ROTATION')
        cr.target = donor_arm
        cr.subtarget = donor_name
        cr.target_space = 'WORLD'
        cr.owner_space = 'WORLD'
        if pb.name.lower() == 'pelvis':
            cl = pb.constraints.new('COPY_LOCATION')
            cl.target = donor_arm
            cl.subtarget = donor_name
            cl.target_space = 'WORLD'
            cl.owner_space = 'WORLD'
    bpy.ops.object.mode_set(mode='OBJECT')

    # Bake each selected UAL1 action cleanly onto TargetArmature as NLA tracks
    if not donor_arm.animation_data:
        donor_arm.animation_data_create()
    if not target_arm.animation_data:
        target_arm.animation_data_create()

    for short_name, ual_action_name in CLIP_MAP.items():
        ual_act = bpy.data.actions.get(ual_action_name)
        if not ual_act:
            continue
        donor_arm.animation_data.action = ual_act
        f_start = int(round(ual_act.frame_range[0]))
        f_end = int(round(ual_act.frame_range[1]))
        bpy.context.scene.frame_start = f_start
        bpy.context.scene.frame_end = f_end

        bpy.ops.object.select_all(action='DESELECT')
        target_arm.select_set(True)
        bpy.context.view_layer.objects.active = target_arm
        bpy.ops.nla.bake(
            frame_start=f_start,
            frame_end=f_end,
            only_selected=False,
            visual_keying=True,
            clear_constraints=False,
            use_current_action=False,
            bake_types={'POSE'},
        )
        baked_act = target_arm.animation_data.action
        baked_act.name = short_name
        track = target_arm.animation_data.nla_tracks.new()
        track.name = short_name
        track.strips.new(short_name, f_start, baked_act)
        target_arm.animation_data.action = None

    # Clear constraints and delete donor objects & unused actions
    bpy.context.view_layer.objects.active = target_arm
    bpy.ops.object.mode_set(mode='POSE')
    for pb in target_arm.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
    bpy.ops.object.mode_set(mode='OBJECT')

    for o in donor_objs:
        bpy.data.objects.remove(o, do_unlink=True)

    keep_names = set(CLIP_MAP.keys())
    for act in list(bpy.data.actions):
        if act.name not in keep_names:
            bpy.data.actions.remove(act)

    # Select only target armature + meshes and export GLB
    bpy.ops.object.select_all(action='DESELECT')
    target_arm.select_set(True)
    for m in target_meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = target_arm

    out_path = os.path.join(MODELS_DIR, out_filename)
    os.makedirs(MODELS_DIR, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format='GLB',
        use_selection=True,
        export_animations=True,
        export_nla_strips=True,
        export_nla_strips_merged_animation_name="Idle",
    )
    print("EXPORTED CHAR:", out_path, "bytes=", os.path.getsize(out_path))


if __name__ == "__main__":
    build_character("sophia.glb", "char_art.glb", None, 0.70)
    build_character("sintel.glb", "char_ibu.glb", (0.88, 0.45, 0.36), 0.70)
    build_character("jay.glb", "char_budi.glb", (0.16, 0.62, 0.56), 0.35)
