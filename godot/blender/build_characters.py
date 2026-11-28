import os
import sys
import math
import numpy as np
import bpy
import bmesh
from mathutils import Quaternion, Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from tex_utils import save_rgba_png, make_pbr_material

GODOT_DIR = os.path.dirname(SCRIPT_DIR)
REPO_DIR = os.path.dirname(GODOT_DIR)
TEX_DIR = os.path.join(GODOT_DIR, "assets", "textures")
RAW_DIR = os.path.join(GODOT_DIR, "assets", "raw")
CHARKIT_DIR = os.path.join(RAW_DIR, "charkit")
MODELS_DIR = os.path.join(GODOT_DIR, "assets", "models")
BUILD_DIR = os.path.join(REPO_DIR, "build")

KEEP_MH_CLIPS = {
    "idle": "Idle",
    "walk": "Walk",
    "idle_unarmed": "Talk",
    "turn_left": "Turn_L",
    "jump": "Jump",
}


def srgb_hex_to_linear(hex_str: str):
    h = hex_str.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return tuple((c ** 2.2) for c in (r, g, b))


def make_matte_mat(name: str, rgb, roughness: float = 0.80, specular: float = 0.16):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = specular
    return mat


def generate_batik_1024(tex_dir: str, name: str, base_rgb, accent_rgb):
    """Crisp 1024x1024 Indonesian parang/floral batik texture with woven cotton grain."""
    size = 1024
    yy, xx = np.mgrid[0:size, 0:size]
    u = xx / float(size)
    v = yy / float(size)

    ku = (u * 6.0) % 1.0 - 0.5
    kv = (v * 6.0) % 1.0 - 0.5
    r = np.sqrt(ku * ku + kv * kv)
    theta = np.arctan2(kv, ku)

    petal = np.exp(-((r - 0.24) * 14.0) ** 2) * (0.5 + 0.5 * np.cos(6.0 * theta))
    center_dot = np.exp(-(r * 16.0) ** 2)
    vine = np.exp(-((np.sin(u * math.pi * 12.0 + v * math.pi * 6.0)) * 6.0) ** 2) * 0.45
    cecek = ((np.sin(u * math.pi * 48.0) * np.sin(v * math.pi * 48.0)) > 0.72).astype(np.float32) * 0.35
    motif = np.clip(petal + center_dot + vine + cecek, 0.0, 1.0)

    weave = 0.96 + 0.04 * (np.sin(u * math.pi * 180.0) * np.sin(v * math.pi * 180.0))
    b_arr = np.array(base_rgb, dtype=np.float32)
    a_arr = np.array(accent_rgb, dtype=np.float32)
    rgb = (b_arr * (1.0 - motif[..., None]) + a_arr * motif[..., None]) * weave[..., None]
    rgb = np.clip(rgb, 0.0, 1.0)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, non_color=False)


def generate_cream_apron_1024(tex_dir: str):
    """Crisp 1024x1024 cream cotton apron texture with subtle weave and hem stitching."""
    size = 1024
    yy, xx = np.mgrid[0:size, 0:size]
    u = xx / float(size)
    v = yy / float(size)

    weave = 0.97 + 0.03 * (np.sin(u * math.pi * 220.0) * 0.5 + np.sin(v * math.pi * 220.0) * 0.5)
    edge_dist = np.minimum(np.minimum(u, 1.0 - u), np.minimum(v, 1.0 - v))
    hem_band = np.exp(-((edge_dist - 0.035) * 90.0) ** 2) * 0.08
    dash = ((np.sin((u + v) * math.pi * 96.0)) > 0.15).astype(np.float32)
    stitch = np.exp(-((edge_dist - 0.022) * 180.0) ** 2) * dash * 0.22

    base_rgb = np.array([0.94, 0.90, 0.82], dtype=np.float32)
    stitch_rgb = np.array([0.62, 0.54, 0.42], dtype=np.float32)
    rgb = base_rgb * weave[..., None] * (1.0 - hem_band[..., None])
    rgb = rgb * (1.0 - stitch[..., None]) + stitch_rgb * stitch[..., None]
    rgb = np.clip(rgb, 0.0, 1.0)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png("apron_cream_cotton_1024", rgba, tex_dir, non_color=False)


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


def _fix_mh_materials_and_textures(mesh_obj, skin_warmth=None, dark_hair: bool = False, is_player: bool = False):
    """Fix Alpha=0, warm Indonesian skin pixels via C-buffer foreach_get/set, and polish hair sheen."""
    seen_imgs = set()
    for m in mesh_obj.data.materials:
        if not m or not m.use_nodes:
            continue
        m.blend_method = 'OPAQUE'
        mname = m.name.lower()
        is_body = any(k in mname for k in ("body", "skin", "caucasian", "african", "asian", "young_", "middleage_", "old_"))
        is_hair = any(k in mname for k in ("hair", "katherine", "bob_with_bangs"))
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            if "Alpha" in bsdf.inputs:
                bsdf.inputs["Alpha"].default_value = 1.0
                for lk in list(bsdf.inputs["Alpha"].links):
                    m.node_tree.links.remove(lk)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = 0.0
            if "Roughness" in bsdf.inputs:
                if any(k in mname for k in ("eye", "iris", "cornea")):
                    bsdf.inputs["Roughness"].default_value = 0.10
                    if "Specular IOR Level" in bsdf.inputs:
                        bsdf.inputs["Specular IOR Level"].default_value = 0.65
                elif is_body:
                    bsdf.inputs["Roughness"].default_value = 0.56
                elif is_hair:
                    bsdf.inputs["Roughness"].default_value = 0.42
                    if "Specular IOR Level" in bsdf.inputs:
                        bsdf.inputs["Specular IOR Level"].default_value = 0.36
                else:
                    bsdf.inputs["Roughness"].default_value = max(0.60, bsdf.inputs["Roughness"].default_value)
            if dark_hair and is_hair:
                for lk in list(bsdf.inputs["Base Color"].links):
                    m.node_tree.links.remove(lk)
                bsdf.inputs["Base Color"].default_value = (*srgb_hex_to_linear("#1D1614"), 1.0)
                bsdf.inputs["Roughness"].default_value = 0.42

        max_dim = (1024 if is_player else 512) if is_body else (512 if is_player else 256)
        for node in m.node_tree.nodes:
            if node.type == 'TEX_IMAGE' and node.image is not None:
                img = node.image
                if img.name in seen_imgs:
                    continue
                seen_imgs.add(img.name)
                w, h = img.size[0], img.size[1]
                if w <= 0 or h <= 0:
                    continue
                if w > max_dim or h > max_dim:
                    scale_f = min(max_dim / max(1, w), max_dim / max(1, h))
                    nw = max(64, int(round(w * scale_f)))
                    nh = max(64, int(round(h * scale_f)))
                    img.scale(nw, nh)
                    w, h = nw, nh
                if is_body and w > 0 and h > 0:
                    flat = np.empty(w * h * 4, dtype=np.float32)
                    img.pixels.foreach_get(flat)
                    px = flat.reshape(-1, 4)
                    luma = 0.299 * px[:, 0] + 0.587 * px[:, 1] + 0.114 * px[:, 2]
                    skin_mask = luma > 0.22
                    avg_luma = float(np.mean(luma[skin_mask])) if np.any(skin_mask) else 0.5
                    # Normalize diverse MakeHuman base textures toward warm Indonesian skin
                    if skin_warmth is not None:
                        tint = np.array(skin_warmth, dtype=np.float32)
                    elif avg_luma > 0.54:
                        tint = np.array((0.84, 0.68, 0.50), dtype=np.float32)
                    elif avg_luma > 0.34:
                        tint = np.array((0.90, 0.76, 0.58), dtype=np.float32)
                    else:
                        tint = np.array((1.02, 0.90, 0.78), dtype=np.float32)
                    px[:, :3] = np.where(skin_mask[:, None], np.clip(px[:, :3] * tint, 0.0, 1.0), px[:, :3])
                    new_img = bpy.data.images.new(f"{img.name}_warm", width=w, height=h, alpha=True, float_buffer=False)
                    new_img.colorspace_settings.name = img.colorspace_settings.name
                    new_img.pixels.foreach_set(flat)
                    new_img.pack()
                    node.image = new_img
                    seen_imgs.add(new_img.name)
                else:
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
    """Replace MakeHuman chest-logo suit material with clean Indonesian Shirt + Pants via connected mesh islands."""
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


