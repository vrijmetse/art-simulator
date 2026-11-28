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

static func should_show_virtual_joystick(viewport_size: Vector2, is_touch: bool, is_mobile_os: bool = false) -> bool:
	if is_mobile_os:
		return true
	if viewport_size.x <= 960.0:
		return true
	if is_touch and viewport_size.x <= 1024.0:
		return true
	return false

static func compute_hud_safe_margins(safe_rect: Rect2, win_size: Vector2, vp_size: Vector2) -> Dictionary:
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0 or win_size.x <= 0.0 or win_size.y <= 0.0 or vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	var sx := vp_size.x / maxf(1.0, win_size.x)
	var sy := vp_size.y / maxf(1.0, win_size.y)
	var pad_left := clampf(safe_rect.position.x * sx, 0.0, 48.0)
	var pad_top := clampf(safe_rect.position.y * sy, 0.0, 48.0)
	var pad_right := clampf((win_size.x - safe_rect.end.x) * sx, 0.0, 48.0)
	var pad_bottom := clampf((win_size.y - safe_rect.end.y) * sy, 0.0, 48.0)
	return {"left": pad_left, "top": pad_top, "right": pad_right, "bottom": pad_bottom}

static func compute_top_center_bounds(vp_width: float, tl_width: float, tr_width: float, safe_left: float = 0.0, safe_right: float = 0.0) -> Dictionary:
	var left_bound := 14.0 + safe_left + tl_width + 12.0
	var right_bound := 16.0 + safe_right + tr_width + 12.0
	if left_bound + right_bound > vp_width - 180.0:
		left_bound = clampf(vp_width * 0.25, 160.0, left_bound)
		right_bound = clampf(vp_width * 0.25, 160.0, right_bound)
	return {
		"offset_left": left_bound,
		"offset_right": -right_bound,
		"max_banner_w": maxf(180.0, vp_width - left_bound - right_bound),
	}

static func clamp_world_prompt_pos(scr_pos: Vector2, prompt_size: Vector2, vp_size: Vector2, margins: Dictionary = {}) -> Vector2:
	var pad_l := float(margins.get("left", 0.0))
	var pad_t := float(margins.get("top", 0.0))
	var pad_r := float(margins.get("right", 0.0))
	var pad_b := float(margins.get("bottom", 0.0))
	var px := clampf(scr_pos.x - prompt_size.x * 0.5, 10.0 + pad_l, maxf(10.0 + pad_l, vp_size.x - prompt_size.x - 10.0 - pad_r))
	var top_floor := 118.0 + pad_t if (px < 330.0 + pad_l or px + prompt_size.x > vp_size.x - 390.0 - pad_r) else 74.0 + pad_t
	var bot_ceil := maxf(top_floor, vp_size.y - prompt_size.y - 96.0 - pad_b)
	var py := clampf(scr_pos.y - prompt_size.y - 18.0, top_floor, bot_ceil)
	return Vector2(px, py)

static func should_show_keyboard_hints(viewport_size: Vector2, is_touch: bool, is_mobile_os: bool = false) -> bool:
	return not should_show_virtual_joystick(viewport_size, is_touch, is_mobile_os)

static func format_action_prompt(action_label: String, locale: String = "id", show_key_hint: bool = true) -> String:
	if show_key_hint:
		return "[E] %s" % action_label
	return ("%s: %s" % ["Tap" if locale == "en" else "Ketuk", action_label])

static func format_tasks_hint(locale: String = "id", show_key_hint: bool = true) -> String:
	if show_key_hint:
		return "How: walk to green ring & press [E]" if locale == "en" else "Cara: dekati lingkaran hijau & tekan [E]"
	return "How: walk to green ring & tap action" if locale == "en" else "Cara: dekati lingkaran hijau lalu ketuk aksi"

static func get_weather(day: int, weather_fx: bool) -> String:
	if not weather_fx:
		return "cerah"
	return "hujan" if posmod(maxi(1, day), 3) == 0 else "cerah"

static func apply_lighting(sun: DirectionalLight3D, bounce: DirectionalLight3D, env: Environment, phase: String, weather: String, world_mode: String = "home") -> void:
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
			sun_col = Color(1.0, 0.87, 0.66)
			sun_energy = 1.06
			bounce_col = Color(1.0, 0.84, 0.64)
			bounce_energy = 0.34
			amb_col = Color(0.74, 0.76, 0.84)
			amb_energy = 0.42
			sky_top = Color(0.22, 0.56, 0.92)
		"siang":
			sun_col = Color(1.0, 0.92, 0.76)
			sun_energy = 1.10
			bounce_col = Color(0.98, 0.86, 0.70)
			bounce_energy = 0.32
			amb_col = Color(0.76, 0.80, 0.88)
			amb_energy = 0.42
			sky_top = Color(0.18, 0.56, 0.96)
		"sore":
			sun_col = Color(1.0, 0.68, 0.40)
			sun_energy = 0.94
			bounce_col = Color(0.90, 0.62, 0.48)
			bounce_energy = 0.28
			amb_col = Color(0.60, 0.58, 0.74)
			amb_energy = 0.36
			adj_sat = 1.18
			adj_con = 1.12
			sky_top = Color(0.22, 0.34, 0.68)
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
			var g_horizon := Color(0.56, 0.72, 0.86)
			var g_bottom := Color(0.30, 0.44, 0.26)
			if phase == "sore":
				g_horizon = Color(0.84, 0.64, 0.50)
				g_bottom = Color(0.32, 0.30, 0.24)
			elif phase == "malam":
				g_horizon = Color(0.14, 0.20, 0.34)
				g_bottom = Color(0.08, 0.11, 0.18)
			if weather == "hujan":
				g_horizon = g_horizon.lerp(Color(0.52, 0.60, 0.68), 0.55)
				g_bottom = g_bottom.lerp(Color(0.28, 0.36, 0.34), 0.45)
			if world_mode == "street":
				sky_mat.ground_horizon_color = g_horizon
				sky_mat.ground_bottom_color = g_bottom
			else:
				sky_mat.ground_horizon_color = g_horizon.lerp(Color(0.72, 0.78, 0.84), 0.22)
				sky_mat.ground_bottom_color = g_bottom.lerp(Color(0.24, 0.34, 0.22), 0.25)

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
	var cfgs: Array = []
	if world_mode == "home" or world_mode == "shift":
		cfgs = get_room_lights_config(phase)
	elif world_mode == "street":
		cfgs = get_street_lights_config(phase)
	var active_names := {}
	for cfg in cfgs:
		var cname := String(cfg["name"])
		active_names[cname] = true
		var omni := holder.get_node_or_null(cname) as OmniLight3D
		if omni == null:
			omni = OmniLight3D.new()
			omni.name = cname
			holder.add_child(omni)
		omni.visible = true
		omni.position = cfg["pos"]
		omni.light_color = cfg["color"]
		omni.light_energy = float(cfg["energy"])
		omni.omni_range = float(cfg["range"])
		omni.omni_attenuation = 1.35
		var want_shadow := (cname == "WarmBedsideOmni" and (world_mode == "home" or world_mode == "shift")) or (cname == "StreetLampC" and world_mode == "street" and phase == "malam")
		omni.shadow_enabled = want_shadow
		if want_shadow:
			omni.shadow_bias = 0.04
			omni.shadow_normal_bias = 1.25
	for c in holder.get_children():
		if not active_names.has(c.name) and c is Node3D:
			(c as Node3D).visible = false

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
