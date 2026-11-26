import os
import sys
import math
import bpy
import bmesh
from mathutils import Vector

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
        bsdf.inputs["Specular IOR Level"].default_value = 0.16
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


def attach_multi_bone(obj, arm, mat, weight_fn):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    vg_cache = {}
    for idx, v in enumerate(obj.data.vertices):
        weights = weight_fn(v.co)
        for bname, w in weights.items():
            if w <= 0.001:
                continue
            vg = vg_cache.get(bname)
            if vg is None:
                vg = obj.vertex_groups.new(name=bname)
                vg_cache[bname] = vg
            vg.add([idx], float(w), 'REPLACE')
    obj.parent = arm
    mod = obj.modifiers.new(name="Armature", type='ARMATURE')
    mod.object = arm
    return obj


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


def measure_head_bounds(body_mesh):
    head_vg = body_mesh.vertex_groups.get("Head")
    hidx = head_vg.index if head_vg else -1
    pts = []
    for v in body_mesh.data.vertices:
        if hidx >= 0 and any(g.group == hidx and g.weight > 0.45 for g in v.groups):
            if v.co.z > 2.22:
                pts.append(v.co)
    if not pts:
        pts = [v.co for v in body_mesh.data.vertices if v.co.z > 2.25]
    xs = [p.x for p in pts]
    ys = [p.y for p in pts]
    zs = [p.z for p in pts]
    return {
        "x_min": min(xs), "x_max": max(xs),
        "y_min": min(ys), "y_max": max(ys),
        "z_min": min(zs), "z_max": max(zs),
        "cx": 0.5 * (min(xs) + max(xs)),
        "cy": 0.5 * (min(ys) + max(ys)),
        "cz": 0.5 * (min(zs) + max(zs)),
        "rx": 0.5 * (max(xs) - min(xs)),
        "ry": 0.5 * (max(ys) - min(ys)),
        "rz": 0.5 * (max(zs) - min(zs)),
    }


def build_fitted_curved_apron(arm, mat_apron, mat_pocket):
    bm = bmesh.new()
    rows = [
        (0.88, 0.24, -0.418),
        (1.14, 0.23, -0.388),
        (1.38, 0.19, -0.348),
        (1.60, 0.16, -0.275),
        (1.80, 0.13, -0.248),
    ]
    cols = 10
    grid = []
    for rz, hw, fy in rows:
        row_v = []
        for c in range(cols + 1):
            t = (c / cols) * 2.0 - 1.0
            row_v.append(bm.verts.new((t * hw, fy + (t * t) * 0.08, rz)))
        grid.append(row_v)
    for r in range(len(grid) - 1):
        for c in range(cols):
            bm.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
    mesh = bpy.data.meshes.new("ArtApronMesh")
    bm.to_mesh(mesh)
    bm.free()
    apron_obj = bpy.data.objects.new("ArtApron", mesh)
    bpy.context.collection.objects.link(apron_obj)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = apron_obj
    apron_obj.select_set(True)
    sol = apron_obj.modifiers.new("Solidify", 'SOLIDIFY')
    sol.thickness = 0.012
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.shade_smooth()

    def apron_weights(co):
        if co.z >= 1.46:
            return {"Torso": 1.0}
        if co.z >= 1.20:
            return {"Abdomen": 1.0}
        if co.x > 0.05:
            return {"Pelvis": 0.72, "UpperLeg.L": 0.28}
        if co.x < -0.05:
            return {"Pelvis": 0.72, "UpperLeg.R": 0.28}
        return {"Pelvis": 1.0}

    attach_multi_bone(apron_obj, arm, mat_apron, apron_weights)

    for sx in (-0.11, 0.11):
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx, -0.10, 1.90), rotation=(math.radians(48), 0, 0))
        st = bpy.context.active_object
        st.scale = (0.032, 0.26, 0.014)
        bpy.ops.object.shade_smooth()
        attach_to_bone(st, arm, "Torso", mat_apron)

    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -0.382, 1.24))
    pkt = bpy.context.active_object
    pkt.scale = (0.18, 0.016, 0.13)
    attach_to_bone(pkt, arm, "Abdomen", mat_pocket)


