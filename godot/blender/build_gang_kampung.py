import os
import sys
import math
import bpy

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from build_kampung_street import (
    add_box,
    add_pitched_roof,
    add_sculpted_scooter,
    bake_cycles_ao,
    import_unpacked_asset,
    make_solid_mat,
)
from tex_utils import (
    generate_batu_alam_texture,
    generate_plaster_ao_texture,
    generate_terracotta_textures,
    generate_tile_textures,
    generate_turf_texture,
    generate_wood_texture,
    make_pbr_material,
)

GODOT_DIR = os.path.dirname(SCRIPT_DIR)
TEX_DIR = os.path.join(GODOT_DIR, "assets", "textures")
OUT_GLB = os.path.join(GODOT_DIR, "assets", "models", "kampung_gang.glb")


def build_gang_kampung():
    """Tier 2 Worksite: Narrow walkable/bike/motorbike Indonesian Gang Kampung (high-detail V15 quality, NO cars!)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)

    roof_a_alb, roof_a_nrm, roof_a_rgh = generate_terracotta_textures(TEX_DIR, "gang_roof_terra_v15", (0.52, 0.23, 0.14))
    roof_b_alb, roof_b_nrm, roof_b_rgh = generate_terracotta_textures(TEX_DIR, "gang_roof_slate_v15", (0.24, 0.29, 0.34))
    wall_a, wall_nrm, wall_rgh = generate_plaster_ao_texture(TEX_DIR, "gang_wall_cream_v15", (0.85, 0.78, 0.65))
    wall_b, _, _ = generate_plaster_ao_texture(TEX_DIR, "gang_wall_mint_v15", (0.71, 0.79, 0.69))
    wall_c, _, _ = generate_plaster_ao_texture(TEX_DIR, "gang_wall_peach_v15", (0.83, 0.70, 0.56))
    pave_alb, pave_nrm, pave_rgh = generate_tile_textures(TEX_DIR, "gang_paving_v15", (0.74, 0.70, 0.64), "paving")
    wood_alb, wood_nrm, wood_rgh = generate_wood_texture(TEX_DIR, "gang_wood_v15", (0.38, 0.22, 0.12))
    grass_alb, grass_nrm, grass_rgh = generate_turf_texture(TEX_DIR, "gang_grass_v15", (0.22, 0.44, 0.18))
    batu_alb, batu_nrm, _ = generate_batu_alam_texture(TEX_DIR, "gang_batu_v15")

    mat_roof_a = make_pbr_material("GangRoofA", roof_a_alb, 0.74, roof_a_nrm, 1.15, (2.0, 2.0), roof_a_rgh)
    mat_roof_b = make_pbr_material("GangRoofB", roof_b_alb, 0.74, roof_b_nrm, 1.15, (2.0, 2.0), roof_b_rgh)
    mat_wall_a = make_pbr_material("GangWallA", wall_a, 0.88, wall_nrm, 0.45, (1.5, 1.5), wall_rgh)
    mat_wall_b = make_pbr_material("GangWallB", wall_b, 0.88, wall_nrm, 0.45, (1.5, 1.5), wall_rgh)
    mat_wall_c = make_pbr_material("GangWallC", wall_c, 0.88, wall_nrm, 0.45, (1.5, 1.5), wall_rgh)
    mat_pave = make_pbr_material("GangPaving", pave_alb, 0.84, pave_nrm, 0.75, (7.0, 1.8), pave_rgh)
    mat_wood = make_pbr_material("GangWood", wood_alb, 0.68, wood_nrm, 0.45, (1.5, 1.5), wood_rgh)
    mat_grass = make_pbr_material("GangGrass", grass_alb, 0.94, grass_nrm, 0.55, (6.0, 5.0), grass_rgh)
    mat_stone = make_pbr_material("GangBatu", batu_alb, 0.88, batu_nrm, 0.90, (2.0, 2.5))

    mat_trim = make_solid_mat("TrimWhite", (0.86, 0.83, 0.76), 0.78)
    mat_iron = make_solid_mat("IronDark", (0.10, 0.11, 0.14), 0.48, 0.65)
    mat_glass = make_solid_mat("WarmGlass", (0.07, 0.15, 0.23), 0.18, 0.0)
    mat_brass = make_solid_mat("BrassMetal", (0.76, 0.58, 0.24), 0.32, 0.85)
    mat_cushion = make_solid_mat("CurtainWarm", (0.78, 0.36, 0.26), 0.86)
    mat_tank = make_solid_mat("PosBlue", (0.18, 0.48, 0.74), 0.42)
    mat_lamp = make_solid_mat("Lamp", (1.0, 0.84, 0.46), 0.30, 0.0, 1.3)
    mat_tail = make_solid_mat("TailLamp", (0.90, 0.14, 0.12), 0.30, 0.0, 0.6)
    mat_scooter = make_solid_mat("ScooterBlue", (0.20, 0.42, 0.66), 0.32, 0.25)
    mat_tire = make_solid_mat("RubberTire", (0.06, 0.06, 0.07), 0.78)
    mat_metal = make_solid_mat("AlloyMetal", (0.72, 0.74, 0.78), 0.42, 0.0)
    mat_banana = make_solid_mat("BananaLeaf", (0.28, 0.60, 0.20), 0.72)

    # Narrow 2.4m walkable Gang Kampung paving alley (ONLY walk/bike/motorbike — NO cars!)
    add_box("GangGround", (24.0, 14.0, 0.12), (0.0, 2.0, -0.14), mat_grass, 0.0)
    add_box("GangAlleyPaving", (22.0, 2.45, 0.12), (0.0, -1.15, -0.04), mat_pave, 0.015)

    # 3 Cozy Detailed Kampung Houses along the narrow paving alley
    for idx, (cx, wmat, rmat) in enumerate([
        (-3.45, mat_wall_a, mat_roof_a),
        (0.0, mat_wall_b, mat_roof_b),
        (3.45, mat_wall_c, mat_roof_a),
    ]):
        add_box(f"KampungHouse_{idx}", (2.95, 2.15, 2.25), (cx, 1.95, 1.125), wmat, 0.025)
        add_box(f"KampungPlinth_{idx}", (3.02, 2.22, 0.42), (cx, 1.95, 0.21), mat_stone, 0.015)
        add_pitched_roof(f"KampungRoof_{idx}", 3.44, 2.68, 1.05, (cx, 1.95, 2.24), rmat, rmat, mat_trim, mat_iron)
        add_box(f"KampungTerrace_{idx}", (3.00, 1.05, 0.12), (cx, 0.48, 0.06), mat_pave, 0.015)
        add_box(f"KampungPorchRoof_{idx}", (3.12, 1.10, 0.07), (cx, 0.48, 1.72), rmat, 0.015, (math.radians(7.0), 0.0, 0.0))
        add_box(f"KampungPorchFascia_{idx}", (3.14, 0.05, 0.08), (cx, -0.08, 1.65), mat_trim, 0.008)
        for px in (-1.22, 1.22):
            add_box(f"KampungPil_{idx}_{px}", (0.18, 0.18, 1.48), (cx + px, 0.06, 0.86), mat_stone, 0.012)
            add_box(f"KampungPilCap_{idx}_{px}", (0.22, 0.22, 0.07), (cx + px, 0.06, 1.62), mat_trim, 0.01)

        # 4-panel teak door + brass handle + glossy curtained window
        add_box(f"KampungDoorFrame_{idx}", (0.82, 0.09, 1.50), (cx - 0.55, 0.88, 0.84), mat_wood, 0.012)
        add_box(f"KampungDoorLeaf_{idx}", (0.66, 0.05, 1.28), (cx - 0.55, 0.855, 0.76), mat_wood, 0.01)
        for px_off in (-0.13, 0.13):
            for pz in (0.45, 1.00):
                add_box(f"KampungDoorPanel_{idx}_{px_off}_{pz}", (0.19, 0.03, 0.36), (cx - 0.55 + px_off, 0.83, pz), mat_cushion, 0.008)
        add_box(f"KampungKnob_{idx}", (0.04, 0.05, 0.10), (cx - 0.30, 0.81, 0.76), mat_brass, 0.006)

        add_box(f"KampungWinFrame_{idx}", (1.06, 0.09, 0.84), (cx + 0.56, 0.88, 1.15), mat_trim, 0.012)
        add_box(f"KampungWinGlass_{idx}", (0.90, 0.03, 0.64), (cx + 0.56, 0.825, 1.12), mat_glass, 0.004)
        add_box(f"KampungWinCurtL_{idx}", (0.14, 0.02, 0.60), (cx + 0.20, 0.818, 1.12), mat_cushion, 0.004)
        add_box(f"KampungWinCurtR_{idx}", (0.14, 0.02, 0.60), (cx + 0.92, 0.818, 1.12), mat_cushion, 0.004)
        add_box(f"KampungWinMul_{idx}", (0.04, 0.04, 0.68), (cx + 0.56, 0.808, 1.12), mat_wood, 0.004)

        add_box(f"KampungBench_{idx}", (0.95, 0.34, 0.06), (cx + 0.56, 0.44, 0.40), mat_wood, 0.012)
        add_box(f"KampungBenchLegs_{idx}", (0.82, 0.28, 0.32), (cx + 0.56, 0.44, 0.22), mat_iron, 0.006)
        add_box(f"KampungLamp_{idx}", (0.12, 0.10, 0.14), (cx - 0.05, 0.82, 1.42), mat_lamp, 0.015)

        import_unpacked_asset("bush-common-flowers.glb", (cx - 1.32, 0.02, 0.0), 0.34, idx * 50, {
            "leaves": (0.18, 0.50, 0.17), "flowers": (0.90, 0.24, 0.46),
        })

    # Authentic Indonesian blue-roofed wooden Pos Ronda guard post
    add_box("PosRondaBase", (1.50, 1.25, 0.22), (-5.85, 0.40, 0.11), mat_wood, 0.02)
    for px in (-0.62, 0.62):
        for py in (-0.50, 0.50):
            bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.05, depth=1.80, location=(-5.85 + px, 0.40 + py, 1.02))
            bpy.context.active_object.data.materials.append(mat_wood)
    add_box("PosRondaRoof", (1.75, 1.50, 0.10), (-5.85, 0.40, 1.98), mat_tank, 0.02, (math.radians(-12), 0, 0))

    # Parked scooter in narrow Gang Kampung (no cars allowed in alley!)
    add_sculpted_scooter("GangScooter", 1.85, -0.78, math.radians(82), mat_scooter, mat_tire, mat_metal, mat_lamp, mat_tail)

    # Smooth Subsurf-2 tropical trees & Banana Palms (Pohon Pisang)
    for tx, ty, ts in [(-5.4, 3.8, 0.48), (-1.75, 4.0, 0.50), (1.75, 4.0, 0.48), (5.4, 3.8, 0.46)]:
        import_unpacked_asset("common-tree-1.glb", (tx, ty, 0.0), ts, 25, {"bark": (0.34, 0.22, 0.14), "leaves": (0.20, 0.52, 0.18)})
    for bx, by in [(-5.05, 0.55), (-1.70, 0.45), (1.70, 0.45), (5.10, 0.55)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.055, depth=1.05, location=(bx, by, 0.52))
        bpy.context.active_object.data.materials.append(mat_banana)
        for fi in range(6):
            ang = fi * (math.pi * 2.0 / 6.0)
            add_box(f"GangBanana_{bx}_{fi}", (0.68, 0.22, 0.025), (bx + math.cos(ang) * 0.32, by + math.sin(ang) * 0.32, 1.12), mat_banana, 0.008, (0.0, math.radians(24), ang))

    bake_cycles_ao()

    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB', export_apply=False, export_image_format='JPEG', export_jpeg_quality=85)
    print("EXPORTED HIGH-DETAIL GANG KAMPUNG:", OUT_GLB, "bytes=", os.path.getsize(OUT_GLB))


if __name__ == "__main__":
    build_gang_kampung()
