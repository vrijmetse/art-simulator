import os
import sys
import math
import numpy as np
import bpy
import bmesh
from mathutils import Quaternion, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from tex_utils import generate_batik_texture, make_pbr_material

GODOT_DIR = os.path.dirname(SCRIPT_DIR)
TEX_DIR = os.path.join(GODOT_DIR, "assets", "textures")
RAW_DIR = os.path.join(GODOT_DIR, "assets", "raw")
CHARKIT_DIR = os.path.join(RAW_DIR, "charkit")
MODELS_DIR = os.path.join(GODOT_DIR, "assets", "models")

KEEP_MH_CLIPS = {
    "idle": "Idle",
    "walk": "Walk",
    "idle_unarmed": "Talk",
    "turn_left": "Turn_L",
    "jump": "Jump",
}


def make_matte_mat(name: str, rgb, roughness: float = 0.80, specular: float = 0.16):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = specular
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
    if levels > 0 and len(obj.data.vertices) < 160:
        sub = obj.modifiers.new("Subsurf", 'SUBSURF')
        sub.levels = levels
        sub.render_levels = levels
        bpy.ops.object.convert(target='MESH')
    bpy.ops.object.shade_smooth()
    return obj


def apply_bevel_and_smooth(obj, width: float = 0.003, segments: int = 2):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bev = obj.modifiers.new("Bevel", 'BEVEL')
    bev.width = width
    bev.segments = segments
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.shade_smooth()
    return obj


def _fix_mh_materials_and_textures(mesh_obj, skin_warmth=None):
    """Fix MakeHuman Alpha=0 / BLEND quirk and downscale embedded images <= 512px for lean mobile/WebGL2 .pck."""
    seen_imgs = set()
    for m in mesh_obj.data.materials:
        if not m or not m.use_nodes:
            continue
        m.blend_method = 'OPAQUE'
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            if "Alpha" in bsdf.inputs:
                bsdf.inputs["Alpha"].default_value = 1.0
                for lk in list(bsdf.inputs["Alpha"].links):
                    m.node_tree.links.remove(lk)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = 0.0
            if "Roughness" in bsdf.inputs and "iris" not in m.name.lower():
                bsdf.inputs["Roughness"].default_value = max(0.62, bsdf.inputs["Roughness"].default_value)

        is_body = "body" in m.name.lower()
        max_dim = 512 if is_body else 256
        for node in m.node_tree.nodes:
            if node.type == 'TEX_IMAGE' and node.image is not None:
                img = node.image
                if img.name in seen_imgs:
                    continue
                seen_imgs.add(img.name)
                w, h = img.size[0], img.size[1]
                if w > max_dim or h > max_dim:
                    scale_f = min(max_dim / max(1, w), max_dim / max(1, h))
                    nw = max(64, int(round(w * scale_f)))
                    nh = max(64, int(round(h * scale_f)))
                    img.scale(nw, nh)
                if is_body and skin_warmth is not None:
                    # Gently warm/tint MakeHuman body skin swatch while keeping facial shading & eyes crisp
                    arr = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
                    tint = np.array([skin_warmth[0], skin_warmth[1], skin_warmth[2], 1.0], dtype=np.float32)
                    arr[:, :, :3] = np.clip(arr[:, :, :3] * tint[:3], 0.0, 1.0)
                    img.pixels.foreach_set(arr.reshape(-1).tolist())
                img.pack()


def _delete_materials_faces(mesh_obj, substrs):
    if not substrs:
        return
    del_idx = {i for i, m in enumerate(mesh_obj.data.materials) if m and any(s in m.name.lower() for s in substrs)}
    if not del_idx:
        return
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = mesh_obj
    mesh_obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.object.mode_set(mode='OBJECT')
    for p in mesh_obj.data.polygons:
        if p.material_index in del_idx:
            p.select = True
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.delete(type='FACE')
    bpy.ops.object.mode_set(mode='OBJECT')


