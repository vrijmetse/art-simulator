import os
import sys
import math
import numpy as np
import bpy
import bmesh

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from tex_utils import (
    bake_scene_lightmap_uv2,
    export_room_glb,
    generate_asphalt_textures,
    generate_batu_alam_texture,
    generate_license_plate,
    generate_plaster_ao_texture,
    generate_sidewalk_concrete_texture,
    generate_street_sign_texture,
    generate_terracotta_textures,
    generate_tile_textures,
    generate_turf_texture,
    generate_wood_texture,
    make_pbr_material,
    polish_scene_textures_1024,
)

GODOT_DIR = os.path.dirname(SCRIPT_DIR)
TEX_DIR = os.path.join(GODOT_DIR, "assets", "textures")
UNPACKED_DIR = os.path.join(GODOT_DIR, "assets", "raw", "unpacked")
OUT_GLB = os.path.join(GODOT_DIR, "assets", "models", "kampung_street.glb")


def make_solid_mat(name, rgb, roughness=0.78, metallic=0.0, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def add_box(name, size, loc, mat, bevel_width=0.022, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel_width > 0:
        bev = obj.modifiers.new(name="Bevel", type='BEVEL')
        bev.width = bevel_width
        bev.segments = 2
        bev.limit_method = 'ANGLE'
        bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_smooth()
    if obj.data.polygons:
        obj.data.use_auto_smooth = True
        obj.data.auto_smooth_angle = math.radians(42)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.cube_project(cube_size=max(size) * 0.6)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.materials.append(mat)
    return obj


_UNPACKED_TEMPLATE_CACHE = {}


def _strip_unlit_and_setup_mat(m, mat_overrides=None):
    m.blend_method = 'OPAQUE'
    m.use_backface_culling = False
    if not m.use_nodes:
        return m
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    if bsdf is None:
        # Strip KHR_materials_unlit: find any image texture (colormap) and wire to a new Principled BSDF
        tex_node = next((n for n in nt.nodes if n.type == 'TEX_IMAGE'), None)
        out_node = next((n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'), None)
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.inputs["Roughness"].default_value = 0.80
        if tex_node is not None:
            nt.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
        if out_node is not None:
            nt.links.new(bsdf.outputs["BSDF"], out_node.inputs["Surface"])
    else:
        bsdf.inputs["Alpha"].default_value = 1.0

    if mat_overrides:
        for key, rgb in mat_overrides.items():
            if key in m.name.lower():
                nm = m.copy()
                nm.use_backface_culling = False
                nbsdf = nm.node_tree.nodes.get("Principled BSDF")
                if nbsdf is not None:
                    nbsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
                    nbsdf.inputs["Roughness"].default_value = 0.84
                    if "leaves" in key:
                        nbsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
                        nbsdf.inputs["Emission Strength"].default_value = 0.03
                return nm
    return m


def import_unpacked_asset(glb_name: str, loc, scale: float, yaw_deg: float = 0.0, mat_overrides=None):
    if not bpy.data.meshes:
        _UNPACKED_TEMPLATE_CACHE.clear()

    ov_key = tuple(sorted((k, tuple(v)) for k, v in (mat_overrides or {}).items()))
    cache_key = (glb_name, ov_key)

    if cache_key not in _UNPACKED_TEMPLATE_CACHE:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(UNPACKED_DIR, glb_name))
        added = [o for o in bpy.data.objects if o not in before]
        template_entries = []
        for o in added:
            if o.type != 'MESH' or not o.data:
                continue
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.select_all(action='DESELECT')
            o.select_set(True)
            for i, m in enumerate(list(o.data.materials)):
                if not m:
                    continue
                o.data.materials[i] = _strip_unlit_and_setup_mat(m, mat_overrides)
            if "tree" not in glb_name.lower() and "bush" not in glb_name.lower():
                sub = o.modifiers.new("TemplateSubsurf", 'SUBSURF')
                sub.levels = 1
                sub.render_levels = 1
                bpy.ops.object.convert(target='MESH')
            bpy.ops.object.shade_smooth()
            bpy.ops.object.mode_set(mode='EDIT')
            bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.mesh.normals_make_consistent(inside=False)
            bpy.ops.object.mode_set(mode='OBJECT')
            template_entries.append((
                o.name,
                o.data,
                tuple(o.matrix_world.to_translation()),
                tuple(o.matrix_world.to_euler()),
                tuple(o.matrix_world.to_scale()),
            ))
        # Remove temporary imported objects (meshes stay alive in _UNPACKED_TEMPLATE_CACHE)
        for o in added:
            bpy.data.objects.remove(o, do_unlink=True)
        _UNPACKED_TEMPLATE_CACHE[cache_key] = template_entries

    created = []
    yaw_rad = math.radians(yaw_deg)
    cos_y, sin_y = math.cos(yaw_rad), math.sin(yaw_rad)
    for tname, tmesh, tloc, trot, tscale in _UNPACKED_TEMPLATE_CACHE[cache_key]:
        inst = bpy.data.objects.new(f"{tname}_inst", tmesh)
        rx = (tloc[0] * cos_y - tloc[1] * sin_y) * scale
        ry = (tloc[0] * sin_y + tloc[1] * cos_y) * scale
        rz = tloc[2] * scale
        inst.location = (loc[0] + rx, loc[1] + ry, loc[2] + rz)
        inst.rotation_euler = (trot[0], trot[1], trot[2] + yaw_rad)
        inst.scale = (tscale[0] * scale, tscale[1] * scale, tscale[2] * scale)
        bpy.context.collection.objects.link(inst)
        created.append(inst)
    return created


def add_pitched_roof(name, width, depth, height, loc, mat, ridge_mat, trim_mat, iron_mat, style="hip"):
    bm = bmesh.new()
    hw, hd = width * 0.5, depth * 0.5
    if style == "pelana_front":
        # Front-facing Pelana gable: ridge runs along Y (front-to-back)
        v0 = bm.verts.new((-hw, -hd, 0.0))
        v1 = bm.verts.new((hw, -hd, 0.0))
        v2 = bm.verts.new((hw, hd, 0.0))
        v3 = bm.verts.new((-hw, hd, 0.0))
        rf = bm.verts.new((0.0, -hd, height))
        rb = bm.verts.new((0.0, hd, height))
        bm.faces.new((v0, rf, rb, v3))
        bm.faces.new((v1, v2, rb, rf))
        bm.faces.new((v0, v1, rf))
        bm.faces.new((v2, v3, rb))
        bm.faces.new((v0, v3, v2, v1))
    else:
        inset = hw * 0.24
        v0 = bm.verts.new((-hw, -hd, 0.0))
        v1 = bm.verts.new((hw, -hd, 0.0))
        v2 = bm.verts.new((hw, hd, 0.0))
        v3 = bm.verts.new((-hw, hd, 0.0))
        r0 = bm.verts.new((-hw + inset, 0.0, height))
        r1 = bm.verts.new((hw - inset, 0.0, height))
        bm.faces.new((v0, v1, r1, r0))
        bm.faces.new((v1, v2, r1))
        bm.faces.new((v2, v3, r0, r1))
        bm.faces.new((v3, v0, r0))
        bm.faces.new((v0, v3, v2, v1))

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    bev = obj.modifiers.new("Bevel", 'BEVEL')
    bev.width = 0.03
    bev.segments = 2
    bpy.ops.object.modifier_apply(modifier="Bevel")
    bpy.ops.object.shade_smooth()
    obj.data.use_auto_smooth = True
    obj.data.auto_smooth_angle = math.radians(45)

    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.cube_project(cube_size=1.4)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.materials.append(mat)

    if style == "pelana_front":
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=14, radius=0.052, depth=depth + 0.14,
            location=(loc[0], loc[1], loc[2] + height + 0.02),
            rotation=(math.pi * 0.5, 0.0, 0.0),
        )
        ridge = bpy.context.active_object
        bpy.ops.object.shade_smooth()
        ridge.data.materials.append(trim_mat)

        # Crisp diagonal white gable lisplank triangles on front & back (trimmed flush at eaves & peak)
        slope_len = math.hypot(hw, height) - 0.06
        slope_ang = math.atan2(height, hw)
        for side_sign in (-1.0, 1.0):
            add_box(
                f"{name}_GableLisplank_{side_sign}",
                (slope_len, 0.08, 0.11),
                (loc[0] + side_sign * hw * 0.5, loc[1] - hd - 0.02, loc[2] + height * 0.5 - 0.03),
                trim_mat, 0.01, (0.0, side_sign * slope_ang, 0.0),
            )
    else:
        inset = hw * 0.24
        ridge_len = width - inset * 2.0 + 0.22
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=14, radius=0.052, depth=ridge_len,
            location=(loc[0], loc[1], loc[2] + height + 0.02),
            rotation=(0.0, math.pi * 0.5, 0.0),
        )
        ridge = bpy.context.active_object
        bpy.ops.object.shade_smooth()
        ridge.data.materials.append(trim_mat)

        rows = 5
        for r in range(rows):
            t = (r + 0.35) / rows
            rz = loc[2] + t * (height * 0.92) + 0.02
            ry = loc[1] - hd * (1.0 - t)
            rw = width - 2.0 * inset * t + 0.08
            add_box(f"{name}_TileCourse_{r}", (rw, 0.12, 0.06), (loc[0], ry, rz), mat, 0.018, (math.radians(38), 0, 0))

        # Crisp diagonal white hip-ridge lisplank accents
        hip_len = math.hypot(inset, math.hypot(hd, height)) * 0.96
        for sx in (-1.0, 1.0):
            add_box(
                f"{name}_HipTrim_{sx}",
                (0.06, hip_len, 0.06),
                (loc[0] + sx * (hw - inset * 0.5), loc[1] - hd * 0.5, loc[2] + height * 0.5 + 0.02),
                trim_mat, 0.01, (math.radians(36), 0.0, sx * math.radians(-28)),
            )

    if style == "two_tier":
        # Taller 2nd-tier upper clerestory + upper pitched roof for distinct silhouette
        add_box(f"{name}_UpperNeck", (width * 0.54, depth * 0.54, 0.34), (loc[0], loc[1], loc[2] + height * 0.72), trim_mat, 0.012)
        add_pitched_roof(f"{name}_UpperTier", width * 0.62, depth * 0.62, height * 0.58, (loc[0], loc[1], loc[2] + height * 0.88), mat, ridge_mat, trim_mat, iron_mat, style="hip")

    add_box(f"{name}_LisplankF", (width + 0.06, 0.06, 0.12), (loc[0], loc[1] - hd - 0.02, loc[2] - 0.03), trim_mat, 0.01)
    add_box(f"{name}_LisplankL", (0.06, depth + 0.06, 0.12), (loc[0] - hw - 0.02, loc[1], loc[2] - 0.03), trim_mat, 0.01)
    add_box(f"{name}_LisplankR", (0.06, depth + 0.06, 0.12), (loc[0] + hw + 0.02, loc[1], loc[2] - 0.03), trim_mat, 0.01)
    add_box(f"{name}_Soffit", (width - 0.04, depth - 0.04, 0.05), (loc[0], loc[1], loc[2] - 0.03), trim_mat, 0.005)
    # Eave rain gutter (talang air) + front-left vertical downspout
    add_box(f"{name}_Gutter", (width + 0.04, 0.08, 0.06), (loc[0], loc[1] - hd - 0.06, loc[2] - 0.07), iron_mat, 0.012)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.032, depth=2.15, location=(loc[0] - hw + 0.25, loc[1] - hd + 0.25, 1.15))
    bpy.context.active_object.data.materials.append(iron_mat)


