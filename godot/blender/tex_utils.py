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
    flipped = np.flipud(np.clip(rgba, 0.0, 1.0)).reshape(-1)
    img.pixels.foreach_set(flipped.tolist())
    img.filepath_raw = out_path
    img.file_format = 'PNG'
    img.save()
    img.colorspace_settings.name = 'Non-Color' if non_color else 'sRGB'
    img.pack()
    return img


def load_polyhaven_pbr(tex_dir: str, short: str, tint_rgb=None, out_name: str = ""):
    """Load real 1K CC0 PolyHaven PBR (albedo, normal, roughness), optionally tinting albedo in numpy (GLTF-safe)."""
    ph_dir = os.path.join(tex_dir, "polyhaven")

    def _find(kind):
        for ext in ("jpg", "png"):
            p = os.path.join(ph_dir, f"{short}_{kind}.{ext}")
            if os.path.exists(p):
                return p
        return None

    alb_p = _find("alb")
    nrm_p = _find("nrm")
    rgh_p = _find("rgh")
    if not alb_p:
        return None, None, None

    alb_img = bpy.data.images.load(alb_p, check_existing=True)
    if tint_rgb is not None:
        w, h = alb_img.size[0], alb_img.size[1]
        arr = np.array(alb_img.pixels[:], dtype=np.float32).reshape(h, w, 4)
        lum = arr[:, :, :3].mean(axis=-1, keepdims=True)
        rel = np.clip(arr[:, :, :3] / np.maximum(lum.mean(), 0.25), 0.35, 1.35)
        tinted = np.clip(rel * np.array(tint_rgb, dtype=np.float32), 0.0, 1.0)
        out_rgba = np.concatenate([tinted, arr[:, :, 3:4]], axis=-1)
        alb_img = save_rgba_png(out_name if out_name else f"{short}_tinted", np.flipud(out_rgba), tex_dir, non_color=False)
    else:
        alb_img.colorspace_settings.name = 'sRGB'
        alb_img.pack()

    nrm_img = None
    if nrm_p:
        nrm_img = bpy.data.images.load(nrm_p, check_existing=True)
        nrm_img.colorspace_settings.name = 'Non-Color'
        nrm_img.pack()

    rgh_img = None
    if rgh_p:
        rgh_img = bpy.data.images.load(rgh_p, check_existing=True)
        rgh_img.colorspace_settings.name = 'Non-Color'
        rgh_img.pack()

    return alb_img, nrm_img, rgh_img


