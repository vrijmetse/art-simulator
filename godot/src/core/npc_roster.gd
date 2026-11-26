class_name ArtNpcRoster
extends RefCounted

const KOS_CHORES := {
	"make_bed": Vector3(-0.75, 0.0, -0.95),
	"sweep_floor": Vector3(0.20, 0.0, 0.35),
	"wash_dishes": Vector3(0.85, 0.0, -1.45),
	"cook_rice": Vector3(1.85, 0.0, -1.45),
	"iron_laundry": Vector3(1.35, 0.0, 0.55),
	"water_plants": Vector3(-1.45, 0.0, 0.95),
}

const KAMPUNG_CHORES := {
	"make_bed": Vector3(-1.35, 0.0, -1.15),
	"sweep_floor": Vector3(0.05, 0.0, 0.95),
	"wash_dishes": Vector3(0.95, 0.0, -0.55),
	"cook_rice": Vector3(1.55, 0.0, -0.55),
	"iron_laundry": Vector3(1.15, 0.0, 1.15),
	"water_plants": Vector3(-1.35, 0.0, 0.95),
}

const ELITE_CHORES := {
	"make_bed": Vector3(-2.35, 0.0, -1.65),
	"sweep_floor": Vector3(0.35, 0.0, 1.60),
	"wash_dishes": Vector3(2.25, 0.0, -0.35),
	"cook_rice": Vector3(2.45, 0.0, -1.45),
	"iron_laundry": Vector3(1.85, 0.0, 1.45),
	"water_plants": Vector3(-2.35, 0.0, 1.55),
}

static func get_tier_bounds_and_chores(tier_id: String) -> Dictionary:
	match tier_id:
		"cluster_elite":
			return {
				"walk_rect": Rect2(-3.4, -2.5, 6.8, 4.8),
				"player_spawn": Vector3(0.35, 0.0, 1.35),
				"chores": ELITE_CHORES,
			}
		"perumahan_36", "perumahan_45":
			return {
				"walk_rect": Rect2(-2.8, -2.1, 5.6, 3.9),
				"player_spawn": Vector3(0.0, 0.0, -0.5),
				"chores": KOS_CHORES,
			}
		"kampung":
			return {
				"walk_rect": Rect2(-2.1, -1.8, 4.2, 3.5),
				"player_spawn": Vector3(0.0, 0.0, 0.35),
				"chores": KAMPUNG_CHORES,
			}
		_:
			return {
				"walk_rect": Rect2(-2.0, -1.8, 4.0, 3.5),
				"player_spawn": Vector3(0.0, 0.0, -0.5),
				"chores": KOS_CHORES,
			}

static func get_shift_npcs(tier_id: String) -> Array:
	match tier_id:
		"cluster_elite":
			return [
				{
					"id": "ibu_citra",
					"role": "ibu2",
					"label_id": "Ibu Citra",
					"label_en": "Mrs. Citra",
					"model_path": "res://assets/models/char_ibu.glb",
					"pos": Vector3(-1.85, 0.0, -0.55),
					"rot_y": 0.45,
					"anim": "Idle",
				},
				{
					"id": "pak_hendra",
					"role": "bapak2",
					"label_id": "Pak Hendra",
					"label_en": "Mr. Hendra",
					"model_path": "res://assets/models/char_budi.glb",
					"pos": Vector3(1.15, 0.0, -1.45),
					"rot_y": -0.35,
					"anim": "Idle",
				},
				{
					"id": "kakak_nadine",
					"role": "kakak2",
					"label_id": "Kakak Nadine",
					"label_en": "Kakak Nadine",
					"model_path": "res://assets/models/char_kakak.glb",
					"pos": Vector3(1.15, 0.0, 0.35),
					"rot_y": 1.15,
					"anim": "Idle",
				},
				{
					"id": "mbak_rina",
					"role": "mba2",
					"label_id": "Mbak Rina",
					"label_en": "Mbak Rina",
					"model_path": "res://assets/models/char_art_pro.glb",
					"pos": Vector3(2.15, 0.0, 0.55),
					"rot_y": -1.35,
					"anim": "Idle",
				},
			]
		"perumahan_36", "perumahan_45":
			return [
				{
					"id": "ibu_sari",
					"role": "ibu2",
					"label_id": "Ibu Sari",
					"label_en": "Mrs. Sari",
					"model_path": "res://assets/models/char_ibu.glb",
					"pos": Vector3(-1.35, 0.0, -0.05),
					"rot_y": 0.75,
					"anim": "Idle",
				},
				{
					"id": "pak_budi",
					"role": "bapak2",
					"label_id": "Pak Budi",
					"label_en": "Mr. Budi",
					"model_path": "res://assets/models/char_budi.glb",
					"pos": Vector3(-2.35, 0.0, 0.35),
					"rot_y": 1.15,
					"anim": "Idle",
				},
				{
					"id": "kakak_maya",
					"role": "kakak2",
					"label_id": "Kakak Maya",
					"label_en": "Kakak Maya",
					"model_path": "res://assets/models/char_kakak.glb",
					"pos": Vector3(0.45, 0.0, 1.45),
					"rot_y": 2.65,
					"anim": "Idle",
				},
			]
		"kampung":
			return [
				{
					"id": "ibu_tini",
					"role": "ibu2",
					"label_id": "Ibu Tini",
					"label_en": "Mrs. Tini",
					"model_path": "res://assets/models/char_ibu.glb",
					"pos": Vector3(-0.20, 0.0, -0.88),
					"rot_y": 0.15,
					"anim": "Idle",
				},
				{
					"id": "pak_agus",
					"role": "bapak2",
					"label_id": "Pak Agus",
					"label_en": "Mr. Agus",
					"model_path": "res://assets/models/char_budi.glb",
					"pos": Vector3(1.75, 0.0, 0.45),
					"rot_y": -1.35,
					"anim": "Idle",
				},
			]
		_:
			return [
				{
					"id": "ibu_melati",
					"role": "ibu2",
					"label_id": "Ibu Melati",
					"label_en": "Mrs. Melati",
					"model_path": "res://assets/models/char_ibu.glb",
					"pos": Vector3(1.30, 0.0, -0.50),
					"rot_y": -1.25,
					"anim": "Idle",
				},
			]