def build_flowing_skirt(arm, mat_skirt, name: str, rings_cfg):
    bm = bmesh.new()
    segs = 28
    rings = []
    for z_val, rx_val, ry_val in rings_cfg:
        ring_v = []
        for i in range(segs):
            ang = (2.0 * math.pi * i) / segs
            x = math.cos(ang) * rx_val
            y = math.sin(ang) * ry_val
            ring_v.append(bm.verts.new((x, y, z_val)))
        rings.append(ring_v)
    for r_idx in range(len(rings) - 1):
        for i in range(segs):
            ni = (i + 1) % segs
            bm.faces.new((rings[r_idx][i], rings[r_idx][ni], rings[r_idx + 1][ni], rings[r_idx + 1][i]))
    skirt_mesh = bpy.data.meshes.new(name + "Mesh")
    bm.to_mesh(skirt_mesh)
    bm.free()
    skirt_obj = bpy.data.objects.new(name, skirt_mesh)
    bpy.context.collection.objects.link(skirt_obj)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = skirt_obj
    skirt_obj.select_set(True)
    sol = skirt_obj.modifiers.new("Solidify", 'SOLIDIFY')
    sol.thickness = 0.014
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.shade_smooth()

    z_bot = rings_cfg[0][0]

    def skirt_weights(co):
        if co.z >= 1.15:
            return {"Pelvis": 1.0}
        t = min(1.0, max(0.0, (1.15 - co.z) / max(0.25, 1.15 - z_bot)))
        leg_w = 0.55 * t
        pel_w = 1.0 - leg_w
        if co.x > 0.025:
            return {"Pelvis": pel_w, "UpperLeg.L": leg_w}
        if co.x < -0.025:
            return {"Pelvis": pel_w, "UpperLeg.R": leg_w}
        return {"Pelvis": 1.0}

    attach_multi_bone(skirt_obj, arm, mat_skirt, skirt_weights)
    return skirt_obj


def build_collared_placket(arm, mat_collar, mat_placket, prefix: str = "Shirt", with_placket: bool = True):
    for sx, rot_z in [(-0.105, math.radians(-26)), (0.105, math.radians(26))]:
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sx, -0.145, 2.06),
            rotation=(math.radians(38), math.radians(-18 if sx < 0 else 18), rot_z),
        )
        flap = bpy.context.active_object
        flap.name = f"{prefix}Collar_{'L' if sx > 0 else 'R'}"
        flap.scale = (0.145, 0.185, 0.036)
        apply_bevel_and_smooth(flap, width=0.005)
        attach_to_bone(flap, arm, "Torso", mat_collar)

    if with_placket:
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -0.222, 1.72))
        placket = bpy.context.active_object
        placket.name = f"{prefix}Placket"
        placket.scale = (0.055, 0.016, 0.42)
        apply_bevel_and_smooth(placket, width=0.004, segments=2)
        attach_to_bone(placket, arm, "Torso", mat_placket)


