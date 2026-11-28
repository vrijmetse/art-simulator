class_name ArtKosDecor
extends RefCounted

const SLOTS := [
	Vector3(1.15, 0.0, -1.15),
	Vector3(-1.45, 0.0, 0.25),
	Vector3(0.05, 0.0, -1.25),
	Vector3(1.45, 0.0, 0.05),
]

const DECOR_ITEMS := {
	"decor_monstera": {
		"id": "decor_monstera",
		"cost_rp": 45000,
		"default_slot": 0,
		"label_id": "Tanaman Monstera Keramik",
		"label_en": "Ceramic Monstera Plant",
	},
	"decor_karpet": {
		"id": "decor_karpet",
		"cost_rp": 65000,
		"default_slot": 1,
		"label_id": "Karpet Anyaman Hangat",
		"label_en": "Warm Woven Floor Rug",
	},
	"decor_lampu_tidur": {
		"id": "decor_lampu_tidur",
		"cost_rp": 80000,
		"default_slot": 2,
		"label_id": "Lampu Lentera Rotan",
		"label_en": "Rattan Bedside Lantern",
	},
	"decor_kucing": {
		"id": "decor_kucing",
		"cost_rp": 120000,
		"default_slot": 3,
		"label_id": "Kucing Kos \"Mochi\"",
		"label_en": "\"Mochi\" the Kos Cat",
	},
}

static func get_slot_positions() -> Array:
	return SLOTS.duplicate()

static func buy_decor(save: Dictionary, decor_id: String) -> Dictionary:
	if not DECOR_ITEMS.has(decor_id):
		return {"ok": false, "reason": "unknown_decor", "save": save}
	var unlocked: Array = save.get("unlocked_decor", [])
	if decor_id in unlocked:
		return {"ok": false, "reason": "already_owned", "save": save}
	var item: Dictionary = DECOR_ITEMS[decor_id]
	var cost := int(item["cost_rp"])
	var bal := int(save.get("balance_rp", 0))
	if bal < cost:
		return {"ok": false, "reason": "insufficient_balance", "save": save}
	var nxt := save.duplicate(true)
	nxt["balance_rp"] = bal - cost
	var arr: Array = nxt.get("unlocked_decor", []).duplicate()
	arr.append(decor_id)
	nxt["unlocked_decor"] = arr
	var lay: Dictionary = nxt.get("kos_decor_layout", {}).duplicate(true)
	lay[decor_id] = {"slot": clampi(int(item["default_slot"]), 0, SLOTS.size() - 1), "rot_deg": 0}
	nxt["kos_decor_layout"] = lay
	nxt["xp"] = int(nxt.get("xp", 0)) + 15
	nxt["mood"] = clampi(int(nxt.get("mood", 65)) + 6, 0, 100)
	return {"ok": true, "cost_rp": cost, "save": nxt}

static func move_decor_next_slot(save: Dictionary, decor_id: String) -> Dictionary:
	var unlocked: Array = save.get("unlocked_decor", [])
	if not DECOR_ITEMS.has(decor_id) or not (decor_id in unlocked):
		return {"ok": false, "reason": "not_owned", "save": save}
	var nxt := save.duplicate(true)
	var lay: Dictionary = nxt.get("kos_decor_layout", {}).duplicate(true)
	var cur: Dictionary = lay.get(decor_id, {"slot": int(DECOR_ITEMS[decor_id]["default_slot"]), "rot_deg": 0}).duplicate(true)
	cur["slot"] = (int(cur.get("slot", 0)) + 1) % SLOTS.size()
	lay[decor_id] = cur
	nxt["kos_decor_layout"] = lay
	return {"ok": true, "save": nxt}

