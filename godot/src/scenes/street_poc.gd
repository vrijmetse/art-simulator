extends Node3D

const I18n := preload("res://src/core/i18n.gd")
const Economy := preload("res://src/core/economy.gd")
const Neighborhood := preload("res://src/core/neighborhood.gd")
const SceneVisuals := preload("res://src/core/scene_visuals.gd")

@onready var cam: Camera3D = $Camera3D
@onready var player_node: Node3D = $Actors/PlayerArt
@onready var ibu_node: Node3D = $Actors/IbuSari
@onready var budi_node: Node3D = $Actors/PakBudi
@onready var hud_balance: Label = $CanvasLayer/TopLeftPill/HBox/BalanceLabel
@onready var hud_rank: Label = $CanvasLayer/TopLeftPill/HBox/RankLabel
@onready var dialogue_panel: PanelContainer = $CanvasLayer/DialogueBar
@onready var dlg_name: Label = $CanvasLayer/DialogueBar/Margin/HBox/VBox/NameLabel
@onready var dlg_text: Label = $CanvasLayer/DialogueBar/Margin/HBox/VBox/TextLabel
@onready var pin_ibu: Label = $CanvasLayer/Pins/PinIbu
@onready var pin_budi: Label = $CanvasLayer/Pins/PinBudi

var _state: Dictionary = {}
var _orbit_yaw := 0.36
var _capture_path := ""
var _capture_dialogue := false
var _frame_count := 0
var _captured := false

func _ready() -> void:
	SceneVisuals.apply_baked_ao(self)
	_state = Economy.create_initial_state()
	_refresh_hud()
	dialogue_panel.visible = false

	_play_anim(player_node, "Idle", 0.0)
	_play_anim(ibu_node, "Idle", 0.65)
	_play_anim(budi_node, "Idle", 1.35)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-street="):
			_capture_path = arg.substr("--capture-street=".length())
		elif arg.begins_with("--capture-dialogue="):
			_capture_path = arg.substr("--capture-dialogue=".length())
			_capture_dialogue = true

	if _capture_dialogue:
		_open_dialogue("ibu_sari")

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var found := _find_anim_player(c)
		if found != null:
			return found
	return null

func _play_anim(actor: Node, target_name: String, seek_sec: float = 0.0) -> void:
	var ap := _find_anim_player(actor)
	if ap == null:
		return
	var list := ap.get_animation_list()
	if list.is_empty():
		return
	for a_name in list:
		if target_name.to_lower() in a_name.to_lower():
			ap.play(a_name)
			if seek_sec > 0.0:
				ap.seek(seek_sec, true)
			return
	ap.play(list[0])

func _refresh_hud() -> void:
	hud_balance.text = I18n.format_balance(int(_state["balance_rp"]), "id")
	hud_rank.text = "Hari %d • %s" % [int(_state["day"]), Economy.get_career_rank(int(_state["xp"]), "id")]

func _open_dialogue(npc_id: String) -> void:
	for spec in Neighborhood.NEIGHBORS:
		if spec["id"] == npc_id:
			dlg_name.text = "%s • %s" % [spec["name_id"], spec["role_id"]]
			dlg_text.text = "\"%s\"" % spec["greeting_id"]
			dialogue_panel.visible = true
			_play_anim(ibu_node, "Talk")
			return

func _on_greet_pressed() -> void:
	var res := Neighborhood.claim_tip(_state, "ibu_sari", "2026-11-26")
	if res["claimed"]:
		_state = res["state"]
		_refresh_hud()

func _on_close_dialogue() -> void:
	dialogue_panel.visible = false
	_play_anim(ibu_node, "Idle")

func _on_rotate_pressed() -> void:
	_orbit_yaw = -0.36 if _orbit_yaw > 0.0 else 0.36
	var r := 9.2
	cam.position = Vector3(sin(_orbit_yaw) * r, 4.9, cos(_orbit_yaw) * r)
	cam.look_at(Vector3(0.0, 0.85, -0.8), Vector3.UP)

func _on_enter_house_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/room_poc.tscn")

func _process(_delta: float) -> void:
	_update_pin(pin_ibu, ibu_node.global_position + Vector3(0.0, 2.05, 0.0))
	_update_pin(pin_budi, budi_node.global_position + Vector3(0.0, 2.05, 0.0))

	if _capture_path != "" and not _captured:
		_frame_count += 1
		if _frame_count >= 4:
			_captured = true
			call_deferred("_do_capture")

func _update_pin(label: Label, world_pos: Vector3) -> void:
	if cam.is_position_behind(world_pos):
		label.visible = false
		return
	var scr := cam.unproject_position(world_pos)
	label.position = scr - label.size * 0.5
	label.visible = not dialogue_panel.visible

func _do_capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_capture_path)
	print("CAPTURED STREET PNG:", _capture_path, "size=", img.get_width(), "x", img.get_height())
	get_tree().quit(0)
