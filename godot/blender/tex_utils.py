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


def generate_plaster_ao_texture(tex_dir: str, name: str, base_rgb=(0.86, 0.78, 0.64)):
    alb, nrm, rgh = load_polyhaven_pbr(tex_dir, "plaster", base_rgb, f"{name}_ph_alb")
    if alb is not None:
        return alb, nrm, rgh
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    v = yy / size
    rng = np.random.default_rng(7)
    grain = rng.normal(0.0, 0.022, (size, size)).astype(np.float32)
    bottom_ao = 1.0 - 0.28 * np.exp(-((1.0 - v) * 6.0) ** 2)
    top_ao = 1.0 - 0.16 * np.exp(-(v * 7.5) ** 2)
    shade = np.clip(bottom_ao * top_ao + grain, 0.45, 1.05)
    rgb = np.stack([np.clip(base_rgb[i] * shade, 0.0, 1.0) for i in range(3)], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return (
        save_rgba_png(name, rgba, tex_dir, False),
        save_rgba_png(f"{name}_nrm", _height_to_normal(grain, 2.2), tex_dir, True),
        None,
    )


def generate_tile_textures(tex_dir: str, name: str = "ceramic_tile", base_rgb=(0.84, 0.76, 0.64), polyhaven_key: str = "ceramic"):
    alb, nrm, rgh = load_polyhaven_pbr(tex_dir, polyhaven_key, base_rgb, f"{name}_ph_alb")
    if alb is not None:
        return alb, nrm, rgh
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    tiles = 6.0
    u = (xx / size * tiles) % 1.0
    v = (yy / size * tiles) % 1.0
    grout = (u < 0.045) | (v < 0.045)
    rng = np.random.default_rng(19)
    speck = rng.normal(0.0, 0.018, (size, size)).astype(np.float32)
    shade = np.where(grout, 0.65, 0.98 + speck)
    height = np.where(grout, 0.12, 0.88 + speck * 0.5).astype(np.float32)
    rgb = np.stack([np.clip(base_rgb[i] * shade, 0.0, 1.0) for i in range(3)], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return (
        save_rgba_png(f"{name}_albedo", rgba, tex_dir, False),
        save_rgba_png(f"{name}_normal", _height_to_normal(height, 2.2), tex_dir, True),
        None,
    )


def generate_asphalt_textures(tex_dir: str):
    alb, nrm, rgh = load_polyhaven_pbr(tex_dir, "asphalt", (0.28, 0.30, 0.34), "asphalt_ph_alb")
    if alb is not None:
        return alb, nrm, rgh
    size = 512
    rng = np.random.default_rng(99)
    grit = rng.normal(0.0, 0.045, (size, size)).astype(np.float32)
    base = np.clip(0.24 + grit * 0.45, 0.10, 0.38)
    rgb = np.stack([base * 0.96, base * 0.98, base * 1.05], axis=-1)
    rgba = np.concatenate([rgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
    return (
        save_rgba_png("asphalt_albedo", rgba, tex_dir, False),
        save_rgba_png("asphalt_normal", _height_to_normal(grit, 1.8), tex_dir, True),
        None,
    )


def generate_wood_texture(tex_dir: str, name: str = "teak_wood", base_rgb=(0.45, 0.27, 0.15)):
    alb, nrm, rgh = load_polyhaven_pbr(tex_dir, "wood", base_rgb, f"{name}_ph_alb")
    if alb is not None:
        return alb, nrm, rgh
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    u, v = xx / size, yy / size
    grain = 0.035 * np.sin(v * 220.0 + np.sin(u * 4.0) * 0.5)
    plank_seam = np.where(((v * 6.0) % 1.0) < 0.02, 0.72, 1.0)
    shade = np.clip((0.96 + grain) * plank_seam, 0.5, 1.1)
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
    """512x512 crisp cozy stylized face texture for planar -Y head UV projection."""
    size = 512
    yy, xx = np.mgrid[0:size, 0:size]
    u = xx / size  # 0..1 left-to-right
    v = yy / size  # 0..1 top-to-bottom (row 0 = top of head)
    rgb = np.zeros((size, size, 3), dtype=np.float32)
    rgb[:, :] = skin_rgb

    # Soft rosy cheeks
    for cx in (0.31, 0.69):
        d2 = ((u - cx) / 0.085) ** 2 + ((v - 0.61) / 0.055) ** 2
        blush = np.exp(-d2 * 1.8)[..., None]
        rgb = rgb * (1.0 - 0.25 * blush) + np.array([0.86, 0.44, 0.40], dtype=np.float32) * (0.25 * blush)

    # Crisp stylized eyes (whites + warm dark irises + bright white catchlights) + arched brows
    for cx, side in ((0.36, -1.0), (0.64, 1.0)):
        eye_w = ((u - cx) / 0.068) ** 2 + ((v - 0.47) / 0.055) ** 2
        rgb[eye_w < 1.0] = [0.96, 0.95, 0.93]
        iris = ((u - cx) / 0.044) ** 2 + ((v - 0.475) / 0.046) ** 2
        rgb[iris < 1.0] = [0.11, 0.09, 0.09]
        pupil = ((u - cx) / 0.022) ** 2 + ((v - 0.478) / 0.024) ** 2
        rgb[pupil < 1.0] = [0.03, 0.03, 0.03]
        spark = ((u - (cx + 0.016)) / 0.014) ** 2 + ((v - 0.455) / 0.014) ** 2
        rgb[spark < 1.0] = [0.99, 0.99, 0.99]
        # Upper lash line
        lash = (np.abs(u - cx) < 0.072) & (np.abs(v - (0.422 + 0.022 * ((u - cx) / 0.072) ** 2)) < 0.011)
        rgb[lash] = [0.07, 0.05, 0.05]
        # Eyebrow
        brow_v = 0.345 + 0.018 * ((u - cx) / 0.08) ** 2
        brow = (np.abs(u - cx) < 0.075) & (np.abs(v - brow_v) < 0.014)
        rgb[brow] = [0.10, 0.08, 0.07]

    # Subtle nose shadow + warm friendly smile
    nose = ((u - 0.50) / 0.028) ** 2 + ((v - 0.57) / 0.024) ** 2
    n_mask = np.exp(-nose * 1.8)[..., None]
    rgb = rgb * (1.0 - 0.16 * n_mask) + np.array([skin_rgb[0] * 0.72, skin_rgb[1] * 0.68, skin_rgb[2] * 0.66], dtype=np.float32) * (0.16 * n_mask)

    smile_v = 0.715 - 0.032 * ((u - 0.50) / 0.095) ** 2
    smile = (np.abs(u - 0.50) < 0.088) & (np.abs(v - smile_v) < 0.011)
    rgb[smile] = [0.56, 0.24, 0.23]

    rgba = np.concatenate([np.clip(rgb, 0.0, 1.0), np.ones((size, size, 1), dtype=np.float32)], axis=-1).astype(np.float32)
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
