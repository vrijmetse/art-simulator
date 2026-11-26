import os
import math
import numpy as np
import bpy


def _ensure_dir(path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)


def save_rgba_png(name: str, rgba: np.ndarray, tex_dir: str, non_color: bool = False):
    """Save HxWx4 float32 [0..1] array as PNG and return Blender Image datablock."""
    h, w, _ = rgba.shape
    out_path = os.path.join(tex_dir, f"{name}.png")
    _ensure_dir(out_path)

    img = bpy.data.images.new(name, width=w, height=h, alpha=True, float_buffer=False)
    # Flip vertically for OpenGL/Blender bottom-left UV origin
    flipped = np.flipud(np.clip(rgba, 0.0, 1.0)).reshape(-1)
    img.pixels.foreach_set(flipped.tolist())
    img.filepath_raw = out_path
    img.file_format = 'PNG'
    img.save()
    img.colorspace_settings.name = 'Non-Color' if non_color else 'sRGB'
    img.pack()
    return img


def make_pbr_material(
    name: str,
    albedo_img,
    roughness_val: float = 0.78,
    normal_img=None,
    normal_strength: float = 0.45,
    uv_scale=(1.0, 1.0),
):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = roughness_val
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    tex_coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (uv_scale[0], uv_scale[1], 1.0)
    nt.links.new(tex_coord.outputs["UV"], mapping.inputs["Vector"])

    tex_alb = nt.nodes.new("ShaderNodeTexImage")
    tex_alb.image = albedo_img
    nt.links.new(mapping.outputs["Vector"], tex_alb.inputs["Vector"])
    nt.links.new(tex_alb.outputs["Color"], bsdf.inputs["Base Color"])

    if normal_img is not None:
        tex_norm = nt.nodes.new("ShaderNodeTexImage")
        tex_norm.image = normal_img
        nt.links.new(mapping.outputs["Vector"], tex_norm.inputs["Vector"])
        norm_map = nt.nodes.new("ShaderNodeNormalMap")
        norm_map.inputs["Strength"].default_value = normal_strength
        nt.links.new(tex_norm.outputs["Color"], norm_map.inputs["Color"])
        nt.links.new(norm_map.outputs["Normal"], bsdf.inputs["Normal"])

    return mat


def _height_to_normal(height: np.ndarray, strength: float = 2.0) -> np.ndarray:
    gx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    gy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    nx = -gx * strength
    ny = -gy * strength
    nz = np.ones_like(height)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
    rgb = np.stack([(nx / norm) * 0.5 + 0.5, (ny / norm) * 0.5 + 0.5, (nz / norm) * 0.5 + 0.5], axis=-1)
    alpha = np.ones((*height.shape, 1), dtype=np.float32)
    return np.concatenate([rgb, alpha], axis=-1).astype(np.float32)


def generate_terracotta_textures(tex_dir: str, name_prefix: str = "genteng", base_rgb=(0.74, 0.34, 0.21)):
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    u = xx / size
    v = yy / size

    rows = 8.0
    cols = 10.0
    vr = (v * rows) % 1.0
    row_id = np.floor(v * rows)
    ur = (u * cols + 0.5 * (row_id % 2)) % 1.0

    # Scalloped wave + step height
    wave = 0.5 + 0.5 * np.cos((ur - 0.5) * 2.0 * math.pi)
    step = np.clip((1.0 - vr) * 1.15, 0.0, 1.0)
    seam = np.where(vr > 0.88, 0.55, 1.0)
    height = (0.45 * wave + 0.55 * step) * seam

    rng = np.random.default_rng(42)
    tile_var = (np.sin(row_id * 3.7 + np.floor(u * cols) * 7.3) * 0.045)
    noise = rng.normal(0.0, 0.018, (size, size)).astype(np.float32)

    shade = np.clip(0.76 + 0.28 * height + tile_var + noise, 0.35, 1.15)
    rgb = np.stack([
        np.clip(base_rgb[0] * shade, 0.0, 1.0),
        np.clip(base_rgb[1] * shade, 0.0, 1.0),
        np.clip(base_rgb[2] * shade, 0.0, 1.0),
    ], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)

    alb = save_rgba_png(f"{name_prefix}_albedo", rgba, tex_dir, non_color=False)
    nrm = save_rgba_png(f"{name_prefix}_normal", _height_to_normal(height, 2.8), tex_dir, non_color=True)
    return alb, nrm


