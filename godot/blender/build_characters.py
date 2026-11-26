import os
import sys
import math
import bpy
import bmesh
from mathutils import Vector

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from tex_utils import generate_batik_texture, generate_stylized_face_texture, make_pbr_material

GODOT_DIR = os.path.dirname(SCRIPT_DIR)
TEX_DIR = os.path.join(GODOT_DIR, "assets", "textures")
RAW_DIR = os.path.join(GODOT_DIR, "assets", "raw")
MODELS_DIR = os.path.join(GODOT_DIR, "assets", "models")

UAL_CLIP_MAP = {
    "Idle_Loop_Armature": "Idle",
    "Walk_Loop_Armature": "Walk",
    "Interact_Armature": "Clean",
    "Idle_Talking_Loop_Armature": "Talk",
    "Celebration_Armature": "Celebrate",
}

SKIN_BONES = {
    "head", "head_leaf", "neck_01",
    "lowerarm_l", "lowerarm_r", "hand_l", "hand_r",
}
FINGER_SUBSTRS = ("index_", "middle_", "pinky_", "ring_", "thumb_")
TOP_BONES = {"spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r"}
LEG_BONES = {"pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r"}
FOOT_BONES = {"foot_l", "foot_r", "ball_l", "ball_r", "ball_leaf_l", "ball_leaf_r"}


def make_matte_mat(name: str, rgb, roughness: float = 0.82, specular: float = 0.16):
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
    # Only subsurf low-poly hair/hijab primitives (< 130 verts) so glTF export stays well under 14,500 verts
    if levels > 0 and len(obj.data.vertices) < 130:
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


def measure_head_bounds(body_mesh, z_min_filter: float = 1.56):
    pts = [v.co for v in body_mesh.data.vertices if v.co.z > z_min_filter]
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


def sample_face_y(body_mesh, target_x: float, target_z: float, rad_x: float = 0.022, rad_z: float = 0.018) -> float:
    pts = [
        v.co.y for v in body_mesh.data.vertices
        if v.co.z > 1.55 and abs(v.co.x - target_x) <= rad_x and abs(v.co.z - target_z) <= rad_z and v.co.y < -0.02
    ]
    return min(pts) if pts else -0.12


def bisect_clean_garment_seams(body_mesh, arm, sleeve_frac: float = 0.52, bare_calves_z=None, long_sleeve: bool = False):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = body_mesh
    body_mesh.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(body_mesh.data)

    def cut_plane(co, no, geom):
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, dist=0.0005)

    for z_cut in (0.092, 0.960, 1.475):
        cut_plane((0, 0, z_cut), (0, 0, 1), bm.verts[:] + bm.edges[:] + bm.faces[:])
    if bare_calves_z is not None:
        cut_plane((0, 0, bare_calves_z), (0, 0, 1), bm.verts[:] + bm.edges[:] + bm.faces[:])

    if not long_sleeve:
        for side in ("l", "r"):
            ua = arm.data.bones.get(f"upperarm_{side}")
            if ua:
                p_cut = ua.head_local.lerp(ua.tail_local, sleeve_frac)
                dir_v = (ua.tail_local - ua.head_local).normalized()
                cut_plane(p_cut, dir_v, bm.verts[:] + bm.edges[:] + bm.faces[:])

    bmesh.update_edit_mesh(body_mesh.data)
    bpy.ops.object.mode_set(mode='OBJECT')