def build_indonesian_hair_or_hijab(arm, hb: dict, style: str, hair_rgb, ribbon_rgb=None, hijab_rgb=None):
    cx, cy, cz = hb["cx"], hb["cy"], hb["cz"]
    rx, ry, rz = hb["rx"], hb["ry"], hb["rz"]

    if style == "hijab_bergo":
        h_col = hijab_rgb if hijab_rgb else (0.52, 0.20, 0.16)
        mat_hijab = make_matte_mat("HijabBergo", h_col, 0.88)

        # Clean open-face rounded Bergo hood shifted slightly back/up so nose/eyes stay 100% clear!
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=18, radius=1.0, location=(cx, cy + 0.105, cz + 0.042))
        hood = bpy.context.active_object
        hood.name = "HijabHood"
        hood.scale = (rx + 0.078, ry + 0.080, rz + 0.068)
        apply_subsurf_and_smooth(hood, levels=1)
        attach_to_bone(hood, arm, "Head", mat_hijab)

        # Flowing Bergo shoulder & chest drape
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=rx + 0.10, radius2=rx - 0.04, depth=0.56, location=(cx, cy + 0.04, 1.98))
        drape = bpy.context.active_object
        drape.name = "HijabDrape"
        drape.scale = (1.04, 0.94, 1.0)
        apply_subsurf_and_smooth(drape, levels=1)
        attach_to_bone(drape, arm, "Torso", mat_hijab)
        return hood

    mat_hair = make_matte_mat("IndonesianHair", hair_rgb, 0.72)

    if style == "cepol":
        # Clean hair cap kept behind forehead + temple side volume + raised visible Cepol bun!
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=26, ring_count=18, radius=1.0, location=(cx, cy + 0.072, cz + 0.048))
        cap = bpy.context.active_object
        cap.name = "HairCap"
        cap.scale = (rx + 0.048, ry + 0.046, rz + 0.044)
        apply_subsurf_and_smooth(cap, levels=1)
        attach_to_bone(cap, arm, "Head", mat_hair)

        # Curved side-temple hair volume framing cheeks at ears/temples (zero forehead bleed!)
        for sx in (-1.0, 1.0):
            bpy.ops.object.select_all(action='DESELECT')
            bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=1.0, location=(cx + sx * (rx * 0.88), cy + 0.08, cz - 0.02))
            side_h = bpy.context.active_object
            side_h.name = f"SideHair_{'L' if sx > 0 else 'R'}"
            side_h.scale = (0.13, 0.15, 0.24)
            apply_subsurf_and_smooth(side_h, levels=1)
            attach_to_bone(side_h, arm, "Head", mat_hair)

        # Soft side-swept forehead bangs (poni miring) so front view reads unmistakably feminine!
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=18, ring_count=12, radius=1.0,
            location=(cx - 0.06, hb["y_min"] + 0.11, hb["z_max"] - 0.14),
            rotation=(math.radians(14), math.radians(-12), 0),
        )
        poni = bpy.context.active_object
        poni.name = "PoniDepan"
        poni.scale = (rx * 0.86, ry * 0.62, 0.11)
        apply_subsurf_and_smooth(poni, levels=1)
        attach_to_bone(poni, arm, "Head", mat_hair)

        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=18, ring_count=14, radius=0.23, location=(cx, hb["y_max"] + 0.02, cz + 0.24))
        bun = bpy.context.active_object
        bun.name = "CepolBun"
        bun.scale = (1.10, 0.96, 1.04)
        apply_subsurf_and_smooth(bun, levels=1)
        attach_to_bone(bun, arm, "Head", mat_hair)

        tie_col = ribbon_rgb if ribbon_rgb else (0.72, 0.22, 0.18)
        mat_tie = make_matte_mat("CepolTie", tie_col, 0.65)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_torus_add(
            major_segments=18, minor_segments=8,
            major_radius=0.175, minor_radius=0.036,
            location=(cx, hb["y_max"] - 0.02, cz + 0.23),
            rotation=(math.radians(78), 0, 0),
        )
        tie = bpy.context.active_object
        tie.name = "CepolScrunchie"
        attach_to_bone(tie, arm, "Head", mat_tie)
        return cap

    if style == "bob":
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=26, ring_count=18, radius=1.0, location=(cx, cy + 0.068, cz + 0.046))
        cap = bpy.context.active_object
        cap.name = "KakakHairCap"
        cap.scale = (rx + 0.056, ry + 0.054, rz + 0.048)
        apply_subsurf_and_smooth(cap, levels=1)
        attach_to_bone(cap, arm, "Head", mat_hair)

        # Wide smooth shoulder-length bob curtain hugging sides & back of neck cleanly
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=rx + 0.072, depth=0.58, location=(cx, cy + 0.07, cz - 0.24))
        curtain = bpy.context.active_object
        curtain.name = "KakakBobCurtain"
        curtain.scale = (1.12, 1.02, 1.0)
        apply_subsurf_and_smooth(curtain, levels=1)
        attach_to_bone(curtain, arm, "Head", mat_hair)
        return cap

    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_uv_sphere_add(segments=22, ring_count=14, radius=1.0, location=(cx, cy + 0.054, cz + 0.042))
    cap = bpy.context.active_object
    cap.name = "BapakHairCap"
    cap.scale = (rx + 0.040, ry + 0.040, rz + 0.036)
    apply_subsurf_and_smooth(cap, levels=1)
    attach_to_bone(cap, arm, "Head", mat_hair)

    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, hb["y_min"] - 0.008, hb["z_min"] + 0.265))
    kumis = bpy.context.active_object
    kumis.name = "BapakKumis"
    kumis.scale = (0.125, 0.022, 0.024)
    apply_bevel_and_smooth(kumis, width=0.006, segments=2)
    attach_to_bone(kumis, arm, "Head", mat_hair)
    return cap