def _recolor_mh_outfit(mesh_obj, arm, pelvis_z: float, shirt_rgb=None, pants_rgb=None, batik_img=None, keep_suit_tex: bool = False):
    """Replace MakeHuman chest-logo suit material with clean Indonesian Shirt + Pants via connected mesh islands (zero sawtooth!)."""
    if keep_suit_tex:
        return
    suit_indices = {
        i for i, m in enumerate(mesh_obj.data.materials)
        if m and any(k in m.name.lower() for k in ("casualsuit", "female_suit", "male_suit", "worksuit"))
    }
    if not suit_indices:
        return

    if batik_img is not None:
        mat_shirt = make_pbr_material("Shirt_Batik", batik_img, 0.80, None, 0.0, (2.4, 2.4))
    else:
        mat_shirt = make_matte_mat("Shirt", shirt_rgb or (0.16, 0.36, 0.26), 0.78, 0.14)
    mat_pants = make_matte_mat("Pants", pants_rgb or (0.14, 0.18, 0.24), 0.84, 0.12)

    idx_shirt = len(mesh_obj.data.materials)
    mesh_obj.data.materials.append(mat_shirt)
    idx_pants = len(mesh_obj.data.materials)
    mesh_obj.data.materials.append(mat_pants)

    bm = bmesh.new()
    bm.from_mesh(mesh_obj.data)
    bm.faces.ensure_lookup_table()
    visited = set()
    face_to_mat = {}
    for f in bm.faces:
        if f.material_index not in suit_indices or f.index in visited:
            continue
        stack = [f]
        visited.add(f.index)
        comp = []
        zs = []
        while stack:
            cur = stack.pop()
            comp.append(cur.index)
            for v in cur.verts:
                zs.append(v.co.z)
                for lf in v.link_faces:
                    if lf.material_index in suit_indices and lf.index not in visited:
                        visited.add(lf.index)
                        stack.append(lf)
        is_shirt = max(zs) >= pelvis_z * 1.34 and min(zs) >= pelvis_z * 0.50
        target_idx = idx_shirt if is_shirt else idx_pants
        for fid in comp:
            face_to_mat[fid] = target_idx
    bm.free()

    for fid, mat_idx in face_to_mat.items():
        mesh_obj.data.polygons[fid].material_index = mat_idx


def _measure_head_bounds_mh(mesh_obj, arm):
    head_z = arm.data.bones["head"].head_local.z
    pts = [v.co for v in mesh_obj.data.vertices if v.co.z >= head_z - 0.02]
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


