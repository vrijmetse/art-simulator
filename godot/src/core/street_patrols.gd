class_name ArtStreetPatrols
extends RefCounted

const PATROL_IDS := ["pak_rt", "kurir_paket", "anak_sekolah", "bang_ojek"]
const PLAYER_PAUSE_DIST := 1.8
const WALK_MARGIN_X := 0.35
const WALK_MARGIN_Z := 0.20
const PORTAL_SAFE_MARGIN := 0.85


static func create_runtime_npcs(street_npcs: Array) -> Array:
	var out: Array = []
	var idx := 0
	for item in street_npcs:
		if not (item is Dictionary):
			continue
		var d: Dictionary = (item as Dictionary).duplicate(true)
		var npc_id := String(d.get("id", ""))
		var is_patrol := bool(d.get("patrol", false)) or (npc_id in PATROL_IDS)
		d["patrol"] = is_patrol
		if not d.has("pos") or not (d["pos"] is Vector3):
			d["pos"] = Vector3.ZERO
		if not d.has("dir") or int(d["dir"]) == 0:
			d["dir"] = 1 if (idx % 2 == 0) else -1
		if not d.has("speed"):
			d["speed"] = 0.85 + float(idx % 3) * 0.15
		d["is_walking"] = false
		d["anim"] = String(d.get("anim", "Idle"))
		if not d.has("node"):
			d["node"] = null
		if not d.has("anim_player"):
			d["anim_player"] = null
		out.append(d)
		idx += 1
	return out


static func step_patrols(runtime_npcs: Array, street_cfg: Dictionary, player_pos: Vector3, delta: float, is_raining: bool = false) -> void:
	if delta <= 0.0:
		return

	var wrect: Rect2 = street_cfg.get("walk_rect", Rect2(-5.2, 0.35, 10.4, 1.70))
	var min_x := wrect.position.x + WALK_MARGIN_X
	var max_x := wrect.position.x + wrect.size.x - WALK_MARGIN_X
	var min_z := wrect.position.y + WALK_MARGIN_Z
	var max_z := wrect.position.y + wrect.size.y - WALK_MARGIN_Z

	var safe_min_x := min_x
	var safe_max_x := max_x
	if street_cfg.has("portal_home") and street_cfg["portal_home"] is Vector3:
		var ph: Vector3 = street_cfg["portal_home"]
		safe_min_x = maxf(safe_min_x, ph.x + PORTAL_SAFE_MARGIN)
	if street_cfg.has("portal_work") and street_cfg["portal_work"] is Vector3:
		var pw: Vector3 = street_cfg["portal_work"]
		safe_max_x = minf(safe_max_x, pw.x - PORTAL_SAFE_MARGIN)
	if safe_min_x >= safe_max_x:
		safe_min_x = min_x
		safe_max_x = max_x

	for item in runtime_npcs:
		if not (item is Dictionary):
			continue
		var npc: Dictionary = item
		if not bool(npc.get("patrol", false)):
			continue

		var pos: Vector3 = npc.get("pos", Vector3.ZERO)
		pos.z = clampf(pos.z, min_z, max_z)

		var dist := Vector2(pos.x - player_pos.x, pos.z - player_pos.z).length()
		var dir := int(npc.get("dir", 1))
		if dir == 0:
			dir = 1

		var walking := dist >= PLAYER_PAUSE_DIST
		if walking:
			var speed := float(npc.get("speed", 0.95))
			pos.x += float(dir) * speed * delta
			if pos.x <= safe_min_x:
				pos.x = safe_min_x
				dir = 1
			elif pos.x >= safe_max_x:
				pos.x = safe_max_x
				dir = -1
			npc["dir"] = dir
			npc["pos"] = pos
			npc["is_walking"] = true
			npc["anim"] = "Walk"
		else:
			pos.x = clampf(pos.x, safe_min_x, safe_max_x)
			npc["pos"] = pos
			npc["is_walking"] = false
			npc["anim"] = "Idle"

		var node_val: Variant = npc.get("node", null)
		if node_val is Node3D and is_instance_valid(node_val):
			var node3d := node_val as Node3D
			node3d.position = pos
			if walking:
				node3d.rotation.y = PI * 0.5 if dir > 0 else -PI * 0.5
			sync_player_umbrella(node3d, is_raining)

		var ap_val: Variant = npc.get("anim_player", null)
		if ap_val is AnimationPlayer and is_instance_valid(ap_val):
			var ap := ap_val as AnimationPlayer
			_play_matching_anim(ap, "walk" if walking else "idle")


static func _play_matching_anim(ap: AnimationPlayer, target_lower: String) -> void:
	var list := ap.get_animation_list()
	for anim_name in list:
		var al := String(anim_name).to_lower()
		if al == target_lower or al.begins_with(target_lower + "_"):
			if ap.current_animation != anim_name:
				ap.play(anim_name)
			return
	for anim_name in list:
		if target_lower in String(anim_name).to_lower():
			if ap.current_animation != anim_name:
				ap.play(anim_name)
			return