def add_indonesian_house_36_72(
    idx, cx, wall_mat, roof_mat, wood_mat, tile_mat, iron_mat, glass_mat,
    ac_mat, lamp_mat, trim_mat, brass_mat, cushion_mat, tank_mat, stone_mat
):
    add_box(f"House_{idx}_Body", (3.15, 2.25, 2.38), (cx, 2.70, 1.19), wall_mat, 0.03)
    add_box(f"House_{idx}_Plinth", (3.25, 2.35, 0.22), (cx, 2.70, 0.11), tile_mat, 0.015)

    roof_style = "pelana_front" if idx in (0, -1) else ("hip" if idx == 1 else "two_tier")
    roof_h = 1.32 if roof_style == "pelana_front" else 1.18
    add_pitched_roof(f"House_{idx}_Roof", 3.76, 2.96, roof_h, (cx, 2.70, 2.34), roof_mat, roof_mat, trim_mat, iron_mat, style=roof_style)
    # Move Toren Air cleanly to rear service deck behind main roof ridge (zero front roof clipping!)
    if idx in (0, 1):
        tx = cx + (1.05 if idx == 1 else -1.05)
        add_box(f"House_{idx}_TorenDeck", (0.72, 0.72, 0.14), (tx, 3.35, 2.75), trim_mat, 0.015)
        add_box(f"House_{idx}_TorenStand", (0.50, 0.50, 0.32), (tx, 3.35, 2.96), iron_mat, 0.008)
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.25, depth=0.52, location=(tx, 3.35, 3.36))
        toren = bpy.context.active_object
        bpy.ops.object.shade_smooth()
        toren.data.materials.append(tank_mat)
        for rz in (3.22, 3.36, 3.50):
            bpy.ops.mesh.primitive_torus_add(major_radius=0.255, minor_radius=0.016, major_segments=16, minor_segments=6, location=(tx, 3.35, rz))
            bpy.ops.object.shade_smooth()
            bpy.context.active_object.data.materials.append(tank_mat)
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.11, depth=0.05, location=(tx, 3.35, 3.64))
        bpy.context.active_object.data.materials.append(iron_mat)

    # 3 Distinct Indonesian House Variations (0: Pergola carport, 1: Hip Limasan + Shutters, 2: Modern Kisi Kayu)
    if idx == 0:
        # Teak pergola beams over front porch (removed blank cream GableTrim rectangle!)
        for rx in (-0.8, -0.4, 0.0, 0.4, 0.8):
            add_box(f"House_{idx}_Pergola_{rx}", (0.06, 1.26, 0.08), (cx + rx, 1.02, 1.84), wood_mat, 0.008)
    elif idx == 1:
        # Indonesian teak krepyak louvered shutters flanking front window!
        for sx in (0.04, 1.24):
            add_box(f"House_{idx}_Shutter_{sx}", (0.20, 0.05, 0.72), (cx + sx, 1.47, 1.16), wood_mat, 0.008)
    else:
        # Modern Cluster vertical teak wood-slat accent wall (kisi kayu) beside front door!
        for kx in range(5):
            add_box(f"House_{idx}_Kisi_{kx}", (0.04, 0.05, 1.85), (cx - 1.38 + kx * 0.09, 1.51, 1.22), wood_mat, 0.006)

    add_box(f"House_{idx}_Terrace", (3.30, 1.28, 0.14), (cx, 1.02, 0.07), tile_mat, 0.02)
    add_box(f"House_{idx}_PorchRoof", (3.44, 1.34, 0.08), (cx, 1.02, 1.78), roof_mat, 0.02, (math.radians(7.0), 0.0, 0.0))
    add_box(f"House_{idx}_PorchFascia", (3.46, 0.06, 0.10), (cx, 0.34, 1.69), trim_mat, 0.01)
    # Exposed dark teak porch rafters under eaves
    for rx in (-1.20, -0.72, -0.24, 0.24, 0.72, 1.20):
        add_box(f"House_{idx}_PorchRafter_{rx}", (0.055, 1.30, 0.075), (cx + rx, 1.02, 1.71), wood_mat, 0.008, (math.radians(7.0), 0.0, 0.0))
    # Full-height natural Batu Alam split-stone square porch pillars + crisp white cap!
    for px in (-1.38, 1.38):
        add_box(f"House_{idx}_PilStone_{px}", (0.25, 0.25, 1.56), (cx + px, 0.48, 0.86), stone_mat, 0.015)
        add_box(f"House_{idx}_PilCap_{px}", (0.30, 0.30, 0.09), (cx + px, 0.48, 1.66), trim_mat, 0.012)

    # High-contrast 4-panel Teak Door + Dark Stone Wainscot + Glossy Dark Glass Windows (WinGlass STRICTLY in front of WinFrame!)
    add_box(f"House_{idx}_Wainscot", (3.20, 2.30, 0.52), (cx, 2.70, 0.36), stone_mat, 0.015)
    add_box(f"House_{idx}_DoorFrame", (0.88, 0.10, 1.58), (cx - 0.58, 1.54, 0.87), wood_mat, 0.015)
    add_box(f"House_{idx}_DoorLeaf", (0.70, 0.05, 1.32), (cx - 0.58, 1.515, 0.78), wood_mat, 0.01)
    for px_off in (-0.14, 0.14):
        for pz in (0.45, 1.02):
            add_box(f"House_{idx}_DoorPanel_{px_off}_{pz}", (0.21, 0.03, 0.38), (cx - 0.58 + px_off, 1.485, pz), cushion_mat, 0.01)
    add_box(f"House_{idx}_DoorKnob", (0.04, 0.06, 0.11), (cx - 0.31, 1.46, 0.78), brass_mat, 0.008)
    for lz in (1.50, 1.55, 1.60):
        add_box(f"House_{idx}_DoorLouver_{lz}", (0.64, 0.04, 0.022), (cx - 0.58, 1.485, lz), trim_mat, 0.004)
    add_box(f"House_{idx}_WelcomeMat", (0.72, 0.46, 0.02), (cx - 0.58, 1.18, 0.155), cushion_mat, 0.008)

    # Recessed Casement Window: WinFrame at y=1.54 (front=1.49), WinGlass at y=1.482 (front=1.467 -> 100% visible!), Mullion at y=1.462!
    add_box(f"House_{idx}_WinFrame", (1.18, 0.10, 0.92), (cx + 0.64, 1.54, 1.20), trim_mat, 0.015)
    add_box(f"House_{idx}_WinSill", (1.26, 0.18, 0.06), (cx + 0.64, 1.46, 0.74), stone_mat, 0.012)
    add_box(f"House_{idx}_WinGlass", (1.00, 0.03, 0.68), (cx + 0.64, 1.482, 1.16), glass_mat, 0.004)
    add_box(f"House_{idx}_WinCurtainL", (0.16, 0.02, 0.64), (cx + 0.24, 1.475, 1.16), cushion_mat, 0.005)
    add_box(f"House_{idx}_WinCurtainR", (0.16, 0.02, 0.64), (cx + 1.04, 1.475, 1.16), cushion_mat, 0.005)
    add_box(f"House_{idx}_WinMullion", (0.04, 0.04, 0.72), (cx + 0.64, 1.462, 1.16), wood_mat, 0.005)
    for wz in (1.56, 1.61):
        add_box(f"House_{idx}_WinLouver_{wz}", (0.98, 0.04, 0.022), (cx + 0.64, 1.482, wz), wood_mat, 0.004)

    # Outdoor AC Compressor Mounted High on Upper Wall (z=2.14, clearly above porch roof!) with L-Brackets + Fan Grille + Copper Pipe
    add_box(f"House_{idx}_ACBody", (0.52, 0.22, 0.36), (cx + 1.15, 1.46, 2.14), ac_mat, 0.02)
    for bx in (0.98, 1.32):
        add_box(f"House_{idx}_ACBracket_{bx}", (0.04, 0.24, 0.04), (cx + bx, 1.46, 1.95), iron_mat, 0.005)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.13, depth=0.04, location=(cx + 1.05, 1.345, 2.14), rotation=(math.pi * 0.5, 0, 0))
    bpy.context.active_object.data.materials.append(iron_mat)
    add_box(f"House_{idx}_ACPipe", (0.04, 0.04, 0.58), (cx + 1.42, 1.50, 1.95), trim_mat, 0.008)
    add_box(f"House_{idx}_Lamp", (0.14, 0.12, 0.18), (cx - 0.05, 1.50, 1.46), lamp_mat, 0.02)
    add_box(f"House_{idx}_Plaque", (0.24, 0.03, 0.15), (cx - 1.54, 0.12, 0.78), brass_mat, 0.008)

    # Porch Rattan Chairs with Coral Cushions + Coffee Table + Teacup
    for ch_x in (0.45, 1.08):
        add_box(f"House_{idx}_ChairSeat_{ch_x}", (0.36, 0.36, 0.06), (cx + ch_x, 0.85, 0.42), wood_mat, 0.015)
        add_box(f"House_{idx}_ChairCushion_{ch_x}", (0.30, 0.30, 0.04), (cx + ch_x, 0.85, 0.46), cushion_mat, 0.012)
        add_box(f"House_{idx}_ChairBack_{ch_x}", (0.36, 0.05, 0.34), (cx + ch_x, 1.01, 0.60), wood_mat, 0.012)
        add_box(f"House_{idx}_ChairLeg_{ch_x}", (0.30, 0.30, 0.28), (cx + ch_x, 0.85, 0.26), iron_mat, 0.006)
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.19, depth=0.04, location=(cx + 0.76, 0.82, 0.44))
    bpy.ops.object.shade_smooth()
    bpy.context.active_object.data.materials.append(wood_mat)
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.04, depth=0.06, location=(cx + 0.76, 0.82, 0.49))
    bpy.context.active_object.data.materials.append(trim_mat)

    # Porch flowering potted shrub (Quaternius CC0 bush-common-flowers!)
    import_unpacked_asset("bush-common-flowers.glb", (cx - 1.12, 0.70, 0.14), 0.36, idx * 40, {
        "leaves": (0.16, 0.48, 0.18),
        "flowers": (0.90, 0.24, 0.46),
    })

    # Framed Wrought-Iron Gate & Batu Alam Cladded Gate Pillars
    for fx in (-1.54, -0.45, 0.45, 1.54):
        add_box(f"House_{idx}_GatePillar_{fx}", (0.25, 0.25, 0.98), (cx + fx, 0.26, 0.49), stone_mat, 0.018)
        add_box(f"House_{idx}_GateCap_{fx}", (0.31, 0.31, 0.08), (cx + fx, 0.26, 1.01), trim_mat, 0.015)
    for side_x in (-0.99, 0.99):
        add_box(f"House_{idx}_FenceWall_{side_x}", (0.96, 0.16, 0.46), (cx + side_x, 0.26, 0.23), wall_mat, 0.018)
        add_box(f"House_{idx}_FenceRailTop_{side_x}", (0.94, 0.04, 0.035), (cx + side_x, 0.26, 0.86), iron_mat, 0.005)
        add_box(f"House_{idx}_FenceRailBot_{side_x}", (0.94, 0.04, 0.035), (cx + side_x, 0.26, 0.50), iron_mat, 0.005)
        for bx in (-0.36, -0.22, -0.08, 0.08, 0.22, 0.36):
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.011, depth=0.44, location=(cx + side_x + bx, 0.26, 0.70))
            bpy.context.active_object.data.materials.append(iron_mat)
    add_box(f"House_{idx}_GateRailT", (0.82, 0.04, 0.04), (cx, 0.26, 0.86), iron_mat, 0.006)
    add_box(f"House_{idx}_GateRailB", (0.82, 0.04, 0.04), (cx, 0.26, 0.20), iron_mat, 0.006)
    for gx in (-0.32, -0.18, -0.05, 0.05, 0.18, 0.32):
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.011, depth=0.72, location=(cx + gx, 0.26, 0.54))
        bpy.context.active_object.data.materials.append(iron_mat)

    # Lush stone-trimmed planter boxes packed with dense flowering shrubs along front fence
    for side_x in (-0.99, 0.99):
        add_box(f"House_{idx}_PlanterBox_{side_x}", (0.94, 0.34, 0.22), (cx + side_x, 0.02, 0.11), stone_mat, 0.015)
        add_box(f"House_{idx}_PlanterRim_{side_x}", (0.98, 0.38, 0.04), (cx + side_x, 0.02, 0.23), trim_mat, 0.008)
        for sx_off, sc, yaw_o in ((-0.26, 0.34, 15), (0.0, 0.38, 95), (0.26, 0.34, 175)):
            import_unpacked_asset("bush-common-flowers.glb", (cx + side_x + sx_off, 0.02, 0.18), sc, idx * 30 + yaw_o, {
                "leaves": (0.18, 0.50, 0.18),
                "flowers": (0.92, 0.26, 0.48),
            })