def assign_body_materials(body_mesh, arm, palette: dict, hb: dict, face_img, batik_img=None, sleeve_frac: float = 0.52,
                          bare_calves_z=None, long_sleeve: bool = False):
    ua_l = arm.data.bones.get("upperarm_l")
    sleeve_x = abs(ua_l.head_local.lerp(ua_l.tail_local, sleeve_frac).x) if ua_l else 0.27

    mat_skin = make_matte_mat("Skin", palette["skin"], 0.72, 0.14)
    if batik_img is not None:
        mat_shirt = make_pbr_material("Shirt_Batik", batik_img, 0.80, None, 0.0, (2.6, 2.6))
    else:
        mat_shirt = make_matte_mat("Shirt", palette["shirt"], 0.78, 0.14)
    mat_pants = make_matte_mat("Pants", palette["pants"], 0.82, 0.12)
    mat_shoes = make_matte_mat("Shoes", palette["shoes"], 0.58, 0.22)
    mat_face = make_pbr_material("FaceSkin", face_img, 0.70, None, 0.0, (1.0, 1.0))

    body_mesh.data.materials.clear()
    for m in (mat_skin, mat_shirt, mat_pants, mat_shoes, mat_face):
        body_mesh.data.materials.append(m)
    idx_skin, idx_shirt, idx_pants, idx_shoes, idx_face = 0, 1, 2, 3, 4

    vg_names = {vg.index: vg.name for vg in body_mesh.vertex_groups}
    verts = body_mesh.data.vertices

    for poly in body_mesh.data.polygons:
        c = poly.center
        grp_weights = {}
        for vi in poly.vertices:
            for g in verts[vi].groups:
                gn = vg_names.get(g.group, "")
                grp_weights[gn] = grp_weights.get(gn, 0.0) + g.weight
        dom_vg = max(grp_weights.items(), key=lambda kv: kv[1])[0] if grp_weights else ""

        if dom_vg in FOOT_BONES or (c.z < 0.092 and dom_vg in LEG_BONES):
            poly.material_index = idx_shoes
        elif dom_vg in {"head", "head_leaf"}:
            if c.y < hb["cy"] - 0.018 and c.z > hb["z_min"] + 0.015:
                poly.material_index = idx_face
            else:
                poly.material_index = idx_skin
        elif dom_vg == "neck_01":
            if c.z >= 1.475 and abs(c.x) < 0.072:
                poly.material_index = idx_skin
            else:
                poly.material_index = idx_shirt
        elif dom_vg in {"lowerarm_l", "lowerarm_r", "hand_l", "hand_r"} or any(s in dom_vg for s in FINGER_SUBSTRS):
            if long_sleeve and ("lowerarm_" in dom_vg):
                poly.material_index = idx_shirt
            else:
                poly.material_index = idx_skin
        elif dom_vg in TOP_BONES:
            if "upperarm_" in dom_vg and not long_sleeve and abs(c.x) > sleeve_x:
                poly.material_index = idx_skin
            elif c.z < 0.960:
                poly.material_index = idx_pants
            else:
                poly.material_index = idx_shirt
        elif dom_vg in LEG_BONES:
            if c.z >= 0.960:
                poly.material_index = idx_shirt
            elif bare_calves_z is not None and c.z < bare_calves_z:
                poly.material_index = idx_skin
            else:
                poly.material_index = idx_pants
        else:
            poly.material_index = idx_skin

    # Push interior garment vertices slightly outward for natural tailored 3D clothing overlap at seams
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = body_mesh
    body_mesh.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(body_mesh.data)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    uv_layer = bm.loops.layers.uv.verify()

    shirt_only_verts = set()
    pants_only_verts = set()
    skin_verts = set()
    for f in bm.faces:
        if f.material_index in (idx_skin, idx_face):
            for v in f.verts:
                skin_verts.add(v)
        elif f.material_index == idx_shirt:
            for v in f.verts:
                shirt_only_verts.add(v)
        elif f.material_index == idx_pants:
            for v in f.verts:
                pants_only_verts.add(v)

    for v in shirt_only_verts - skin_verts:
        v.co += v.normal * 0.0042
    for v in pants_only_verts - skin_verts - shirt_only_verts:
        v.co += v.normal * 0.0028

    # Project crisp planar -Y UV onto FaceSkin polygons
    rx_span = max(0.08, hb["rx"] * 1.46)
    z_bot = hb["z_min"] + 0.005
    z_span = max(0.12, hb["z_max"] - z_bot)
    for f in bm.faces:
        if f.material_index == idx_face:
            for loop in f.loops:
                co = loop.vert.co
                u = 0.5 + (co.x - hb["cx"]) / (rx_span * 2.0)
                v = (co.z - z_bot) / z_span
                loop[uv_layer].uv = (max(0.02, min(0.98, u)), max(0.02, min(0.98, v)))

    bmesh.update_edit_mesh(body_mesh.data)
    bpy.ops.object.mode_set(mode='OBJECT')

    for p in body_mesh.data.polygons:
        p.select = (p.material_index == idx_shirt)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66))
    bpy.ops.object.mode_set(mode='OBJECT')


def build_stylized_indonesian_face(arm, body_mesh, hb: dict, skin_rgb, hair_rgb):
    # Facial features are rendered cleanly via 256x256 anti-aliased FaceSkin UV projection;
    # keep geometry flush and smooth like The Sims (no protruding cubes/spheres).
    return None


