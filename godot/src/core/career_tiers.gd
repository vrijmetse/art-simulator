class_name ArtCareerTiers
extends RefCounted

const TIERS := [
	{
		"id": "kamar_kos",
		"min_xp": 0,
		"min_level": 1,
		"house_type": "Kamar Kos Harian",
		"house_type_en": "Daily Boarding Room",
		"label_id": "Jasa Bersih Kamar Kos (Jalan Kaki, 1 Ruangan)",
		"label_en": "Boarding Room Cleaning (Walkable, Single Room)",
		"access": ["walk"],
		"car_allowed": false,
		"live_in_room_provided": false,
		"pay_multiplier": 0.85,
		"street_scene": "res://assets/models/kos_room.glb",
	},
	{
		"id": "kampung",
		"min_xp": 80,
		"min_level": 2,
		"house_type": "Kontrakan & Rumah Kampung",
		"house_type_en": "Kampung House",
		"label_id": "Gang Kampung (Jalan Kaki / Sepeda / Motor)",
		"label_en": "Kampung Alley (Walk / Bike / Motorbike)",
		"access": ["walk", "bicycle", "motorbike"],
		"car_allowed": false,
		"live_in_room_provided": false,
		"pay_multiplier": 1.0,
		"street_scene": "res://assets/models/kampung_gang.glb",
	},
	{
		"id": "perumahan_36",
		"min_xp": 200,
		"min_level": 3,
		"house_type": "Tipe 36/72",
		"house_type_en": "Type 36/72 House",
		"label_id": "Perumahan Tipe 36/72 (Komplek Subsidi)",
		"label_en": "Type 36/72 Housing Complex",
		"access": ["walk", "bicycle", "motorbike", "car"],
		"car_allowed": true,
		"live_in_room_provided": false,
		"pay_multiplier": 1.45,
		"street_scene": "res://assets/models/kampung_street.glb",
	},
	{
		"id": "perumahan_45",
		"min_xp": 600,
		"min_level": 4,
		"house_type": "Tipe 45/90",
		"house_type_en": "Type 45/90 House",
		"label_id": "Perumahan Tipe 45/90 (Klaster Menengah)",
		"label_en": "Type 45/90 Mid-Tier Cluster",
		"access": ["walk", "bicycle", "motorbike", "car"],
		"car_allowed": true,
		"live_in_room_provided": true,
		"pay_multiplier": 2.0,
		"street_scene": "res://assets/models/kampung_street.glb",
	},
	{
		"id": "cluster_elite",
		"min_xp": 1400,
		"min_level": 6,
		"house_type": "Tipe 120+ (2 Lantai)",
		"house_type_en": "Elite Type 120+ (2-Story)",
		"label_id": "Cluster Elite Tipe 120+ (Rumah Mewah)",
		"label_en": "Elite Cluster Type 120+ (2-Story)",
		"access": ["walk", "bicycle", "motorbike", "car"],
		"car_allowed": true,
		"live_in_room_provided": true,
		"pay_multiplier": 3.0,
		"street_scene": "res://assets/models/cluster_elite_street.glb",
	},
]

static func get_all_tiers() -> Array:
	return TIERS

static func get_tier(tier_id: String) -> Dictionary:
	for t in TIERS:
		if t["id"] == tier_id:
			return t
	return {}

static func can_access_tier(tier_id: String, xp: int) -> bool:
	var t := get_tier(tier_id)
	if t.is_empty():
		return false
	return xp >= int(t["min_xp"])

static func get_active_tier(xp: int) -> Dictionary:
	var current: Dictionary = TIERS[0]
	for t in TIERS:
		if xp >= int(t["min_xp"]):
			current = t
	return current

const OUTFIT_TIERS := [
	{
		"id": "starter_kasual",
		"min_xp": 0,
		"label_id": "Kaos Harian Kampung",
		"label_en": "Everyday Kampung Tee",
		"has_apron": false,
		"model_path": "res://assets/models/char_art.glb",
		"customizable_colors": ["#4E7D63", "#C9855E", "#5A6D8C", "#D6C5A9"],
	},
	{
		"id": "seragam_perumahan",
		"min_xp": 200,
		"label_id": "Seragam Kerja & Celemek Rapi",
		"label_en": "Neat Work Uniform & Apron",
		"has_apron": true,
		"model_path": "res://assets/models/char_art_pro.glb",
		"customizable_colors": ["#237A75", "#3E6B89", "#7B4F6D", "#A86444"],
	},
	{
		"id": "housekeeper_elite",
		"min_xp": 1400,
		"label_id": "Seragam Housekeeper Cluster Elite",
		"label_en": "Elite Cluster Housekeeper Suit",
		"has_apron": true,
		"model_path": "res://assets/models/char_art_elite.glb",
		"customizable_colors": ["#1E3442", "#59382C", "#2C4A3B", "#4A3E63"],
	},
]

static func get_unlocked_outfits(xp: int) -> Array:
	var out: Array = []
	for o in OUTFIT_TIERS:
		if xp >= int(o["min_xp"]):
			out.append(o)
	return out

static func can_equip_outfit(outfit_id: String, xp: int) -> bool:
	for o in OUTFIT_TIERS:
		if o["id"] == outfit_id:
			return xp >= int(o["min_xp"])
	return false

static func get_active_outfit(xp: int) -> Dictionary:
	var current: Dictionary = OUTFIT_TIERS[0]
	for o in OUTFIT_TIERS:
		if xp >= int(o["min_xp"]):
			current = o
	return current