def _import_sculpted_hair(arm, body_mesh, hb: dict, zmax: float, src_glb: str, mat_substr: str, hair_hex: str = "#1D1614", decimate_ratio: float = 1.0):
    """Transfer real sculpted MakeHuman hair aligned dynamically to target skull bounding box."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(CHARKIT_DIR, src_glb))
    new_objs = [o for o in bpy.data.objects if o not in before]
    src_mesh = max((o for o in new_objs if o.type == 'MESH'), key=lambda o: len(o.data.vertices))

    hair_idx = {i for i, m in enumerate(src_mesh.data.materials) if m and mat_substr in m.name.lower()}
    assert hair_idx, f"{mat_substr} not found in {src_glb}"

    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = src_mesh
    src_mesh.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.object.mode_set(mode='OBJECT')
    for p in src_mesh.data.polygons:
        if p.material_index not in hair_idx:
            p.select = True
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.delete(type='FACE')
    bpy.ops.object.mode_set(mode='OBJECT')

    src_mesh.parent = None
    for mod in list(src_mesh.modifiers):
        src_mesh.modifiers.remove(mod)
    src_mesh.vertex_groups.clear()
    for o in new_objs:
        if o != src_mesh:
            bpy.data.objects.remove(o, do_unlink=True)

    src_mesh.name = "SculptedHair"
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = src_mesh
    src_mesh.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    if decimate_ratio < 0.99:
        dec = src_mesh.modifiers.new("HairDecimate", 'DECIMATE')
        dec.ratio = decimate_ratio
        dec.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="HairDecimate")

    pts = [v.co for v in src_mesh.data.vertices]
    hx_min, hx_max = min(p.x for p in pts), max(p.x for p in pts)
    hy_min, hy_max = min(p.y for p in pts), max(p.y for p in pts)
    hz_max = max(p.z for p in pts)
    hx_c = 0.5 * (hx_min + hx_max)
    hy_c = 0.5 * (hy_min + hy_max)
    h_rx = max(0.05, 0.5 * (hx_max - hx_min))
    h_ry = max(0.05, 0.5 * (hy_max - hy_min))
    s_u = zmax / 1.72

    fit_x = min(0.98, (hb["rx"] * 1.24) / h_rx)
    fit_y = min(0.98, (hb["ry"] * 1.20) / h_ry)
    fit_scale = max(0.94, min(fit_x, fit_y))
    dz = hb["z_max"] - hz_max + 0.044 * s_u
    dy = (hb["cy"] - hy_c) + 0.006 * s_u
    dx = hb["cx"] - hx_c

    for v in src_mesh.data.vertices:
        v.co.x = hx_c + (v.co.x - hx_c) * fit_scale + dx
        v.co.y = hy_c + (v.co.y - hy_c) * fit_scale + dy
        v.co.z = hz_max + (v.co.z - hz_max) * fit_scale + dz

    mat_hair = make_matte_mat("SculptedHair_Dark", srgb_hex_to_linear(hair_hex), roughness=0.42, specular=0.36)
    src_mesh.data.materials.clear()
    src_mesh.data.materials.append(mat_hair)
    vg = src_mesh.vertex_groups.new(name="head")
    vg.add(list(range(len(src_mesh.data.vertices))), 1.0, 'REPLACE')
    src_mesh.parent = arm
    mod = src_mesh.modifiers.new(name="Armature", type='ARMATURE')
    mod.object = arm
    bpy.ops.object.shade_smooth()
    return src_mesh


def _add_headgear(arm, body_mesh, hb: dict, zmax: float, style: str, hair_hex: str = "#1D1614", hijab_rgb=None, is_player: bool = True):
    cx, cy, cz = hb["cx"], hb["cy"], hb["cz"]
    rx, ry, rz = hb["rx"], hb["ry"], hb["rz"]
    s_u = zmax / 1.72

    if style == "none":
        return None

    if style == "sculpted_katherine":
        return _import_sculpted_hair(arm, body_mesh, hb, zmax, "mh_3488.glb", "katherine", hair_hex=hair_hex, decimate_ratio=1.0 if is_player else 0.58)

    if style == "sculpted_bob":
        return _import_sculpted_hair(arm, body_mesh, hb, zmax, "mh_3183.glb", "bob_with_bangs", hair_hex=hair_hex, decimate_ratio=1.0 if is_player else 0.72)

    if style == "hijab_bergo":
        h_col = hijab_rgb or (0.14, 0.30, 0.22)
        mat_hijab = make_matte_mat("HijabBergo", h_col, 0.84, 0.14)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=22, ring_count=14, radius=1.0, location=(cx, cy + 0.030 * s_u, cz + 0.024 * s_u), rotation=(math.radians(10), 0, 0))
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

    if style == "peci":
        mat_peci = make_matte_mat("PeciVelvet", (0.04, 0.04, 0.05), 0.88, 0.08)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=rx + 0.008 * s_u, depth=0.092 * s_u, location=(cx, cy + 0.006 * s_u, hb["z_max"] - 0.004 * s_u), rotation=(math.radians(-4), 0, 0))
        peci = bpy.context.active_object
        peci.name = "PakRtPeci"
        peci.scale = (0.95, 1.06, 1.0)
        apply_bevel_and_smooth(peci, width=0.004 * s_u, segments=2)
        attach_to_bone(peci, arm, "head", mat_peci)
        return peci

    if style == "ojek_helmet":
        mat_helmet = make_matte_mat("OjekHelmet", (0.06, 0.44, 0.16), 0.22, 0.44)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1.0, location=(cx, cy + 0.026 * s_u, cz + 0.048 * s_u), rotation=(math.radians(10), 0, 0))
        helm = bpy.context.active_object
        helm.name = "OjekHelmet"
        helm.scale = (rx + 0.024 * s_u, ry + 0.022 * s_u, rz * 0.84)
        apply_subsurf_and_smooth(helm, levels=1)
        attach_to_bone(helm, arm, "head", mat_helmet)

        mat_visor = make_matte_mat("OjekVisor", (0.05, 0.07, 0.10), 0.12, 0.68)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=rx + 0.018 * s_u, depth=0.026 * s_u, location=(cx, hb["y_min"] + 0.020 * s_u, cz + 0.042 * s_u), rotation=(math.radians(8), 0, 0))
        vis = bpy.context.active_object
        vis.name = "OjekVisor"
        vis.scale = (0.92, 0.40, 0.80)
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


def _prune_and_normalize_garment_weights(target_obj):
    forbidden_prefixes = ("upperarm", "lowerarm", "hand", "thumb", "index", "middle", "ring", "pinky", "wrist", "head", "neck", "clavicle")
    for vg in list(target_obj.vertex_groups):
        if any(vg.name.lower().startswith(p) for p in forbidden_prefixes):
            target_obj.vertex_groups.remove(vg)
    for idx in range(len(target_obj.data.vertices)):
        v = target_obj.data.vertices[idx]
        groups = [(g.group, g.weight) for g in v.groups]
        tot = sum(w for _, w in groups)
        if tot > 0.0:
            for gid, w in groups:
                target_obj.vertex_groups[gid].add([idx], w / tot, 'REPLACE')
        else:
            vg_p = target_obj.vertex_groups.get("pelvis") or target_obj.vertex_groups.new(name="pelvis")
            vg_p.add([idx], 1.0, 'REPLACE')


def _build_body_topo_garments(arm, body_mesh, zmax: float, pelvis_z: float, skirt_cfg=None, apron: bool = False, apron_img=None, batik_img=None):
    """Build nested zero-clip skirt + rounded apron + pocket via datalayout_transfer + NEAREST lockstep cascade."""
    s_u = zmax / 1.68
    skirt = None
    rx_top, ry_top = 0.192 * s_u, 0.154 * s_u
    rx_bot, ry_bot = 0.240 * s_u, 0.200 * s_u
    rx_top_sk, ry_top_sk = rx_top, ry_top
    rx_bot_sk, ry_bot_sk = rx_bot, ry_bot
    z_top = pelvis_z * 1.09
    z_bot = pelvis_z * (0.28 if (skirt_cfg and skirt_cfg.get("long", False)) else 0.44)

    if skirt_cfg is not None:
        # Measure actual torso waist & hip widths before tucking (exclude arms out to sides)
        waist_pts = [v.co for v in body_mesh.data.vertices
                     if abs(v.co.z - z_top) < 0.040 * s_u and abs(v.co.x) < 0.145 * s_u and abs(v.co.y) < 0.130 * s_u]
        waist_rx = max((abs(p.x) for p in waist_pts), default=0.132 * s_u)
        waist_ry = max((abs(p.y) for p in waist_pts), default=0.105 * s_u)
        hip_pts = [v.co for v in body_mesh.data.vertices
                   if abs(v.co.z - pelvis_z * 0.96) < 0.055 * s_u and abs(v.co.x) < 0.165 * s_u and abs(v.co.y) < 0.140 * s_u]
        hip_rx = max((abs(p.x) for p in hip_pts), default=0.155 * s_u)
        hip_ry = max((abs(p.y) for p in hip_pts), default=0.125 * s_u)

        # Tuck underlying tunic/shirt hem inside skirt waist so shirt never pokes through skirt
        tuck_z_hi = z_top + 0.015 * s_u
        tuck_z_lo = z_bot
        tuck_x_lim = max(waist_rx, hip_rx) + 0.018 * s_u
        for v in body_mesh.data.vertices:
            if tuck_z_lo <= v.co.z <= tuck_z_hi and abs(v.co.x) < tuck_x_lim:
                t_w = max(0.0, min(1.0, (tuck_z_hi - v.co.z) / 0.08))
                shrink = 1.0 - 0.15 * t_w
                v.co.x *= shrink
                v.co.y *= shrink

        rx_top_sk = max(0.118 * s_u, waist_rx + 0.008 * s_u)
        ry_top_sk = max(0.096 * s_u, waist_ry + 0.008 * s_u)
        rx_bot_sk = max(rx_top_sk + 0.040 * s_u, hip_rx + 0.030 * s_u, 0.178 * s_u)
        ry_bot_sk = max(ry_top_sk + 0.036 * s_u, hip_ry + 0.030 * s_u, 0.152 * s_u)
        bm = bmesh.new()
        segs = 20
        rings = 8
        ring_verts = []
        for r in range(rings + 1):
            t = r / rings
            rz = z_top * (1.0 - t) + z_bot * t
            # Slight tailored curve over hips before falling smoothly to hem
            ease_t = math.pow(t, 0.82)
            rx = rx_top_sk * (1.0 - ease_t) + rx_bot_sk * ease_t
            ry = ry_top_sk * (1.0 - ease_t) + ry_bot_sk * ease_t
            rv = []
            for i in range(segs):
                ang = (2.0 * math.pi * i) / segs
                rv.append(bm.verts.new((math.cos(ang) * rx, math.sin(ang) * ry, rz)))
            ring_verts.append(rv)
        uv_layer = bm.loops.layers.uv.new("UVMap")
        for r in range(rings):
            for i in range(segs):
                ni = (i + 1) % segs
                f = bm.faces.new((ring_verts[r][i], ring_verts[r][ni], ring_verts[r + 1][ni], ring_verts[r + 1][i]))
                for loop, (uu, vv) in zip(f.loops, [(i / segs, 1.0 - r / rings), ((i + 1) / segs, 1.0 - r / rings), ((i + 1) / segs, 1.0 - (r + 1) / rings), (i / segs, 1.0 - (r + 1) / rings)]):
                    loop[uv_layer].uv = (uu, vv)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        sk_obj_name = skirt_cfg.get("obj_name", "DasterSkirt")
        msh_skirt = bpy.data.meshes.new(sk_obj_name + "Mesh")
        bm.to_mesh(msh_skirt)
        bm.free()
        skirt = bpy.data.objects.new(sk_obj_name, msh_skirt)
        bpy.context.collection.objects.link(skirt)

        bpy.ops.object.select_all(action='DESELECT')
        bpy.context.view_layer.objects.active = skirt
        skirt.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        sub_s = skirt.modifiers.new("Subsurf", 'SUBSURF')
        sub_s.levels = 1
        sub_s.render_levels = 1
        bpy.ops.object.modifier_apply(modifier=sub_s.name)
        bpy.ops.object.shade_smooth()

        if batik_img is not None and skirt_cfg.get("use_batik", False):
            mat_skirt = make_pbr_material(skirt_cfg.get("name", "DasterSkirt_Batik"), batik_img, 0.86, None, 0.0, (2.4, 2.4))
        else:
            mat_skirt = make_matte_mat(skirt_cfg.get("name", "Skirt"), skirt_cfg.get("color", (0.18, 0.22, 0.32)), 0.86)
        mat_skirt.use_backface_culling = False
        skirt.data.materials.append(mat_skirt)

        dt_s = skirt.modifiers.new("DataTransfer", 'DATA_TRANSFER')
        dt_s.object = body_mesh
        dt_s.use_vert_data = True
        dt_s.data_types_verts = {'VGROUP_WEIGHTS'}
        dt_s.vert_mapping = 'POLYINTERP_NEAREST'
        bpy.ops.object.datalayout_transfer(modifier=dt_s.name)
        bpy.ops.object.modifier_apply(modifier=dt_s.name)
        _prune_and_normalize_garment_weights(skirt)

        skirt.parent = arm
        skirt.modifiers.new("Armature", 'ARMATURE').object = arm

    if apron:
        bm = bmesh.new()
        cols, rows = 8, 6
        z_a_top = pelvis_z * 1.12
        z_a_bot = pelvis_z * 0.54
        grid = []
        rx_a_top = rx_top_sk if skirt_cfg is not None else rx_top
        ry_a_top = ry_top_sk if skirt_cfg is not None else ry_top
        rx_a_bot = rx_bot_sk if skirt_cfg is not None else rx_bot
        ry_a_bot = ry_bot_sk if skirt_cfg is not None else ry_bot
        for r in range(rows + 1):
            tr = r / rows
            rz = z_a_top * (1.0 - tr) + z_a_bot * tr
            ts = max(0.0, min(1.0, (z_top - rz) / max(0.01, z_top - z_bot)))
            ease_ts = math.pow(ts, 0.82) if skirt_cfg is not None else ts
            sk_rx = rx_a_top * (1.0 - ease_ts) + rx_a_bot * ease_ts + (0.018 + 0.012 * tr) * s_u
            sk_ry = ry_a_top * (1.0 - ease_ts) + ry_a_bot * ease_ts + (0.020 + 0.014 * tr) * s_u
            max_ang = math.radians(46.0 + 10.0 * tr)
            rv = []
            for c in range(cols + 1):
                tc = (c / cols) * 2.0 - 1.0
                corner_t = max(0.0, abs(tc) - 0.55) / 0.45
                rz_pt = rz + (0.032 * s_u * (corner_t ** 1.6) * (tr ** 2.0))
                ang = tc * max_ang * (1.0 - 0.10 * corner_t * (tr ** 2.0)) - math.pi * 0.5
                rv.append(bm.verts.new((math.cos(ang) * sk_rx, math.sin(ang) * sk_ry, rz_pt)))
            grid.append(rv)
        uv_layer = bm.loops.layers.uv.new("UVMap")
        for r in range(rows):
            for c in range(cols):
                f = bm.faces.new((grid[r][c], grid[r + 1][c], grid[r + 1][c + 1], grid[r][c + 1]))
                for loop, (uu, vv) in zip(f.loops, [(c / cols, 1.0 - r / rows), (c / cols, 1.0 - (r + 1) / rows), ((c + 1) / cols, 1.0 - (r + 1) / rows), ((c + 1) / cols, 1.0 - r / rows)]):
                    loop[uv_layer].uv = (uu, vv)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        msh_apron = bpy.data.meshes.new("ArtApronMesh")
        bm.to_mesh(msh_apron)
        bm.free()
        apron_obj = bpy.data.objects.new("ArtApron", msh_apron)
        bpy.context.collection.objects.link(apron_obj)

        bpy.ops.object.select_all(action='DESELECT')
        bpy.context.view_layer.objects.active = apron_obj
        apron_obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

        sub_a = apron_obj.modifiers.new("Subsurf", 'SUBSURF')
        sub_a.levels = 1
        sub_a.render_levels = 1
        sub_a.boundary_smooth = 'PRESERVE_CORNERS'
        bpy.ops.object.modifier_apply(modifier=sub_a.name)

        sol_a = apron_obj.modifiers.new("Solidify", 'SOLIDIFY')
        sol_a.thickness = 0.004 * s_u
        sol_a.offset = 1.0
        bpy.ops.object.modifier_apply(modifier=sol_a.name)
        bpy.ops.object.shade_smooth()

        mat_apron = make_pbr_material("ArtApron_Cream", apron_img, 0.86, None, 0.0, (1.0, 1.0))
        apron_obj.data.materials.append(mat_apron)

        dt_a = apron_obj.modifiers.new("DataTransfer", 'DATA_TRANSFER')
        dt_a.object = skirt if skirt is not None else body_mesh
        dt_a.use_vert_data = True
        dt_a.data_types_verts = {'VGROUP_WEIGHTS'}
        dt_a.vert_mapping = 'NEAREST' if skirt is not None else 'POLYINTERP_NEAREST'
        bpy.ops.object.datalayout_transfer(modifier=dt_a.name)
        bpy.ops.object.modifier_apply(modifier=dt_a.name)
        _prune_and_normalize_garment_weights(apron_obj)

        apron_obj.parent = arm
        apron_obj.modifiers.new("Armature", 'ARMATURE').object = arm

        bm = bmesh.new()
        p_cols, p_rows = 4, 3
        z_p_top = pelvis_z * 1.04
        z_p_bot = pelvis_z * 0.86
        p_grid = []
        for r in range(p_rows + 1):
            tr = r / p_rows
            rz = z_p_top * (1.0 - tr) + z_p_bot * tr
            ts = max(0.0, min(1.0, (z_top - rz) / max(0.01, z_top - z_bot)))
            sk_rx = rx_top * (1.0 - ts) + rx_bot * ts + 0.044 * s_u
            sk_ry = ry_top * (1.0 - ts) + ry_bot * ts + 0.046 * s_u
            rv = []
            for c in range(p_cols + 1):
                tc = (c / p_cols) * 2.0 - 1.0
                ang = tc * math.radians(17.0) - math.pi * 0.5
                rv.append(bm.verts.new((math.cos(ang) * sk_rx, math.sin(ang) * sk_ry, rz)))
            p_grid.append(rv)
        uv_layer = bm.loops.layers.uv.new("UVMap")
        for r in range(p_rows):
            for c in range(p_cols):
                f = bm.faces.new((p_grid[r][c], p_grid[r + 1][c], p_grid[r + 1][c + 1], p_grid[r][c + 1]))
                for loop, (uu, vv) in zip(f.loops, [(c / p_cols, 1.0 - r / p_rows), (c / p_cols, 1.0 - (r + 1) / p_rows), ((c + 1) / p_cols, 1.0 - (r + 1) / p_rows), ((c + 1) / p_cols, 1.0 - r / p_rows)]):
                    loop[uv_layer].uv = (uu, vv)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        msh_pkt = bpy.data.meshes.new("ApronPocketMesh")
        bm.to_mesh(msh_pkt)
        bm.free()
        pkt = bpy.data.objects.new("ApronPocket", msh_pkt)
        bpy.context.collection.objects.link(pkt)

        bpy.ops.object.select_all(action='DESELECT')
        bpy.context.view_layer.objects.active = pkt
        pkt.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

        sol_p = pkt.modifiers.new("Solidify", 'SOLIDIFY')
        sol_p.thickness = 0.004 * s_u
        sol_p.offset = 1.0
        bpy.ops.object.modifier_apply(modifier=sol_p.name)
        bpy.ops.object.shade_smooth()

        mat_pkt = make_pbr_material("ApronPocket_Cream", apron_img, 0.88, None, 0.0, (1.0, 1.0))
        pkt.data.materials.append(mat_pkt)

        dt_p = pkt.modifiers.new("DataTransfer", 'DATA_TRANSFER')
        dt_p.object = apron_obj
        dt_p.use_vert_data = True
        dt_p.data_types_verts = {'VGROUP_WEIGHTS'}
        dt_p.vert_mapping = 'NEAREST'
        bpy.ops.object.datalayout_transfer(modifier=dt_p.name)
        bpy.ops.object.modifier_apply(modifier=dt_p.name)
        _prune_and_normalize_garment_weights(pkt)

        pkt.parent = arm
        pkt.modifiers.new("Armature", 'ARMATURE').object = arm


def _apply_posture_offset_to_action(act, bone_euler_deg: dict):
    if act is None:
        return
    bone_curves = {}
    for fc in act.fcurves:
        if 'pose.bones["' in fc.data_path and fc.data_path.endswith('"].rotation_quaternion'):
            bname = fc.data_path.split('pose.bones["')[1].split('"]')[0]
            if bname in bone_euler_deg:
                bone_curves.setdefault(bname, {})[fc.array_index] = fc
    for bname, spec in bone_euler_deg.items():
        curves = bone_curves.get(bname)
        if not curves or len(curves) < 4:
            continue
        rx, ry, rz = spec if isinstance(spec, tuple) else (spec, 0.0, 0.0)
        q_corr = (
            Quaternion((0.0, 0.0, 1.0), math.radians(rz))
            @ Quaternion((0.0, 1.0, 0.0), math.radians(ry))
            @ Quaternion((1.0, 0.0, 0.0), math.radians(rx))
        )
        frames = sorted({kp.co.x for fc in curves.values() for kp in fc.keyframe_points})
        for fr in frames:
            q_orig = Quaternion((
                curves[0].evaluate(fr),
                curves[1].evaluate(fr),
                curves[2].evaluate(fr),
                curves[3].evaluate(fr),
            )).normalized()
            q_new = (q_corr @ q_orig).normalized()
            for idx in range(4):
                for kp in curves[idx].keyframe_points:
                    if abs(kp.co.x - fr) < 1e-3:
                        kp.co.y = q_new[idx]
        for fc in curves.values():
            fc.update()


def _replace_walk_upper_body_casual(arm, walk_act, idle_act):
    """Replace tactical walk_Armature upper-body keys with natural upright casual walk."""
    if walk_act is None:
        return
    idle_q = {}
    if idle_act is not None:
        by_bone = {}
        for fc in idle_act.fcurves:
            if 'pose.bones["' in fc.data_path and fc.data_path.endswith('"].rotation_quaternion'):
                bn = fc.data_path.split('pose.bones["')[1].split('"]')[0]
                by_bone.setdefault(bn, {})[fc.array_index] = fc
        for bn, cs in by_bone.items():
            if len(cs) == 4:
                idle_q[bn] = Quaternion((cs[0].evaluate(1), cs[1].evaluate(1), cs[2].evaluate(1), cs[3].evaluate(1))).normalized()

    _apply_posture_offset_to_action(walk_act, {
        "thigh_l": (6.0, 0.0, 0.0),
        "thigh_r": (6.0, 0.0, 0.0),
    })

    upper_bones = {
        "spine_01", "spine_02", "spine_03", "neck_01", "head",
        "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
        "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r",
    }
    for fc in list(walk_act.fcurves):
        if 'pose.bones["' in fc.data_path:
            bn = fc.data_path.split('pose.bones["')[1].split('"]')[0]
            if bn in upper_bones and (fc.data_path.endswith("rotation_quaternion") or fc.data_path.endswith("rotation_euler")):
                walk_act.fcurves.remove(fc)

    f_start, f_end = int(round(walk_act.frame_range[0])), int(round(walk_act.frame_range[1]))
    mid_a = f_start + int(round((f_end - f_start) * 0.27))
    mid_0 = f_start + int(round((f_end - f_start) * 0.52))
    mid_b = f_start + int(round((f_end - f_start) * 0.77))
    key_frames = [
        (f_start, 0.0),
        (mid_a, 1.0),
        (mid_0, 0.0),
        (mid_b, -1.0),
        (f_end, 0.0),
    ]

    valid_bones = set(arm.pose.bones.keys())

    def set_bone_keys(bname, fn_q):
        if bname not in valid_bones:
            return
        fcs = [walk_act.fcurves.new(data_path=f'pose.bones["{bname}"].rotation_quaternion', index=i) for i in range(4)]
        for fr, phase in key_frames:
            q = fn_q(phase).normalized()
            for i in range(4):
                kp = fcs[i].keyframe_points.insert(fr, q[i])
                kp.interpolation = 'BEZIER'
        for fc in fcs:
            fc.update()

    set_bone_keys("spine_01", lambda ph: Quaternion((0, 1, 0), math.radians(-3.5 * ph)) @ Quaternion((1, 0, 0), math.radians(-2.5)))
    set_bone_keys("spine_03", lambda ph: Quaternion((0, 1, 0), math.radians(-2.0 * ph)) @ Quaternion((1, 0, 0), math.radians(-1.5)))
    set_bone_keys("neck_01", lambda ph: Quaternion((1, 0, 0), math.radians(0.0)))
    set_bone_keys("head", lambda ph: Quaternion((1, 0, 0), math.radians(1.5)))

    q_cl_l = idle_q.get("clavicle_l", Quaternion((1, 0, 0, 0)))
    q_cl_r = idle_q.get("clavicle_r", Quaternion((1, 0, 0, 0)))
    q_ua_l = idle_q.get("upperarm_l", Quaternion((0.970, 0.005, -0.179, 0.166)))
    q_ua_r = idle_q.get("upperarm_r", Quaternion((0.936, 0.044, 0.259, -0.235)))
    q_la_l = idle_q.get("lowerarm_l", Quaternion((1, 0, 0, 0)))
    q_la_r = idle_q.get("lowerarm_r", Quaternion((1, 0, 0, 0)))

    set_bone_keys("clavicle_l", lambda ph: q_cl_l)
    set_bone_keys("clavicle_r", lambda ph: q_cl_r)
    set_bone_keys("upperarm_l", lambda ph: Quaternion((0, 1, 0), math.radians(-5.0)) @ Quaternion((1, 0, 0), math.radians(14.0 * ph)) @ q_ua_l)
    set_bone_keys("upperarm_r", lambda ph: Quaternion((0, 1, 0), math.radians(5.0)) @ Quaternion((1, 0, 0), math.radians(-14.0 * ph)) @ q_ua_r)
    set_bone_keys("lowerarm_l", lambda ph: q_la_l @ Quaternion((1, 0, 0), math.radians(-14.0 + 6.0 * ph)))
    set_bone_keys("lowerarm_r", lambda ph: q_la_r @ Quaternion((1, 0, 0), math.radians(-14.0 - 6.0 * ph)))
    set_bone_keys("hand_l", lambda ph: Quaternion((1, 0, 0, 0)))
    set_bone_keys("hand_r", lambda ph: Quaternion((1, 0, 0, 0)))


def _synthesize_mh_action(arm, name: str, key_poses: list):
    act = bpy.data.actions.new(name=name)
    act.use_fake_user = True
    arm.animation_data.action = act
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
    stance_defaults = {
        "clavicle_l": (0.0, 0.0, 2.0),
        "clavicle_r": (0.0, 0.0, -2.0),
        "thigh_l": (2.0, 0.0, 1.5),
        "thigh_r": (2.0, 0.0, -1.5),
        "calf_l": (-3.0, 0.0, 0.0),
        "calf_r": (-3.0, 0.0, 0.0),
    }
    for frame, bone_rots in key_poses:
        bpy.context.scene.frame_set(frame)
        for pb in arm.pose.bones:
            pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        merged = dict(stance_defaults)
        merged.update(bone_rots)
        for bname, euler_deg in merged.items():
            pb = arm.pose.bones.get(bname)
            if pb:
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
    hair_hex: str = "#1D1614",
    hijab_rgb=None,
    apron: bool = False,
    skirt_cfg=None,
    is_player: bool = False,
    decimate_ratio: float = 0.42,
    dark_hair: bool = False,
):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(CHARKIT_DIR, mh_file))

    for obj in list(bpy.data.objects):
        if obj.type == 'MESH' and 'icosphere' in obj.name.lower():
            bpy.data.objects.remove(obj, do_unlink=True)

    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    body_mesh = next(o for o in bpy.data.objects if o.type == 'MESH')

    _delete_materials_faces(body_mesh, strip_mats)

    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = body_mesh
    body_mesh.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    bpy.context.view_layer.update()
    pts = [v.co for v in body_mesh.data.vertices]
    zmax = max(p.z for p in pts)
    pelvis_z = arm.data.bones["pelvis"].head_local.z
    hb = _measure_head_bounds_mh(body_mesh, arm)

    _fix_mh_materials_and_textures(body_mesh, skin_warmth=skin_warmth, dark_hair=dark_hair, is_player=is_player)
    batik_img = None
    if batik_cfg is not None:
        batik_img = generate_batik_1024(TEX_DIR, batik_cfg["name"], batik_cfg["base"], batik_cfg["accent"])
    apron_img = generate_cream_apron_1024(TEX_DIR) if apron else None
    _recolor_mh_outfit(
        body_mesh, arm, pelvis_z,
        shirt_rgb=shirt_rgb, pants_rgb=pants_rgb, batik_img=batik_img, keep_suit_tex=keep_suit_tex,
    )

    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = body_mesh
    body_mesh.select_set(True)
    if len(body_mesh.data.vertices) > 9500 or (not is_player and len(body_mesh.data.vertices) > 7200):
        dec = body_mesh.modifiers.new("Decimate", 'DECIMATE')
        dec.ratio = decimate_ratio
        dec.delimit = {'MATERIAL', 'UV', 'SEAM'}
        dec.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="Decimate")
    bpy.ops.object.shade_smooth()

    _add_headgear(arm, body_mesh, hb, zmax, hair_style, hair_hex=hair_hex, hijab_rgb=hijab_rgb, is_player=is_player)
    if skirt_cfg is not None or apron:
        _build_body_topo_garments(arm, body_mesh, zmax, pelvis_z, skirt_cfg=skirt_cfg, apron=apron, apron_img=apron_img, batik_img=batik_img)

    raw_cap = 13800 if is_player else 7600
    cur_raw = sum(len(o.data.vertices) for o in bpy.data.objects if o.type == 'MESH')
    if cur_raw > raw_cap and len(body_mesh.data.vertices) > 3200:
        excess = cur_raw - raw_cap
        target_body = max(2800, len(body_mesh.data.vertices) - excess - 250)
        extra_ratio = max(0.42, target_body / float(len(body_mesh.data.vertices)))
        bpy.ops.object.select_all(action='DESELECT')
        bpy.context.view_layer.objects.active = body_mesh
        body_mesh.select_set(True)
        dec2 = body_mesh.modifiers.new("DecimateCap", 'DECIMATE')
        dec2.ratio = extra_ratio
        dec2.delimit = {'MATERIAL', 'UV'}
        dec2.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="DecimateCap")
        bpy.ops.object.shade_smooth()

    if arm.animation_data:
        idle_act_ref = None
        walk_act_ref = None
        for tr in list(arm.animation_data.nla_tracks):
            base = tr.name.strip()
            if base in KEEP_MH_CLIPS:
                new_name = KEEP_MH_CLIPS[base]
                tr.name = new_name
                for st in tr.strips:
                    if st.action:
                        st.action.name = new_name
                        st.action.use_fake_user = True
                        if new_name == "Idle":
                            idle_act_ref = st.action
                            _apply_posture_offset_to_action(st.action, {
                                "spine_01": -4.0,
                                "neck_01": -3.0,
                                "head": 1.0,
                            })
                        elif new_name == "Talk":
                            _apply_posture_offset_to_action(st.action, {
                                "spine_03": -18.0,
                                "neck_01": -8.0,
                                "head": 2.0,
                            })
                        elif new_name == "Walk":
                            walk_act_ref = st.action
            else:
                arm.animation_data.nla_tracks.remove(tr)
        if walk_act_ref is not None:
            _replace_walk_upper_body_casual(arm, walk_act_ref, idle_act_ref)

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

    for act in list(bpy.data.actions):
        if not act.use_fake_user and act.users == 0:
            bpy.data.actions.remove(act)

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


def render_showcase():
    """Render Cycles showcase: Sari Idle + Sari Walk +0.25s + Ibu + Pak RT + Ojek + Pelajar."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.view_settings.view_transform = 'AgX'

    slots = [
        ("char_art.glb", -1.45, 0.0, "Idle", 1),
        ("char_art.glb", -0.85, -30.0, "Walk", 7),
        ("char_ibu.glb", -0.20, 0.0, "Idle", 1),
        ("char_pak_rt.glb", 0.40, 0.0, "Idle", 1),
        ("char_ojek.glb", 0.98, 0.0, "Idle", 1),
        ("char_pelajar.glb", 1.54, 0.0, "Idle", 1),
    ]
    for fn, lx, rot_deg, anim_name, fr in slots:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS_DIR, fn))
        new_objs = [o for o in bpy.data.objects if o not in before]
        arm = next(o for o in new_objs if o.type == 'ARMATURE')
        arm.location = (lx, 0.0, 0.0)
        arm.rotation_euler = (0.0, 0.0, math.radians(rot_deg))
        if arm.animation_data:
            for tr in arm.animation_data.nla_tracks:
                tr.mute = (tr.name != anim_name)
                if tr.name == anim_name and tr.strips:
                    st = tr.strips[0]
                    if st.action:
                        st.action.use_fake_user = True
                        arm.animation_data.action = st.action
        scene.frame_set(fr)

    bpy.context.view_layer.update()
    bpy.ops.mesh.primitive_plane_add(size=10.0, location=(0.0, 0.0, 0.0))
    fl = bpy.context.active_object
    fl.data.materials.append(make_matte_mat("StudioFloor", (0.78, 0.74, 0.68), 0.85))

    world = bpy.data.worlds.new("StudioWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.76, 0.80, 0.86, 1.0)
    bg.inputs["Strength"].default_value = 0.75

    bpy.ops.object.light_add(type='AREA', location=(2.2, -3.5, 2.8))
    kl = bpy.context.active_object
    kl.data.energy = 260.0
    kl.data.size = 2.0
    kl.data.color = (1.0, 0.94, 0.86)
    kl.rotation_euler = (math.radians(55), 0.0, math.radians(28))

    bpy.ops.object.light_add(type='AREA', location=(-2.5, -2.5, 2.2))
    fl_l = bpy.context.active_object
    fl_l.data.energy = 110.0
    fl_l.data.size = 2.5
    fl_l.data.color = (0.86, 0.92, 1.0)
    fl_l.rotation_euler = (math.radians(60), 0.0, math.radians(-38))

    bpy.ops.object.camera_add(location=(0.05, -4.70, 1.15), rotation=(math.radians(85.0), 0.0, 0.0))
    cam = bpy.context.active_object
    cam.data.lens = 40.0
    scene.camera = cam

    os.makedirs(BUILD_DIR, exist_ok=True)
    out_png = os.path.join(BUILD_DIR, "rollout_chars_showcase.png")
    scene.render.filepath = out_png
    bpy.ops.render.render(write_still=True)
    print("RENDERED SHOWCASE:", out_png)


if __name__ == "__main__":
    # 4 Hero / Player Tiers (<= 14,500 split verts, sculpted hair / hijab, zero-clip apron + casual walk)
    build_mh_character(
        "mh_1000.glb", "char_art.glb", target_h=1.64,
        shirt_rgb=(0.055, 0.24, 0.165), pants_rgb=(0.055, 0.24, 0.165),
        batik_cfg={"name": "daster_art_starter_1024", "base": (0.055, 0.24, 0.165), "accent": (0.78, 0.66, 0.36)},
        strip_mats=("fedora", "afro"), hair_style="sculpted_katherine", hair_hex="#1D1614",
        apron=True, skirt_cfg={"name": "DasterSkirt_Batik", "obj_name": "DasterSkirt", "use_batik": True, "long": False},
        is_player=True, decimate_ratio=0.42,
    )
    build_mh_character(
        "mh_1000.glb", "char_art_hijab.glb", target_h=1.64,
        shirt_rgb=(0.14, 0.32, 0.40), pants_rgb=(0.14, 0.32, 0.40),
        batik_cfg={"name": "daster_art_hijab_1024", "base": (0.14, 0.32, 0.40), "accent": (0.86, 0.76, 0.50)},
        strip_mats=("fedora", "afro"), hair_style="hijab_bergo", hijab_rgb=(0.14, 0.30, 0.22),
        apron=True, skirt_cfg={"name": "DasterHijab_Batik", "obj_name": "DasterSkirt", "use_batik": True, "long": True},
        is_player=True, decimate_ratio=0.42,
    )
    build_mh_character(
        "mh_1000.glb", "char_art_pro.glb", target_h=1.64,
        shirt_rgb=(0.08, 0.34, 0.34), pants_rgb=(0.10, 0.14, 0.20),
        strip_mats=("fedora", "afro"), hair_style="sculpted_katherine", hair_hex="#1D1614",
        apron=True, is_player=True, decimate_ratio=0.42,
    )
    build_mh_character(
        "mh_1000.glb", "char_art_elite.glb", target_h=1.64,
        shirt_rgb=(0.09, 0.16, 0.28), pants_rgb=(0.08, 0.10, 0.16),
        strip_mats=("fedora", "afro"), hair_style="sculpted_katherine", hair_hex="#1D1614",
        apron=True, is_player=True, decimate_ratio=0.42,
    )

    # 3 Shift NPCs (unique MakeHuman bases, <= 10,500 split verts, casual walk)
    build_mh_character(
        "mh_3488.glb", "char_ibu.glb", target_h=1.66,
        shirt_rgb=(0.48, 0.14, 0.12), pants_rgb=(0.16, 0.10, 0.10),
        batik_cfg={"name": "batik_ibu_1024", "base": (0.48, 0.14, 0.12), "accent": (0.88, 0.66, 0.26)},
        strip_mats=("katherine",), hair_style="hijab_bergo", hijab_rgb=(0.24, 0.06, 0.08),
        skirt_cfg={"name": "IbuLongSkirt", "obj_name": "LongSkirt", "use_batik": False, "color": (0.16, 0.10, 0.09), "long": True},
        decimate_ratio=0.34,
    )
    build_mh_character(
        "mh_3183.glb", "char_kakak.glb", target_h=1.65,
        shirt_rgb=(0.64, 0.28, 0.36), pants_rgb=(0.18, 0.22, 0.32),
        hair_style="none",
        skirt_cfg={"name": "KakakSkirt", "obj_name": "KakakSkirt", "use_batik": False, "color": (0.18, 0.22, 0.32), "long": False},
        decimate_ratio=0.42, dark_hair=True,
    )
    build_mh_character(
        "mh_1037.glb", "char_budi.glb", target_h=1.74,
        shirt_rgb=(0.14, 0.26, 0.16), pants_rgb=(0.12, 0.13, 0.16),
        batik_cfg={"name": "batik_budi_1024", "base": (0.14, 0.26, 0.16), "accent": (0.76, 0.62, 0.26)},
        strip_mats=("faun_beard",), hair_style="none", decimate_ratio=0.40, dark_hair=True,
    )

    # 8 Unique Street NPCs (<= 10,500 split verts, sculpted hair / headgear, casual walk)
    build_mh_character(
        "mh_3183.glb", "char_dewi.glb", target_h=1.63,
        shirt_rgb=(0.82, 0.36, 0.24), pants_rgb=(0.16, 0.22, 0.36),
        hair_style="none", decimate_ratio=0.44, dark_hair=True,
    )
    build_mh_character(
        "mh_3549.glb", "char_pak_rt.glb", target_h=1.71,
        shirt_rgb=(0.50, 0.36, 0.16), pants_rgb=(0.12, 0.12, 0.15),
        batik_cfg={"name": "batik_pak_rt_1024", "base": (0.48, 0.34, 0.15), "accent": (0.92, 0.78, 0.42)},
        hair_style="peci", decimate_ratio=0.36, dark_hair=True,
    )
    build_mh_character(
        "mh_3427.glb", "char_ojek.glb", target_h=1.72,
        shirt_rgb=(0.10, 0.56, 0.24), pants_rgb=(0.14, 0.18, 0.30),
        strip_mats=("moustache", "hair", "afro", "fedora", "katherine", "bob"), hair_style="ojek_helmet", decimate_ratio=0.44,
    )
    build_mh_character(
        "mh_1148.glb", "char_kurir.glb", target_h=1.72,
        shirt_rgb=(0.88, 0.40, 0.12), pants_rgb=(0.15, 0.18, 0.26),
        strip_mats=("moustache", "hair", "afro", "fedora", "katherine", "bob"), hair_style="cap", decimate_ratio=0.46,
    )
    build_mh_character(
        "mh_1000.glb", "char_pelajar.glb", target_h=1.60,
        shirt_rgb=(0.90, 0.90, 0.88), pants_rgb=(0.34, 0.36, 0.42),
        strip_mats=("fedora", "afro"), hair_style="sculpted_bob", hair_hex="#1D1614",
        skirt_cfg={"name": "SmaSkirt", "obj_name": "SmaSkirt", "use_batik": False, "color": (0.34, 0.36, 0.42), "long": False},
        decimate_ratio=0.34,
    )
    build_mh_character(
        "mh_3000.glb", "char_hendra.glb", target_h=1.73,
        keep_suit_tex=True,
        strip_mats=("beard",), hair_style="none", decimate_ratio=0.40, dark_hair=True,
    )
    build_mh_character(
        "mh_3488.glb", "char_rina.glb", target_h=1.64,
        shirt_rgb=(0.46, 0.34, 0.58), pants_rgb=(0.16, 0.16, 0.20),
        strip_mats=("katherine",), hair_style="hijab_bergo", hijab_rgb=(0.82, 0.76, 0.66),
        skirt_cfg={"name": "RinaSkirt", "obj_name": "RinaSkirt", "use_batik": False, "color": (0.18, 0.16, 0.24), "long": True},
        decimate_ratio=0.34,
    )
    build_mh_character(
        "mh_3427.glb", "char_agus.glb", target_h=1.71,
        shirt_rgb=(0.48, 0.24, 0.14), pants_rgb=(0.16, 0.15, 0.14),
        batik_cfg={"name": "batik_agus_1024", "base": (0.48, 0.24, 0.14), "accent": (0.86, 0.70, 0.36)},
        hair_style="none", decimate_ratio=0.44, dark_hair=True,
    )

    if "--showcase" in sys.argv:
        render_showcase()