def add_utility_pole_and_wires(x_positions, y_pos, iron_mat, white_mat, lamp_mat):
    for i, x in enumerate(x_positions):
        bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.075, radius2=0.048, depth=3.45, location=(x, y_pos, 1.725))
        pole = bpy.context.active_object
        bpy.ops.object.shade_smooth()
        pole.data.materials.append(iron_mat)
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.105, depth=0.26, location=(x, y_pos, 0.13))
        base = bpy.context.active_object
        bpy.ops.object.shade_smooth()
        base.data.materials.append(white_mat)
        add_box(f"PoleArm_{i}", (0.76, 0.07, 0.07), (x, y_pos, 3.25), iron_mat, 0.01)
        for ix in (-0.28, 0.0, 0.28):
            bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.025, depth=0.07, location=(x + ix, y_pos, 3.31))
            bpy.context.active_object.data.materials.append(white_mat)
        if i == 1:
            add_box(f"StreetLampArm_{i}", (0.06, 0.55, 0.05), (x, y_pos - 0.28, 2.86), iron_mat, 0.01, (math.radians(-18), 0, 0))
            add_box(f"StreetLampHead_{i}", (0.18, 0.28, 0.08), (x, y_pos - 0.54, 2.94), lamp_mat, 0.02)

    for i in range(len(x_positions) - 1):
        x0, x1 = x_positions[i], x_positions[i + 1]
        for z_off in (-0.24, 0.24):
            steps = 14
            for s in range(steps):
                t0, t1 = s / steps, (s + 1) / steps
                sx0, sx1 = x0 + (x1 - x0) * t0, x0 + (x1 - x0) * t1
                sz0 = 3.28 - 0.24 * math.sin(t0 * math.pi)
                sz1 = 3.28 - 0.24 * math.sin(t1 * math.pi)
                mid = ((sx0 + sx1) * 0.5, y_pos + z_off, (sz0 + sz1) * 0.5)
                dx, dz = sx1 - sx0, sz1 - sz0
                seg_len = math.hypot(dx, dz)
                ang = math.atan2(dz, dx)
                bpy.ops.mesh.primitive_cylinder_add(
                    vertices=6, radius=0.007, depth=seg_len + 0.015,
                    location=mid, rotation=(0.0, math.pi * 0.5 - ang, 0.0),
                )
                bpy.context.active_object.data.materials.append(iron_mat)


