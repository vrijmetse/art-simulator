import os
import sys
import math
import bpy
import bmesh

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from tex_utils import generate_batik_texture, make_pbr_material

GODOT_DIR = os.path.dirname(SCRIPT_DIR)
TEX_DIR = os.path.join(GODOT_DIR, "assets", "textures")
UNPACKED_DIR = os.path.join(GODOT_DIR, "assets", "raw", "unpacked")
MODELS_DIR = os.path.join(GODOT_DIR, "assets", "models")

CLIP_RENAME = {
    "Idle_CharacterArmature": "Idle",
    "Walk_CharacterArmature": "Walk",
    "PickUp_CharacterArmature": "Clean",
    "Victory_CharacterArmature": "Celebrate",
    "Walk_Carry_CharacterArmatur": "Talk",
}


def make_matte_mat(name: str, rgb, roughness: float = 0.84, emit_strength: float = 0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.20
    if emit_strength > 0.0 and "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit_strength
    return mat


def attach_to_bone(obj, arm, bone_name: str, mat):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    vg = obj.vertex_groups.new(name=bone_name)
    vg.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    obj.parent = arm
    mod = obj.modifiers.new(name="Armature", type='ARMATURE')
    mod.object = arm
    return obj


def build_fitted_curved_apron(arm, mat_apron, mat_pocket):
    bm = bmesh.new()
    rows = [
        (0.84, 0.22, -0.255),
        (1.12, 0.21, -0.255),
        (1.38, 0.17, -0.248),
        (1.58, 0.15, -0.246),
        (1.78, 0.13, -0.232),
    ]
    cols = 8
    grid = []
    for rz, hw, fy in rows:
        row_v = []
        for c in range(cols + 1):
            t = (c / cols) * 2.0 - 1.0
            row_v.append(bm.verts.new((t * hw, fy + (t * t) * 0.06, rz)))
        grid.append(row_v)
    for r in range(len(grid) - 1):
        for c in range(cols):
            bm.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
    mesh = bpy.data.meshes.new("ArtApronMesh")
    bm.to_mesh(mesh)
    bm.free()
    apron_obj = bpy.data.objects.new("ArtApron", mesh)
    bpy.context.collection.objects.link(apron_obj)
    bpy.context.view_layer.objects.active = apron_obj
    apron_obj.select_set(True)
    sol = apron_obj.modifiers.new("Solidify", 'SOLIDIFY')
    sol.thickness = 0.012
    bpy.ops.object.modifier_apply(modifier="Solidify")
    bpy.ops.object.shade_smooth()
    attach_to_bone(apron_obj, arm, "Torso", mat_apron)

    for sx in (-0.11, 0.11):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx, -0.10, 1.88), rotation=(math.radians(48), 0, 0))
        st = bpy.context.active_object
        st.scale = (0.032, 0.26, 0.014)
        bpy.ops.object.shade_smooth()
        attach_to_bone(st, arm, "Torso", mat_apron)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -0.268, 1.15))
    pkt = bpy.context.active_object
    pkt.scale = (0.18, 0.015, 0.14)
    attach_to_bone(pkt, arm, "Abdomen", mat_pocket)


def apply_subsurf_and_smooth(obj, levels: int = 1):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    sub = obj.modifiers.new("Subsurf", 'SUBSURF')
    sub.levels = levels
    sub.render_levels = levels
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.shade_smooth()
    return obj


def apply_bevel_and_smooth(obj, width: float = 0.004, segments: int = 2):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bev = obj.modifiers.new("Bevel", 'BEVEL')
    bev.width = width
    bev.segments = segments
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.shade_smooth()
    return obj


def build_collared_placket(arm, mat_collar, mat_placket):
    # Neat open polo/batik shirt collar framing upper chest & neck cleanly
    for sx, rot_z in [(-0.105, math.radians(-26)), (0.105, math.radians(26))]:
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sx, -0.145, 2.06),
            rotation=(math.radians(38), math.radians(-18 if sx < 0 else 18), rot_z),
        )
        flap = bpy.context.active_object
        flap.name = f"ShirtCollar_{'L' if sx > 0 else 'R'}"
        flap.scale = (0.145, 0.185, 0.036)
        apply_bevel_and_smooth(flap, width=0.005)
        attach_to_bone(flap, arm, "Torso", mat_collar)

    # Center button placket flush on chest (attached to Torso)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -0.222, 1.72))
    placket = bpy.context.active_object
    placket.name = "ShirtPlacket"
    placket.scale = (0.055, 0.016, 0.42)
    apply_bevel_and_smooth(placket, width=0.004, segments=2)
    attach_to_bone(placket, arm, "Torso", mat_placket)


