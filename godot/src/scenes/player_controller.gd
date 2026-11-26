class_name ArtPlayerController
extends CharacterBody3D

signal arrived_at_target

@export var move_speed := 3.4

var walk_bounds := Rect2(-2.1, -2.0, 4.2, 4.0)
var joystick_input := Vector2.ZERO
var _tap_target := Vector3.ZERO
var _has_tap_target := false
var _busy_cleaning := false
var movement_locked := false
var _model_root: Node3D = null
var _anim_player: AnimationPlayer = null
var _current_anim := ""
var _equipped_outfit_id := ""
var _equipped_model_path := ""
var _equipped_color_hex := "#4E7D63"
var _equipped_skin_hex := "#B87A4B"

func _ready() -> void:
	floor_stop_on_slope = true

func set_walk_bounds(min_x: float, max_x: float, min_z: float, max_z: float) -> void:
	walk_bounds = Rect2(min_x, min_z, maxf(0.5, max_x - min_x), maxf(0.5, max_z - min_z))
	position.x = clampf(position.x, walk_bounds.position.x, walk_bounds.end.x)
	position.z = clampf(position.z, walk_bounds.position.y, walk_bounds.end.y)

func set_tap_target(world_pos: Vector3) -> void:
	if _busy_cleaning:
		return
	_tap_target = Vector3(
		clampf(world_pos.x, walk_bounds.position.x, walk_bounds.end.x),
		0.0,
		clampf(world_pos.z, walk_bounds.position.y, walk_bounds.end.y)
	)
	_has_tap_target = true

func cancel_movement() -> void:
	_has_tap_target = false
	velocity = Vector3.ZERO

func set_cleaning(active: bool) -> void:
	_busy_cleaning = active
	if active:
		cancel_movement()
		_play_anim("Clean")
	else:
		_play_anim("Idle")

func play_celebrate() -> void:
	_play_anim("Celebrate")

func load_outfit(outfit_id: String, model_path: String, color_hex: String, skin_hex: String = "") -> void:
	if _equipped_outfit_id != outfit_id or _equipped_model_path != model_path or _model_root == null:
		if _model_root != null:
			_model_root.queue_free()
			_model_root = null
			_anim_player = null
		var resolved_path := model_path
		if not ResourceLoader.exists(resolved_path):
			resolved_path = "res://assets/models/char_art_pro.glb"
		if not ResourceLoader.exists(resolved_path):
			resolved_path = "res://assets/models/char_art.glb"
		var packed: PackedScene = load(resolved_path)
		if packed != null:
			_model_root = packed.instantiate() as Node3D
			_model_root.scale = Vector3(0.84, 0.84, 0.84)
			add_child(_model_root)
			_anim_player = _find_anim_player(_model_root)
		_equipped_outfit_id = outfit_id
		_equipped_model_path = model_path

	_equipped_color_hex = color_hex
	if skin_hex != "" and Color.html_is_valid(skin_hex):
		_equipped_skin_hex = skin_hex
	if _model_root != null and Color.html_is_valid(color_hex):
		_apply_outfit_tint(_model_root, Color.html(color_hex))
	if _model_root != null and Color.html_is_valid(_equipped_skin_hex):
		_apply_skin_tint(_model_root, Color.html(_equipped_skin_hex))
	_play_anim("Idle")

func _apply_skin_tint(node: Node, skin_col: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.get_active_material(s)
				if mat is StandardMaterial3D:
					var std := mat as StandardMaterial3D
					var mname := std.resource_name.to_lower()
					if ("skin" in mname or "nose" in mname) and std.albedo_texture == null:
						var dup := std.duplicate() as StandardMaterial3D
						dup.albedo_color = skin_col.darkened(0.08) if "nose" in mname else skin_col
						mi.set_surface_override_material(s, dup)
	for child in node.get_children():
		_apply_skin_tint(child, skin_col)

func _apply_outfit_tint(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.get_active_material(s)
				if mat is StandardMaterial3D:
					var std := mat as StandardMaterial3D
					var mname := std.resource_name.to_lower()
					if "shirt" in mname and not ("collar" in mname) and not ("apron" in mname) and not ("batik" in mname) and not ("daster" in mname) and std.albedo_texture == null:
						var dup := std.duplicate() as StandardMaterial3D
						dup.albedo_color = tint
						mi.set_surface_override_material(s, dup)
	for child in node.get_children():
		_apply_outfit_tint(child, tint)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var found := _find_anim_player(c)
		if found != null:
			return found
	return null

func _play_anim(target: String) -> void:
	if _anim_player == null:
		return
	var list := _anim_player.get_animation_list()
	if list.is_empty():
		return
	for a_name in list:
		if target.to_lower() in a_name.to_lower():
			if _current_anim != a_name:
				_anim_player.play(a_name)
				_current_anim = a_name
			return
	if _current_anim != list[0]:
		_anim_player.play(list[0])
		_current_anim = list[0]

func _physics_process(delta: float) -> void:
	if _busy_cleaning or movement_locked:
		return

	var key_vec := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		key_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		key_vec.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		key_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		key_vec.y += 1.0

	var move_dir := Vector3.ZERO
	if key_vec.length() > 0.05:
		_has_tap_target = false
		var norm := key_vec.normalized()
		move_dir = Vector3(norm.x, 0.0, norm.y)
	elif joystick_input.length() > 0.12:
		_has_tap_target = false
		move_dir = Vector3(joystick_input.x, 0.0, joystick_input.y).normalized()
	elif _has_tap_target:
		var to_t := _tap_target - Vector3(position.x, 0.0, position.z)
		if to_t.length() <= 0.18:
			_has_tap_target = false
			emit_signal("arrived_at_target")
		else:
			move_dir = to_t.normalized()

	if move_dir.length() > 0.05:
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		var target_yaw := atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 12.0))
		_play_anim("Walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_anim("Idle")

	velocity.y = 0.0
	move_and_slide()
	position.y = 0.0
	position.x = clampf(position.x, walk_bounds.position.x, walk_bounds.end.x)
	position.z = clampf(position.z, walk_bounds.position.y, walk_bounds.end.y)