def add_sculpted_scooter(name, x, y, yaw, body_mat, dark_mat, metal_mat, lamp_mat, tail_mat):
    lean = math.radians(10.0)
    add_box(f"{name}_Floor", (0.30, 0.62, 0.12), (x, y, 0.25), body_mat, 0.05, (0, lean, yaw))
    add_box(f"{name}_RearCowling", (0.32, 0.44, 0.22), (x - math.sin(yaw) * 0.24, y + math.cos(yaw) * 0.24, 0.42), body_mat, 0.07, (0, lean, yaw))
    add_box(f"{name}_Seat", (0.26, 0.46, 0.10), (x - math.sin(yaw) * 0.20, y + math.cos(yaw) * 0.20, 0.56), dark_mat, 0.04, (0, lean, yaw))
    add_box(f"{name}_FrontApron", (0.28, 0.18, 0.52), (x + math.sin(yaw) * 0.28, y - math.cos(yaw) * 0.28, 0.54), body_mat, 0.06, (math.radians(-12), lean, yaw))
    add_box(f"{name}_Fork", (0.08, 0.08, 0.46), (x + math.sin(yaw) * 0.32, y - math.cos(yaw) * 0.32, 0.40), metal_mat, 0.02, (math.radians(-10), lean, yaw))
    add_box(f"{name}_Headlamp", (0.14, 0.08, 0.10), (x + math.sin(yaw) * 0.36, y - math.cos(yaw) * 0.36, 0.72), lamp_mat, 0.02, (0, lean, yaw))
    add_box(f"{name}_Taillamp", (0.14, 0.06, 0.07), (x - math.sin(yaw) * 0.46, y + math.cos(yaw) * 0.46, 0.48), tail_mat, 0.015, (0, lean, yaw))
    add_box(f"{name}_Handle", (0.48, 0.07, 0.07), (x + math.sin(yaw) * 0.26, y - math.cos(yaw) * 0.26, 0.86), dark_mat, 0.02, (0, lean, yaw))
    for mx in (-0.21, 0.21):
        add_box(f"{name}_Mirror_{mx}", (0.10, 0.04, 0.07), (x + math.sin(yaw) * 0.26 + mx * math.cos(yaw), y - math.cos(yaw) * 0.26 + mx * math.sin(yaw), 0.96), metal_mat, 0.01, (0, 0, yaw))
    for w_off in (-0.36, 0.36):
        wx = x + math.sin(yaw) * w_off
        wy = y - math.cos(yaw) * w_off
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.14, minor_radius=0.05,
            major_segments=18, minor_segments=10,
            location=(wx, wy, 0.19), rotation=(0.0, math.pi * 0.5, yaw),
        )
        tire = bpy.context.active_object
        bpy.ops.object.shade_smooth()
        tire.data.materials.append(dark_mat)
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=14, radius=0.10, depth=0.06,
            location=(wx, wy, 0.19), rotation=(0.0, math.pi * 0.5, yaw),
        )
        rim = bpy.context.active_object
        bpy.ops.object.shade_smooth()
        rim.data.materials.append(metal_mat)