def build_white_collar(arm, mat_collar):
    # Crisp folded white collar framing upper chest & neck cleanly
    for sx, rot_z in [(-0.105, math.radians(-26)), (0.105, math.radians(26))]:
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sx, -0.145, 2.06),
            rotation=(math.radians(38), math.radians(-18 if sx < 0 else 18), rot_z),
        )
        flap = bpy.context.active_object
        flap.name = f"EliteCollar_{'L' if sx > 0 else 'R'}"
        flap.scale = (0.145, 0.185, 0.036)
        apply_bevel_and_smooth(flap, width=0.005)
        attach_to_bone(flap, arm, "Torso", mat_collar)


def build_quaternius_character(raw_filename: str, out_filename: str, palette: dict, batik_cfg=None, apron=False, hijab=None, skirt=None, collar_placket=False, white_collar=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(UNPACKED_DIR, raw_filename))

    for o in list(bpy.data.objects):
        if o.type == 'MESH' and 'icosphere' in o.name.lower():
            bpy.data.objects.remove(o, do_unlink=True)

    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    body_mesh = next(o for o in bpy.data.objects if o.type == 'MESH')

    # Sleek 1:5.6 Warung-Life stylized human proportions
    arm.scale = (0.86, 0.86, 1.08)

    bpy.context.view_layer.objects.active = body_mesh
    body_mesh.select_set(True)
    skin_mat_idx = next((idx for idx, m in enumerate(body_mesh.data.materials) if "skin" in m.name.lower()), -1)
    if skin_mat_idx >= 0:
        bpy.ops.object.mode_set(mode='OBJECT')
        for p in body_mesh.data.polygons:
            p.select = (p.material_index == skin_mat_idx)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.remove_doubles(threshold=0.0005)
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.uv.smart_project(angle_limit=math.radians(66))
        bpy.ops.object.mode_set(mode='OBJECT')
    sub = body_mesh.modifiers.new("Subsurf", 'SUBSURF')
    sub.levels = 1
    sub.render_levels = 1
    bpy.ops.object.modifier_apply(modifier="Subsurf")
    bpy.ops.object.shade_smooth()
    body_mesh.data.use_auto_smooth = True
    body_mesh.data.auto_smooth_angle = math.radians(62)

    # Scale down oversized chibi head to sleek 1:5.6 proportions around neck pivot (0, 0, 2.24)
    head_vg = body_mesh.vertex_groups.get("Head")
    head_vg_idx = head_vg.index if head_vg else -1
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.object.mode_set(mode='OBJECT')
    for v in body_mesh.data.vertices:
        w = 0.0
        if head_vg_idx >= 0:
            for g in v.groups:
                if g.group == head_vg_idx:
                    w = g.weight
                    break
        v.select = (w > 0.35) or (v.co.z > 2.25)
    bpy.context.scene.cursor.location = (0.0, 0.0, 2.24)
    bpy.context.scene.tool_settings.transform_pivot_point = 'CURSOR'
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.transform.resize(value=(0.72, 0.72, 0.74), orient_type='GLOBAL')
    bpy.ops.object.mode_set(mode='OBJECT')

    # Shorten Arm.L/R + Hand.L/R slightly so hands end naturally at upper/mid thigh instead of knees
    for side, sx in [("L", 0.38), ("R", -0.38)]:
        arm_vg_indices = {
            vg.index for vg in body_mesh.vertex_groups
            if any(part in vg.name for part in (f"UpperArm.{side}", f"LowerArm.{side}", f"Hand.{side}"))
        }
        if arm_vg_indices:
            bpy.ops.object.mode_set(mode='EDIT')
            bpy.ops.mesh.select_all(action='DESELECT')
            bpy.ops.object.mode_set(mode='OBJECT')
            for v in body_mesh.data.vertices:
                w = sum(g.weight for g in v.groups if g.group in arm_vg_indices)
                v.select = (w > 0.35)
            bpy.context.scene.cursor.location = (sx, 0.0, 2.08)
            bpy.context.scene.tool_settings.transform_pivot_point = 'CURSOR'
            bpy.ops.object.mode_set(mode='EDIT')
            bpy.ops.transform.resize(value=(0.85, 1.0, 0.85), orient_type='GLOBAL')
            bpy.ops.object.mode_set(mode='OBJECT')

    batik_img = None
    if batik_cfg is not None:
        batik_img = generate_batik_texture(TEX_DIR, batik_cfg["name"], batik_cfg["base"], batik_cfg["accent"])

    for i, mat in enumerate(list(body_mesh.data.materials)):
        mat.blend_method = 'OPAQUE'
        if not mat.use_nodes:
            continue
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if not bsdf:
            continue
        bsdf.inputs["Alpha"].default_value = 1.0
        bsdf.inputs["Roughness"].default_value = 0.84
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.18

        lname = mat.name.lower()
        if "shirt" in lname and batik_img is not None:
            batik_mat = make_pbr_material(f"{mat.name}_Batik", batik_img, 0.86, None, 0.0, (2.2, 2.2))
            body_mesh.data.materials[i] = batik_mat
            continue
        for key, rgb in palette.items():
            if key in lname:
                bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
                if key == "skin" and "Emission Color" in bsdf.inputs:
                    # Subtle warm subsurface bounce eliminates harsh dark hair-bang shadows on forehead!
                    bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
                    bsdf.inputs["Emission Strength"].default_value = 0.16
                if key == "face":
                    bsdf.inputs["Roughness"].default_value = 0.35

    mat_shoes = make_matte_mat("Shoes", palette["shoes"], 0.68)
    shoes_idx = len(body_mesh.data.materials)
    body_mesh.data.materials.append(mat_shoes)
    verts = body_mesh.data.vertices
    for poly in body_mesh.data.polygons:
        cz = sum(verts[vi].co.z for vi in poly.vertices) / len(poly.vertices)
        if cz < 0.20:
            poly.material_index = shoes_idx

    for side, fx in [("L", 0.264), ("R", -0.264)]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.145, location=(fx, -0.055, 0.085))
        shoe = bpy.context.active_object
        shoe.name = f"Shoe_{side}"
        shoe.scale = (0.72, 1.38, 0.58)
        bpy.ops.object.shade_smooth()
        attach_to_bone(shoe, arm, f"Foot.{side}", mat_shoes)

    mat_nose = make_matte_mat("Nose", tuple(max(0.0, c - 0.05) for c in palette["skin"]), 0.78, 0.14)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, radius=0.023, location=(0.0, -0.366, 2.476))
    nose = bpy.context.active_object
    nose.scale = (0.85, 0.85, 0.75)
    bpy.ops.object.shade_smooth()
    attach_to_bone(nose, arm, "Head", mat_nose)

    mat_smile = make_matte_mat("Smile", (0.58, 0.28, 0.26), 0.72)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -0.364, 2.362))
    sm = bpy.context.active_object
    sm.scale = (0.081, 0.019, 0.015)
    attach_to_bone(sm, arm, "Head", mat_smile)

    # Smooth draped Hijab veil wrapping Ibu Sari's hair/neck cleanly (shrink Hair inward around Head cursor!)
    if hijab is not None:
        hair_idx = next((idx for idx, m in enumerate(body_mesh.data.materials) if "hair" in m.name.lower()), -1)
        if hair_idx >= 0:
            bpy.context.scene.cursor.location = (0.0, 0.04, 2.66)
            bpy.context.scene.tool_settings.transform_pivot_point = 'CURSOR'
            bpy.context.view_layer.objects.active = body_mesh
            bpy.ops.object.mode_set(mode='EDIT')
            bpy.ops.mesh.select_all(action='DESELECT')
            bpy.ops.object.mode_set(mode='OBJECT')
            for p in body_mesh.data.polygons:
                p.select = (p.material_index == hair_idx)
            bpy.ops.object.mode_set(mode='EDIT')
            bpy.ops.transform.resize(value=(0.30, 0.30, 0.30), orient_type='GLOBAL')
            bpy.ops.object.mode_set(mode='OBJECT')
        mat_hijab = make_matte_mat("Hijab", hijab, 0.86)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=22, ring_count=16, radius=0.435, location=(0.0, 0.055, 2.575))
        hood = bpy.context.active_object
        hood.name = "HijabHood"
        hood.scale = (1.04, 1.05, 1.08)
        apply_subsurf_and_smooth(hood, levels=1)
        attach_to_bone(hood, arm, "Head", mat_hijab)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=0.42, radius2=0.29, depth=0.52, location=(0.0, 0.055, 2.02))
        drape = bpy.context.active_object
        drape.name = "HijabDrape"
        drape.scale = (1.12, 0.96, 1.0)
        apply_subsurf_and_smooth(drape, levels=1)
        attach_to_bone(drape, arm, "Torso", mat_hijab)

    if skirt is not None:
        mat_skirt = make_matte_mat("LongSkirt", skirt, 0.88)
        bm = bmesh.new()
        rings_cfg = [
            (0.28, 0.34),
            (0.52, 0.31),
            (0.78, 0.28),
            (1.02, 0.26),
            (1.24, 0.25),
        ]
        segs = 24
        rings = []
        for z_val, r_val in rings_cfg:
            ring_v = []
            for i in range(segs):
                ang = (2.0 * math.pi * i) / segs
                x = math.cos(ang) * r_val * 1.08
                y = math.sin(ang) * r_val * 0.88
                ring_v.append(bm.verts.new((x, y, z_val)))
            rings.append(ring_v)
        for r_idx in range(len(rings) - 1):
            for i in range(segs):
                ni = (i + 1) % segs
                bm.faces.new((rings[r_idx][i], rings[r_idx][ni], rings[r_idx + 1][ni], rings[r_idx + 1][i]))
        skirt_mesh = bpy.data.meshes.new("LongSkirtMesh")
        bm.to_mesh(skirt_mesh)
        bm.free()
        skirt_obj = bpy.data.objects.new("LongSkirt", skirt_mesh)
        bpy.context.collection.objects.link(skirt_obj)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.context.view_layer.objects.active = skirt_obj
        skirt_obj.select_set(True)
        sol = skirt_obj.modifiers.new("Solidify", 'SOLIDIFY')
        sol.thickness = 0.015
        bpy.ops.object.convert(target='MESH')
        bpy.ops.object.shade_smooth()
        attach_to_bone(skirt_obj, arm, "Pelvis", mat_skirt)

    if collar_placket:
        base_col = batik_cfg["base"] if batik_cfg else (0.24, 0.38, 0.25)
        mat_collar = make_matte_mat("ShirtCollar", tuple(min(1.0, c + 0.04) for c in base_col), 0.84)
        mat_placket = make_matte_mat("ShirtPlacket", tuple(max(0.0, c - 0.03) for c in base_col), 0.84)
        build_collared_placket(arm, mat_collar, mat_placket)

    if white_collar:
        mat_white_collar = make_matte_mat("EliteWhiteCollar", (0.94, 0.94, 0.92), 0.80)
        build_white_collar(arm, mat_white_collar)

    if apron:
        mat_apron = make_matte_mat("ArtApron", (0.93, 0.89, 0.79), 0.86)
        mat_pocket = make_matte_mat("ApronPocket", (0.84, 0.78, 0.66), 0.88)
        build_fitted_curved_apron(arm, mat_apron, mat_pocket)

    keep_actions = []
    for act in list(bpy.data.actions):
        short = None
        for substr, target_name in CLIP_RENAME.items():
            if substr.lower() in act.name.lower():
                short = target_name
                break
        if short:
            act.name = short
            keep_actions.append(act)
        else:
            bpy.data.actions.remove(act)

    if not arm.animation_data:
        arm.animation_data_create()
    for tr in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(tr)
    for act in keep_actions:
        tr = arm.animation_data.nla_tracks.new()
        tr.name = act.name
        tr.strips.new(act.name, int(round(act.frame_range[0])), act)

    idle_act = bpy.data.actions.get("Idle")
    if idle_act:
        from mathutils import Quaternion
        for side, sign in [("UpperArm.L", 1.0), ("UpperArm.R", -1.0)]:
            dp_quat = f'pose.bones["{side}"].rotation_quaternion'
            fcs = [fc for fc in idle_act.fcurves if fc.data_path == dp_quat]
            if len(fcs) == 4:
                fcs.sort(key=lambda fc: fc.array_index)
                delta = Quaternion((0.0, 0.0, 1.0), math.radians(10.0 * sign))
                for k_idx in range(len(fcs[0].keyframe_points)):
                    q = Quaternion([fc.keyframe_points[k_idx].co[1] for fc in fcs])
                    q_new = q @ delta
                    for i, fc in enumerate(fcs):
                        fc.keyframe_points[k_idx].co[1] = q_new[i]
                        fc.update()
        arm.animation_data.action = idle_act

    out_path = os.path.join(MODELS_DIR, out_filename)
    os.makedirs(MODELS_DIR, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out_path, export_format='GLB',
        export_animations=True, export_nla_strips=True, export_nla_strips_merged_animation_name="Idle",
    )
    print("EXPORTED SLEEK INDONESIAN CHAR V12:", out_path, "bytes=", os.path.getsize(out_path))