def _add_headgear(arm, hb: dict, zmax: float, style: str, hair_rgb=(0.05, 0.04, 0.04), ribbon_rgb=None, hijab_rgb=None):
    cx, cy, cz = hb["cx"], hb["cy"], hb["cz"]
    rx, ry, rz = hb["rx"], hb["ry"], hb["rz"]
    s_u = zmax / 1.72  # scale relative to standard 1.72m human

    if style == "none":
        return None

    if style == "hijab_bergo":
        h_col = hijab_rgb or (0.14, 0.30, 0.22)
        mat_hijab = make_matte_mat("HijabBergo", h_col, 0.86, 0.12)
        bpy.ops.object.select_all(action='DESELECT')
        # MakeHuman faces -Y; shift hood +Y (back) & +Z (up) + tilt back so face/eyes stay 100% open!
        bpy.ops.mesh.primitive_uv_sphere_add(segments=22, ring_count=14, radius=1.0, location=(cx, cy + 0.032 * s_u, cz + 0.024 * s_u), rotation=(math.radians(10), 0, 0))
        hood = bpy.context.active_object
        hood.name = "HijabHood"
        hood.scale = (rx + 0.016 * s_u, ry + 0.002 * s_u, rz + 0.012 * s_u)
        apply_subsurf_and_smooth(hood, levels=1)
        attach_to_bone(hood, arm, "head", mat_hijab)

        neck_z = arm.data.bones["neck_01"].head_local.z
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cone_add(vertices=22, radius1=0.148 * s_u, radius2=0.076 * s_u, depth=0.22 * s_u, location=(cx, cy + 0.018 * s_u, neck_z - 0.02 * s_u))
        drape = bpy.context.active_object
        drape.name = "HijabDrape"
        drape.scale = (1.00, 0.78, 1.0)
        apply_subsurf_and_smooth(drape, levels=1)
        attach_multi_bone(drape, arm, mat_hijab, lambda co: {"neck_01": 0.45, "spine_03": 0.55} if co.z > neck_z - 0.02 else {"spine_03": 1.0})
        return hood

    mat_hair = make_matte_mat("IndonesianHair", hair_rgb, 0.68, 0.18)

    if style == "cepol":
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=22, ring_count=14, radius=1.0, location=(cx, cy + 0.028 * s_u, cz + 0.030 * s_u), rotation=(math.radians(14), 0, 0))
        cap = bpy.context.active_object
        cap.name = "HairCap"
        cap.scale = (rx + 0.008 * s_u, ry - 0.004 * s_u, rz * 0.90)
        apply_subsurf_and_smooth(cap, levels=1)
        attach_to_bone(cap, arm, "head", mat_hair)

        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=12, radius=0.052 * s_u, location=(cx, hb["y_max"] + 0.014 * s_u, cz + 0.052 * s_u))
        bun = bpy.context.active_object
        bun.name = "CepolBun"
        bun.scale = (1.04, 0.94, 1.0)
        apply_subsurf_and_smooth(bun, levels=1)
        attach_to_bone(bun, arm, "head", mat_hair)

        tie_col = ribbon_rgb or (0.76, 0.24, 0.18)
        mat_tie = make_matte_mat("CepolTie", tie_col, 0.62)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_torus_add(
            major_segments=14, minor_segments=8,
            major_radius=0.042 * s_u, minor_radius=0.009 * s_u,
            location=(cx, hb["y_max"] + 0.004 * s_u, cz + 0.046 * s_u),
            rotation=(math.radians(68), 0, 0),
        )
        tie = bpy.context.active_object
        tie.name = "CepolScrunchie"
        attach_to_bone(tie, arm, "head", mat_tie)
        return cap

    if style == "ponytail":
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=22, ring_count=14, radius=1.0, location=(cx, cy + 0.028 * s_u, cz + 0.030 * s_u), rotation=(math.radians(14), 0, 0))
        cap = bpy.context.active_object
        cap.name = "PonytailCap"
        cap.scale = (rx + 0.008 * s_u, ry - 0.004 * s_u, rz * 0.90)
        apply_subsurf_and_smooth(cap, levels=1)
        attach_to_bone(cap, arm, "head", mat_hair)

        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.048 * s_u, radius2=0.020 * s_u, depth=0.20 * s_u, location=(cx, hb["y_max"] + 0.024 * s_u, cz - 0.036 * s_u), rotation=(math.radians(-22), 0, 0))
        tail = bpy.context.active_object
        tail.name = "Ponytail"
        apply_subsurf_and_smooth(tail, levels=1)
        attach_to_bone(tail, arm, "head", mat_hair)
        return cap

    if style == "peci":
        mat_peci = make_matte_mat("PeciVelvet", (0.06, 0.06, 0.07), 0.88, 0.08)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cylinder_add(vertices=22, radius=rx + 0.004 * s_u, depth=0.062 * s_u, location=(cx, cy + 0.008 * s_u, hb["z_max"] - 0.012 * s_u), rotation=(math.radians(-6), 0, 0))
        peci = bpy.context.active_object
        peci.name = "PakRtPeci"
        peci.scale = (0.96, 1.04, 1.0)
        apply_bevel_and_smooth(peci, width=0.003 * s_u, segments=2)
        attach_to_bone(peci, arm, "head", mat_peci)
        return peci

    if style == "ojek_helmet":
        mat_helmet = make_matte_mat("OjekHelmet", (0.12, 0.60, 0.28), 0.34, 0.28)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=22, ring_count=14, radius=1.0, location=(cx, cy + 0.020 * s_u, cz + 0.038 * s_u), rotation=(math.radians(12), 0, 0))
        helm = bpy.context.active_object
        helm.name = "OjekHelmet"
        helm.scale = (rx + 0.024 * s_u, ry + 0.016 * s_u, rz + 0.012 * s_u)
        apply_subsurf_and_smooth(helm, levels=1)
        attach_to_bone(helm, arm, "head", mat_helmet)

        mat_visor = make_matte_mat("OjekVisor", (0.10, 0.14, 0.20), 0.22, 0.45)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, hb["y_min"] - 0.014 * s_u, cz + 0.044 * s_u), rotation=(math.radians(14), 0, 0))
        vis = bpy.context.active_object
        vis.name = "OjekVisor"
        vis.scale = (rx * 1.32, 0.050 * s_u, 0.012 * s_u)
        apply_bevel_and_smooth(vis, width=0.003 * s_u, segments=2)
        attach_to_bone(vis, arm, "head", mat_visor)
        return helm

    if style == "cap":
        mat_cap = make_matte_mat("KurirCap", (0.10, 0.18, 0.34), 0.72, 0.14)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=1.0, location=(cx, cy + 0.012 * s_u, cz + 0.034 * s_u), rotation=(math.radians(8), 0, 0))
        c_dome = bpy.context.active_object
        c_dome.name = "KurirCapDome"
        c_dome.scale = (rx + 0.016 * s_u, ry + 0.012 * s_u, rz * 0.72)
        apply_subsurf_and_smooth(c_dome, levels=1)
        attach_to_bone(c_dome, arm, "head", mat_cap)

        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, hb["y_min"] - 0.022 * s_u, cz + 0.032 * s_u), rotation=(math.radians(10), 0, 0))
        brim = bpy.context.active_object
        brim.name = "KurirCapBrim"
        brim.scale = (rx * 1.36, 0.072 * s_u, 0.012 * s_u)
        apply_bevel_and_smooth(brim, width=0.003 * s_u, segments=2)
        attach_to_bone(brim, arm, "head", mat_cap)
        return c_dome
    return None