def add_trash_bin(name, x, y, body_mat, lid_mat):
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.15, radius2=0.19, depth=0.50, location=(x, y, 0.25))
    body = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    body.data.materials.append(body_mat)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.20, depth=0.06, location=(x, y, 0.51))
    rim = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    rim.data.materials.append(lid_mat)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.19, location=(x, y, 0.52))
    dome = bpy.context.active_object
    dome.scale = (1.0, 1.0, 0.35)
    bpy.ops.object.shade_smooth()
    dome.data.materials.append(lid_mat)
    add_box(f"{name}_Handle", (0.12, 0.04, 0.04), (x, y, 0.59), body_mat, 0.01)


def bake_cycles_ao(arch_prefixes=("Ground_", "Sidewalk_", "Road_", "Kanstin", "PerimeterWall", "GangGround", "GangAlley", "PosRondaBase", "PosRondaRoof"), arch_suffixes=("_Body", "_Plinth", "_Terrace", "_PorchRoof", "KampungHouse_", "KampungPlinth_", "KampungTerrace_", "KampungPorchRoof_")):
    """Subdivide large architectural surfaces (6 cuts), bake Cycles CPU AO (8 samples, distance 1.0) into Col (COLOR_0), and remap RGB to 0.50 + 0.50 * val."""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 4
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 1
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.light_settings.distance = 1.0
    scene.render.bake.target = 'VERTEX_COLORS'

    arch_objs = []
    hidden_objs = []
    for obj in bpy.data.objects:
        if obj.type != 'MESH' or not obj.data:
            continue
        if any(obj.name.startswith(p) for p in arch_prefixes) or any(s in obj.name for s in arch_suffixes):
            arch_objs.append(obj)
        else:
            if not obj.hide_render:
                obj.hide_render = True
                hidden_objs.append(obj)

    subdiv_targets = ("Ground_", "Sidewalk_", "Road_", "GangGround", "GangAlley", "_Body", "PorchRoof", "KampungHouse", "KampungPorchRoof", "PerimeterWall")
    for obj in arch_objs:
        if any(t in obj.name for t in subdiv_targets):
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.select_all(action='DESELECT')
            obj.select_set(True)
            bpy.ops.object.mode_set(mode='EDIT')
            bpy.ops.mesh.select_all(action='SELECT')
            bpy.ops.mesh.subdivide(number_cuts=4)
            bpy.ops.object.mode_set(mode='OBJECT')

        # Ensure Col (BYTE_COLOR, CORNER) attribute exists and is active
        col_attr = obj.data.color_attributes.get("Col")
        if col_attr is None:
            col_attr = obj.data.color_attributes.new(name="Col", type='BYTE_COLOR', domain='CORNER')
        obj.data.color_attributes.active_color = col_attr

    if not arch_objs:
        return

    bpy.ops.object.select_all(action='DESELECT')
    for obj in arch_objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = arch_objs[0]
    bpy.ops.object.bake(type='AO')

    for obj in hidden_objs:
        obj.hide_render = False

    for obj in arch_objs:
        col_attr = obj.data.color_attributes.get("Col")
        if col_attr is None or len(col_attr.data) == 0:
            continue
        n = len(col_attr.data)
        arr = np.empty(n * 4, dtype=np.float32)
        col_attr.data.foreach_get("color", arr)
        arr = arr.reshape(-1, 4)
        arr[:, :3] = 0.50 + 0.50 * arr[:, :3]
        col_attr.data.foreach_set("color", arr.reshape(-1))