if __name__ == "__main__":
    # 1. Sari ART Starter (Tier 0/1 Kamar Kos & Kampung: short-sleeve modest everyday sage tee + dark pants, NO tan belt gap!)
    build_quaternius_character("casual-2-female.glb", "char_art.glb", {
        "skin": (0.76, 0.54, 0.39),
        "shirt": (0.28, 0.49, 0.39),
        "pants": (0.14, 0.17, 0.23),
        "belt": (0.14, 0.17, 0.23),
        "hair": (0.08, 0.06, 0.05),
        "face": (0.08, 0.06, 0.06),
        "shoes": (0.86, 0.84, 0.79),
    }, None, apron=False)

    # 2. Sari ART Tier 2 (Perumahan 36/72: teal work uniform + tailored cream apron!)
    build_quaternius_character("casual-3-female.glb", "char_art_pro.glb", {
        "skin": (0.76, 0.54, 0.39),
        "shirt": (0.14, 0.48, 0.46),
        "pants": (0.12, 0.16, 0.23),
        "belt": (0.12, 0.16, 0.23),
        "hair": (0.08, 0.06, 0.05),
        "face": (0.08, 0.06, 0.06),
        "shoes": (0.88, 0.86, 0.82),
    }, None, apron=True)

    # 3. Ibu Sari (Homeowner: warm dusty-rose Hijab + dark inner hair + terracotta batik blouse + brown pants!)
    build_quaternius_character("casual-2-female.glb", "char_ibu.glb", {
        "skin": (0.78, 0.56, 0.41),
        "pants": (0.22, 0.16, 0.15),
        "belt": (0.22, 0.16, 0.15),
        "hair": (0.09, 0.07, 0.06),
        "face": (0.08, 0.06, 0.06),
        "shoes": (0.38, 0.22, 0.14),
    }, {"name": "batik_ibu", "base": (0.66, 0.24, 0.19), "accent": (0.90, 0.72, 0.36)}, apron=False, hijab=(0.76, 0.44, 0.38), skirt=(0.20, 0.14, 0.13))

    # 4. Pak Budi (Homeowner: olive-gold batik shirt + charcoal chinos!)
    build_quaternius_character("casual-2-male.glb", "char_budi.glb", {
        "skin": (0.68, 0.47, 0.34),
        "pants": (0.17, 0.18, 0.22),
        "belt": (0.17, 0.18, 0.22),
        "hair": (0.07, 0.06, 0.05),
        "face": (0.08, 0.06, 0.06),
        "shoes": (0.24, 0.15, 0.11),
    }, {"name": "batik_budi", "base": (0.24, 0.38, 0.25), "accent": (0.78, 0.68, 0.36)}, apron=False, collar_placket=True)

    # 5. Sari ART Tier 4 (Cluster Elite: dark slate-teal collared uniform tunic + crisp white collar + fitted cream apron!)
    build_quaternius_character("casual-3-female.glb", "char_art_elite.glb", {
        "skin": (0.76, 0.54, 0.39),
        "shirt": (0.12, 0.24, 0.30),
        "pants": (0.10, 0.13, 0.18),
        "belt": (0.10, 0.13, 0.18),
        "hair": (0.08, 0.06, 0.05),
        "face": (0.08, 0.06, 0.06),
        "shoes": (0.12, 0.15, 0.19),
    }, None, apron=True, white_collar=True)