def build_indonesian_hair_or_hijab(arm, body_mesh, hb: dict, style: str, hair_rgb, ribbon_rgb=None, hijab_rgb=None):
    cx, cy, cz = hb["cx"], hb["cy"], hb["cz"]
    rx, ry, rz = hb["rx"], hb["ry"], hb["rz"]

    if style == "hijab_bergo":
        h_col = hijab_rgb if hijab_rgb else (0.52, 0.20, 0.16)
        mat_hijab = make_matte_mat("HijabBergo", h_col, 0.86, 0.12)

        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=26, ring_count=16, radius=1.0, location=(cx, cy + 0.028, cz + 0.016))
        hood = bpy.context.active_object
        hood.name = "HijabHood"
        hood.scale = (rx + 0.022, ry + 0.016, rz + 0.020)
        apply_subsurf_and_smooth(hood, levels=1)
        attach_to_bone(hood, arm, "head", mat_hijab)

        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=0.195, radius2=0.095, depth=0.36, location=(cx, 0.005, 1.44))
        drape = bpy.context.active_object
        drape.name = "HijabDrape"
        drape.scale = (1.06, 0.82, 1.0)
        apply_subsurf_and_smooth(drape, levels=1)
        attach_multi_bone(drape, arm, mat_hijab, lambda co: {"neck_01": 0.45, "spine_03": 0.55} if co.z > 1.46 else {"spine_03": 1.0})
        return hood

    mat_hair = make_matte_mat("IndonesianHair", hair_rgb, 0.68, 0.18)

    if style == "cepol":
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1.0, location=(cx, cy + 0.018, cz + 0.018))
        cap = bpy.context.active_object
        cap.name = "HairCap"
        cap.scale = (rx + 0.014, ry + 0.010, rz + 0.016)
        apply_subsurf_and_smooth(cap, levels=1)
        attach_to_bone(cap, arm, "head", mat_hair)

        for sx in (-1.0, 1.0):
            bpy.ops.object.select_all(action='DESELECT')
            bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=10, radius=1.0, location=(cx + sx * (rx * 0.90), cy + 0.005, cz - 0.015))
            sh = bpy.context.active_object
            sh.name = f"SideHair_{'L' if sx > 0 else 'R'}"
            sh.scale = (0.026, 0.036, 0.068)
            apply_subsurf_and_smooth(sh, levels=1)
            attach_to_bone(sh, arm, "head", mat_hair)

        fy = sample_face_y(body_mesh, cx, hb["z_max"] - 0.045, 0.03, 0.02)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=16, ring_count=10, radius=1.0,
            location=(cx - 0.014, fy + 0.014, hb["z_max"] - 0.042),
            rotation=(math.radians(14), math.radians(-12), 0),
        )
        poni = bpy.context.active_object
        poni.name = "PoniDepan"
        poni.scale = (rx * 0.80, 0.048, 0.034)
        apply_subsurf_and_smooth(poni, levels=1)
        attach_to_bone(poni, arm, "head", mat_hair)

        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=12, radius=0.056, location=(cx, hb["y_max"] + 0.026, cz + 0.062))
        bun = bpy.context.active_object
        bun.name = "CepolBun"
        bun.scale = (1.06, 0.94, 1.02)
        apply_subsurf_and_smooth(bun, levels=1)
        attach_to_bone(bun, arm, "head", mat_hair)

        tie_col = ribbon_rgb if ribbon_rgb else (0.76, 0.24, 0.18)
        mat_tie = make_matte_mat("CepolTie", tie_col, 0.62)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_torus_add(
            major_segments=16, minor_segments=8,
            major_radius=0.044, minor_radius=0.010,
            location=(cx, hb["y_max"] + 0.012, cz + 0.056),
            rotation=(math.radians(68), 0, 0),
        )
        tie = bpy.context.active_object
        tie.name = "CepolScrunchie"
        attach_to_bone(tie, arm, "head", mat_tie)
        return cap

    if style == "bob":
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1.0, location=(cx, cy + 0.016, cz + 0.018))
        cap = bpy.context.active_object
        cap.name = "KakakHairCap"
        cap.scale = (rx + 0.018, ry + 0.014, rz + 0.018)
        apply_subsurf_and_smooth(cap, levels=1)
        attach_to_bone(cap, arm, "head", mat_hair)

        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cylinder_add(vertices=22, radius=rx + 0.020, depth=0.16, location=(cx, cy + 0.022, cz - 0.068))
        curtain = bpy.context.active_object
        curtain.name = "KakakBobCurtain"
        curtain.scale = (1.08, 0.94, 1.0)
        apply_subsurf_and_smooth(curtain, levels=1)
        attach_to_bone(curtain, arm, "head", mat_hair)

        fy = sample_face_y(body_mesh, cx, hb["z_max"] - 0.045, 0.03, 0.02)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=16, ring_count=10, radius=1.0,
            location=(cx + 0.012, fy + 0.014, hb["z_max"] - 0.044),
            rotation=(math.radians(14), math.radians(10), 0),
        )
        poni = bpy.context.active_object
        poni.name = "KakakPoni"
        poni.scale = (rx * 0.80, 0.048, 0.032)
        apply_subsurf_and_smooth(poni, levels=1)
        attach_to_bone(poni, arm, "head", mat_hair)
        return cap

    if style == "ponytail":
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1.0, location=(cx, cy + 0.016, cz + 0.018))
        cap = bpy.context.active_object
        cap.name = "DewiHairCap"
        cap.scale = (rx + 0.016, ry + 0.012, rz + 0.017)
        apply_subsurf_and_smooth(cap, levels=1)
        attach_to_bone(cap, arm, "head", mat_hair)

        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cone_add(vertices=18, radius1=0.056, radius2=0.024, depth=0.24, location=(cx, hb["y_max"] + 0.036, cz - 0.045), rotation=(math.radians(-22), 0, 0))
        tail = bpy.context.active_object
        tail.name = "DewiPonytail"
        apply_subsurf_and_smooth(tail, levels=1)
        attach_to_bone(tail, arm, "head", mat_hair)

        fy = sample_face_y(body_mesh, cx, hb["z_max"] - 0.045, 0.03, 0.02)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=1.0, location=(cx - 0.012, fy + 0.015, hb["z_max"] - 0.042), rotation=(math.radians(12), math.radians(-10), 0))
        poni = bpy.context.active_object
        poni.name = "DewiPoni"
        poni.scale = (rx * 0.78, 0.044, 0.030)
        apply_subsurf_and_smooth(poni, levels=1)
        attach_to_bone(poni, arm, "head", mat_hair)
        return cap

    if style == "peci":
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=22, ring_count=14, radius=1.0, location=(cx, cy + 0.015, cz + 0.012))
        cap = bpy.context.active_object
        cap.name = "PakRtHairCap"
        cap.scale = (rx + 0.010, ry + 0.008, rz + 0.012)
        apply_subsurf_and_smooth(cap, levels=1)
        attach_to_bone(cap, arm, "head", mat_hair)

        mat_peci = make_matte_mat("PeciVelvet", (0.06, 0.06, 0.07), 0.88, 0.08)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=rx + 0.022, depth=0.105, location=(cx, cy + 0.012, hb["z_max"] + 0.015))
        peci = bpy.context.active_object
        peci.name = "PakRtPeci"
        peci.scale = (0.94, 1.12, 1.0)
        apply_bevel_and_smooth(peci, width=0.006, segments=2)
        attach_to_bone(peci, arm, "head", mat_peci)
        return peci

    if style == "ojek_helmet":
        mat_helmet = make_matte_mat("OjekHelmet", (0.12, 0.60, 0.28), 0.34, 0.28)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1.0, location=(cx, cy + 0.012, cz + 0.026))
        helm = bpy.context.active_object
        helm.name = "OjekHelmet"
        helm.scale = (rx + 0.032, ry + 0.028, rz + 0.032)
        apply_subsurf_and_smooth(helm, levels=1)
        attach_to_bone(helm, arm, "head", mat_helmet)

        mat_visor = make_matte_mat("OjekVisor", (0.10, 0.14, 0.20), 0.18, 0.55)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, hb["y_min"] - 0.020, cz + 0.022))
        vis = bpy.context.active_object
        vis.name = "OjekVisor"
        vis.scale = (rx * 1.48, 0.035, 0.056)
        apply_bevel_and_smooth(vis, width=0.006, segments=2)
        attach_to_bone(vis, arm, "head", mat_visor)
        return helm

    if style == "cap":
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=22, ring_count=14, radius=1.0, location=(cx, cy + 0.015, cz + 0.012))
        hair = bpy.context.active_object
        hair.name = "KurirHair"
        hair.scale = (rx + 0.010, ry + 0.008, rz + 0.010)
        apply_subsurf_and_smooth(hair, levels=1)
        attach_to_bone(hair, arm, "head", mat_hair)

        mat_cap = make_matte_mat("KurirCap", (0.10, 0.18, 0.34), 0.72, 0.14)
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_uv_sphere_add(segments=22, ring_count=12, radius=1.0, location=(cx, cy + 0.012, cz + 0.034))
        c_dome = bpy.context.active_object
        c_dome.name = "KurirCapDome"
        c_dome.scale = (rx + 0.022, ry + 0.020, rz * 0.72)
        apply_subsurf_and_smooth(c_dome, levels=1)
        attach_to_bone(c_dome, arm, "head", mat_cap)

        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, hb["y_min"] - 0.042, cz + 0.032), rotation=(math.radians(8), 0, 0))
        brim = bpy.context.active_object
        brim.name = "KurirCapBrim"
        brim.scale = (rx * 1.42, 0.088, 0.014)
        apply_bevel_and_smooth(brim, width=0.004, segments=2)
        attach_to_bone(brim, arm, "head", mat_cap)
        return c_dome

    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_uv_sphere_add(segments=22, ring_count=14, radius=1.0, location=(cx, cy + 0.016, cz + 0.018))
    cap = bpy.context.active_object
    cap.name = "BapakHairCap"
    cap.scale = (rx + 0.012, ry + 0.008, rz + 0.014)
    apply_subsurf_and_smooth(cap, levels=1)
    attach_to_bone(cap, arm, "head", mat_hair)
    return cap


