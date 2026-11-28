class_name ArtJemuranEvent
extends RefCounted

const BONUS_RP := 15000
const BONUS_XP := 15
const DEFAULT_DURATION_S := 15.0

const STAGE_JEMURAN_POS := {
	"kampung": Vector3(-1.85, 0.0, 0.0),
	"perumahan_36": Vector3(-2.45, 0.0, 0.05),
	"perumahan_45": Vector3(-2.45, 0.0, 0.05),
	"cluster_elite": Vector3(0.15, 0.0, 2.05),
}

static func should_trigger(tier_id: String, elapsed_s: float, already_triggered: bool, completed_count: int, total_count: int) -> bool:
	if already_triggered or tier_id == "kamar_kos":
		return false
	if not STAGE_JEMURAN_POS.has(tier_id):
		return false
	if elapsed_s < 16.0 or completed_count < 1:
		return false
	if total_count > 0 and completed_count >= total_count:
		return false
	return true

static func get_stage_pos(tier_id: String) -> Vector3:
	return STAGE_JEMURAN_POS.get(tier_id, Vector3(-1.85, 0.0, 0.0))

static func create_state(pos: Vector3) -> Dictionary:
	return {
		"active": true,
		"remaining_s": DEFAULT_DURATION_S,
		"pos": pos,
		"rescued": false,
		"failed": false,
	}

static func tick_state(state: Dictionary, delta: float) -> Dictionary:
	if not bool(state.get("active", false)):
		return state
	var nxt := state.duplicate(true)
	var rem := maxf(0.0, float(nxt.get("remaining_s", 0.0)) - maxf(0.0, delta))
	nxt["remaining_s"] = rem
	if rem <= 0.0:
		nxt["active"] = false
		nxt["failed"] = true
	return nxt

static func rescue(state: Dictionary) -> Dictionary:
	if not bool(state.get("active", false)) or bool(state.get("rescued", false)) or bool(state.get("failed", false)):
		return {"ok": false, "bonus_rp": 0, "xp": 0, "mood_bonus": 0, "trust_bonus": 0, "state": state}
	var nxt := state.duplicate(true)
	nxt["active"] = false
	nxt["rescued"] = true
	return {
		"ok": true,
		"bonus_rp": BONUS_RP,
		"xp": BONUS_XP,
		"mood_bonus": 8,
		"trust_bonus": 6,
		"state": nxt,
	}