def make_pbr_material(
    name: str,
    albedo_img,
    roughness_val: float = 0.78,
    normal_img=None,
    normal_strength: float = 0.65,
    uv_scale=(1.0, 1.0),
    roughness_img=None,
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

    if roughness_img is not None:
        tex_rgh = nt.nodes.new("ShaderNodeTexImage")
        tex_rgh.image = roughness_img
        nt.links.new(mapping.outputs["Vector"], tex_rgh.inputs["Vector"])
        nt.links.new(tex_rgh.outputs["Color"], bsdf.inputs["Roughness"])

    if normal_img is not None:
        tex_norm = nt.nodes.new("ShaderNodeTexImage")
        tex_norm.image = normal_img
        nt.links.new(mapping.outputs["Vector"], tex_norm.inputs["Vector"])
        norm_map = nt.nodes.new("ShaderNodeNormalMap")
        norm_map.inputs["Strength"].default_value = normal_strength
        nt.links.new(tex_norm.outputs["Color"], norm_map.inputs["Color"])
        nt.links.new(norm_map.outputs["Normal"], bsdf.inputs["Normal"])

    return mat


def _height_to_normal(height: np.ndarray, strength: float = 3.5) -> np.ndarray:
    gx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    gy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    nx = -gx * strength
    ny = -gy * strength
    nz = np.ones_like(height)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
    rgb = np.stack([(nx / norm) * 0.5 + 0.5, (ny / norm) * 0.5 + 0.5, (nz / norm) * 0.5 + 0.5], axis=-1)
    alpha = np.ones((*height.shape, 1), dtype=np.float32)
    return np.concatenate([rgb, alpha], axis=-1).astype(np.float32)


def generate_terracotta_textures(tex_dir: str, name_prefix: str = "genteng", base_rgb=(0.70, 0.24, 0.13)):
    alb, nrm, rgh = load_polyhaven_pbr(tex_dir, "roof", base_rgb, f"{name_prefix}_ph_alb")
    if alb is not None:
        return alb, nrm, rgh
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    u, v = xx / size, yy / size
    rows, cols = 8.0, 10.0
    vr = (v * rows) % 1.0
    row_id = np.floor(v * rows)
    ur = (u * cols + 0.5 * (row_id % 2)) % 1.0
    wave = 0.5 + 0.5 * np.cos((ur - 0.5) * 2.0 * math.pi)
    step = np.clip((1.0 - vr) * 1.15, 0.0, 1.0)
    seam = np.where(vr > 0.88, 0.42, 1.0)
    height = (0.45 * wave + 0.55 * step) * seam
    shade = np.clip(0.68 + 0.36 * height, 0.30, 1.12)
    rgb = np.stack([np.clip(base_rgb[i] * shade, 0.0, 1.0) for i in range(3)], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return (
        save_rgba_png(f"{name_prefix}_albedo", rgba, tex_dir, False),
        save_rgba_png(f"{name_prefix}_normal", _height_to_normal(height, 4.8), tex_dir, True),
        None,
    )


def generate_plaster_ao_texture(tex_dir: str, name: str, base_rgb=(0.86, 0.78, 0.64), use_polyhaven: bool = False):
    if use_polyhaven:
        alb, nrm, rgh = load_polyhaven_pbr(tex_dir, "plaster", base_rgb, f"{name}_ph_alb")
        if alb is not None:
            return alb, nrm, rgh
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    v = yy / size
    u = xx / size
    # Subtle soft stylized plaster tone without gritty high-frequency noise
    soft_wave = 0.012 * np.sin(u * math.pi * 4.0) * np.cos(v * math.pi * 4.0)
    bottom_ao = 1.0 - 0.16 * np.exp(-((1.0 - v) * 5.0) ** 2)
    top_ao = 1.0 - 0.10 * np.exp(-(v * 6.5) ** 2)
    shade = np.clip(bottom_ao * top_ao + soft_wave, 0.68, 1.04)
    rgb = np.stack([np.clip(base_rgb[i] * shade, 0.0, 1.0) for i in range(3)], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, False), None, None


def generate_tile_textures(tex_dir: str, name: str = "ceramic_tile", base_rgb=(0.84, 0.76, 0.64), polyhaven_key: str = "ceramic", use_polyhaven: bool = False):
    if use_polyhaven:
        alb, nrm, rgh = load_polyhaven_pbr(tex_dir, polyhaven_key, base_rgb, f"{name}_ph_alb")
        if alb is not None:
            return alb, nrm, rgh
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    tiles = 4.0
    tx = np.floor(xx / size * tiles)
    ty = np.floor(yy / size * tiles)
    u = (xx / size * tiles) % 1.0
    v = (yy / size * tiles) % 1.0
    grout = (u < 0.032) | (v < 0.032)
    tile_var = 0.96 + 0.05 * (((tx * 3 + ty * 5) % 4) / 3.0)
    sheen = 1.0 + 0.025 * (1.0 - 0.5 * (u + v))
    shade = np.where(grout, 0.72, tile_var * sheen)
    height = np.where(grout, 0.20, 0.92).astype(np.float32)
    rgb = np.stack([np.clip(base_rgb[i] * shade, 0.0, 1.0) for i in range(3)], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return (
        save_rgba_png(f"{name}_albedo", rgba, tex_dir, False),
        save_rgba_png(f"{name}_normal", _height_to_normal(height, 1.4), tex_dir, True),
        None,
    )


def generate_asphalt_textures(tex_dir: str, use_polyhaven: bool = False):
    if use_polyhaven:
        alb, nrm, rgh = load_polyhaven_pbr(tex_dir, "asphalt", (0.28, 0.30, 0.34), "asphalt_ph_alb")
        if alb is not None:
            return alb, nrm, rgh
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    u, v = xx / size, yy / size
    rng = np.random.default_rng(99)
    coarse = rng.normal(0.0, 0.014, (64, 64)).astype(np.float32)
    coarse_up = np.repeat(np.repeat(coarse, 8, axis=0), 8, axis=1)
    fine = rng.normal(0.0, 0.008, (size, size)).astype(np.float32)
    base = np.clip(0.19 + coarse_up + fine + 0.015 * np.sin(v * math.pi * 2.0), 0.14, 0.25)
    rgb = np.stack([base * 0.92, base * 0.96, base * 1.08], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png("asphalt_albedo", rgba, tex_dir, False), None, None


def generate_wood_texture(tex_dir: str, name: str = "teak_wood", base_rgb=(0.45, 0.27, 0.15), use_polyhaven: bool = False):
    if use_polyhaven:
        alb, nrm, rgh = load_polyhaven_pbr(tex_dir, "wood", base_rgb, f"{name}_ph_alb")
        if alb is not None:
            return alb, nrm, rgh
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    u, v = xx / size, yy / size
    grain = 0.032 * np.sin(v * 95.0 + np.sin(u * 4.0) * 0.8) + 0.015 * np.sin(v * 32.0)
    plank_seam = np.where(((v * 4.0) % 1.0) < 0.018, 0.78, 1.0)
    shade = np.clip((0.97 + grain) * plank_seam, 0.65, 1.08)
    rgb = np.stack([np.clip(base_rgb[i] * shade, 0.0, 1.0) for i in range(3)], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, False), None, None


def generate_turf_texture(tex_dir: str, name: str = "turf_grass", base_rgb=(0.24, 0.46, 0.20)):
    alb, nrm, rgh = load_polyhaven_pbr(tex_dir, "grass", base_rgb, f"{name}_ph_alb")
    if alb is not None:
        return alb, nrm, rgh
    size = 512
    rng = np.random.default_rng(31)
    coarse = rng.normal(0.0, 0.05, (64, 64)).astype(np.float32)
    coarse_up = np.repeat(np.repeat(coarse, 8, axis=0), 8, axis=1)
    fine = rng.normal(0.0, 0.035, (size, size)).astype(np.float32)
    shade = np.clip(0.92 + coarse_up + fine, 0.60, 1.15)
    rgb = np.stack([np.clip(base_rgb[i] * shade, 0.0, 1.0) for i in range(3)], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, False), None, None


def generate_foliage_texture(tex_dir: str, name: str = "tropical_leaf", base_rgb=(0.18, 0.48, 0.16)):
    size = 256
    rng = np.random.default_rng(55)
    mottle = rng.normal(0.0, 0.04, (32, 32)).astype(np.float32)
    mottle_up = np.repeat(np.repeat(mottle, 8, axis=0), 8, axis=1)
    yy, xx = np.mgrid[0:size, 0:size]
    sun = 0.88 + 0.22 * (1.0 - yy / size) + mottle_up
    rgb = np.stack([np.clip(base_rgb[i] * sun, 0.0, 1.0) for i in range(3)], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, False)


def generate_wall_art_padi(tex_dir: str, name: str = "wall_art_padi"):
    """Hand-painted style Indonesian rice terrace & volcano sunset wall painting."""
    w, h = 256, 192
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / w, yy / h

    sky_r = 0.94 - 0.15 * (1.0 - v)
    sky_g = 0.64 + 0.22 * v
    sky_b = 0.36 + 0.26 * (1.0 - v)
    rgb = np.stack([sky_r, sky_g, sky_b], axis=-1)

    sun = ((u - 0.68) ** 2 + (v - 0.28) ** 2) < 0.008
    rgb[sun] = [0.98, 0.90, 0.58]

    mountain_y = 0.48 - 0.24 * np.exp(-((u - 0.38) * 4.5) ** 2) - 0.12 * np.exp(-((u - 0.72) * 5.0) ** 2)
    m_mask = v > mountain_y
    rgb[m_mask] = [0.24, 0.36, 0.42]

    for idx, (y_base, col) in enumerate([
        (0.55, [0.28, 0.54, 0.26]),
        (0.67, [0.36, 0.62, 0.28]),
        (0.79, [0.24, 0.48, 0.22]),
        (0.90, [0.18, 0.38, 0.18]),
    ]):
        wave = y_base + 0.03 * np.sin(u * 7.0 + idx * 1.4)
        mask = v > wave
        rgb[mask] = col

    rgba = np.concatenate([np.clip(rgb, 0.0, 1.0), np.ones((h, w, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, False)


def generate_laptop_ui(tex_dir: str, name: str = "laptop_ui"):
    """Crisp dark-teal desktop UI screen texture so laptop screen never clips to flat white."""
    w, h = 192, 128
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / w, yy / h
    rgb = np.zeros((h, w, 3), dtype=np.float32)
    rgb[:, :] = [0.09, 0.16, 0.24]
    # Taskbar at bottom
    rgb[v > 0.88] = [0.05, 0.09, 0.14]
    # Open cozy app window + sidebar
    win = (u > 0.14) & (u < 0.84) & (v > 0.14) & (v < 0.80)
    rgb[win] = [0.92, 0.94, 0.96]
    bar = (u > 0.14) & (u < 0.84) & (v > 0.14) & (v < 0.22)
    rgb[bar] = [0.16, 0.52, 0.48]
    card = (u > 0.20) & (u < 0.48) & (v > 0.30) & (v < 0.70)
    rgb[card] = [0.85, 0.48, 0.32]
    rgba = np.concatenate([rgb, np.ones((h, w, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, False)


def generate_batik_texture(tex_dir: str, name: str, base_rgb, accent_rgb):
    """Refined Indonesian batik parang-floral motif (organic smooth curves, no harsh X-grid)."""
    size = 256
    yy, xx = np.mgrid[0:size, 0:size]
    u, v = xx / size, yy / size
    wave1 = np.sin((u * 6.0 + v * 6.0) * math.pi + np.sin(u * 12.0 * math.pi) * 0.6)
    petal = np.sin(u * 12.0 * math.pi) * np.sin(v * 12.0 * math.pi)
    motif = np.clip(0.5 + 0.5 * wave1, 0.0, 1.0) * 0.55 + np.clip(petal, 0.0, 1.0) * 0.45
    motif = np.clip((motif - 0.45) * 2.5, 0.0, 1.0)[..., None]
    base = np.array(base_rgb, dtype=np.float32)[None, None, :]
    acc = np.array(accent_rgb, dtype=np.float32)[None, None, :]
    rgb = np.clip(base * (1.0 - 0.24 * motif) + acc * (0.24 * motif), 0.0, 1.0)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, False)


def generate_woven_rug_texture(tex_dir: str, name: str = "woven_rug"):
    """Rich Nusantara woven kilim rug texture (zero blown-out white center)."""
    size = 256
    yy, xx = np.mgrid[0:size, 0:size]
    u, v = xx / size, yy / size
    weave = 0.04 * np.sin(u * 140.0) * np.sin(v * 140.0)
    rgb = np.zeros((size, size, 3), dtype=np.float32)
    rgb[:, :] = [0.68, 0.28, 0.20]  # warm terracotta base
    # Concentric geometric border + mustard & indigo stripes
    border = (u < 0.10) | (u > 0.90) | (v < 0.12) | (v > 0.88)
    inner_line = ((u > 0.13) & (u < 0.16)) | ((u > 0.84) & (u < 0.87)) | ((v > 0.16) & (v < 0.20)) | ((v > 0.80) & (v < 0.84))
    diamond = (np.abs((u - 0.5) * 2.2) + np.abs((v - 0.5) * 2.2)) < 0.42
    rgb[border] = [0.20, 0.30, 0.36]
    rgb[inner_line] = [0.80, 0.62, 0.28]
    rgb[diamond] = [0.76, 0.58, 0.30]
    rgb = np.clip(rgb + weave[..., None], 0.0, 1.0)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, False)


def generate_fabric_weave_texture(tex_dir: str, name: str, base_rgb):
    """Tactile subtle linen/cotton cross-hatch weave texture for bedsheet, blanket & curtains."""
    size = 256
    yy, xx = np.mgrid[0:size, 0:size]
    u, v = xx / size, yy / size
    warp = 0.045 * np.sin(u * 160.0) + 0.045 * np.sin(v * 160.0)
    plaid = 0.04 * (np.sin(u * 16.0 * math.pi) > 0.85) + 0.04 * (np.sin(v * 16.0 * math.pi) > 0.85)
    shade = np.clip(0.95 + warp - plaid, 0.65, 1.08)
    rgb = np.stack([np.clip(base_rgb[i] * shade, 0.0, 1.0) for i in range(3)], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, False)


def generate_stylized_face_texture(tex_dir: str, name: str, skin_rgb):
    """256x256 smooth anti-aliased Sims-like stylized face texture for planar -Y head UV projection."""
    size = 256
    yy, xx = np.mgrid[0:size, 0:size]
    u = xx / size
    v = yy / size
    # Convert linear skin_rgb (Blender Principled BSDF base_color) -> sRGB PNG values so FaceSkin matches Neck/Arms seamlessly!
    skin_srgb = [float(max(0.0, min(1.0, c)) ** (1.0 / 2.2)) for c in skin_rgb]
    rgb = np.zeros((size, size, 3), dtype=np.float32)
    rgb[:, :] = skin_srgb

    def _blend(mask_arr, col_rgb, alpha=1.0):
        nonlocal rgb
        m = np.clip(mask_arr, 0.0, 1.0)[..., None] * alpha
        rgb = rgb * (1.0 - m) + np.array(col_rgb, dtype=np.float32) * m

    # Soft rosy cheeks
    for cx in (0.31, 0.69):
        d2 = ((u - cx) / 0.088) ** 2 + ((v - 0.60) / 0.056) ** 2
        _blend(np.exp(-d2 * 1.8), [0.92, 0.58, 0.54], 0.24)

    # Soft anti-aliased eyes (whites + warm dark irises + bright white catchlights) + arched brows
    for cx in (0.36, 0.64):
        eye_r = np.sqrt(((u - cx) / 0.064) ** 2 + ((v - 0.47) / 0.048) ** 2)
        _blend((1.0 - eye_r) * 6.0, [0.96, 0.96, 0.94])
        iris_r = np.sqrt(((u - cx) / 0.040) ** 2 + ((v - 0.474) / 0.042) ** 2)
        _blend((1.0 - iris_r) * 7.0, [0.22, 0.16, 0.14])
        pupil_r = np.sqrt(((u - cx) / 0.020) ** 2 + ((v - 0.476) / 0.022) ** 2)
        _blend((1.0 - pupil_r) * 8.0, [0.06, 0.05, 0.05])
        spark_r = np.sqrt(((u - (cx + 0.015)) / 0.014) ** 2 + ((v - 0.456) / 0.014) ** 2)
        _blend((1.0 - spark_r) * 6.0, [0.99, 0.99, 0.99])
        lash_d = np.abs(v - (0.426 + 0.018 * ((u - cx) / 0.068) ** 2))
        lash_m = np.clip(1.0 - lash_d / 0.012, 0.0, 1.0) * np.clip(1.0 - np.abs(u - cx) / 0.072, 0.0, 1.0)
        _blend(lash_m, [0.16, 0.12, 0.11])
        brow_v = 0.352 + 0.016 * ((u - cx) / 0.078) ** 2
        brow_m = np.clip(1.0 - np.abs(v - brow_v) / 0.015, 0.0, 1.0) * np.clip(1.0 - np.abs(u - cx) / 0.074, 0.0, 1.0)
        _blend(brow_m, [0.20, 0.16, 0.14])

    # Subtle nose bridge & tip shadow + warm curved smile
    nose = ((u - 0.50) / 0.024) ** 2 + ((v - 0.57) / 0.022) ** 2
    _blend(np.exp(-nose * 1.9), [skin_srgb[0] * 0.84, skin_srgb[1] * 0.80, skin_srgb[2] * 0.78], 0.24)
    smile_v = 0.708 - 0.026 * ((u - 0.50) / 0.088) ** 2
    smile_m = np.clip(1.0 - np.abs(v - smile_v) / 0.015, 0.0, 1.0) * np.clip(1.0 - np.abs(u - 0.50) / 0.090, 0.0, 1.0)
    _blend(smile_m, [0.46, 0.14, 0.16], 0.92)

    rgba = np.concatenate([np.clip(rgb, 0.0, 1.0), np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, False)


def generate_sajadah_texture(tex_dir: str, name: str = "sajadah_emerald"):
    """Crisp emerald-and-gold Nusantara prayer mat texture with mihrab arch & tassels."""
    w, h = 192, 320
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / w, yy / h
    rgb = np.zeros((h, w, 3), dtype=np.float32)
    rgb[:, :] = [0.09, 0.36, 0.24]
    border = (u < 0.11) | (u > 0.89) | (v < 0.08) | (v > 0.92)
    gold_trim = ((u > 0.12) & (u < 0.16)) | ((u > 0.84) & (u < 0.88)) | ((v > 0.09) & (v < 0.12)) | ((v > 0.88) & (v < 0.91))
    arch_y = 0.24 + 0.12 * (np.abs(u - 0.5) / 0.28) ** 1.5
    arch = (np.abs(u - 0.5) < 0.28) & (v > arch_y) & (v < 0.78)
    arch_rim = (np.abs(u - 0.5) < 0.31) & (v > arch_y - 0.025) & (v < 0.80) & (~arch)
    rgb[border] = [0.06, 0.24, 0.16]
    rgb[gold_trim | arch_rim] = [0.88, 0.72, 0.30]
    rgb[arch] = [0.12, 0.46, 0.30]
    weave = 0.03 * np.sin(u * 120.0) * np.sin(v * 160.0)
    rgb = np.clip(rgb + weave[..., None], 0.0, 1.0)
    rgba = np.concatenate([rgb, np.ones((h, w, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, False)


def generate_tv_weather_texture(tex_dir: str, name: str = "tv_weather"):
    """Glowing TV screen texture (cozy Indonesian weather broadcast)."""
    w, h = 192, 128
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / w, yy / h
    rgb = np.zeros((h, w, 3), dtype=np.float32)
    rgb[:, :] = [0.22, 0.60, 0.88]
    rgb[v > 0.78] = [0.10, 0.18, 0.32]
    sun = ((u - 0.26) ** 2 + (v - 0.32) ** 2) < 0.015
    rgb[sun] = [0.98, 0.84, 0.30]
    cloud = (((u - 0.42) / 0.16) ** 2 + ((v - 0.42) / 0.10) ** 2) < 1.0
    rgb[cloud] = [0.96, 0.97, 0.99]
    bar = (u > 0.62) & (u < 0.88) & (v > 0.24) & (v < 0.66)
    rgb[bar] = [0.94, 0.95, 0.97]
    rgba = np.concatenate([rgb, np.ones((h, w, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, False)


def generate_batu_alam_texture(tex_dir: str, name: str = "batu_alam"):
    """Indonesian stacked natural split-stone (batu alam) albedo + deep mortar normal map."""
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    u, v = xx / size, yy / size
    rows = 12.0
    vr = (v * rows) % 1.0
    row_id = np.floor(v * rows).astype(np.int32)
    cols = 4.0 + (row_id % 2)
    ur = (u * cols + 0.37 * row_id) % 1.0
    col_id = np.floor(u * cols + 0.37 * row_id).astype(np.int32)
    stone_id = row_id * 17 + col_id * 31
    rng = np.random.default_rng(42)
    speck = rng.normal(0.0, 0.045, (size, size)).astype(np.float32)
    tone = 0.24 + 0.14 * ((stone_id % 7) / 6.0) + speck
    mortar = (vr < 0.09) | (ur < 0.05)
    height = np.where(mortar, 0.15, 0.78 + 0.16 * ((stone_id % 5) / 4.0) + speck).astype(np.float32)
    shade = np.where(mortar, 0.18, tone)
    rgb = np.stack([shade * 0.98, shade * 0.96, shade * 0.92], axis=-1)
    rgba = np.concatenate([np.clip(rgb, 0.0, 1.0), np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return (
        save_rgba_png(f"{name}_alb", rgba, tex_dir, False),
        save_rgba_png(f"{name}_nrm", _height_to_normal(height, 5.2), tex_dir, True),
        None,
    )


def generate_license_plate(tex_dir: str, name: str = "plate_id"):
    """Indonesian black/white license plate texture (no blank white rectangle!)."""
    w, h = 256, 96
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / w, yy / h
    rgb = np.zeros((h, w, 3), dtype=np.float32)
    rgb[:, :] = [0.08, 0.09, 0.11]  # classic Indonesian black plate
    border = (u < 0.04) | (u > 0.96) | (v < 0.07) | (v > 0.93)
    rgb[border] = [0.85, 0.85, 0.85]
    # Stylized bold white plate characters blocks
    for cx in (0.18, 0.30, 0.39, 0.48, 0.57, 0.70, 0.79, 0.88):
        ch = (np.abs(u - cx) < 0.032) & (v > 0.25) & (v < 0.68)
        rgb[ch] = [0.90, 0.90, 0.90]
    rgba = np.concatenate([rgb, np.ones((h, w, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, False)


def generate_sidewalk_concrete_texture(tex_dir: str, name: str = "sidewalk_concrete"):
    """Clean light-grey/warm-beige Indonesian concrete sidewalk with subtle expansion joints (no checkerboard!)."""
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    u, v = xx / size, yy / size
    rng = np.random.default_rng(77)
    grain = rng.normal(0.0, 0.018, (size, size)).astype(np.float32)
    seam = ((u * 4.0) % 1.0 < 0.025) | ((v * 2.0) % 1.0 < 0.025)
    shade = np.where(seam, 0.78, 0.96 + grain)
    height = np.where(seam, 0.25, 0.85 + grain).astype(np.float32)
    base = np.array([0.78, 0.76, 0.72], dtype=np.float32)
    rgb = np.stack([np.clip(base[i] * shade, 0.0, 1.0) for i in range(3)], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return (
        save_rgba_png(f"{name}_alb", rgba, tex_dir, False),
        save_rgba_png(f"{name}_nrm", _height_to_normal(height, 2.0), tex_dir, True),
        None,
    )


def generate_street_sign_texture(tex_dir: str, name: str = "street_sign", bg_rgb=(0.12, 0.44, 0.24)):
    """Indonesian green street nameplate texture (Jl. Melati) so signboards never appear blank."""
    w, h = 256, 96
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / w, yy / h
    rgb = np.zeros((h, w, 3), dtype=np.float32)
    rgb[:, :] = bg_rgb
    border = (u < 0.04) | (u > 0.96) | (v < 0.08) | (v > 0.92)
    rgb[border] = [0.92, 0.92, 0.90]
    for cx in (0.16, 0.23, 0.30, 0.42, 0.50, 0.58, 0.66, 0.74, 0.83):
        ch = (np.abs(u - cx) < 0.026) & (v > 0.28) & (v < 0.62)
        rgb[ch] = [0.94, 0.94, 0.92]
    sub = (u > 0.28) & (u < 0.72) & (v > 0.70) & (v < 0.80)
    rgb[sub] = [0.88, 0.82, 0.45]
    rgba = np.concatenate([rgb, np.ones((h, w, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return save_rgba_png(name, rgba, tex_dir, False)


def bake_scene_lightmap_uv2(
    out_png_path: str,
    size: int = 1024,
    samples: int = 16,
    exclude_substrings=("tree", "bush", "flower", "planter", "sedan", "van", "car", "pug", "cat", "casual", "glass", "window", "wheel", "trunk", "leaf", "leaves"),
    include_substrings=None,
    lift_min: float = 0.34,
    sun_energy: float = 4.2,
    sun_rot_deg=(48.0, 0.0, 28.0),
    ambient_strength: float = 0.32,
):
    """Bake shared Cycles GI lightmap into UV2 (LightmapUV -> glTF TEXCOORD_1) without bloating .glb."""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = samples
    scene.cycles.use_denoising = False
    scene.cycles.max_bounces = 4
    scene.cycles.diffuse_bounces = 3
    scene.cycles.bake_type = 'DIFFUSE'
    scene.render.bake.use_pass_direct = True
    scene.render.bake.use_pass_indirect = True
    scene.render.bake.use_pass_color = False
    scene.render.bake.target = 'IMAGE_TEXTURES'
    scene.render.bake.use_clear = True
    scene.render.bake.margin = 4

    world = scene.world or bpy.data.worlds.new("BakeWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.76, 0.84, 0.96, 1.0)
        bg.inputs["Strength"].default_value = ambient_strength

    temp_sun = None
    if not any(o.type == 'LIGHT' and o.data and o.data.type == 'SUN' for o in bpy.data.objects):
        bpy.ops.object.light_add(type='SUN', location=(4.0, -4.0, 8.0))
        temp_sun = bpy.context.active_object
        temp_sun.data.energy = sun_energy
        temp_sun.data.color = (1.0, 0.94, 0.84)
        temp_sun.data.angle = math.radians(10.0)
        temp_sun.rotation_euler = tuple(math.radians(a) for a in sun_rot_deg)

    hidden_glass = []
    for o in bpy.data.objects:
        if o.type == 'MESH' and any(g in o.name.lower() for g in ("glass", "window")) and not o.hide_render:
            o.hide_render = True
            hidden_glass.append(o)

    target_objs = [
        o for o in bpy.data.objects
        if o.type == 'MESH' and o.data and len(o.data.polygons) > 0
        and not any(ex in o.name.lower() for ex in exclude_substrings)
        and (include_substrings is None or any(inc in o.name.lower() for inc in include_substrings))
    ]

    for o in target_objs:
        if o.data.users > 1:
            o.data = o.data.copy()
        if not o.data.uv_layers:
            o.data.uv_layers.new(name="UVMap")
        lm_uv = o.data.uv_layers.get("LightmapUV") or o.data.uv_layers.new(name="LightmapUV")
        o.data.uv_layers.active = lm_uv

    bpy.ops.object.select_all(action='DESELECT')
    for o in target_objs:
        o.select_set(True)
    if target_objs:
        bpy.context.view_layer.objects.active = target_objs[0]
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.025)
        bpy.ops.object.mode_set(mode='OBJECT')

    bake_img = bpy.data.images.new("_SceneLightmapBake", width=size, height=size, alpha=False, float_buffer=True)
    bake_mat = bpy.data.materials.new("_SceneBakeMat")
    bake_mat.use_nodes = True
    nt = bake_mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.88, 0.88, 0.88, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.90
    tex_node = nt.nodes.new("ShaderNodeTexImage")
    tex_node.image = bake_img
    nt.nodes.active = tex_node

    orig_mats = {}
    for o in target_objs:
        orig_mats[o.name] = list(o.data.materials)
        o.data.materials.clear()
        o.data.materials.append(bake_mat)

    bpy.ops.object.bake(type='DIFFUSE')

    arr = np.array(bake_img.pixels[:], dtype=np.float32).reshape(size, size, 4)
    p97 = max(0.28, float(np.percentile(arr[:, :, :3], 97)))
    norm = np.clip(arr[:, :, :3] / p97, 0.0, 1.0)
    lifted = np.clip(lift_min + norm * (1.0 - lift_min), lift_min, 1.0)
    arr[:, :, :3] = lifted
    arr[:, :, 3] = 1.0
    bake_img.pixels.foreach_set(arr.reshape(-1).tolist())

    os.makedirs(os.path.dirname(out_png_path), exist_ok=True)
    bake_img.filepath_raw = out_png_path
    bake_img.file_format = 'PNG'
    bake_img.save()

    for o in target_objs:
        o.data.materials.clear()
        for m in orig_mats.get(o.name, []):
            o.data.materials.append(m)
        o.data.uv_layers.active_index = 0
    for o in hidden_glass:
        o.hide_render = False
    if temp_sun is not None:
        bpy.data.objects.remove(temp_sun, do_unlink=True)
    bpy.data.materials.remove(bake_mat)
    bpy.data.images.remove(bake_img)
    print("BAKED SCENE LIGHTMAP UV2:", out_png_path, "targets=", len(target_objs))


def ensure_uv0(obj, mode: str = 'CUBE'):
    if obj.type != 'MESH':
        return
    if not obj.data.uv_layers:
        obj.data.uv_layers.new(name="UVMap")
    obj.data.uv_layers.active = obj.data.uv_layers[0]
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    if mode == 'RESET':
        bpy.ops.uv.reset()
    elif mode == 'SMART':
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
    else:
        cube_sz = max(0.2, max(obj.dimensions) * 0.6)
        bpy.ops.uv.cube_project(cube_size=cube_sz)
    bpy.ops.object.mode_set(mode='OBJECT')


def spin_profile(name: str, profile_rz, loc, mat, steps: int = 24, smooth: bool = True, uv_mode: str = 'CUBE', rot=(0.0, 0.0, 0.0)):
    import bmesh
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    verts = [bm.verts.new((r, 0.0, z)) for r, z in profile_rz]
    for i in range(len(verts) - 1):
        bm.edges.new((verts[i], verts[i + 1]))
    bmesh.ops.spin(
        bm,
        geom=bm.verts[:] + bm.edges[:],
        cent=(0.0, 0.0, 0.0),
        axis=(0.0, 0.0, 1.0),
        angle=math.radians(360.0),
        steps=steps,
        use_merge=True,
    )
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if smooth:
        for f in bm.faces:
            f.smooth = True
    bm.to_mesh(mesh)
    bm.free()
    obj.location = loc
    obj.rotation_euler = rot
    bpy.context.view_layer.objects.active = obj
    if smooth:
        bpy.ops.object.shade_smooth()
    obj.data.materials.append(mat)
    ensure_uv0(obj, mode=uv_mode)
    return obj


def generate_rattan_textures(tex_dir: str, prefix: str = "rattan_woven_hd", size: int = 1024):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    cells = 16.0
    u = (xx / size) * cells
    v = (yy / size) * cells
    iu = np.floor(u).astype(np.int32)
    iv = np.floor(v).astype(np.int32)
    fu = u - iu
    fv = v - iv

    horiz_on_top = ((iu + iv) % 2) == 0
    h_arch = np.sin(np.clip(fv, 0.0, 1.0) * math.pi)
    v_arch = np.sin(np.clip(fu, 0.0, 1.0) * math.pi)
    height = np.where(horiz_on_top, h_arch * 0.85 + 0.15, v_arch * 0.85 + 0.15)
    fiber = 0.06 * np.sin((np.where(horiz_on_top, fv, fu)) * 28.0)
    height = np.clip(height + fiber, 0.0, 1.0)

    r = 0.56 + 0.26 * height
    g = 0.42 + 0.22 * height
    b = 0.24 + 0.14 * height
    alb_rgba = np.stack([r, g, b, np.ones_like(r)], axis=-1).astype(np.float32)
    alb_img = save_rgba_png(f"{prefix}_alb", alb_rgba, tex_dir, non_color=False)
    nrm_img = save_rgba_png(f"{prefix}_nrm", _height_to_normal(height, 2.6), tex_dir, non_color=True)
    return alb_img, nrm_img


def add_sculpted_plant_blade(name: str, base_loc, angle_z: float, length: float, width: float, arch_out: float, leaf_mat):
    import bmesh
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    segs = 8
    rows = []
    for i in range(segs + 1):
        t = i / float(segs)
        y_loc = arch_out * (t ** 1.35)
        z_loc = length * (t - 0.32 * t * t)
        w = width * math.sin(math.pi * (t ** 0.72)) if i < segs else 0.0
        if i == segs:
            rows.append([bm.verts.new((0.0, y_loc, z_loc))])
        else:
            rows.append([
                bm.verts.new((-w * 0.5, y_loc, z_loc + w * 0.16)),
                bm.verts.new((0.0, y_loc, z_loc)),
                bm.verts.new((w * 0.5, y_loc, z_loc + w * 0.16)),
            ])
    for i in range(segs - 1):
        r0, r1 = rows[i], rows[i + 1]
        bm.faces.new((r0[0], r0[1], r1[1], r1[0]))
        bm.faces.new((r0[1], r0[2], r1[2], r1[1]))
    r_last = rows[segs - 1]
    tip = rows[segs][0]
    bm.faces.new((r_last[0], r_last[1], tip))
    bm.faces.new((r_last[1], r_last[2], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    obj.location = base_loc
    obj.rotation_euler = (0.0, 0.0, angle_z)
    bpy.context.view_layer.objects.active = obj
    sub = obj.modifiers.new("Subsurf", 'SUBSURF')
    sub.levels = 1
    sub.render_levels = 1
    bpy.ops.object.modifier_apply(modifier="Subsurf")
    bpy.ops.object.shade_smooth()
    obj.data.materials.append(leaf_mat)
    ensure_uv0(obj, mode='SMART')
    return obj


def add_layered_broadleaf_plant(x: float, y: float, pot_mat, soil_mat, leaf_mat, prefix: str = "Plant", scale: float = 1.0):
    def _cyl(nm, r, d, loc, verts=16):
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=loc)
        o = bpy.context.active_object
        o.name = nm
        bpy.ops.object.shade_smooth()
        return o

    _cyl(f"{prefix}Saucer", 0.21 * scale, 0.035 * scale, (x, y, 0.018 * scale), 18).data.materials.append(pot_mat)
    bpy.ops.mesh.primitive_cone_add(vertices=18, radius1=0.14 * scale, radius2=0.19 * scale, depth=0.34 * scale, location=(x, y, 0.20 * scale))
    pot = bpy.context.active_object
    pot.name = f"{prefix}PotBody"
    bpy.ops.object.shade_smooth()
    pot.data.materials.append(pot_mat)
    _cyl(f"{prefix}PotRim", 0.205 * scale, 0.055 * scale, (x, y, 0.365 * scale), 18).data.materials.append(pot_mat)
    _cyl(f"{prefix}Soil", 0.175 * scale, 0.03 * scale, (x, y, 0.35 * scale), 14).data.materials.append(soil_mat)
    for i in range(10):
        ang = i * (2.0 * math.pi / 10.0) + (0.18 if i % 2 == 0 else -0.14)
        blade_len = (0.44 + (i % 3) * 0.13) * scale
        blade_w = (0.095 + (i % 2) * 0.022) * scale
        arch_out = (0.18 + (i % 3) * 0.075) * scale
        rad_off = (0.02 + (i % 3) * 0.022) * scale
        add_sculpted_plant_blade(
            f"{prefix}Blade_{i}",
            (x + math.cos(ang) * rad_off, y + math.sin(ang) * rad_off, 0.35 * scale),
            ang, blade_len, blade_w, arch_out, leaf_mat,
        )


def add_open_standing_fan_hd(x: float, y: float, dark_mat, teal_mat, metal_mat, scale: float = 1.0):
    def _cyl(nm, r, d, loc, rot=(0.0, 0.0, 0.0), verts=14, mat=metal_mat):
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=loc, rotation=rot)
        o = bpy.context.active_object
        o.name = nm
        bpy.ops.object.shade_smooth()
        o.data.materials.append(mat)
        return o

    def _box(nm, sz, loc, mat, bev=0.003, rot=(0.0, 0.0, 0.0)):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
        o = bpy.context.active_object
        o.name = nm
        o.scale = sz
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        if bev > 0:
            b = o.modifiers.new("Bevel", 'BEVEL')
            b.width = bev
            b.segments = 2
            bpy.ops.object.modifier_apply(modifier="Bevel")
        bpy.ops.object.shade_smooth()
        o.data.materials.append(mat)
        ensure_uv0(o, mode='CUBE')
        return o

    _cyl("FanBase", 0.18 * scale, 0.036 * scale, (x, y, 0.018 * scale), verts=16, mat=dark_mat)
    _cyl("FanPole", 0.018 * scale, 0.92 * scale, (x, y, 0.48 * scale), verts=12, mat=metal_mat)
    hz = 0.98 * scale
    cowl_prof = [(0.001, -0.07 * scale), (0.042 * scale, -0.06 * scale), (0.058 * scale, -0.02 * scale), (0.055 * scale, 0.04 * scale), (0.028 * scale, 0.065 * scale), (0.001, 0.07 * scale)]
    spin_profile("FanMotorCowl", cowl_prof, (x, y + 0.03 * scale, hz), dark_mat, steps=20, rot=(math.pi * 0.5, 0, 0))
    for r_name, ry in (("FanGuardRingFront", y - 0.065 * scale), ("FanGuardRingBack", y - 0.005 * scale)):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.19 * scale, minor_radius=0.008 * scale, major_segments=24, minor_segments=8,
            location=(x, ry, hz), rotation=(math.pi * 0.5, 0, 0)
        )
        ring = bpy.context.active_object
        ring.name = r_name
        bpy.ops.object.shade_smooth()
        ring.data.materials.append(metal_mat)
        ensure_uv0(ring, mode='CUBE')
    for s in range(4):
        ang = s * (math.pi / 4.0)
        _cyl(f"FanSpoke_{s}", 0.0018 * scale, 0.365 * scale, (x, y - 0.065 * scale, hz), rot=(0.0, ang, 0.0), verts=6, mat=metal_mat)
    _cyl("FanHubBadge", 0.036 * scale, 0.016 * scale, (x, y - 0.068 * scale, hz), rot=(math.pi * 0.5, 0.0, 0.0), verts=14, mat=teal_mat)
    for bi in range(3):
        _box(f"FanBtn_{bi}", (0.018 * scale, 0.022 * scale, 0.014 * scale), (x + (-0.03 + bi * 0.03) * scale, y - 0.11 * scale, 0.038 * scale), teal_mat if bi == 1 else metal_mat, 0.003 * scale)
    for b in range(3):
        ang = b * (2.0 * math.pi / 3.0)
        _box(f"FanBlade_{b}", (0.055 * scale, 0.008 * scale, 0.155 * scale), (x + math.cos(ang) * 0.08 * scale, y - 0.035 * scale, hz + math.sin(ang) * 0.08 * scale), teal_mat, 0.004 * scale, (0.28, ang, 0.0))


def add_galon_dispenser_hd(x: float, y: float, z: float, white_mat, dark_mat, hot_mat, cold_mat, prefix: str = "Galon"):
    def _mat(nm, rgba, rgh=0.12, alpha=1.0):
        m = bpy.data.materials.new(nm)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = rgba
        bsdf.inputs["Roughness"].default_value = rgh
        if alpha < 1.0:
            bsdf.inputs["Alpha"].default_value = alpha
            m.blend_method = 'BLEND'
        return m

    def _cyl(nm, r, d, loc, mat, rot=(0.0, 0.0, 0.0), verts=20):
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=loc, rotation=rot)
        o = bpy.context.active_object
        o.name = nm
        bpy.ops.object.shade_smooth()
        o.data.materials.append(mat)
        return o

    disp_prof = [(0.001, 0.0), (0.142, 0.0), (0.145, 0.03), (0.138, 0.29), (0.145, 0.31), (0.125, 0.32), (0.001, 0.32)]
    spin_profile(f"{prefix}DispenserTower", disp_prof, (x, y, z), white_mat, steps=28)
    _cyl(f"{prefix}TapHot", 0.012, 0.035, (x - 0.13, y - 0.08, z + 0.18), hot_mat, rot=(math.radians(45), math.pi * 0.5, 0), verts=10)
    _cyl(f"{prefix}TapCold", 0.012, 0.035, (x - 0.07, y - 0.13, z + 0.18), cold_mat, rot=(math.radians(45), math.pi * 0.5, 0), verts=10)

    mat_water = _mat(f"{prefix}WaterFillMat", (0.12, 0.54, 0.88, 1.0), 0.10, 0.58)
    mat_pet = _mat(f"{prefix}PETMat", (0.58, 0.84, 0.98, 1.0), 0.06, 0.32)
    mat_lbl = _mat(f"{prefix}LabelMat", (0.08, 0.38, 0.78, 1.0), 0.32, 1.0)
    _cyl(f"{prefix}WaterFill", 0.122, 0.22, (x, y, z + 0.48), mat_water, verts=24)
    _cyl(f"{prefix}LabelBand", 0.140, 0.065, (x, y, z + 0.56), mat_lbl, verts=28)
    _cyl(f"{prefix}Cap", 0.042, 0.035, (x, y, z + 0.335), mat_lbl, verts=16)
    galon_prof = [
        (0.001, 0.0), (0.038, 0.0), (0.038, 0.04), (0.125, 0.09),
        (0.138, 0.14), (0.130, 0.17), (0.138, 0.20), (0.130, 0.23),
        (0.138, 0.26), (0.130, 0.29), (0.138, 0.33), (0.120, 0.37),
        (0.065, 0.395), (0.001, 0.40),
    ]
    g_obj = spin_profile(f"{prefix}AquaBottle", galon_prof, (x, y, z + 0.32), mat_pet, steps=32, uv_mode='SMART')
    g_obj.data.use_auto_smooth = False


def add_magic_com_hd(x: float, y: float, z: float, body_mat, lid_mat, metal_mat, dark_mat):
    mc_body_prof = [(0.001, 0.0), (0.125, 0.0), (0.132, 0.03), (0.132, 0.17), (0.122, 0.19), (0.001, 0.19)]
    spin_profile("MagicComBody", mc_body_prof, (x, y, z), body_mat, steps=24)
    mc_lid_prof = [(0.001, 0.0), (0.124, 0.0), (0.118, 0.025), (0.075, 0.052), (0.001, 0.058)]
    spin_profile("MagicComLid", mc_lid_prof, (x, y, z + 0.19), lid_mat, steps=24)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.022, depth=0.024, location=(x, y, z + 0.252))
    v = bpy.context.active_object
    v.name = "MagicComVent"
    bpy.ops.object.shade_smooth()
    v.data.materials.append(metal_mat)
    mat_led = bpy.data.materials.new("MagicComLedGlow")
    mat_led.use_nodes = True
    bsdf = mat_led.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (1.0, 0.48, 0.12, 1.0)
    bsdf.inputs["Emission Color"].default_value = (1.0, 0.48, 0.12, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 1.6
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x - 0.12, y - 0.04, z + 0.08))
    led = bpy.context.active_object
    led.name = "MagicComLED"
    led.scale = (0.012, 0.024, 0.014)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    led.data.materials.append(mat_led)


def polish_scene_textures_1024():
    """Fast C-buffer 1024px upscale + micro-contrast polish, skipping uniform swatches (std < 0.01) to prevent VRAM bloat."""
    seen_imgs = set()
    for img in bpy.data.images:
        if img.name in seen_imgs:
            continue
        if any(skip in img.name.lower() for skip in ("render", "viewer", "lightmap", "normal", "_nrm")):
            continue
        seen_imgs.add(img.name)
        w, h = img.size[0], img.size[1]
        if w <= 0 or h <= 0:
            continue
        flat = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(flat)
        px = flat.reshape(-1, 4)
        # Skip uniform/solid swatches (e.g., flat Kenney colormaps or solid buffers)
        if float(np.std(px[:, :3])) < 0.01:
            img.pack()
            continue
        if w < 1024:
            nw = 1024
            nh = max(64, int(round(h * (1024.0 / w))))
            img.scale(nw, nh)
            w, h = nw, nh
            flat = np.empty(w * h * 4, dtype=np.float32)
            img.pixels.foreach_get(flat)
            px = flat.reshape(-1, 4)
        px[:, :3] = np.clip((px[:, :3] - 0.5) * 1.08 + 0.5, 0.0, 1.0)
        new_img = bpy.data.images.new(f"{img.name}_hd", width=w, height=h, alpha=True, float_buffer=False)
        new_img.colorspace_settings.name = img.colorspace_settings.name
        new_img.pixels.foreach_set(flat)
        new_img.pack()
        for m in bpy.data.materials:
            if m and m.use_nodes:
                for node in m.node_tree.nodes:
                    if node.type == 'TEX_IMAGE' and node.image == img:
                        node.image = new_img
        seen_imgs.add(new_img.name)


def export_room_glb(filepath: str, quality: int = 88):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format='GLB',
        export_apply=False,
        export_image_format='JPEG',
        export_jpeg_quality=quality,
    )