def build_flowing_skirt(arm, mat_skirt, name: str, rings_cfg):
    bm = bmesh.new()
    segs = 28
    rings = []
    for z_val, rx_val, ry_val, cy_off in rings_cfg:
        ring_v = []
        for i in range(segs):
            ang = (2.0 * math.pi * i) / segs
            ring_v.append(bm.verts.new((math.cos(ang) * rx_val, cy_off + math.sin(ang) * ry_val, z_val)))
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
    sol.thickness = 0.008
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.shade_smooth()

    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66))
    bpy.ops.object.mode_set(mode='OBJECT')

    z_bot = rings_cfg[0][0]
    z_hip = 0.96

    def skirt_weights(co):
        if co.z >= z_hip:
            return {"pelvis": 1.0}
        t = min(1.0, max(0.0, (z_hip - co.z) / max(0.18, z_hip - z_bot)))
        leg_w = 0.65 * t
        hip_w = 1.0 - leg_w
        if co.z < 0.53:
            b_leg = "calf_l" if co.x > 0.0 else "calf_r"
            return {"pelvis": 0.25, "thigh_l" if co.x > 0 else "thigh_r": 0.35, b_leg: 0.40}
        if co.x > 0.015:
            return {"pelvis": hip_w, "thigh_l": leg_w}
        if co.x < -0.015:
            return {"pelvis": hip_w, "thigh_r": leg_w}
        return {"pelvis": 1.0}

    attach_multi_bone(skirt_obj, arm, mat_skirt, skirt_weights)
    return skirt_obj