def _build_mh_skirt(arm, mat_skirt, name: str, zmax: float, pelvis_z: float, long_skirt: bool = False):
    s_u = zmax / 1.72
    if long_skirt:
        rings_cfg = [
            (pelvis_z * 0.28, 0.23 * s_u, 0.20 * s_u, 0.0),
            (pelvis_z * 0.58, 0.22 * s_u, 0.19 * s_u, 0.0),
            (pelvis_z * 0.88, 0.21 * s_u, 0.18 * s_u, 0.0),
            (pelvis_z * 1.18, 0.175 * s_u, 0.145 * s_u, 0.0),
        ]
    else:
        rings_cfg = [
            (pelvis_z * 0.50, 0.23 * s_u, 0.20 * s_u, 0.0),
            (pelvis_z * 0.74, 0.22 * s_u, 0.19 * s_u, 0.0),
            (pelvis_z * 0.96, 0.21 * s_u, 0.18 * s_u, 0.0),
            (pelvis_z * 1.18, 0.175 * s_u, 0.145 * s_u, 0.0),
        ]
    bm = bmesh.new()
    segs = 24
    rings = []
    for z_val, rx_val, ry_val, cy_off in rings_cfg:
        rv = []
        for i in range(segs):
            ang = (2.0 * math.pi * i) / segs
            rv.append(bm.verts.new((math.cos(ang) * rx_val, cy_off + math.sin(ang) * ry_val, z_val)))
        rings.append(rv)
    for r in range(len(rings) - 1):
        for i in range(segs):
            ni = (i + 1) % segs
            bm.faces.new((rings[r][i], rings[r][ni], rings[r + 1][ni], rings[r + 1][i]))
    msh = bpy.data.meshes.new(name + "Mesh")
    bm.to_mesh(msh)
    bm.free()
    obj = bpy.data.objects.new(name, msh)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    sol = obj.modifiers.new("Solidify", 'SOLIDIFY')
    sol.thickness = 0.006 * s_u
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.shade_smooth()
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66))
    bpy.ops.object.mode_set(mode='OBJECT')

    z_hip = pelvis_z * 1.04
    z_bot = rings_cfg[0][0]
    def sk_w(co):
        if co.z >= z_hip:
            return {"pelvis": 1.0}
        t = min(1.0, max(0.0, (z_hip - co.z) / max(0.14 * s_u, z_hip - z_bot)))
        leg_w = 0.65 * t
        hip_w = 1.0 - leg_w
        if co.x > 0.015 * s_u:
            return {"pelvis": hip_w, "thigh_l": leg_w}
        if co.x < -0.015 * s_u:
            return {"pelvis": hip_w, "thigh_r": leg_w}
        return {"pelvis": 1.0}
    attach_multi_bone(obj, arm, mat_skirt, sk_w)
    return obj


def _build_mh_apron(arm, zmax: float, pelvis_z: float, mat_apron, mat_pocket):
    # MakeHuman faces -Y forward in Blender (+Z in Godot)! Place apron & pocket on -Y front!
    s_u = zmax / 1.72
    rows = [
        (pelvis_z * 0.62, 0.165 * s_u, -0.205 * s_u),
        (pelvis_z * 0.88, 0.155 * s_u, -0.195 * s_u),
        (pelvis_z * 1.12, 0.135 * s_u, -0.190 * s_u),
        (pelvis_z * 1.32, 0.118 * s_u, -0.210 * s_u),
        (pelvis_z * 1.50, 0.098 * s_u, -0.180 * s_u),
    ]
    bm = bmesh.new()
    cols = 10
    grid = []
    for rz, hw, fy in rows:
        rv = []
        for c in range(cols + 1):
            t = (c / cols) * 2.0 - 1.0
            rv.append(bm.verts.new((t * hw, fy + (t * t) * 0.032 * s_u, rz)))
        grid.append(rv)
    for r in range(len(grid) - 1):
        for c in range(cols):
            bm.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
    msh = bpy.data.meshes.new("ArtApronMesh")
    bm.to_mesh(msh)
    bm.free()
    apron = bpy.data.objects.new("ArtApron", msh)
    bpy.context.collection.objects.link(apron)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = apron
    apron.select_set(True)
    sol = apron.modifiers.new("Solidify", 'SOLIDIFY')
    sol.thickness = 0.005 * s_u
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.shade_smooth()

    def ap_w(co):
        if co.z >= pelvis_z * 1.25:
            return {"spine_03": 0.70, "spine_01": 0.30}
        if co.x > 0.02 * s_u:
            return {"pelvis": 0.70, "thigh_l": 0.30}
        if co.x < -0.02 * s_u:
            return {"pelvis": 0.70, "thigh_r": 0.30}
        return {"pelvis": 1.0}
    attach_multi_bone(apron, arm, mat_apron, ap_w)

    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -0.205 * s_u, pelvis_z * 0.90))
    pkt = bpy.context.active_object
    pkt.name = "ApronPocket"
    pkt.scale = (0.10 * s_u, 0.012 * s_u, 0.08 * s_u)
    apply_bevel_and_smooth(pkt, width=0.002 * s_u, segments=1)
    attach_to_bone(pkt, arm, "pelvis", mat_pocket)


