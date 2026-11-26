class_name ArtChoreEngine
extends RefCounted

const CHORES := {
	"sweep_floor": {
		"id": "sweep_floor",
		"skill": "sweeping",
		"base_duration": 4.0,
		"energy": 12,
		"base_pay": 8000,
		"xp": 12,
		"label_id": "Menyapu Lantai",
		"label_en": "Sweep Floor",
	},
	"make_bed": {
		"id": "make_bed",
		"skill": "tidiness",
		"base_duration": 3.5,
		"energy": 10,
		"base_pay": 7000,
		"xp": 10,
		"label_id": "Rapikan Tempat Tidur",
		"label_en": "Make the Bed",
	},
	"wash_dishes": {
		"id": "wash_dishes",
		"skill": "cooking",
		"base_duration": 4.5,
		"energy": 14,
		"base_pay": 10000,
		"xp": 15,
		"label_id": "Cuci Piring",
		"label_en": "Wash Dishes",
	},
	"cook_rice": {
		"id": "cook_rice",
		"skill": "cooking",
		"base_duration": 5.0,
		"energy": 15,
		"base_pay": 12000,
		"xp": 18,
		"label_id": "Masak Nasi & Lauk",
		"label_en": "Cook Rice & Meal",
	},
	"iron_laundry": {
		"id": "iron_laundry",
		"skill": "laundry",
		"base_duration": 5.5,
		"energy": 16,
		"base_pay": 13000,
		"xp": 20,
		"label_id": "Setrika & Lipat Baju",
		"label_en": "Iron & Fold Clothes",
	},
	"water_plants": {
		"id": "water_plants",
		"skill": "tidiness",
		"base_duration": 3.0,
		"energy": 8,
		"base_pay": 6000,
		"xp": 9,
		"label_id": "Siram Tanaman",
		"label_en": "Water Plants",
	},
}

const TIER_CHORE_SETS := {
	"kamar_kos": ["make_bed", "sweep_floor", "water_plants"],
	"kampung": ["make_bed", "sweep_floor", "wash_dishes", "water_plants"],
	"perumahan_36": ["make_bed", "sweep_floor", "wash_dishes", "cook_rice", "water_plants"],
	"perumahan_45": ["make_bed", "sweep_floor", "wash_dishes", "cook_rice", "iron_laundry"],
	"cluster_elite": ["make_bed", "sweep_floor", "wash_dishes", "cook_rice", "iron_laundry", "water_plants"],
}

static func create_shift(tier_id: String, profile: Dictionary, max_energy: int) -> Dictionary:
	var clamped_max := maxi(10, max_energy)
	var raw_ids: Array = TIER_CHORE_SETS.get(tier_id, TIER_CHORE_SETS["kamar_kos"])
	var assigned: Array = raw_ids.duplicate()
	return {
		"tier_id": tier_id,
		"profile_id": String(profile.get("id", "ibu_kos_melati")),
		"assigned_ids": assigned,
		"completed_ids": [],
		"energy": clamped_max,
		"max_energy": clamped_max,
		"earned_rp": 0,
		"xp_earned": 0,
		"skill_xp_earned": {},
		"settled": false,
	}

static func effective_duration(chore_id: String, skill_level: int, mood: int = 60) -> float:
	if not CHORES.has(chore_id):
		return 4.0
	var lvl := maxi(1, skill_level)
	var base_dur := float(CHORES[chore_id]["base_duration"])
	var skill_mult := maxf(0.55, 1.0 - float(lvl - 1) * 0.10)
	var mood_mult := 1.0
	if mood >= 80:
		mood_mult = 0.85
	elif mood <= 25:
		mood_mult = 1.15
	return base_dur * skill_mult * mood_mult

static func complete_chore(shift: Dictionary, chore_id: String, pay_multiplier: float, skill_level: int) -> Dictionary:
	if not CHORES.has(chore_id):
		return {"ok": false, "reason": "unknown_chore", "shift": shift}
	var assigned: Array = shift.get("assigned_ids", [])
	if not (chore_id in assigned):
		return {"ok": false, "reason": "not_assigned", "shift": shift}
	var completed: Array = shift.get("completed_ids", [])
	if chore_id in completed:
		return {"ok": false, "reason": "already_done", "shift": shift}

	var chore: Dictionary = CHORES[chore_id]
	var e_cost := int(chore["energy"])
	var cur_energy := int(shift.get("energy", 0))
	if cur_energy < e_cost:
		return {"ok": false, "reason": "low_energy", "shift": shift}

	var lvl := maxi(1, skill_level)
	var mult := maxf(0.1, pay_multiplier)
	var pay_rp := int(round(float(chore["base_pay"]) * mult * (1.0 + float(lvl - 1) * 0.08)))
	var xp_gain := int(chore["xp"])
	var skill_key := String(chore["skill"])

	var nxt := shift.duplicate(true)
	var nxt_done: Array = nxt.get("completed_ids", [])
	nxt_done.append(chore_id)
	nxt["completed_ids"] = nxt_done
	nxt["energy"] = cur_energy - e_cost
	nxt["earned_rp"] = int(nxt.get("earned_rp", 0)) + pay_rp
	nxt["xp_earned"] = int(nxt.get("xp_earned", 0)) + xp_gain

	var sk: Dictionary = nxt.get("skill_xp_earned", {})
	sk[skill_key] = int(sk.get(skill_key, 0)) + xp_gain
	nxt["skill_xp_earned"] = sk

	return {
		"ok": true,
		"reason": "",
		"payout_rp": pay_rp,
		"xp_gain": xp_gain,
		"shift": nxt,
	}

static func is_shift_complete(shift: Dictionary) -> bool:
	var assigned: Array = shift.get("assigned_ids", [])
	var completed: Array = shift.get("completed_ids", [])
	if assigned.is_empty():
		return false
	for cid in assigned:
		if not (cid in completed):
			return false
	return true

static func rest_recover(shift: Dictionary, gain: int) -> Dictionary:
	var nxt := shift.duplicate(true)
	var max_e := maxi(10, int(nxt.get("max_energy", 100)))
	nxt["energy"] = clampi(int(nxt.get("energy", 0)) + maxi(0, gain), 0, max_e)
	return nxt

static func get_checklist_items(shift: Dictionary, locale: String = "id") -> Array:
	var assigned: Array = shift.get("assigned_ids", [])
	var completed: Array = shift.get("completed_ids", [])
	var out: Array = []
	for raw_cid in assigned:
		var cid := String(raw_cid)
		if not CHORES.has(cid):
			continue
		var cfg: Dictionary = CHORES[cid]
		var lbl := String(cfg["label_en"] if locale == "en" else cfg["label_id"])
		out.append({"id": cid, "label": lbl, "done": cid in completed})
	return out
