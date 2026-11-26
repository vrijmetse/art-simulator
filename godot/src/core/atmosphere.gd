class_name ArtAtmosphere
extends RefCounted

const AC_NODES := ["IndoorAC", "IndoorACVent"]
const FAN_NODES := ["FanBlade_0", "FanBlade_1", "FanBlade_2", "FanBlade_3", "Cylinder_006", "Cylinder_007", "Sphere", "Torus_001"]
const RICE_COOKER_NODES := ["RiceCookerStand", "Cylinder_008", "Cylinder_009"]

static func get_phase(_world_mode: String, _day: int, shift_elapsed_s: float) -> String:
	var t := maxf(0.0, shift_elapsed_s)
	if t < 45.0:
		return "pagi"
	if t < 110.0:
		return "siang"
	if t < 160.0:
		return "sore"
	return "malam"

static func get_weather(day: int, weather_fx: bool) -> String:
	if not weather_fx:
		return "cerah"
	return "hujan" if posmod(maxi(1, day), 3) == 0 else "cerah"

static func apply_lighting(sun: DirectionalLight3D, bounce: DirectionalLight3D, env: Environment, phase: String, weather: String) -> void:
	var sun_col := Color(1.0, 0.96, 0.88)
	var sun_energy := 1.05
	var bounce_col := Color(0.75, 0.85, 1.0)
	var bounce_energy := 0.35
	var amb_col := Color(0.85, 0.88, 0.95)
	var amb_energy := 0.45

	match phase:
		"pagi":
			sun_col = Color(1.0, 0.93, 0.82)
			sun_energy = 0.95
			bounce_col = Color(0.8, 0.88, 1.0)
			bounce_energy = 0.35
			amb_col = Color(0.88, 0.9, 0.95)
			amb_energy = 0.45
		"siang":
			sun_col = Color(1.0, 0.98, 0.94)
			sun_energy = 1.2
			bounce_col = Color(0.82, 0.9, 1.0)
			bounce_energy = 0.4
			amb_col = Color(0.92, 0.94, 0.98)
			amb_energy = 0.5
		"sore":
			sun_col = Color(1.0, 0.72, 0.48)
			sun_energy = 0.85
			bounce_col = Color(0.9, 0.68, 0.58)
			bounce_energy = 0.32
			amb_col = Color(0.85, 0.72, 0.68)
			amb_energy = 0.4
		"malam":
			sun_col = Color(0.52, 0.62, 0.85)
			sun_energy = 0.38
			bounce_col = Color(0.35, 0.45, 0.7)
			bounce_energy = 0.25
			amb_col = Color(0.32, 0.38, 0.55)
			amb_energy = 0.32

	if weather == "hujan":
		sun_energy *= 0.65
		bounce_energy *= 0.8
		amb_energy *= 0.8
		sun_col = sun_col.lerp(Color(0.68, 0.75, 0.85), 0.45)
		amb_col = amb_col.lerp(Color(0.6, 0.68, 0.78), 0.45)

	if sun != null:
		sun.light_color = sun_col
		sun.light_energy = sun_energy
	if bounce != null:
		bounce.light_color = bounce_col
		bounce.light_energy = bounce_energy
	if env != null:
		env.ambient_light_color = amb_col
		env.ambient_light_energy = amb_energy
		if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
			var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
			sky_mat.sky_top_color = amb_col.lerp(Color(0.25, 0.48, 0.82), 0.5)
			sky_mat.sky_horizon_color = sun_col.lerp(Color(0.75, 0.82, 0.9), 0.4)

static func _set_nodes_visible(stage_root: Node, names: Array, is_visible: bool) -> void:
	for n_name in names:
		var node := stage_root.find_child(String(n_name), true, false)
		if node is Node3D:
			(node as Node3D).visible = is_visible

static func _tint_bed_mesh(stage_root: Node, node_name: String, upgraded: bool, tint_color: Color) -> void:
	var node := stage_root.find_child(node_name, true, false)
	if not (node is MeshInstance3D):
		return
	var mesh_inst := node as MeshInstance3D
	var mat := mesh_inst.get_active_material(0)
	if mat is StandardMaterial3D:
		var dup_mat := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		if upgraded:
			dup_mat.albedo_color = tint_color
		mesh_inst.set_surface_override_material(0, dup_mat)

static func _ensure_rak_sepatu(stage_root: Node, is_visible: bool) -> void:
	var existing := stage_root.find_child("RakSepatu", true, false)
	if existing is Node3D:
		(existing as Node3D).visible = is_visible
		return
	if not is_visible:
		return
	var rack := Node3D.new()
	rack.name = "RakSepatu"
	rack.position = Vector3(-0.65, 0.0, -0.85)
	var shelf_mat := StandardMaterial3D.new()
	shelf_mat.albedo_color = Color(0.42, 0.28, 0.16)
	for i in range(2):
		var shelf := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.48, 0.03, 0.24)
		shelf.mesh = box
		shelf.material_override = shelf_mat
		shelf.position = Vector3(0.0, 0.08 + float(i) * 0.18, 0.0)
		rack.add_child(shelf)
	stage_root.add_child(rack)

static func apply_kos_upgrades_visual(stage_root: Node, owned_upgrades: Array) -> void:
	if stage_root == null:
		return
	_set_nodes_visible(stage_root, AC_NODES, "ac_hemat" in owned_upgrades)
	_set_nodes_visible(stage_root, FAN_NODES, "kipas_angin" in owned_upgrades)
	_set_nodes_visible(stage_root, RICE_COOKER_NODES, "magic_com_pro" in owned_upgrades)
	var has_kasur := "kasur_empuk" in owned_upgrades
	_tint_bed_mesh(stage_root, "cover", has_kasur, Color(0.82, 0.45, 0.52))
	_tint_bed_mesh(stage_root, "pillow", has_kasur, Color(0.96, 0.92, 0.86))
	_ensure_rak_sepatu(stage_root, "rak_sepatu" in owned_upgrades)
