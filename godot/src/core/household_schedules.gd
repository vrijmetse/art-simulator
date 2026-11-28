class_name ArtHouseholdSchedules
extends RefCounted

const StreetPatrols := preload("res://src/core/street_patrols.gd")
const NpcRoster := preload("res://src/core/npc_roster.gd")

const PLAYER_PAUSE_DIST := 1.65
const WALK_SPEED := 0.65

const WAYPOINT_PAIRS := {
	"ibu_melati": [Vector3(-1.45, 0.0, -0.15), Vector3(-0.65, 0.0, 1.35)],
	"ibu_tini": [Vector3(-0.20, 0.0, -0.88), Vector3(-0.30, 0.0, -0.15)],
	"pak_agus": [Vector3(1.75, 0.0, 0.45), Vector3(0.05, 0.0, -1.65)],
	"adik_bima": [Vector3(-0.35, 0.0, -1.48), Vector3(-1.95, 0.0, -0.15)],
	"ibu_sari": [Vector3(-1.35, 0.0, -0.05), Vector3(-2.35, 0.0, -1.45)],
	"pak_budi": [Vector3(-2.35, 0.0, 0.35), Vector3(-0.35, 0.0, 1.45)],
	"kakak_maya": [Vector3(0.45, 0.0, 1.45), Vector3(2.35, 0.0, 1.45)],
	"ibu_citra": [Vector3(-1.85, 0.0, -0.55), Vector3(-2.95, 0.0, 0.35)],
	"pak_hendra": [Vector3(1.15, 0.0, -1.45), Vector3(0.35, 0.0, -2.05)],
	"kakak_nadine": [Vector3(-0.20, 0.0, 0.10), Vector3(-1.20, 0.0, 1.15)],
	"mbak_rina": [Vector3(0.65, 0.0, -0.65), Vector3(1.15, 0.0, 0.45)],
}

static func create_runtime_shift_npcs(shift_npcs: Array, tier_id: String) -> Array:
	var bounds := NpcRoster.get_tier_bounds_and_chores(tier_id)
	var wrect: Rect2 = bounds.get("walk_rect", Rect2(-2.0, -1.8, 4.0, 3.5))
	var out: Array = []
	var idx := 0
	for raw in shift_npcs:
		if not (raw is Dictionary):
			continue
		var d: Dictionary = (raw as Dictionary).duplicate(true)
		var nid := String(d.get("id", ""))
		var start_pos: Vector3 = d.get("pos", Vector3.ZERO)
		var pair: Array = WAYPOINT_PAIRS.get(nid, [start_pos, start_pos])
		var wp0: Vector3 = pair[0]
		var wp1: Vector3 = pair[1]
		wp0.x = clampf(wp0.x, wrect.position.x, wrect.end.x)
		wp0.z = clampf(wp0.z, wrect.position.y, wrect.end.y)
		wp1.x = clampf(wp1.x, wrect.position.x, wrect.end.x)
		wp1.z = clampf(wp1.z, wrect.position.y, wrect.end.y)
		d["waypoints"] = [wp0, wp1]
		d["wp_idx"] = 1
		d["wait_s"] = 3.2 + float(idx % 3) * 1.6
		d["speed"] = WALK_SPEED
		d["is_walking"] = false
		if not d.has("node"):
			d["node"] = null
		if not d.has("anim_player"):
			d["anim_player"] = null
		out.append(d)
		idx += 1
	return out

static func step_shift_npcs(runtime_npcs: Array, player_pos: Vector3, delta: float, paused: bool = false) -> void:
	if delta <= 0.0:
		return
	for item in runtime_npcs:
		if not (item is Dictionary):
			continue
		var npc: Dictionary = item
		var wps: Array = npc.get("waypoints", [])
		if wps.size() < 2:
			continue
		var pos: Vector3 = npc.get("pos", Vector3.ZERO)
		var dist_p := Vector2(pos.x - player_pos.x, pos.z - player_pos.z).length()
		var walking := false

		if paused or dist_p < PLAYER_PAUSE_DIST:
			walking = false
		else:
			var w_wait := float(npc.get("wait_s", 0.0))
			if w_wait > 0.0:
				npc["wait_s"] = maxf(0.0, w_wait - delta)
			else:
				var wp_idx := int(npc.get("wp_idx", 1)) % wps.size()
				var target: Vector3 = wps[wp_idx]
				var diff := Vector2(target.x - pos.x, target.z - pos.z)
				var dlen := diff.length()
				if dlen <= 0.08:
					pos = target
					npc["pos"] = pos
					npc["wp_idx"] = (wp_idx + 1) % wps.size()
					npc["wait_s"] = 4.2
				else:
					var step_d := minf(dlen, float(npc.get("speed", WALK_SPEED)) * delta)
					var dir_v := diff / dlen
					pos.x += dir_v.x * step_d
					pos.z += dir_v.y * step_d
					npc["pos"] = pos
					npc["rot_y"] = atan2(dir_v.x, dir_v.y)
					walking = true

		npc["is_walking"] = walking
		npc["anim"] = "Walk" if walking else "Idle"

		var node_val: Variant = npc.get("node", null)
		if node_val is Node3D and is_instance_valid(node_val):
			var n3 := node_val as Node3D
			n3.position = pos
			if walking:
				n3.rotation.y = lerp_angle(n3.rotation.y, float(npc.get("rot_y", n3.rotation.y)), minf(1.0, delta * 8.0))
			elif dist_p < PLAYER_PAUSE_DIST and dist_p > 0.05:
				var to_p := atan2(player_pos.x - pos.x, player_pos.z - pos.z)
				n3.rotation.y = lerp_angle(n3.rotation.y, to_p, minf(1.0, delta * 6.0))

		var ap_val: Variant = npc.get("anim_player", null)
		if ap_val is AnimationPlayer and is_instance_valid(ap_val):
			StreetPatrols._play_matching_anim(ap_val as AnimationPlayer, "walk" if walking else "idle")