static func rotate_decor(save: Dictionary, decor_id: String) -> Dictionary:
	var unlocked: Array = save.get("unlocked_decor", [])
	if not DECOR_ITEMS.has(decor_id) or not (decor_id in unlocked):
		return {"ok": false, "reason": "not_owned", "save": save}
	var nxt := save.duplicate(true)
	var lay: Dictionary = nxt.get("kos_decor_layout", {}).duplicate(true)
	var cur: Dictionary = lay.get(decor_id, {"slot": int(DECOR_ITEMS[decor_id]["default_slot"]), "rot_deg": 0}).duplicate(true)
	cur["rot_deg"] = (int(cur.get("rot_deg", 0)) + 45) % 360
	lay[decor_id] = cur
	nxt["kos_decor_layout"] = lay
	return {"ok": true, "save": nxt}

static func _make_box_mesh(sz: Vector3, col: Color, pos: Vector3, emit: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = sz
	mi.mesh = bx
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.78
	if emit:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 0.9
	mi.material_override = mat
	return mi

static func spawn_decor_nodes(stage_root: Node, save: Dictionary) -> void:
	if stage_root == null:
		return
	var prev := stage_root.find_child("_KosDecorRoot", false, false)
	if prev != null:
		prev.free()
	var unlocked: Array = save.get("unlocked_decor", [])
	if unlocked.is_empty():
		return
	var root := Node3D.new()
	root.name = "_KosDecorRoot"
	var layout: Dictionary = save.get("kos_decor_layout", {})
	for raw_id in unlocked:
		var did := String(raw_id)
		if not DECOR_ITEMS.has(did):
			continue
		var entry: Dictionary = layout.get(did, {"slot": int(DECOR_ITEMS[did]["default_slot"]), "rot_deg": 0})
		var slot_idx := clampi(int(entry.get("slot", 0)), 0, SLOTS.size() - 1)
		var rot_deg := float(int(entry.get("rot_deg", 0)) % 360)
		var prop := Node3D.new()
		prop.name = "Decor_" + did
		prop.position = SLOTS[slot_idx]
		prop.rotation_degrees = Vector3(0.0, rot_deg, 0.0)
		match did:
			"decor_monstera":
				prop.add_child(_make_box_mesh(Vector3(0.24, 0.22, 0.24), Color(0.72, 0.38, 0.24), Vector3(0.0, 0.11, 0.0)))
				prop.add_child(_make_box_mesh(Vector3(0.32, 0.24, 0.18), Color(0.20, 0.56, 0.30), Vector3(0.0, 0.30, 0.0)))
				prop.add_child(_make_box_mesh(Vector3(0.18, 0.22, 0.32), Color(0.24, 0.62, 0.34), Vector3(0.0, 0.32, 0.0)))
			"decor_karpet":
				prop.add_child(_make_box_mesh(Vector3(0.86, 0.016, 0.58), Color(0.76, 0.42, 0.28), Vector3(0.0, 0.008, 0.0)))
				prop.add_child(_make_box_mesh(Vector3(0.68, 0.018, 0.42), Color(0.92, 0.78, 0.48), Vector3(0.0, 0.009, 0.0)))
			"decor_lampu_tidur":
				prop.add_child(_make_box_mesh(Vector3(0.18, 0.28, 0.18), Color(0.46, 0.30, 0.18), Vector3(0.0, 0.14, 0.0)))
				prop.add_child(_make_box_mesh(Vector3(0.22, 0.22, 0.22), Color(1.0, 0.80, 0.38), Vector3(0.0, 0.38, 0.0), true))
			"decor_kucing":
				prop.add_child(_make_box_mesh(Vector3(0.38, 0.06, 0.32), Color(0.86, 0.54, 0.34), Vector3(0.0, 0.03, 0.0)))
				prop.add_child(_make_box_mesh(Vector3(0.24, 0.14, 0.18), Color(0.95, 0.68, 0.36), Vector3(0.0, 0.12, 0.0)))
				prop.add_child(_make_box_mesh(Vector3(0.14, 0.12, 0.14), Color(0.97, 0.74, 0.44), Vector3(0.12, 0.18, 0.0)))
		root.add_child(prop)
	stage_root.add_child(root)