def generate_plaster_ao_texture(tex_dir: str, name: str, base_rgb=(0.97, 0.93, 0.85)):
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    v = yy / size  # 0 at top, 1 at bottom in image coords
    rng = np.random.default_rng(7)
    grain = rng.normal(0.0, 0.014, (size, size)).astype(np.float32)
    # Soft bottom moisture/AO gradient + top eave shadow
    bottom_ao = 1.0 - 0.24 * np.exp(-((1.0 - v) * 6.5) ** 2)
    top_ao = 1.0 - 0.14 * np.exp(-(v * 8.0) ** 2)
    shade = np.clip(bottom_ao * top_ao + grain, 0.5, 1.08)

    rgb = np.stack([
        np.clip(base_rgb[0] * shade, 0.0, 1.0),
        np.clip(base_rgb[1] * shade, 0.0, 1.0),
        np.clip(base_rgb[2] * shade, 0.0, 1.0),
    ], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, non_color=False)


def generate_tile_textures(tex_dir: str, name: str = "ceramic_tile", base_rgb=(0.93, 0.89, 0.82)):
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    tiles = 6.0
    u = (xx / size * tiles) % 1.0
    v = (yy / size * tiles) % 1.0
    grout = (u < 0.045) | (v < 0.045)
    rng = np.random.default_rng(19)
    speck = rng.normal(0.0, 0.015, (size, size)).astype(np.float32)
    shade = np.where(grout, 0.72, 0.98 + speck)
    height = np.where(grout, 0.15, 0.85 + speck * 0.5).astype(np.float32)

    rgb = np.stack([
        np.clip(base_rgb[0] * shade, 0.0, 1.0),
        np.clip(base_rgb[1] * shade, 0.0, 1.0),
        np.clip(base_rgb[2] * shade, 0.0, 1.0),
    ], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    alb = save_rgba_png(f"{name}_albedo", rgba, tex_dir, non_color=False)
    nrm = save_rgba_png(f"{name}_normal", _height_to_normal(height, 1.6), tex_dir, non_color=True)
    return alb, nrm


def generate_asphalt_textures(tex_dir: str):
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    v = yy / size
    rng = np.random.default_rng(99)
    grit = rng.normal(0.0, 0.045, (size, size)).astype(np.float32)
    # Subtle darker tire wear bands
    wear = 1.0 - 0.10 * (np.exp(-((v - 0.35) * 9.0) ** 2) + np.exp(-((v - 0.65) * 9.0) ** 2))
    base = np.clip(0.28 * wear + grit * 0.45, 0.12, 0.45)
    rgb = np.stack([base * 0.96, base * 0.98, base * 1.05], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    alb = save_rgba_png("asphalt_albedo", rgba, tex_dir, non_color=False)
    nrm = save_rgba_png("asphalt_normal", _height_to_normal(grit, 1.2), tex_dir, non_color=True)
    return alb, nrm


def generate_wood_texture(tex_dir: str, name: str = "teak_wood", base_rgb=(0.56, 0.36, 0.21)):
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    u = xx / size
    v = yy / size
    grain = 0.07 * np.sin(v * 70.0 + np.sin(u * 12.0) * 2.5)
    plank_seam = np.where(((v * 6.0) % 1.0) < 0.03, 0.65, 1.0)
    shade = np.clip((0.95 + grain) * plank_seam, 0.45, 1.15)
    rgb = np.stack([
        np.clip(base_rgb[0] * shade, 0.0, 1.0),
        np.clip(base_rgb[1] * shade, 0.0, 1.0),
        np.clip(base_rgb[2] * shade, 0.0, 1.0),
    ], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, non_color=False)


def generate_foliage_texture(tex_dir: str, name: str = "tropical_leaf", base_rgb=(0.24, 0.56, 0.22)):
    size = 256
    yy, xx = np.mgrid[0:size, 0:size]
    u = xx / size
    v = yy / size
    vein = 0.08 * np.sin((u - 0.5) * 45.0 + v * 12.0)
    sun = 0.85 + 0.28 * (1.0 - v) + vein
    rgb = np.stack([
        np.clip(base_rgb[0] * sun, 0.0, 1.0),
        np.clip(base_rgb[1] * sun, 0.0, 1.0),
        np.clip(base_rgb[2] * sun, 0.0, 1.0),
    ], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, non_color=False)