def shorten_arms_uniformly(arm, body_mesh, scale_factor: float = 0.76):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    pivots = {}
    for side in ("L", "R"):
        ua = arm.data.edit_bones.get(f"UpperArm.{side}")
        la = arm.data.edit_bones.get(f"LowerArm.{side}")
        ha = arm.data.edit_bones.get(f"Hand.{side}")
        if not (ua and la and ha):
            continue
        piv = ua.head.copy()
        pivots[side] = piv.copy()
        la.use_connect = False
        ha.use_connect = False
        for b in (ua, la, ha):
            b.head = piv + (b.head - piv) * scale_factor
            b.tail = piv + (b.tail - piv) * scale_factor
        la.use_connect = True
        ha.use_connect = True
    bpy.ops.object.mode_set(mode='OBJECT')

    for side, piv in pivots.items():
        arm_vg_indices = {
            vg.index for vg in body_mesh.vertex_groups
            if any(part in vg.name for part in (f"UpperArm.{side}", f"LowerArm.{side}", f"Hand.{side}"))
        }
        if not arm_vg_indices:
            continue
        for v in body_mesh.data.vertices:
            w = sum(g.weight for g in v.groups if g.group in arm_vg_indices)
            if w > 0.35:
                v.co = piv + (v.co - piv) * scale_factor


