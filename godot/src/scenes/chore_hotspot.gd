class_name ArtChoreHotspot
extends Node3D

var chore_id := ""
var label_id := ""
var label_en := ""
var completed := false

var _ring_mesh: MeshInstance3D = null
var _mat: StandardMaterial3D = null
var _pulse := 0.0

func setup(p_chore_id: String, p_label_id: String, p_label_en: String, pos: Vector3) -> void:
	chore_id = p_chore_id
	label_id = p_label_id
	label_en = p_label_en
	position = Vector3(pos.x, 0.03, pos.z)

	_ring_mesh = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.36
	torus.rings = 18
	torus.ring_segments = 8
	_ring_mesh.mesh = torus

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.24, 0.78, 0.56, 0.92)
	_mat.emission_enabled = true
	_mat.emission = Color(0.24, 0.78, 0.56)
	_mat.emission_energy_multiplier = 0.85
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mesh.material_override = _mat
	add_child(_ring_mesh)

func set_highlighted(near: bool) -> void:
	if completed or _mat == null:
		return
	if near:
		_mat.albedo_color = Color(0.98, 0.78, 0.24, 0.98)
		_mat.emission = Color(0.98, 0.78, 0.24)
		_mat.emission_energy_multiplier = 1.35
	else:
		_mat.albedo_color = Color(0.24, 0.78, 0.56, 0.85)
		_mat.emission = Color(0.24, 0.78, 0.56)
		_mat.emission_energy_multiplier = 0.75

func mark_completed() -> void:
	completed = true
	visible = false

func _process(delta: float) -> void:
	if completed or _ring_mesh == null:
		return
	_pulse += delta * 3.2
	var s := 1.0 + sin(_pulse) * 0.08
	_ring_mesh.scale = Vector3(s, 1.0, s)