def build_fitted_curved_apron(arm, mat_apron, mat_pocket):
    bm = bmesh.new()
    rows = [
        (0.60, 0.180, -0.228),
        (0.78, 0.172, -0.214),
        (0.96, 0.162, -0.194),
        (1.08, 0.145, -0.176),
        (1.24, 0.132, -0.196),
        (1.37, 0.112, -0.168),
    ]
    cols = 10
    grid = []
    for rz, hw, fy in rows:
        row_v = []
        for c in range(cols + 1):
            t = (c / cols) * 2.0 - 1.0
            row_v.append(bm.verts.new((t * hw, fy + (t * t) * 0.036, rz)))
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
    sol.thickness = 0.007
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.shade_smooth()

    def apron_weights(co):
        if co.z >= 1.20:
            return {"spine_03": 0.7, "spine_02": 0.3}
        if co.z >= 1.04:
            return {"spine_01": 0.65, "spine_02": 0.35}
        if co.x > 0.025:
            return {"pelvis": 0.70, "thigh_l": 0.30}
        if co.x < -0.025:
            return {"pelvis": 0.70, "thigh_r": 0.30}
        return {"pelvis": 1.0}

    attach_multi_bone(apron_obj, arm, mat_apron, apron_weights)

    for sx in (-0.074, 0.074):
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(sx, -0.055, 1.43), rotation=(math.radians(46), 0, 0))
        st = bpy.context.active_object
        st.scale = (0.026, 0.18, 0.012)
        bpy.ops.object.shade_smooth()
        attach_to_bone(st, arm, "spine_03", mat_apron)

    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -0.224, 0.86))
    pkt = bpy.context.active_object
    pkt.name = "ApronPocket"
    pkt.scale = (0.118, 0.014, 0.088)
    apply_bevel_and_smooth(pkt, width=0.002, segments=1)
    attach_to_bone(pkt, arm, "pelvis", mat_pocket)


def build_collared_placket(arm, mat_collar, mat_placket, prefix: str = "Shirt", with_placket: bool = True):
    for sx, rot_z in [(-0.064, math.radians(-26)), (0.064, math.radians(26))]:
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cube_add(
            size=1.0,
            location=(sx, -0.095, 1.442),
            rotation=(math.radians(38), math.radians(-18 if sx < 0 else 18), rot_z),
        )
        flap = bpy.context.active_object
        flap.name = f"{prefix}Collar_{'L' if sx > 0 else 'R'}"
        flap.scale = (0.092, 0.115, 0.022)
        apply_bevel_and_smooth(flap, width=0.003)
        attach_to_bone(flap, arm, "spine_03", mat_collar)

    if with_placket:
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, -0.142, 1.24))
        placket = bpy.context.active_object
        placket.name = f"{prefix}Placket"
        placket.scale = (0.032, 0.010, 0.26)
        apply_bevel_and_smooth(placket, width=0.002, segments=2)
        attach_to_bone(placket, arm, "spine_02", mat_placket)