def _synthesize_mh_action(arm, name: str, key_poses: list):
    """Synthesize clean keyframed pose clip on MakeHuman 22-bone armature (e.g. Fixing_Kneeling / Celebration)."""
    act = bpy.data.actions.new(name=name)
    act.use_fake_user = True
    arm.animation_data.action = act
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
    for frame, bone_rots in key_poses:
        bpy.context.scene.frame_set(frame)
        for pb in arm.pose.bones:
            pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        for bname, euler_deg in bone_rots.items():
            pb = arm.pose.bones.get(bname)
            if pb:
                q = Quaternion((1.0, 0.0, 0.0, 0.0))
                rx, ry, rz = (math.radians(a) for a in euler_deg)
                q = Quaternion((1.0, 0.0, 0.0), rx) @ Quaternion((0.0, 1.0, 0.0), ry) @ Quaternion((0.0, 0.0, 1.0), rz)
                pb.rotation_quaternion = q
                pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)
    return act


def build_mh_character(
    mh_file: str,
    out_filename: str,
    target_h: float = 1.66,
    skin_warmth=None,
    shirt_rgb=None,
    pants_rgb=None,
    batik_cfg=None,
    keep_suit_tex: bool = False,
    strip_mats=(),
    hair_style: str = "none",
    hair_rgb=(0.05, 0.04, 0.04),
    ribbon_rgb=None,
    hijab_rgb=None,
    apron: bool = False,
    skirt_cfg=None,
    is_player: bool = False,
    decimate_ratio: float = 0.46,
):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(CHARKIT_DIR, mh_file))

    for obj in list(bpy.data.objects):
        if obj.type == 'MESH' and 'icosphere' in obj.name.lower():
            bpy.data.objects.remove(obj, do_unlink=True)

    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    body_mesh = next(o for o in bpy.data.objects if o.type == 'MESH')

    # 1. Strip unwanted MakeHuman props (fedora, micky afro, overgrown beard, etc.)
    _delete_materials_faces(body_mesh, strip_mats)

    # 2. Measure height & pelvis before adding custom Indonesian garments
    bpy.context.view_layer.update()
    pts = [v.co for v in body_mesh.data.vertices]
    zmax = max(p.z for p in pts)
    pelvis_z = arm.data.bones["pelvis"].head_local.z
    hb = _measure_head_bounds_mh(body_mesh, arm)

    # 3. Fix MakeHuman Alpha=0, downscale images <= 512px, remove MakeHuman chest logo
    _fix_mh_materials_and_textures(body_mesh, skin_warmth=skin_warmth)
    batik_img = None
    if batik_cfg is not None:
        batik_img = generate_batik_texture(TEX_DIR, batik_cfg["name"], batik_cfg["base"], batik_cfg["accent"])
    _recolor_mh_outfit(
        body_mesh, arm, pelvis_z,
        shirt_rgb=shirt_rgb, pants_rgb=pants_rgb, batik_img=batik_img, keep_suit_tex=keep_suit_tex,
    )

    # 4. Gentle UV+Material delimited Decimate to stay strictly <= 14,500 glTF split verts
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = body_mesh
    body_mesh.select_set(True)
    if len(body_mesh.data.vertices) > 9500:
        dec = body_mesh.modifiers.new("Decimate", 'DECIMATE')
        dec.ratio = decimate_ratio
        dec.delimit = {'MATERIAL', 'UV'}
        dec.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="Decimate")
    bpy.ops.object.shade_smooth()

    # 5. Add Indonesian headwear, skirt, and apron in local MakeHuman coordinates
    _add_headgear(arm, hb, zmax, hair_style, hair_rgb=hair_rgb, ribbon_rgb=ribbon_rgb, hijab_rgb=hijab_rgb)
    if skirt_cfg is not None:
        if batik_img is not None and skirt_cfg.get("use_batik", False):
            mat_skirt = make_pbr_material(skirt_cfg.get("name", "DasterSkirt_Batik"), batik_img, 0.86, None, 0.0, (2.4, 2.4))
        else:
            mat_skirt = make_matte_mat(skirt_cfg.get("name", "Skirt"), skirt_cfg["color"], 0.86)
        _build_mh_skirt(arm, mat_skirt, skirt_cfg.get("obj_name", "DasterSkirt"), zmax, pelvis_z, long_skirt=skirt_cfg.get("long", False))
    if apron:
        mat_apron = make_matte_mat("ArtApron", (0.95, 0.92, 0.84), 0.86)
        mat_pocket = make_matte_mat("ApronPocket", (0.68, 0.58, 0.44), 0.88)
        _build_mh_apron(arm, zmax, pelvis_z, mat_apron, mat_pocket)

    # 6. Keep ONLY life-sim clips from NLA tracks + synthesize Fixing_Kneeling & Celebration for Player
    kept_tracks = []
    if arm.animation_data:
        for tr in list(arm.animation_data.nla_tracks):
            base = tr.name.strip()
            if base in KEEP_MH_CLIPS:
                new_name = KEEP_MH_CLIPS[base]
                tr.name = new_name
                for st in tr.strips:
                    if st.action:
                        st.action.name = new_name
                        st.action.use_fake_user = True
                kept_tracks.append(tr)
            else:
                arm.animation_data.nla_tracks.remove(tr)

    # Synthesize Clean & Celebrate on all characters so player + NPCs + Godot tests all have Clean/Celebrate clips
    clean_act = _synthesize_mh_action(arm, "Clean", [
        (1, {"spine_01": (14, 0, 0), "upperarm_r": (-28, 0, -14), "lowerarm_r": (-35, 0, 0), "upperarm_l": (-18, 0, 12)}),
        (10, {"spine_01": (20, 0, 6), "upperarm_r": (-40, 0, -24), "lowerarm_r": (-22, 0, -8), "upperarm_l": (-18, 0, 12)}),
        (20, {"spine_01": (14, 0, -6), "upperarm_r": (-24, 0, -8), "lowerarm_r": (-38, 0, 6), "upperarm_l": (-18, 0, 12)}),
        (30, {"spine_01": (14, 0, 0), "upperarm_r": (-28, 0, -14), "lowerarm_r": (-35, 0, 0), "upperarm_l": (-18, 0, 12)}),
    ])
    tr_clean = arm.animation_data.nla_tracks.new()
    tr_clean.name = "Clean"
    tr_clean.strips.new("Clean", 1, clean_act)
    tr_clean.mute = True

    cel_act = _synthesize_mh_action(arm, "Celebrate", [
        (1, {"spine_01": (-5, 0, 0), "upperarm_l": (-40, 0, 48), "upperarm_r": (-40, 0, -48), "lowerarm_l": (-15, 0, 0), "lowerarm_r": (-15, 0, 0)}),
        (12, {"spine_01": (-8, 0, 4), "upperarm_l": (-52, 0, 64), "upperarm_r": (-52, 0, -64), "lowerarm_l": (-8, 0, 0), "lowerarm_r": (-8, 0, 0)}),
        (24, {"spine_01": (-5, 0, 0), "upperarm_l": (-40, 0, 48), "upperarm_r": (-40, 0, -48), "lowerarm_l": (-15, 0, 0), "lowerarm_r": (-15, 0, 0)}),
    ])
    tr_cel = arm.animation_data.nla_tracks.new()
    tr_cel.name = "Celebrate"
    tr_cel.strips.new("Celebrate", 1, cel_act)
    tr_cel.mute = True

    # Reset pose & evaluate Idle NLA at frame 1 so default rest/exported pose has natural arms at sides!
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
    for tr in arm.animation_data.nla_tracks:
        tr.mute = (tr.name != "Idle")
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    for tr in arm.animation_data.nla_tracks:
        tr.mute = False

    # Clean unused actions
    for act in list(bpy.data.actions):
        if not act.use_fake_user and act.users == 0:
            bpy.data.actions.remove(act)

    # 7. Normalize character real-world height cleanly via armature scale (keeps hip-height root motion scaled too!)
    s_norm = target_h / max(0.5, zmax)
    arm.scale = (arm.scale.x * s_norm, arm.scale.y * s_norm, arm.scale.z * s_norm)

    total_verts = sum(len(o.data.vertices) for o in bpy.data.objects if o.type == 'MESH')
    assert total_verts <= 14500, f"{out_filename} exceeded 14500 vert budget: {total_verts}"
    out_path = os.path.join(MODELS_DIR, out_filename)
    os.makedirs(MODELS_DIR, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out_path, export_format='GLB',
        export_animations=True, export_nla_strips=True, export_nla_strips_merged_animation_name="Idle",
    )
    print("EXPORTED MAKEHUMAN CHAR:", out_path, "verts=", total_verts, "bytes=", os.path.getsize(out_path))