static func get_home_npcs(_tier_id: String) -> Array:
	# Private bedroom belongs solely to the player; neighbors & fellow ARTs live outside on the street!
	return []

static func get_street_config(tier_id: String) -> Dictionary:
	match tier_id:
		"cluster_elite":
			return {
				"street_scene": "res://assets/models/cluster_elite_street.glb",
				"walk_rect": Rect2(-6.0, -0.45, 12.0, 1.55),
				"player_spawn": Vector3(-1.4, 0.0, 0.45),
				"portal_home": Vector3(-4.8, 0.0, -0.15),
				"portal_work": Vector3(4.8, 0.0, -0.15),
				"street_npcs": [
					{"id": "ibu_sari", "label_id": "Ibu Citra", "label_en": "Ibu Citra", "model_path": "res://assets/models/char_ibu.glb", "pos": Vector3(2.4, 0.0, 0.35), "rot_y": -0.45, "anim": "Idle"},
					{"id": "pak_budi", "label_id": "Pak Hendra", "label_en": "Pak Hendra", "model_path": "res://assets/models/char_budi.glb", "pos": Vector3(0.3, 0.0, 0.70), "rot_y": 0.30, "anim": "Idle"},
					{"id": "adik_bima", "label_id": "Kakak Nadine", "label_en": "Kakak Nadine", "model_path": "res://assets/models/char_kakak.glb", "pos": Vector3(-3.1, 0.0, 0.65), "rot_y": 0.55, "anim": "Idle"},
				],
			}
		"perumahan_36", "perumahan_45":
			return {
				"street_scene": "res://assets/models/kampung_street.glb",
				"walk_rect": Rect2(-5.2, 0.35, 10.4, 1.45),
				"player_spawn": Vector3(-1.6, 0.0, 1.15),
				"portal_home": Vector3(-4.2, 0.0, 0.55),
				"portal_work": Vector3(3.1, 0.0, 0.55),
				"street_npcs": [
					{"id": "ibu_sari", "label_id": "Ibu Sari", "label_en": "Ibu Sari", "model_path": "res://assets/models/char_ibu.glb", "pos": Vector3(1.5, 0.0, 0.85), "rot_y": -0.35, "anim": "Idle"},
					{"id": "pak_budi", "label_id": "Pak Budi", "label_en": "Pak Budi", "model_path": "res://assets/models/char_budi.glb", "pos": Vector3(4.6, 0.0, 1.25), "rot_y": -0.75, "anim": "Idle"},
					{"id": "adik_bima", "label_id": "Kakak Maya", "label_en": "Kakak Maya", "model_path": "res://assets/models/char_kakak.glb", "pos": Vector3(-0.1, 0.0, 1.45), "rot_y": 0.25, "anim": "Idle"},
				],
			}
		_:
			return {
				"street_scene": "res://assets/models/kampung_gang.glb",
				"walk_rect": Rect2(-5.2, 0.35, 10.4, 1.70),
				"player_spawn": Vector3(-1.4, 0.0, 1.25),
				"portal_home": Vector3(-3.9, 0.0, 0.55),
				"portal_work": Vector3(2.9, 0.0, 0.55),
				"street_npcs": [
					{"id": "ibu_sari", "label_id": "Ibu Melati", "label_en": "Ibu Melati", "model_path": "res://assets/models/char_ibu.glb", "pos": Vector3(0.45, 0.0, 1.40), "rot_y": -0.35, "anim": "Idle"},
					{"id": "adik_bima", "label_id": "Mbak Dewi", "label_en": "Mbak Dewi", "model_path": "res://assets/models/char_art.glb", "pos": Vector3(-2.6, 0.0, 1.60), "rot_y": 0.45, "anim": "Idle"},
					{"id": "pak_budi", "label_id": "Pak Agus", "label_en": "Pak Agus", "model_path": "res://assets/models/char_budi.glb", "pos": Vector3(4.2, 0.0, 1.45), "rot_y": -0.75, "anim": "Idle"},
				],
			}
