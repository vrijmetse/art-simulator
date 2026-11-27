class_name ArtAtmosphere
extends RefCounted

const AC_NODES := ["IndoorAC", "IndoorACVent"]
const FAN_NODES := [
	"FanBase", "FanPole", "FanMotorCowl", "FanGuardRingFront", "FanGuardRingBack",
	"FanSpoke_0", "FanSpoke_1", "FanSpoke_2", "FanSpoke_3", "FanHubBadge",
	"FanBtn_0", "FanBtn_1", "FanBtn_2", "FanBlade_0", "FanBlade_1", "FanBlade_2", "FanBlade_3",
	"Cylinder_006", "Cylinder_007", "Sphere", "Torus_001",
]
const RICE_COOKER_NODES := [
	"RiceCookerStand", "MagicComBody", "MagicComLid", "MagicComVent", "MagicComHandle", "MagicComLED",
	"Cylinder_008", "Cylinder_009",
]

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
	var sun_col := Color(1.0, 0.94, 0.80)
	var sun_energy := 1.00
	var bounce_col := Color(0.92, 0.82, 0.68)
	var bounce_energy := 0.22
	var amb_col := Color(0.76, 0.82, 0.92)
	var amb_energy := 0.28
	var adj_sat := 1.20
	var adj_con := 1.12
	var sky_top := Color(0.18, 0.56, 0.94)

	match phase:
		"pagi":
			sun_col = Color(1.0, 0.88, 0.68)
			sun_energy = 0.98
			bounce_col = Color(0.84, 0.78, 0.70)
			bounce_energy = 0.20
			amb_col = Color(0.46, 0.58, 0.84)
			amb_energy = 0.24
			sky_top = Color(0.18, 0.52, 0.90)
		"siang":
			sun_col = Color(1.0, 0.94, 0.82)
			sun_energy = 1.04
			bounce_col = Color(0.86, 0.82, 0.76)
			bounce_energy = 0.20
			amb_col = Color(0.50, 0.66, 0.90)
			amb_energy = 0.26
			sky_top = Color(0.14, 0.54, 0.96)
		"sore":
			sun_col = Color(1.0, 0.64, 0.36)
			sun_energy = 0.90
			bounce_col = Color(0.78, 0.56, 0.48)
			bounce_energy = 0.18
			amb_col = Color(0.42, 0.48, 0.74)
			amb_energy = 0.24
			adj_sat = 1.18
			adj_con = 1.14
			sky_top = Color(0.20, 0.32, 0.68)
		"malam":
			sun_col = Color(0.44, 0.56, 0.90)
			sun_energy = 0.44
			bounce_col = Color(0.28, 0.38, 0.64)
			bounce_energy = 0.16
			amb_col = Color(0.24, 0.30, 0.52)
			amb_energy = 0.24
			adj_sat = 1.08
			adj_con = 1.08
			sky_top = Color(0.08, 0.14, 0.32)

	if weather == "hujan":
		sun_energy *= 0.68
		bounce_energy *= 0.82
		amb_energy *= 0.86
		adj_sat = 1.06
		adj_con = 1.08
		sun_col = sun_col.lerp(Color(0.62, 0.72, 0.86), 0.42)
		amb_col = amb_col.lerp(Color(0.54, 0.64, 0.78), 0.42)
		sky_top = sky_top.lerp(Color(0.36, 0.46, 0.58), 0.55)

	if sun != null:
		sun.light_color = sun_col
		sun.light_energy = sun_energy
	if bounce != null:
		bounce.light_color = bounce_col
		bounce.light_energy = bounce_energy
	if env != null:
		env.ambient_light_color = amb_col
		env.ambient_light_energy = amb_energy
		env.adjustment_enabled = true
		env.adjustment_brightness = 1.0
		env.adjustment_contrast = adj_con
		env.adjustment_saturation = adj_sat
		if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
			var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
			sky_mat.sky_top_color = sky_top
			sky_mat.sky_horizon_color = sun_col.lerp(Color(0.86, 0.88, 0.92), 0.30)

static func get_room_lights_config(phase: String) -> Array:
	var warm := 0.48
	var beam := 0.56
	if phase == "sore":
		warm = 0.82
		beam = 0.88
	elif phase == "malam":
		warm = 1.25
		beam = 0.32
	return [
		{"name": "WarmBedsideOmni", "pos": Vector3(-0.60, 0.92, -1.90), "color": Color(1.0, 0.66, 0.28), "energy": warm, "range": 4.8},
		{"name": "WarmWindowOmni", "pos": Vector3(0.35, 1.55, -1.75), "color": Color(1.0, 0.78, 0.44), "energy": beam, "range": 4.4},
	]

static func get_street_lights_config(phase: String) -> Array:
	var e := 0.35
	if phase == "sore":
		e = 0.95
	elif phase == "malam":
		e = 1.45
	return [
		{"name": "StreetLampL", "pos": Vector3(-3.45, 1.85, -0.55), "color": Color(1.0, 0.70, 0.30), "energy": e, "range": 5.2},
		{"name": "StreetLampC", "pos": Vector3(0.0, 1.85, -0.55), "color": Color(1.0, 0.70, 0.30), "energy": e, "range": 5.2},
		{"name": "StreetLampR", "pos": Vector3(3.45, 1.85, -0.55), "color": Color(1.0, 0.70, 0.30), "energy": e, "range": 5.2},
	]

static func sync_stage_lights(stage_root: Node, world_mode: String, phase: String) -> void:
	if stage_root == null:
		return
	var holder := stage_root.find_child("_WarmStageLights", false, false)
	if holder == null:
		holder = Node3D.new()
		holder.name = "_WarmStageLights"
		stage_root.add_child(holder)
	for c in holder.get_children():
		c.queue_free()
	var cfgs: Array = []
	if world_mode == "home" or world_mode == "shift":
		cfgs = get_room_lights_config(phase)
	elif world_mode == "street":
		cfgs = get_street_lights_config(phase)
	for cfg in cfgs:
		var omni := OmniLight3D.new()
		omni.name = String(cfg["name"])
		omni.position = cfg["pos"]
		omni.light_color = cfg["color"]
		omni.light_energy = float(cfg["energy"])
		omni.omni_range = float(cfg["range"])
		omni.omni_attenuation = 1.35
		omni.shadow_enabled = false
		holder.add_child(omni)

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