def build_quaternius_character(
    raw_filename: str,
    out_filename: str,
    palette: dict,
    hair_style: str = "cepol",
    batik_cfg=None,
    apron: bool = False,
    hijab=None,
    ribbon_rgb=None,
    skirt_cfg=None,
    collar_placket: bool = False,
    white_collar: bool = False,
):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(UNPACKED_DIR, raw_filename))

    for o in list(bpy.data.objects):
        if o.type == 'MESH' and 'icosphere' in o.name.lower():
            bpy.data.objects.remove(o, do_unlink=True)

    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    body_mesh = next(o for o in bpy.data.objects if o.type == 'MESH')

    arm.scale = (0.94, 0.94, 1.00)

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
    bpy.ops.transform.resize(value=(0.76, 0.76, 0.78), orient_type='GLOBAL')
    bpy.ops.object.mode_set(mode='OBJECT')

    hair_idx = next((idx for idx, m in enumerate(body_mesh.data.materials) if "hair" in m.name.lower()), -1)
    if hair_idx >= 0:
        hb_pre = measure_head_bounds(body_mesh)
        bpy.context.scene.cursor.location = (hb_pre["cx"], hb_pre["cy"] + 0.02, hb_pre["cz"])
        bpy.context.scene.tool_settings.transform_pivot_point = 'CURSOR'
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='DESELECT')
        bpy.ops.object.mode_set(mode='OBJECT')
        for p in body_mesh.data.polygons:
            p.select = (p.material_index == hair_idx)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.transform.resize(value=(0.06, 0.06, 0.06), orient_type='GLOBAL')
        bpy.ops.object.mode_set(mode='OBJECT')

    shorten_arms_uniformly(arm, body_mesh, scale_factor=0.76)

    hb = measure_head_bounds(body_mesh)

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
            bsdf.inputs["Specular IOR Level"].default_value = 0.15

        lname = mat.name.lower()
        if "shirt" in lname and batik_img is not None:
            batik_mat = make_pbr_material(f"{mat.name}_Batik", batik_img, 0.86, None, 0.0, (2.2, 2.2))
            body_mesh.data.materials[i] = batik_mat
            continue
        for key, rgb in palette.items():
            if key in lname:
                bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
                if key == "face":
                    bsdf.inputs["Roughness"].default_value = 0.30

    mat_shoes = make_matte_mat("Shoes", palette["shoes"], 0.68)
    shoes_idx = len(body_mesh.data.materials)
    body_mesh.data.materials.append(mat_shoes)
    verts = body_mesh.data.vertices
    for poly in body_mesh.data.polygons:
        cz = sum(verts[vi].co.z for vi in poly.vertices) / len(poly.vertices)
        if cz < 0.20:
            poly.material_index = shoes_idx

    for side, fx in [("L", 0.264), ("R", -0.264)]:
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.145, location=(fx, -0.055, 0.085))
        shoe = bpy.context.active_object
        shoe.name = f"Shoe_{side}"
        shoe.scale = (0.72, 1.38, 0.58)
        bpy.ops.object.shade_smooth()
        attach_to_bone(shoe, arm, f"Foot.{side}", mat_shoes)

    mat_nose = make_matte_mat("Nose", tuple(max(0.0, c - 0.05) for c in palette["skin"]), 0.78)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, radius=0.025, location=(hb["cx"], hb["y_min"] - 0.004, hb["z_min"] + 0.33))
    nose = bpy.context.active_object
    nose.scale = (0.85, 0.85, 0.78)
    bpy.ops.object.shade_smooth()
    attach_to_bone(nose, arm, "Head", mat_nose)

    mat_smile = make_matte_mat("Smile", (0.56, 0.26, 0.24), 0.72)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(hb["cx"], hb["y_min"] - 0.002, hb["z_min"] + 0.21))
    sm = bpy.context.active_object
    sm.scale = (0.084, 0.018, 0.016)
    attach_to_bone(sm, arm, "Head", mat_smile)

    headwear = build_indonesian_hair_or_hijab(arm, hb, hair_style, palette["hair"], ribbon_rgb=ribbon_rgb, hijab_rgb=hijab)
    hw_xs = [v.co.x for v in headwear.data.vertices]
    assert max(hw_xs) > hb["x_max"] + 0.02 and min(hw_xs) < hb["x_min"] - 0.02, (
        f"Headwear clearance check failed for {out_filename}: hw={min(hw_xs):.2f}..{max(hw_xs):.2f} vs skull={hb['x_min']:.2f}..{hb['x_max']:.2f}"
    )

    if skirt_cfg is not None:
        if batik_img is not None and skirt_cfg.get("use_batik", False):
            mat_skirt = make_pbr_material(skirt_cfg.get("name", "DasterSkirt_Batik"), batik_img, 0.86, None, 0.0, (2.4, 2.4))
        else:
            mat_skirt = make_matte_mat(skirt_cfg.get("name", "LongSkirt"), skirt_cfg["color"], 0.86)
        build_flowing_skirt(arm, mat_skirt, skirt_cfg.get("obj_name", "LongSkirt"), skirt_cfg["rings"])

    if collar_placket:
        base_col = batik_cfg["base"] if batik_cfg else (0.24, 0.38, 0.25)
        mat_collar = make_matte_mat("ShirtCollar", tuple(min(1.0, c + 0.04) for c in base_col), 0.84)
        mat_placket = make_matte_mat("ShirtPlacket", tuple(max(0.0, c - 0.03) for c in base_col), 0.84)
        build_collared_placket(arm, mat_collar, mat_placket, prefix="Shirt", with_placket=True)

    if white_collar:
        mat_white_collar = make_matte_mat("EliteWhiteCollar", (0.94, 0.94, 0.92), 0.80)
        build_collared_placket(arm, mat_white_collar, mat_white_collar, prefix="Elite", with_placket=False)

    if apron:
        mat_apron = make_matte_mat("ArtApron", (0.95, 0.92, 0.84), 0.86)
        mat_pocket = make_matte_mat("ApronPocket", (0.86, 0.80, 0.68), 0.88)
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
    print("EXPORTED INDONESIAN CHAR V22:", out_path, "bytes=", os.path.getsize(out_path))