def build_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

    genteng_a_alb, genteng_a_nrm, genteng_a_rgh = generate_terracotta_textures(TEX_DIR, "genteng_terra_v5", (0.50, 0.22, 0.14))
    genteng_b_alb, genteng_b_nrm, genteng_b_rgh = generate_terracotta_textures(TEX_DIR, "genteng_slate_v5", (0.24, 0.29, 0.34))
    wall_cream, wall_nrm, wall_rgh = generate_plaster_ao_texture(TEX_DIR, "wall_cream_v20", (0.90, 0.84, 0.72), use_polyhaven=False)
    wall_warm, _, _ = generate_plaster_ao_texture(TEX_DIR, "wall_peach_v20", (0.88, 0.74, 0.60), use_polyhaven=False)
    wall_mint, _, _ = generate_plaster_ao_texture(TEX_DIR, "wall_mint_v20", (0.76, 0.84, 0.74), use_polyhaven=False)
    tile_alb, tile_nrm, tile_rgh = generate_sidewalk_concrete_texture(TEX_DIR, "sidewalk_concrete_v14")
    sign_img = generate_street_sign_texture(TEX_DIR, "street_sign_v14", (0.12, 0.44, 0.24))
    plaque_img = generate_street_sign_texture(TEX_DIR, "house_plaque_v14", (0.28, 0.20, 0.12))
    asphalt_alb, asphalt_nrm, asphalt_rgh = generate_asphalt_textures(TEX_DIR, use_polyhaven=False)
    teak_img, teak_nrm, teak_rgh = generate_wood_texture(TEX_DIR, "teak_wood_v20", (0.44, 0.24, 0.12), use_polyhaven=False)
    grass_img, grass_nrm, grass_rgh = generate_turf_texture(TEX_DIR, "kampung_turf_v22", (0.16, 0.28, 0.13))

    mat_roof_terra = make_pbr_material("RoofTerra", genteng_a_alb, 0.70, genteng_a_nrm, 0.85, (2.2, 2.2), genteng_a_rgh)
    mat_roof_sage = make_pbr_material("RoofSlate", genteng_b_alb, 0.70, genteng_b_nrm, 0.85, (2.2, 2.2), genteng_b_rgh)
    mat_wall_cream = make_pbr_material("WallCream", wall_cream, 0.84, None, 0.0, (1.0, 1.0))
    mat_wall_warm = make_pbr_material("WallWarm", wall_warm, 0.84, None, 0.0, (1.0, 1.0))
    mat_wall_mint = make_pbr_material("WallMint", wall_mint, 0.84, None, 0.0, (1.0, 1.0))
    mat_tile = make_pbr_material("SidewalkTile", tile_alb, 0.62, tile_nrm, 0.35, (5.5, 1.5))
    mat_sign = make_pbr_material("StreetSignTex", sign_img, 0.45)
    mat_plaque = make_pbr_material("HousePlaqueTex", plaque_img, 0.40)
    mat_asphalt = make_pbr_material("Asphalt", asphalt_alb, 0.46, None, 0.0, (4.0, 2.0))
    mat_wood = make_pbr_material("TeakWood", teak_img, 0.44, teak_nrm, 0.55, (1.5, 1.5), teak_rgh)
    mat_grass = make_pbr_material("KampungGrass", grass_img, 0.94, grass_nrm, 0.55, (7.0, 5.0), grass_rgh)

    mat_iron = make_solid_mat("WroughtIron", (0.09, 0.10, 0.13), 0.45, 0.65)
    mat_glass = make_solid_mat("WarmGlass", (0.07, 0.15, 0.23), 0.18, 0.0)
    batu_alb, batu_nrm, _ = generate_batu_alam_texture(TEX_DIR, "batu_alam_v11")
    mat_stone = make_pbr_material("NaturalStone", batu_alb, 0.88, batu_nrm, 0.95, (2.2, 2.8))
    plate_img = generate_license_plate(TEX_DIR, "plate_id_v11")
    mat_plate = make_pbr_material("LicensePlate", plate_img, 0.45, None, 0.0, (1.0, 1.0))
    mat_banana = make_solid_mat("BananaLeaf", (0.28, 0.60, 0.20), 0.72)
    mat_ac = make_solid_mat("OutdoorAC", (0.76, 0.76, 0.73), 0.62)
    mat_trim = make_solid_mat("TrimCream", (0.85, 0.82, 0.74), 0.78)
    mat_brass = make_solid_mat("BrassMetal", (0.76, 0.58, 0.24), 0.32, 0.85)
    mat_cushion = make_solid_mat("PorchFabric", (0.78, 0.36, 0.26), 0.86)
    mat_tank = make_solid_mat("TorenBlue", (0.18, 0.48, 0.74), 0.42)
    mat_lamp = make_solid_mat("PorchLamp", (1.0, 0.84, 0.46), 0.28, 0.0, 1.4)
    mat_tail = make_solid_mat("TailLamp", (0.90, 0.14, 0.12), 0.30, 0.0, 0.6)
    mat_scooter = make_solid_mat("ScooterRed", (0.78, 0.20, 0.18), 0.32, 0.25)
    mat_metal = make_solid_mat("AlloyMetal", (0.72, 0.74, 0.78), 0.42, 0.0)
    mat_tire = make_solid_mat("RubberTire", (0.06, 0.06, 0.07), 0.78)
    mat_bin_body = make_solid_mat("BinBody", (0.20, 0.22, 0.25), 0.55)
    mat_bin_green = make_solid_mat("BinGreen", (0.16, 0.48, 0.24), 0.42)
    mat_white = make_solid_mat("KanstinWhite", (0.88, 0.87, 0.84), 0.72)
    mat_black = make_solid_mat("KanstinBlack", (0.14, 0.15, 0.18), 0.72)
    mat_musholla_green = make_solid_mat("MushollaGreen", (0.14, 0.48, 0.28), 0.56)
    mat_musholla_gold = make_solid_mat("MushollaGold", (0.88, 0.70, 0.22), 0.26, 0.75)

    add_box("Ground_Lawn", (28.0, 18.0, 0.12), (0.0, 5.0, -0.14), mat_grass, 0.0)
    add_box("Sidewalk_Paving", (22.0, 2.65, 0.12), (0.0, -0.95, -0.04), mat_tile, 0.015)
    add_box("Road_Asphalt", (26.0, 6.8, 0.10), (0.0, -5.60, -0.06), mat_asphalt, 0.0)
    add_box("CurbGutter", (22.0, 0.24, 0.015), (0.0, -2.42, -0.008), mat_tile, 0.004)

    for dx in range(-10, 11, 2):
        add_box(f"RoadDash_{dx}", (0.85, 0.12, 0.012), (float(dx), -5.20, 0.002), mat_white, 0.002)

    # Indonesian crisp white Zebra Crossing across the street clearly visible from sidewalk
    for zi in range(6):
        zx = -0.75 + zi * 0.52
        add_box(f"ZebraStripe_{zi}", (0.30, 2.35, 0.014), (zx, -3.75, 0.004), mat_white, 0.004)

    # Roadside drainage grates (got beton) along the curb
    for gx in (-6.8, -3.4, 0.0, 3.4, 6.8):
        add_box(f"DrainGrateFrame_{gx}", (0.58, 0.24, 0.025), (gx, -2.42, -0.002), mat_black, 0.005)
        for gi in range(-2, 3):
            add_box(f"DrainGrateBar_{gx}_{gi}", (0.04, 0.20, 0.03), (gx + gi * 0.10, -2.42, 0.001), mat_iron, 0.002)

    # Indonesian concrete curb (kanstin): subtle alternating warm-ivory (#D0CBC0) / slate-grey (#7C7B76) blocks
    for i in range(18):
        kx = -8.5 + i * 1.0
        kmat = mat_white if i % 2 == 0 else mat_black
        add_box(f"KanstinBlock_{i}", (0.98, 0.20, 0.14), (kx, -2.24, 0.02), kmat, 0.012)

    # 3 Tipe 36/72 Indonesian Perumahan Houses + 2 flanking background houses at x=-7.6 and x=+7.6
    add_indonesian_house_36_72(-1, -7.60, mat_wall_mint, mat_roof_sage, mat_wood, mat_tile, mat_iron, mat_glass, mat_ac, mat_lamp, mat_trim, mat_brass, mat_cushion, mat_tank, mat_stone)
    add_indonesian_house_36_72(0, -3.75, mat_wall_cream, mat_roof_terra, mat_wood, mat_tile, mat_iron, mat_glass, mat_ac, mat_lamp, mat_trim, mat_brass, mat_cushion, mat_tank, mat_stone)
    add_indonesian_house_36_72(1, 0.0, mat_wall_warm, mat_roof_sage, mat_wood, mat_tile, mat_iron, mat_glass, mat_ac, mat_lamp, mat_trim, mat_brass, mat_cushion, mat_tank, mat_stone)
    add_indonesian_house_36_72(2, 3.75, mat_wall_mint, mat_roof_terra, mat_wood, mat_tile, mat_iron, mat_glass, mat_ac, mat_lamp, mat_trim, mat_brass, mat_cushion, mat_tank, mat_stone)

    # Right-edge neighborhood Musholla / Masjid landmark (cream walls + green trim + dome + gold finial)
    mx, my = 7.45, 2.40
    add_box("MushollaBody", (3.20, 3.40, 2.75), (mx, my, 1.375), mat_wall_cream, 0.025)
    add_box("MushollaTrimTop", (3.36, 3.56, 0.16), (mx, my, 2.78), mat_musholla_green, 0.02)
    add_box("MushollaGate", (2.80, 0.22, 1.45), (mx, 0.25, 0.725), mat_wall_cream, 0.02)
    add_box("MushollaGateTrim", (2.86, 0.26, 0.12), (mx, 0.25, 1.48), mat_musholla_green, 0.015)
    add_box("MushollaArchL", (0.28, 0.28, 2.15), (mx - 0.65, 0.25, 1.075), mat_musholla_green, 0.015)
    add_box("MushollaArchR", (0.28, 0.28, 2.15), (mx + 0.65, 0.25, 1.075), mat_musholla_green, 0.015)
    add_box("MushollaArchTop", (1.60, 0.30, 0.32), (mx, 0.25, 2.18), mat_musholla_green, 0.02)
    add_box("MushollaLantern", (0.20, 0.18, 0.24), (mx - 0.95, 0.05, 1.55), mat_lamp, 0.02)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=1.05, location=(mx, my, 3.15))
    dome = bpy.context.active_object
    dome.name = "MushollaDome"
    dome.scale = (1.0, 1.0, 0.92)
    bpy.ops.object.shade_smooth()
    dome.data.materials.append(mat_musholla_green)
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.04, depth=0.45, location=(mx, my, 4.25))
    fin = bpy.context.active_object
    fin.name = "MushollaFinial"
    bpy.ops.object.shade_smooth()
    fin.data.materials.append(mat_musholla_gold)

    # Extended perimeter garden walls so zero bare green grass void shows at left/right edges
    for side_label, wx in (("L", -9.6), ("R", 9.6)):
        add_box(f"PerimeterWall_{side_label}", (0.22, 6.4, 1.35), (wx, 2.2, 0.675), mat_wall_cream, 0.015)
        add_box(f"PerimeterWallCap_{side_label}", (0.28, 6.46, 0.08), (wx, 2.2, 1.38), mat_trim, 0.01)
    # Taller far-left perimeter fence wall extending to x = -11.5 behind Pos Ronda
    add_box("PerimeterWall_FarL", (4.0, 0.24, 1.95), (-9.5, 1.8, 0.975), mat_wall_cream, 0.015)
    add_box("PerimeterWallCap_FarL", (4.06, 0.30, 0.08), (-9.5, 1.8, 1.98), mat_trim, 0.01)
    for px in (-9.6, -5.65, 5.65, 9.6):
        add_box(f"PerimeterFrontWall_{px}", (0.26, 0.26, 1.05), (px, 0.26, 0.525), mat_stone, 0.015)
        add_box(f"PerimeterFrontCap_{px}", (0.32, 0.32, 0.08), (px, 0.26, 1.08), mat_trim, 0.012)

    # Smooth organic multi-lobe tropical trees (zero jagged faceted icosphere triangles!)
    for ti, (tx, ty, ts, leaf_rgb) in enumerate([
        (-8.8, 1.6, 1.05, (0.18, 0.48, 0.16)),
        (-10.5, 3.2, 1.15, (0.20, 0.52, 0.18)),
        (-5.85, 0.95, 0.86, (0.20, 0.50, 0.17)),
        (-1.88, -0.45, 0.58, (0.24, 0.56, 0.20)),
        (1.88, -0.45, 0.60, (0.18, 0.46, 0.16)),
        (5.85, 0.95, 0.86, (0.20, 0.50, 0.17)),
        (-3.6, 5.2, 1.05, (0.16, 0.42, 0.15)),
        (0.2, 5.4, 1.10, (0.24, 0.54, 0.19)),
        (3.8, 5.2, 1.02, (0.18, 0.48, 0.16)),
    ]):
        lmat = make_solid_mat(f"SmoothLeaf_{ti}", leaf_rgb, 0.72)
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.11 * ts, depth=1.55 * ts, location=(tx, ty, 0.78 * ts))
        trk = bpy.context.active_object
        trk.name = f"SmoothTreeTrunk_{ti}"
        bpy.ops.object.shade_smooth()
        trk.data.materials.append(mat_wood)
        for li, (ox, oy, oz, rad) in enumerate([
            (0.0, 0.0, 1.92, 0.68), (-0.32, 0.16, 1.65, 0.52),
            (0.34, -0.14, 1.68, 0.50), (0.05, 0.28, 1.72, 0.46),
        ]):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=rad * ts, location=(tx + ox * ts, ty + oy * ts, oz * ts))
            cn = bpy.context.active_object
            cn.name = f"SmoothTreeCanopy_{ti}_{li}"
            cn.scale = (1.05, 1.02, 0.84)
            bpy.ops.object.shade_smooth()
            cn.data.materials.append(lmat)

    # Natural stylized bushes between houses (zero flat neon slabs)
    for bx, by in [(-5.15, 0.45), (-1.85, 0.42), (1.85, 0.42), (5.20, 0.45)]:
        import_unpacked_asset("bush-common.glb", (bx, by, 0.0), 0.42, int(bx * 20), {
            "leaves": (0.16, 0.34, 0.14),
        })

    for bi, (bx, by, bs, yaw) in enumerate([
        (-2.22, -0.04, 0.38, 10), (-1.55, -0.04, 0.35, 90), (1.55, -0.04, 0.36, 45), (2.22, -0.04, 0.38, 160),
        (-5.15, 0.02, 0.44, 25), (5.15, 0.02, 0.44, 140),
        (-2.95, -0.06, 0.32, 70), (2.95, -0.06, 0.32, 125),
    ]):
        import_unpacked_asset("bush-common-flowers.glb", (bx, by, 0.0), bs, yaw, {
            "leaves": (0.16, 0.36, 0.15),
            "flowers": (0.88, 0.28, 0.44),
        })

    # Use normalized CC0 Kenney stylized vehicles (sedan.glb & van.glb) at 0.46x compact scale, parked cleanly at road edges!
    def add_cc0_vehicle(glb_name, cx, cy, yaw_deg):
        import_unpacked_asset(glb_name, (cx, cy, 0.0), 0.46, yaw_deg, {})
        for img in bpy.data.images:
            if "colormap" in img.name.lower() and img.size[0] > 0:
                arr = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
                lum = arr[:, :3].mean(axis=1)
                chroma = arr[:, :3].max(axis=1) - arr[:, :3].min(axis=1)
                glass_mask = (lum > 0.70) & (chroma < 0.16)
                arr[glass_mask, :3] = [0.09, 0.16, 0.26]
                img.pixels.foreach_set(arr.reshape(-1).tolist())
                img.pack()

    add_cc0_vehicle("sedan.glb", -5.1, -3.45, -90)
    add_cc0_vehicle("van.glb", 5.4, -3.45, 90)
    add_utility_pole_and_wires([-5.6, 2.20, 5.6], -2.02, mat_iron, mat_white, mat_lamp)
    add_trash_bin("TrashBin_0", -1.98, -1.92, mat_bin_body, mat_bin_green)
    add_sculpted_scooter("Scooter_0", 1.10, -2.05, math.radians(74), mat_scooter, mat_tire, mat_metal, mat_lamp, mat_tail)

    # Place Jl. Melati street sign inward at x=3.55, y=-2.02 so it is 100% framed
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.025, depth=1.95, location=(3.55, -2.02, 0.975))
    bpy.context.active_object.data.materials.append(mat_iron)
    add_box("StreetSignBoard", (0.58, 0.04, 0.22), (3.55, -2.02, 1.86), mat_bin_green, 0.01)
    add_box("StreetSignBorder", (0.52, 0.01, 0.16), (3.55, -2.041, 1.86), mat_white, 0.004)
    add_box("StreetSignInner", (0.48, 0.012, 0.12), (3.55, -2.043, 1.86), mat_bin_green, 0.003)
    add_box("StreetSignTextBar", (0.36, 0.014, 0.045), (3.55, -2.045, 1.86), mat_white, 0.002)

    # Planters along fences and cozy cat resting on House 1's front porch
    for px, py, yaw in [(-4.85, 0.22, 0), (-1.95, 0.22, 90), (1.95, 0.22, 0), (4.85, 0.22, 90)]:
        import_unpacked_asset("planter.glb", (px, py, 0.0), 0.45, yaw)
    import_unpacked_asset("animal-cat.glb", (0.42, 0.36, 0.12), 0.20, -25)
    add_box("StreetBenchSeat", (1.15, 0.38, 0.06), (-2.75, -0.55, 0.42), mat_wood, 0.015)
    add_box("StreetBenchLegL", (0.08, 0.34, 0.40), (-3.22, -0.55, 0.20), mat_iron, 0.008)
    add_box("StreetBenchLegR", (0.08, 0.34, 0.40), (-2.28, -0.55, 0.20), mat_iron, 0.008)

    # Warung-Life signature blue-roofed wooden Pos Ronda guard post on left edge
    add_box("PosRondaBase", (1.45, 1.25, 0.22), (-6.35, -0.55, 0.11), mat_wood, 0.02)
    for px in (-0.60, 0.60):
        for py in (-0.50, 0.50):
            bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.05, depth=1.80, location=(-6.35 + px, -0.55 + py, 1.02))
            bpy.context.active_object.data.materials.append(mat_wood)
    add_box("PosRondaRoof", (1.70, 1.50, 0.10), (-6.35, -0.55, 1.98), mat_tank, 0.02, (math.radians(-12), 0, 0))

    bake_scene_lightmap_uv2(
        os.path.join(GODOT_DIR, "assets", "lightmaps", "kampung_street_lightmap.png"),
        size=1024, samples=14,
        include_substrings=(
            "ground_", "sidewalk_", "road_", "gangground", "gangalley",
            "_body", "_terrace", "_porchroof",
            "kampunghouse", "kampungterrace", "kampungporchroof",
            "perimeterwall", "perimeterfrontwall", "posronda",
        ),
        lift_min=0.38, sun_energy=4.5, sun_rot_deg=(46.0, 0.0, 26.0), ambient_strength=0.34,
    )
    polish_scene_textures_1024()
    export_room_glb(OUT_GLB, quality=88)
    print("EXPORTED V4 PERUMAHAN 36/72 STREET:", OUT_GLB, "bytes=", os.path.getsize(OUT_GLB))


if __name__ == "__main__":
    build_scene()