if __name__ == "__main__":
    # 4 Player Tiers (mh_1000 Asian female base, full Indonesian daster/uniform + cepol/hijab + Fixing_Kneeling/Celebration)
    build_mh_character(
        "mh_1000.glb", "char_art.glb", target_h=1.64,
        skin_warmth=(0.94, 0.86, 0.80), shirt_rgb=(0.14, 0.36, 0.26), pants_rgb=(0.14, 0.20, 0.16),
        batik_cfg={"name": "daster_art_starter", "base": (0.14, 0.36, 0.26), "accent": (0.92, 0.76, 0.38)},
        strip_mats=("fedora", "afro"), hair_style="cepol", ribbon_rgb=(0.76, 0.24, 0.18),
        apron=True, skirt_cfg={"name": "DasterSkirt_Batik", "obj_name": "DasterSkirt", "use_batik": True, "long": False},
        is_player=True, decimate_ratio=0.40,
    )
    build_mh_character(
        "mh_1000.glb", "char_art_hijab.glb", target_h=1.64,
        skin_warmth=(0.94, 0.86, 0.80), shirt_rgb=(0.16, 0.34, 0.42), pants_rgb=(0.12, 0.16, 0.22),
        batik_cfg={"name": "daster_art_hijab", "base": (0.16, 0.34, 0.42), "accent": (0.90, 0.80, 0.56)},
        strip_mats=("fedora", "afro"), hair_style="hijab_bergo", hijab_rgb=(0.14, 0.30, 0.22),
        apron=True, skirt_cfg={"name": "DasterHijab_Batik", "obj_name": "DasterSkirt", "use_batik": True, "long": True},
        is_player=True, decimate_ratio=0.40,
    )
    build_mh_character(
        "mh_1000.glb", "char_art_pro.glb", target_h=1.64,
        skin_warmth=(0.94, 0.86, 0.80), shirt_rgb=(0.08, 0.34, 0.34), pants_rgb=(0.10, 0.14, 0.20),
        strip_mats=("fedora", "afro"), hair_style="cepol", ribbon_rgb=(0.12, 0.42, 0.40),
        apron=True, is_player=True, decimate_ratio=0.40,
    )
    build_mh_character(
        "mh_1000.glb", "char_art_elite.glb", target_h=1.64,
        skin_warmth=(0.94, 0.86, 0.80), shirt_rgb=(0.09, 0.16, 0.28), pants_rgb=(0.08, 0.10, 0.16),
        strip_mats=("fedora", "afro"), hair_style="cepol", ribbon_rgb=(0.82, 0.80, 0.76),
        apron=True, is_player=True, decimate_ratio=0.40,
    )

    # 3 Shift NPCs (unique MakeHuman bases)
    build_mh_character(
        "mh_3488.glb", "char_ibu.glb", target_h=1.66,
        skin_warmth=(1.10, 0.96, 0.88), shirt_rgb=(0.48, 0.14, 0.12), pants_rgb=(0.16, 0.10, 0.10),
        batik_cfg={"name": "batik_ibu", "base": (0.48, 0.14, 0.12), "accent": (0.88, 0.66, 0.26)},
        strip_mats=("katherine",), hair_style="hijab_bergo", hijab_rgb=(0.24, 0.06, 0.08),
        skirt_cfg={"name": "IbuLongSkirt", "obj_name": "LongSkirt", "use_batik": False, "color": (0.16, 0.10, 0.09), "long": True},
        decimate_ratio=0.38,
    )
    build_mh_character(
        "mh_3183.glb", "char_kakak.glb", target_h=1.65,
        skin_warmth=(1.08, 0.94, 0.86), shirt_rgb=(0.64, 0.28, 0.36), pants_rgb=(0.18, 0.22, 0.32),
        hair_style="none",
        skirt_cfg={"name": "KakakSkirt", "obj_name": "KakakSkirt", "use_batik": False, "color": (0.18, 0.22, 0.32), "long": False},
        decimate_ratio=0.48,
    )
    build_mh_character(
        "mh_1037.glb", "char_budi.glb", target_h=1.74,
        skin_warmth=(0.94, 0.86, 0.80), shirt_rgb=(0.14, 0.26, 0.16), pants_rgb=(0.12, 0.13, 0.16),
        batik_cfg={"name": "batik_budi", "base": (0.14, 0.26, 0.16), "accent": (0.76, 0.62, 0.26)},
        strip_mats=("faun_beard",), hair_style="none", decimate_ratio=0.45,
    )

    # 8 Unique Street NPCs (MakeHuman CC0 cohesive cast!)
    build_mh_character(
        "mh_3183.glb", "char_dewi.glb", target_h=1.63,
        skin_warmth=(1.04, 0.92, 0.84), shirt_rgb=(0.82, 0.36, 0.24), pants_rgb=(0.16, 0.22, 0.36),
        strip_mats=("bob_with_bangs",), hair_style="ponytail", decimate_ratio=0.48,
    )
    build_mh_character(
        "mh_3549.glb", "char_pak_rt.glb", target_h=1.71,
        skin_warmth=(0.94, 0.86, 0.80), shirt_rgb=(0.50, 0.36, 0.16), pants_rgb=(0.12, 0.12, 0.15),
        batik_cfg={"name": "batik_pak_rt", "base": (0.48, 0.34, 0.15), "accent": (0.92, 0.78, 0.42)},
        hair_style="peci", decimate_ratio=0.40,
    )
    build_mh_character(
        "mh_3427.glb", "char_ojek.glb", target_h=1.72,
        skin_warmth=(1.04, 0.92, 0.84), shirt_rgb=(0.10, 0.56, 0.24), pants_rgb=(0.14, 0.18, 0.30),
        strip_mats=("moustache", "hair", "afro", "fedora", "katherine", "bob"), hair_style="ojek_helmet", decimate_ratio=0.50,
    )
    build_mh_character(
        "mh_1148.glb", "char_kurir.glb", target_h=1.72,
        skin_warmth=(0.94, 0.86, 0.80), shirt_rgb=(0.88, 0.40, 0.12), pants_rgb=(0.15, 0.18, 0.26),
        strip_mats=("moustache", "hair", "afro", "fedora", "katherine", "bob"), hair_style="cap", decimate_ratio=0.54,
    )
    build_mh_character(
        "mh_1000.glb", "char_pelajar.glb", target_h=1.60,
        skin_warmth=(0.96, 0.88, 0.82), shirt_rgb=(0.90, 0.90, 0.88), pants_rgb=(0.34, 0.36, 0.42),
        strip_mats=("fedora", "afro"), hair_style="ponytail",
        skirt_cfg={"name": "SmaSkirt", "obj_name": "SmaSkirt", "use_batik": False, "color": (0.34, 0.36, 0.42), "long": False},
        decimate_ratio=0.42,
    )
    build_mh_character(
        "mh_3000.glb", "char_hendra.glb", target_h=1.73,
        skin_warmth=(0.92, 0.84, 0.78), keep_suit_tex=True,
        strip_mats=("beard",), hair_style="none", decimate_ratio=0.46,
    )
    build_mh_character(
        "mh_3488.glb", "char_rina.glb", target_h=1.64,
        skin_warmth=(1.08, 0.94, 0.86), shirt_rgb=(0.46, 0.34, 0.58), pants_rgb=(0.16, 0.16, 0.20),
        strip_mats=("katherine",), hair_style="hijab_bergo", hijab_rgb=(0.82, 0.76, 0.66),
        skirt_cfg={"name": "RinaSkirt", "obj_name": "RinaSkirt", "use_batik": False, "color": (0.18, 0.16, 0.24), "long": True},
        decimate_ratio=0.38,
    )
    build_mh_character(
        "mh_3427.glb", "char_agus.glb", target_h=1.71,
        skin_warmth=(1.02, 0.90, 0.82), shirt_rgb=(0.48, 0.24, 0.14), pants_rgb=(0.16, 0.15, 0.14),
        batik_cfg={"name": "batik_agus", "base": (0.48, 0.24, 0.14), "accent": (0.86, 0.70, 0.36)},
        hair_style="none", decimate_ratio=0.50,
    )