def build_ual_character(
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
    long_sleeve: bool = False,
    bare_calves_z=None,
    is_male: bool = False,
):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(RAW_DIR, "UAL1.glb"))
    saved_actions = []
    for src_name, dst_name in UAL_CLIP_MAP.items():
        src_act = bpy.data.actions.get(src_name)
        if not src_act:
            raise RuntimeError(f"Missing UAL1 action {src_name}")
        ac = src_act.copy()
        ac.name = dst_name
        ac.use_fake_user = True
        for fc in ac.fcurves:
            if '"Head"' in fc.data_path:
                fc.data_path = fc.data_path.replace('"Head"', '"head"')
        saved_actions.append(ac)

    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for act in list(bpy.data.actions):
        if act not in saved_actions:
            bpy.data.actions.remove(act)

    bpy.ops.import_scene.gltf(filepath=os.path.join(RAW_DIR, raw_filename))
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    for pb in arm.pose.bones:
        pb.custom_shape = None
    for obj in list(bpy.data.objects):
        if obj.type == 'MESH' and 'icosphere' in obj.name.lower():
            bpy.data.objects.remove(obj, do_unlink=True)

    body_mesh = next(o for o in bpy.data.objects if o.type == 'MESH')

    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = body_mesh
    body_mesh.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    # Keep full smooth mannequin topology (7,011-7,222 verts) without destructive Decimate
    # Clear fragmented split normals & merge body UVs so glTF exports ~8,500 smooth vertices instead of 24k split UV islands
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = body_mesh
    body_mesh.select_set(True)
    # Gentle 0.72 weld keeps smooth anatomy (~11.5k glTF verts <= 14,500 cap!) without 0.45 faceting
    if len(body_mesh.data.vertices) > 7050:
        dec = body_mesh.modifiers.new("Decimate", 'DECIMATE')
        dec.ratio = 0.72
        bpy.ops.object.modifier_apply(modifier="Decimate")
    if body_mesh.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(82))
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.shade_smooth()

    hb = measure_head_bounds(body_mesh)
    bisect_clean_garment_seams(body_mesh, arm, sleeve_frac=0.52, bare_calves_z=bare_calves_z, long_sleeve=long_sleeve)
    batik_img = None
    if batik_cfg is not None:
        batik_img = generate_batik_texture(TEX_DIR, batik_cfg["name"], batik_cfg["base"], batik_cfg["accent"])
    face_name = f"face_{os.path.splitext(out_filename)[0]}"
    face_img = generate_stylized_face_texture(TEX_DIR, face_name, palette["skin"])
    assign_body_materials(
        body_mesh, arm, palette, hb, face_img, batik_img=batik_img,
        sleeve_frac=0.52, bare_calves_z=bare_calves_z, long_sleeve=long_sleeve,
    )

    build_stylized_indonesian_face(arm, body_mesh, hb, palette["skin"], palette["hair"])
    headwear = build_indonesian_hair_or_hijab(arm, body_mesh, hb, hair_style, palette["hair"], ribbon_rgb=ribbon_rgb, hijab_rgb=hijab)
    hw_xs = [v.co.x for v in headwear.data.vertices]
    assert max(hw_xs) > hb["x_max"] + 0.006 and min(hw_xs) < hb["x_min"] - 0.006, (
        f"Headwear clearance failed for {out_filename}: hw={min(hw_xs):.3f}..{max(hw_xs):.3f} vs skull={hb['x_min']:.3f}..{hb['x_max']:.3f}"
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
        mat_pocket = make_matte_mat("ApronPocket", (0.68, 0.58, 0.44), 0.88)
        build_fitted_curved_apron(arm, mat_apron, mat_pocket)

    valid_bones = {b.name for b in arm.data.bones}
    if not arm.animation_data:
        arm.animation_data_create()
    for tr in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(tr)

    for act in saved_actions:
        for fc in list(act.fcurves):
            if 'pose.bones["' in fc.data_path:
                bname = fc.data_path.split('pose.bones["')[1].split('"]')[0]
                if bname not in valid_bones:
                    act.fcurves.remove(fc)
        tr = arm.animation_data.nla_tracks.new()
        tr.name = act.name
        tr.strips.new(act.name, int(round(act.frame_range[0])), act)

    idle_act = bpy.data.actions.get("Idle")
    if idle_act:
        arm.animation_data.action = idle_act

    total_verts = sum(len(o.data.vertices) for o in bpy.data.objects if o.type == 'MESH')
    assert total_verts <= 14500, f"{out_filename} exceeded 14500 vert budget: {total_verts}"
    out_path = os.path.join(MODELS_DIR, out_filename)
    os.makedirs(MODELS_DIR, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out_path, export_format='GLB',
        export_animations=True, export_nla_strips=True, export_nla_strips_merged_animation_name="Idle",
    )
    print("EXPORTED UAL1 HUMAN:", out_path, "total_verts=", total_verts, "bytes=", os.path.getsize(out_path))


if __name__ == "__main__":
    build_ual_character(
        "mannequin-female.glb", "char_art.glb",
        {"skin": (0.34, 0.18, 0.09), "shirt": (0.14, 0.36, 0.26), "pants": (0.12, 0.16, 0.14), "hair": (0.04, 0.03, 0.03), "shoes": (0.14, 0.08, 0.06)},
        hair_style="cepol",
        batik_cfg={"name": "daster_art_starter", "base": (0.14, 0.36, 0.26), "accent": (0.92, 0.76, 0.38)},
        apron=True, ribbon_rgb=(0.76, 0.24, 0.18), bare_calves_z=0.49,
        skirt_cfg={"name": "DasterSkirt_Batik", "obj_name": "DasterSkirt", "use_batik": True,
                   "rings": [(0.48, 0.235, 0.195, 0.01), (0.68, 0.225, 0.185, 0.01), (0.88, 0.205, 0.165, 0.01), (1.03, 0.175, 0.145, 0.00)]},
    )

    build_ual_character(
        "mannequin-female.glb", "char_art_hijab.glb",
        {"skin": (0.34, 0.18, 0.09), "shirt": (0.16, 0.34, 0.42), "pants": (0.10, 0.13, 0.18), "hair": (0.04, 0.03, 0.03), "shoes": (0.14, 0.08, 0.06)},
        hair_style="hijab_bergo",
        batik_cfg={"name": "daster_art_hijab", "base": (0.16, 0.34, 0.42), "accent": (0.90, 0.80, 0.56)},
        apron=True, hijab=(0.14, 0.30, 0.22), long_sleeve=True,
        skirt_cfg={"name": "DasterHijab_Batik", "obj_name": "DasterSkirt", "use_batik": True,
                   "rings": [(0.26, 0.245, 0.205, 0.02), (0.52, 0.225, 0.185, 0.01), (0.78, 0.215, 0.175, 0.01), (1.03, 0.175, 0.145, 0.00)]},
    )

    build_ual_character(
        "mannequin-female.glb", "char_art_pro.glb",
        {"skin": (0.34, 0.18, 0.09), "shirt": (0.08, 0.32, 0.32), "pants": (0.09, 0.12, 0.18), "hair": (0.04, 0.03, 0.03), "shoes": (0.76, 0.74, 0.70)},
        hair_style="cepol", apron=True, ribbon_rgb=(0.12, 0.42, 0.40), white_collar=True,
    )

    build_ual_character(
        "mannequin-female.glb", "char_art_elite.glb",
        {"skin": (0.34, 0.18, 0.09), "shirt": (0.07, 0.15, 0.24), "pants": (0.07, 0.09, 0.14), "hair": (0.04, 0.03, 0.03), "shoes": (0.10, 0.12, 0.16)},
        hair_style="cepol", apron=True, ribbon_rgb=(0.82, 0.80, 0.76), white_collar=True,
    )

    build_ual_character(
        "mannequin-female.glb", "char_ibu.glb",
        {"skin": (0.38, 0.21, 0.11), "shirt": (0.48, 0.14, 0.11), "pants": (0.14, 0.09, 0.09), "hair": (0.04, 0.03, 0.03), "shoes": (0.18, 0.08, 0.05)},
        hair_style="hijab_bergo",
        batik_cfg={"name": "batik_ibu", "base": (0.48, 0.14, 0.11), "accent": (0.88, 0.66, 0.26)},
        apron=False, hijab=(0.20, 0.04, 0.05), long_sleeve=True,
        skirt_cfg={"name": "LongSkirt", "obj_name": "LongSkirt", "use_batik": False, "color": (0.16, 0.10, 0.09),
                   "rings": [(0.24, 0.245, 0.205, 0.02), (0.50, 0.225, 0.195, 0.01), (0.76, 0.215, 0.175, 0.01), (1.03, 0.175, 0.145, 0.00)]},
    )

    build_ual_character(
        "mannequin-female.glb", "char_kakak.glb",
        {"skin": (0.40, 0.22, 0.12), "shirt": (0.56, 0.24, 0.32), "pants": (0.16, 0.20, 0.30), "hair": (0.05, 0.04, 0.03), "shoes": (0.82, 0.80, 0.78)},
        hair_style="bob", apron=False, bare_calves_z=0.53,
        skirt_cfg={"name": "KakakMidiSkirt", "obj_name": "KakakSkirt", "use_batik": False, "color": (0.16, 0.20, 0.30),
                   "rings": [(0.52, 0.22, 0.19, 0.01), (0.74, 0.21, 0.17, 0.01), (0.94, 0.19, 0.15, 0.01), (1.03, 0.17, 0.14, 0.00)]},
    )

    build_ual_character(
        "base.glb", "char_budi.glb",
        {"skin": (0.30, 0.15, 0.08), "shirt": (0.14, 0.26, 0.15), "pants": (0.12, 0.13, 0.16), "hair": (0.04, 0.03, 0.03), "shoes": (0.16, 0.09, 0.06)},
        hair_style="bapak",
        batik_cfg={"name": "batik_budi", "base": (0.14, 0.26, 0.15), "accent": (0.76, 0.62, 0.26)},
        apron=False, collar_placket=True, is_male=True,
    )

    # 8 Unique NPC models (zero green daster reuse, zero duplicate NPC silhouettes!)
    build_ual_character(
        "mannequin-female.glb", "char_dewi.glb",
        {"skin": (0.37, 0.20, 0.11), "shirt": (0.82, 0.34, 0.24), "pants": (0.15, 0.22, 0.36), "hair": (0.04, 0.03, 0.03), "shoes": (0.72, 0.68, 0.62)},
        hair_style="ponytail", apron=False, collar_placket=True,
    )

    build_ual_character(
        "base.glb", "char_pak_rt.glb",
        {"skin": (0.33, 0.17, 0.09), "shirt": (0.52, 0.38, 0.16), "pants": (0.11, 0.12, 0.15), "hair": (0.05, 0.04, 0.04), "shoes": (0.14, 0.10, 0.08)},
        hair_style="peci",
        batik_cfg={"name": "batik_pak_rt", "base": (0.46, 0.32, 0.14), "accent": (0.92, 0.78, 0.42)},
        apron=False, collar_placket=True, is_male=True,
    )

    build_ual_character(
        "base.glb", "char_ojek.glb",
        {"skin": (0.31, 0.16, 0.08), "shirt": (0.10, 0.56, 0.24), "pants": (0.14, 0.19, 0.30), "hair": (0.04, 0.03, 0.03), "shoes": (0.12, 0.12, 0.14)},
        hair_style="ojek_helmet", apron=False, collar_placket=True, long_sleeve=True, is_male=True,
    )

    build_ual_character(
        "base.glb", "char_kurir.glb",
        {"skin": (0.34, 0.18, 0.09), "shirt": (0.88, 0.40, 0.12), "pants": (0.15, 0.18, 0.26), "hair": (0.04, 0.03, 0.03), "shoes": (0.14, 0.14, 0.16)},
        hair_style="cap", apron=False, collar_placket=True, is_male=True,
    )

    build_ual_character(
        "mannequin-female.glb", "char_pelajar.glb",
        {"skin": (0.39, 0.21, 0.11), "shirt": (0.90, 0.90, 0.88), "pants": (0.34, 0.36, 0.42), "hair": (0.04, 0.03, 0.03), "shoes": (0.12, 0.12, 0.14)},
        hair_style="bob", apron=False, collar_placket=True, bare_calves_z=0.52,
        skirt_cfg={"name": "SmaSkirt", "obj_name": "SmaSkirt", "use_batik": False, "color": (0.34, 0.36, 0.42),
                   "rings": [(0.52, 0.22, 0.19, 0.01), (0.74, 0.21, 0.17, 0.01), (0.94, 0.19, 0.15, 0.01), (1.03, 0.17, 0.14, 0.00)]},
    )

    build_ual_character(
        "base.glb", "char_hendra.glb",
        {"skin": (0.36, 0.19, 0.10), "shirt": (0.14, 0.22, 0.38), "pants": (0.48, 0.42, 0.32), "hair": (0.05, 0.04, 0.03), "shoes": (0.22, 0.14, 0.09)},
        hair_style="bapak", apron=False, collar_placket=True, is_male=True,
    )

    build_ual_character(
        "mannequin-female.glb", "char_rina.glb",
        {"skin": (0.35, 0.19, 0.10), "shirt": (0.44, 0.32, 0.56), "pants": (0.14, 0.14, 0.18), "hair": (0.04, 0.03, 0.03), "shoes": (0.20, 0.14, 0.12)},
        hair_style="hijab_bergo", hijab=(0.82, 0.76, 0.66), long_sleeve=True,
        skirt_cfg={"name": "RinaSkirt", "obj_name": "RinaSkirt", "use_batik": False, "color": (0.18, 0.16, 0.24),
                   "rings": [(0.26, 0.24, 0.20, 0.02), (0.52, 0.22, 0.18, 0.01), (0.78, 0.21, 0.17, 0.01), (1.03, 0.17, 0.14, 0.00)]},
    )

    build_ual_character(
        "base.glb", "char_agus.glb",
        {"skin": (0.32, 0.17, 0.09), "shirt": (0.48, 0.24, 0.14), "pants": (0.16, 0.15, 0.14), "hair": (0.05, 0.04, 0.03), "shoes": (0.18, 0.12, 0.08)},
        hair_style="bapak",
        batik_cfg={"name": "batik_agus", "base": (0.48, 0.24, 0.14), "accent": (0.86, 0.70, 0.36)},
        apron=False, collar_placket=True, is_male=True,
    )
