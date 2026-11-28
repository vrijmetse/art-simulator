class_name ArtMajikanProfiles
extends RefCounted

const PERSONALITIES := {
	"ramah": {
		"id": "ramah",
		"call_patience_s": 14.0,
		"miss_trust_penalty": 12,
		"miss_deduction_rp": 5000,
		"warning_template": "Aduh, kok lama nyahutnya? Jangan keasyikan %s ya, kerjaan dulu.",
		"warning_template_en": "Hey, why did it take so long? Please focus on work instead of %s.",
	},
	"ramai": {
		"id": "ramai",
		"call_patience_s": 11.0,
		"miss_trust_penalty": 18,
		"miss_deduction_rp": 7500,
		"warning_template": "Aduh ini anak-anak rewel! Lain kali jangan sibuk %s pas dipanggil.",
		"warning_template_en": "The kids are fussy! Next time don't get busy %s when I call.",
	},
	"perfeksionis": {
		"id": "perfeksionis",
		"call_patience_s": 7.5,
		"miss_trust_penalty": 25,
		"miss_deduction_rp": 10000,
		"warning_template": "Saya panggil berkali-kali tidak dengar? Saya tidak bayar untuk %s di jam kerja!",
		"warning_template_en": "I called repeatedly and you didn't hear? I don't pay for %s on the clock!",
	},
}

const PROFILES := [
	{
		"id": "ibu_kos_melati",
		"name": "Ibu Kos Melati",
		"tier_id": "kamar_kos",
		"personality": "ramah",
		"kamar_art_variant": "none",
		"kamar_art_scene": "res://assets/models/kos_room.glb",
		"work_scene": "res://assets/models/kos_room.glb",
		"work_interior_scene": "res://assets/models/kos_neighbor_room.glb",
		"base_pay_rp": 35000,
		"initial_trust": 65,
		"fire_threshold": 20,
	},
	{
		"id": "pak_agus_kampung",
		"name": "Keluarga Pak Agus & Ibu Tini",
		"tier_id": "kampung",
		"personality": "ramah",
		"kamar_art_variant": "none",
		"kamar_art_scene": "res://assets/models/kos_room.glb",
		"work_scene": "res://assets/models/kampung_gang.glb",
		"work_interior_scene": "res://assets/models/room_kampung_house.glb",
		"base_pay_rp": 50000,
		"initial_trust": 60,
		"fire_threshold": 20,
	},
	{
		"id": "keluarga_budi_36",
		"name": "Ibu Sari & Pak Budi",
		"tier_id": "perumahan_36",
		"personality": "ramai",
		"kamar_art_variant": "none",
		"kamar_art_scene": "res://assets/models/kos_room.glb",
		"work_scene": "res://assets/models/kampung_street.glb",
		"work_interior_scene": "res://assets/models/room_majikan_living.glb",
		"base_pay_rp": 75000,
		"initial_trust": 60,
		"fire_threshold": 20,
	},
	{
		"id": "bu_ratna_45",
		"name": "Ibu Ratna (Karier)",
		"tier_id": "perumahan_45",
		"personality": "perfeksionis",
		"kamar_art_variant": "small",
		"kamar_art_scene": "res://assets/models/kamar_art_small.glb",
		"work_scene": "res://assets/models/kampung_street.glb",
		"work_interior_scene": "res://assets/models/room_majikan_living.glb",
		"base_pay_rp": 115000,
		"initial_trust": 55,
		"fire_threshold": 25,
	},
	{
		"id": "keluarga_wijaya_elite",
		"name": "Keluarga Wijaya",
		"tier_id": "cluster_elite",
		"personality": "perfeksionis",
		"kamar_art_variant": "large",
		"kamar_art_scene": "res://assets/models/kamar_art_large.glb",
		"work_scene": "res://assets/models/cluster_elite_street.glb",
		"work_interior_scene": "res://assets/models/room_elite_living.glb",
		"base_pay_rp": 180000,
		"initial_trust": 55,
		"fire_threshold": 25,
	},
]

static func get_personality(personality_id: String) -> Dictionary:
	return PERSONALITIES.get(personality_id, PERSONALITIES["ramah"])

static func get_profile(profile_id: String) -> Dictionary:
	var lookup := "pak_agus_kampung" if profile_id == "pak_hendra_kampung" else profile_id
	for p in PROFILES:
		if p["id"] == lookup:
			return p
	return {}

static func get_profiles_for_tier(tier_id: String) -> Array:
	var out: Array = []
	for p in PROFILES:
		if p["tier_id"] == tier_id:
			out.append(p)
	return out