if __name__ == "__main__":
    build_quaternius_character("casual-2-female.glb", "char_art.glb", {
        "skin": (0.34, 0.18, 0.09),
        "pants": (0.14, 0.36, 0.26),
        "belt": (0.14, 0.36, 0.26),
        "hair": (0.04, 0.03, 0.03),
        "face": (0.05, 0.04, 0.04),
        "shoes": (0.48, 0.28, 0.16),
    }, hair_style="cepol", batik_cfg={"name": "daster_art_starter", "base": (0.14, 0.36, 0.26), "accent": (0.92, 0.76, 0.38)},
       apron=True, ribbon_rgb=(0.76, 0.24, 0.18),
       skirt_cfg={"name": "DasterSkirt_Batik", "obj_name": "DasterSkirt", "use_batik": True,
                  "rings": [(0.56, 0.45, 0.38), (0.82, 0.43, 0.36), (1.06, 0.41, 0.35), (1.32, 0.38, 0.32)]})

    build_quaternius_character("casual-2-female.glb", "char_art_hijab.glb", {
        "skin": (0.34, 0.18, 0.09),
        "pants": (0.10, 0.13, 0.18),
        "belt": (0.10, 0.13, 0.18),
        "hair": (0.04, 0.03, 0.03),
        "face": (0.05, 0.04, 0.04),
        "shoes": (0.48, 0.28, 0.16),
    }, hair_style="hijab_bergo", batik_cfg={"name": "daster_art_hijab", "base": (0.16, 0.34, 0.42), "accent": (0.90, 0.80, 0.56)},
       apron=True, hijab=(0.24, 0.46, 0.36),
       skirt_cfg={"name": "DasterHijab_Batik", "obj_name": "DasterSkirt", "use_batik": True,
                  "rings": [(0.42, 0.43, 0.36), (0.72, 0.40, 0.34), (1.02, 0.37, 0.32), (1.30, 0.33, 0.29)]})

    build_quaternius_character("casual-3-female.glb", "char_art_pro.glb", {
        "skin": (0.34, 0.18, 0.09),
        "shirt": (0.08, 0.32, 0.32),
        "pants": (0.09, 0.12, 0.18),
        "belt": (0.09, 0.12, 0.18),
        "hair": (0.04, 0.03, 0.03),
        "face": (0.05, 0.04, 0.04),
        "shoes": (0.76, 0.74, 0.70),
    }, hair_style="cepol", apron=True, ribbon_rgb=(0.12, 0.42, 0.40), white_collar=True)

    build_quaternius_character("casual-3-female.glb", "char_art_elite.glb", {
        "skin": (0.34, 0.18, 0.09),
        "shirt": (0.07, 0.15, 0.24),
        "pants": (0.07, 0.09, 0.14),
        "belt": (0.07, 0.09, 0.14),
        "hair": (0.04, 0.03, 0.03),
        "face": (0.05, 0.04, 0.04),
        "shoes": (0.10, 0.12, 0.16),
    }, hair_style="cepol", apron=True, ribbon_rgb=(0.82, 0.80, 0.76), white_collar=True)

    build_quaternius_character("casual-2-female.glb", "char_ibu.glb", {
        "skin": (0.38, 0.21, 0.11),
        "pants": (0.14, 0.09, 0.09),
        "belt": (0.14, 0.09, 0.09),
        "hair": (0.04, 0.03, 0.03),
        "face": (0.05, 0.04, 0.04),
        "shoes": (0.28, 0.15, 0.09),
    }, hair_style="hijab_bergo", batik_cfg={"name": "batik_ibu", "base": (0.48, 0.14, 0.11), "accent": (0.88, 0.66, 0.26)},
       apron=False, hijab=(0.56, 0.22, 0.18),
       skirt_cfg={"name": "LongSkirt", "obj_name": "LongSkirt", "use_batik": False, "color": (0.16, 0.10, 0.09),
                  "rings": [(0.28, 0.37, 0.33), (0.56, 0.34, 0.31), (0.86, 0.31, 0.29), (1.14, 0.27, 0.26), (1.26, 0.26, 0.25)]})

    build_quaternius_character("casual-female.glb", "char_kakak.glb", {
        "skin": (0.40, 0.22, 0.12),
        "shirt": (0.56, 0.24, 0.32),
        "pants": (0.16, 0.20, 0.30),
        "belt": (0.16, 0.20, 0.30),
        "hair": (0.05, 0.04, 0.03),
        "face": (0.05, 0.04, 0.04),
        "shoes": (0.82, 0.80, 0.78),
    }, hair_style="bob", apron=False,
       skirt_cfg={"name": "KakakMidiSkirt", "obj_name": "KakakSkirt", "use_batik": False, "color": (0.16, 0.20, 0.30),
                  "rings": [(0.56, 0.45, 0.38), (0.82, 0.43, 0.36), (1.06, 0.41, 0.35), (1.32, 0.38, 0.32)]})

    build_quaternius_character("casual-2-male.glb", "char_budi.glb", {
        "skin": (0.30, 0.15, 0.08),
        "pants": (0.12, 0.13, 0.16),
        "belt": (0.12, 0.13, 0.16),
        "hair": (0.04, 0.03, 0.03),
        "face": (0.05, 0.04, 0.04),
        "shoes": (0.16, 0.09, 0.06),
    }, hair_style="bapak", batik_cfg={"name": "batik_budi", "base": (0.14, 0.26, 0.15), "accent": (0.76, 0.62, 0.26)},
       apron=False, collar_placket=True)
