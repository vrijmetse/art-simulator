class_name ArtChoreHotspot
extends Node3D

var chore_id := ""
var label_id := ""
var label_en := ""
var completed := false

var _ring_mesh: MeshInstance3D = null
var _mat: StandardMaterial3D = null
var _mess_nodes: Array[Node3D] = []
var _mess_popped := 0
var _pulse := 0.0

func setup(p_chore_id: String, p_label_id: String, p_label_en: String, pos: Vector3) -> void:
	chore_id = p_chore_id
	label_id = p_label_id
	label_en = p_label_en
	position = Vector3(pos.x, 0.03, pos.z)

	_ring_mesh = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.28
	disc.bottom_radius = 0.30
	disc.height = 0.004
	disc.radial_segments = 24
	_ring_mesh.mesh = disc
	_ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.95, 0.84, 0.48, 0.22)
	_mat.emission_enabled = true
	_mat.emission = Color(0.95, 0.84, 0.48)
	_mat.emission_energy_multiplier = 0.20
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mesh.material_override = _mat
	add_child(_ring_mesh)
	_spawn_mess_chunks()

func _spawn_mess_chunks() -> void:
	var offsets := [
		Vector3(-0.18, 0.0, -0.14),
		Vector3(0.16, 0.0, -0.10),
		Vector3(-0.10, 0.0, 0.16),
		Vector3(0.18, 0.0, 0.14),
	]
	var prop_y := 0.024
	var col := Color(0.68, 0.56, 0.42)
	var chunk_sz := Vector3(0.11, 0.022, 0.09)
	match chore_id:
		"make_bed":
			prop_y = 0.028
			col = Color(0.82, 0.68, 0.54)
			chunk_sz = Vector3(0.14, 0.036, 0.11)
		"wash_dishes":
			prop_y = 0.022
			col = Color(0.74, 0.88, 0.96)
			chunk_sz = Vector3(0.14, 0.014, 0.12)
		"cook_rice":
			prop_y = 0.024
			col = Color(0.76, 0.54, 0.30)
			chunk_sz = Vector3(0.10, 0.024, 0.09)
		"iron_laundry":
			prop_y = 0.030
			col = Color(0.45, 0.62, 0.78)
			chunk_sz = Vector3(0.15, 0.038, 0.12)
		"water_plants":
			prop_y = 0.022
			col = Color(0.58, 0.44, 0.26)
			chunk_sz = Vector3(0.10, 0.018, 0.09)
		_:
			prop_y = 0.020
			col = Color(0.62, 0.52, 0.38)
			chunk_sz = Vector3(0.12, 0.016, 0.09)

	var mess_mat := StandardMaterial3D.new()
	mess_mat.albedo_color = col
	mess_mat.roughness = 0.85

	for i in range(offsets.size()):
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = chunk_sz
		mi.mesh = bx
		mi.material_override = mess_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(offsets[i].x, prop_y, offsets[i].z)
		mi.rotation_degrees = Vector3(float((i % 2) * 8 - 4), float(i * 42 + 15), float(((i + 1) % 2) * 10 - 5))
		add_child(mi)
		_mess_nodes.append(mi)

func set_progress(ratio: float) -> void:
	if _mess_nodes.is_empty():
		return
	var target_popped := clampi(int(floor(clampf(ratio, 0.0, 1.0) * float(_mess_nodes.size()))), 0, _mess_nodes.size())
	while _mess_popped < target_popped:
		var m := _mess_nodes[_mess_popped]
		_mess_popped += 1
		if is_instance_valid(m) and m.visible:
			if is_inside_tree():
				var tw := create_tween()
				tw.tween_property(m, "scale", Vector3(0.01, 0.01, 0.01), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				tw.tween_callback(func():
					if is_instance_valid(m):
						m.visible = false
				)
			else:
				m.visible = false

func set_highlighted(near: bool) -> void:
	if completed or _mat == null:
		return
	if near:
		_mat.albedo_color = Color(0.98, 0.82, 0.32, 0.46)
		_mat.emission = Color(0.98, 0.82, 0.32)
		_mat.emission_energy_multiplier = 0.42
	else:
		_mat.albedo_color = Color(0.95, 0.84, 0.48, 0.20)
		_mat.emission = Color(0.95, 0.84, 0.48)
		_mat.emission_energy_multiplier = 0.18

func mark_completed() -> void:
	completed = true
	for m in _mess_nodes:
		if is_instance_valid(m):
			m.visible = false
	if not is_inside_tree() or _ring_mesh == null:
		visible = false
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_ring_mesh, "scale", Vector3(1.85, 1.0, 1.85), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _mat != null:
		tw.tween_property(_mat, "albedo_color:a", 0.0, 0.18)
	tw.chain().tween_callback(func():
		if is_instance_valid(self):
			visible = false
	)

func _process(delta: float) -> void:
	if completed or _ring_mesh == null:
		return
	_pulse += delta * 3.2
	var s := 1.0 + sin(_pulse) * 0.08
	_ring_mesh.scale = Vector3(s, 1.0, s)