static func sync_player_umbrella(player_node: Node3D, should_show: bool) -> Node3D:
	if player_node == null or not is_instance_valid(player_node):
		return null

	var umbrella := player_node.get_node_or_null("UmbrellaProp") as Node3D
	if not should_show:
		if umbrella != null:
			umbrella.visible = false
		return umbrella

	if umbrella == null:
		umbrella = Node3D.new()
		umbrella.name = "UmbrellaProp"
		umbrella.position = Vector3(0.24, 1.58, 0.05)
		umbrella.rotation_degrees = Vector3(-8.0, 0.0, -10.0)

		var handle := MeshInstance3D.new()
		handle.name = "Handle"
		var handle_mesh := CylinderMesh.new()
		handle_mesh.top_radius = 0.014
		handle_mesh.bottom_radius = 0.014
		handle_mesh.height = 0.78
		handle_mesh.radial_segments = 8
		handle.mesh = handle_mesh
		handle.position = Vector3(0.0, -0.35, 0.0)
		var handle_mat := StandardMaterial3D.new()
		handle_mat.albedo_color = Color("#5C3A21")
		handle_mat.roughness = 0.7
		handle.material_override = handle_mat
		umbrella.add_child(handle)

		var canopy := MeshInstance3D.new()
		canopy.name = "Canopy"
		var canopy_mesh := CylinderMesh.new()
		canopy_mesh.top_radius = 0.04
		canopy_mesh.bottom_radius = 0.54
		canopy_mesh.height = 0.16
		canopy_mesh.radial_segments = 12
		canopy.mesh = canopy_mesh
		canopy.position = Vector3(0.0, 0.08, 0.0)
		var canopy_mat := StandardMaterial3D.new()
		canopy_mat.albedo_color = Color("#2A9D8F")
		canopy_mat.roughness = 0.55
		canopy_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		canopy.material_override = canopy_mat
		umbrella.add_child(canopy)

		var tip := MeshInstance3D.new()
		tip.name = "Tip"
		var tip_mesh := CylinderMesh.new()
		tip_mesh.top_radius = 0.006
		tip_mesh.bottom_radius = 0.02
		tip_mesh.height = 0.07
		tip_mesh.radial_segments = 8
		tip.mesh = tip_mesh
		tip.position = Vector3(0.0, 0.19, 0.0)
		tip.material_override = handle_mat
		umbrella.add_child(tip)

		player_node.add_child(umbrella)

	umbrella.visible = true
	return umbrella


static func _make_box_part(part_name: String, size: Vector3, pos: Vector3, color_hex: String, roughness: float = 0.65) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color_hex)
	mat.roughness = roughness
	mi.material_override = mat
	return mi


static func _make_cyl_part(part_name: String, top_r: float, bot_r: float, h: float, pos: Vector3, color_hex: String, roughness: float = 0.65) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bot_r
	mesh.height = h
	mesh.radial_segments = 8
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color_hex)
	mat.roughness = roughness
	mi.material_override = mat
	return mi


static func sync_chore_tool(player_node: Node3D, tool_id: String) -> Node3D:
	if player_node == null or not is_instance_valid(player_node):
		return null

	var clean_id := tool_id.strip_edges().to_lower()
	var prop := player_node.get_node_or_null("ChoreToolProp") as Node3D
	if clean_id.is_empty():
		if prop != null:
			prop.visible = false
		return prop

	if prop == null:
		prop = Node3D.new()
		prop.name = "ChoreToolProp"
		prop.position = Vector3(0.28, 0.92, 0.14)
		player_node.add_child(prop)

	if String(prop.get_meta("tool_id", "")) != clean_id:
		for child in prop.get_children():
			prop.remove_child(child)
			child.queue_free()
		prop.set_meta("tool_id", clean_id)
		prop.rotation_degrees = Vector3.ZERO

		match clean_id:
			"broom":
				prop.rotation_degrees = Vector3(18.0, 0.0, -8.0)
				prop.add_child(_make_cyl_part("Handle", 0.015, 0.015, 0.92, Vector3(0.0, 0.05, 0.0), "#8D5B32"))
				prop.add_child(_make_box_part("Head", Vector3(0.24, 0.10, 0.06), Vector3(0.0, -0.44, 0.0), "#D4A359", 0.85))
			"duster":
				prop.rotation_degrees = Vector3(25.0, 0.0, 0.0)
				prop.add_child(_make_cyl_part("Handle", 0.012, 0.012, 0.36, Vector3(0.0, 0.0, 0.0), "#6D4C3D"))
				prop.add_child(_make_cyl_part("Plume", 0.075, 0.045, 0.24, Vector3(0.0, 0.26, 0.0), "#E76F51", 0.9))
			"sponge":
				prop.add_child(_make_box_part("Pad", Vector3(0.14, 0.055, 0.09), Vector3(0.0, 0.0, 0.04), "#F4D35E", 0.85))
				prop.add_child(_make_box_part("Scrub", Vector3(0.14, 0.02, 0.09), Vector3(0.0, -0.035, 0.04), "#2A9D8F", 0.95))
			"spatula":
				prop.rotation_degrees = Vector3(22.0, 0.0, 0.0)
				prop.add_child(_make_cyl_part("Handle", 0.014, 0.014, 0.24, Vector3(0.0, -0.04, 0.0), "#3D2B1F"))
				prop.add_child(_make_box_part("Blade", Vector3(0.09, 0.13, 0.012), Vector3(0.0, 0.14, 0.0), "#B8C0C8", 0.3))
			"iron":
				prop.add_child(_make_box_part("Sole", Vector3(0.13, 0.035, 0.22), Vector3(0.0, -0.02, 0.06), "#9AA5B1", 0.25))
				prop.add_child(_make_box_part("Body", Vector3(0.10, 0.06, 0.14), Vector3(0.0, 0.025, 0.04), "#E63946", 0.45))
			"watering_can":
				prop.add_child(_make_cyl_part("Body", 0.095, 0.105, 0.19, Vector3(0.0, -0.04, 0.05), "#457B9D", 0.45))
				var spout := _make_cyl_part("Spout", 0.014, 0.022, 0.18, Vector3(0.0, 0.03, 0.16), "#457B9D", 0.45)
				spout.rotation_degrees = Vector3(55.0, 0.0, 0.0)
				prop.add_child(spout)
			_:
				prop.add_child(_make_box_part("GenericTool", Vector3(0.08, 0.14, 0.08), Vector3.ZERO, "#A8DADC"))

	prop.visible = true
	return prop
