extends Node3D

const I18n := preload("res://src/core/i18n.gd")
const CareerTiers := preload("res://src/core/career_tiers.gd")
const MajikanProfiles := preload("res://src/core/majikan_profiles.gd")
const MajikanCall := preload("res://src/core/majikan_call.gd")
const ChoreEngine := preload("res://src/core/chore_engine.gd")
const Economy := preload("res://src/core/economy.gd")
const Progression := preload("res://src/core/progression.gd")
const SaveStore := preload("res://src/core/save_store.gd")
const AudioSynth := preload("res://src/core/audio_synth.gd")
const SceneVisuals := preload("res://src/core/scene_visuals.gd")
const NpcRoster := preload("res://src/core/npc_roster.gd")
const Neighborhood := preload("res://src/core/neighborhood.gd")
const Atmosphere := preload("res://src/core/atmosphere.gd")
const Settings := preload("res://src/core/settings_store.gd")
const StreetTraffic := preload("res://src/core/street_traffic.gd")
const Portraits := preload("res://src/core/portraits.gd")
const WishlistStory := preload("res://src/core/wishlist_story.gd")
const StreetPatrols := preload("res://src/core/street_patrols.gd")
const Retention := preload("res://src/core/retention.gd")
const LifeRhythm := preload("res://src/core/life_rhythm.gd")
const JemuranEvent := preload("res://src/core/jemuran_event.gd")
const HouseholdClues := preload("res://src/core/household_clues.gd")
const HouseholdSchedules := preload("res://src/core/household_schedules.gd")
const HouseholdDilemmas := preload("res://src/core/household_dilemmas.gd")
const CulturalNotes := preload("res://src/core/cultural_notes.gd")
const PlayerControllerScene := preload("res://src/scenes/player_controller.gd")
const ChoreHotspotScene := preload("res://src/scenes/chore_hotspot.gd")

const CHORE_POSITIONS := {
	"make_bed": Vector3(-0.75, 0.0, -0.95),
	"sweep_floor": Vector3(0.20, 0.0, 0.35),
	"wash_dishes": Vector3(0.85, 0.0, -1.45),
	"cook_rice": Vector3(1.85, 0.0, -1.45),
	"iron_laundry": Vector3(1.35, 0.0, 0.55),
	"water_plants": Vector3(-1.45, 0.0, 0.95),
}

@onready var stage_root: Node3D = $StageRoot
@onready var hotspots_root: Node3D = $Hotspots
@onready var player: PlayerControllerScene = $Player
@onready var cam: Camera3D = $Camera3D
@onready var sfx: AudioStreamPlayer = $SfxPlayer
@onready var hud: CanvasLayer = $HUD
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $SunLight
@onready var bounce_light: DirectionalLight3D = $GroundBounceLight

var _save: Dictionary = {}
var _shift: Dictionary = {}
var _call_state: Dictionary = {}
var _world_mode := "home"
var _in_shift := false
var _street_cfg: Dictionary = {}
var _street_npcs_data: Array = []
var _shift_npcs_data: Array = []
var _chatted_shift_npcs: Dictionary = {}
var _portal_nodes: Array = []
var _traffic_root: Node3D
var _traffic_items: Array = []
var _traffic_nodes: Array = []
var _fan_blades: Array = []
var _rain_particles: CPUParticles3D
var _cur_phase := "pagi"
var _cur_weather := "cerah"
var _reset_confirm := false
var _muted := false
var _active_chore_id := ""
var _chore_progress := 0.0
var _chore_duration := 3.5
var _chore_boosts_used := 0
var _chore_boost_cd := 0.0
var _pending_auto_chore_id := ""
var _float_popups: Array = []
var _footstep_cd := 0.0
var _call_cooldown := 14.0
var _shift_elapsed_s := 0.0
var _phone_open := false

var _wav_coin: AudioStreamWAV
var _wav_ring: AudioStreamWAV
var _wav_sweep: AudioStreamWAV
var _wav_fanfare: AudioStreamWAV
var _wav_buzz: AudioStreamWAV
var _wav_bgm: AudioStreamWAV
var _wav_rain: AudioStreamWAV
var _wav_click: AudioStreamWAV
var _wav_door: AudioStreamWAV
var _wav_chore_tick: AudioStreamWAV
var _wav_step: AudioStreamWAV
var _wav_prayer: AudioStreamWAV
var _wav_sleep: AudioStreamWAV
var _wav_dish: AudioStreamWAV
var _wav_sizzle: AudioStreamWAV
var _wav_cloth: AudioStreamWAV
var _wav_thunder: AudioStreamWAV
var _jemuran_state: Dictionary = {}
var _jemuran_triggered_shift := false
var _jemuran_node: Node3D = null
var _shift_clue: Dictionary = {}
var _clue_node: Node3D = null
var _dilemma_triggered_shift := false
var _bgm_player: AudioStreamPlayer
var _rain_player: AudioStreamPlayer
var _step_player: AudioStreamPlayer
var _audio_unlocked := false
var _pending_story_tier := ""
var _pending_level_unlocks: Array = []
var _shift_event: Dictionary = {}
var _clock_accum := 0.0
var _late_night_warned_day := 0
var _cam_punch := 0.0
var _last_prayer_id := ""
var _is_sleeping := false
var _tasks_collapsed := false
var _btn_tasks_toggle: Button
var _stage_mat_cache: Dictionary = {}
var _actor_mat_cache: Dictionary = {}
var _outline_mat: ShaderMaterial = null

# HUD nodes
var _lbl_balance: Label
var _lbl_level_badge: Label
var _lbl_meta: Label
var _lbl_day_sub: Label
var _lbl_energy: Label
var _bar_energy: ProgressBar
var _lbl_mood: Label
var _bar_mood: ProgressBar
var _lbl_trust: Label
var _lbl_tasks_hdr: Label
var _tasks_list: VBoxContainer
var _tasks_card: PanelContainer
var _btn_map: Button
var _btn_settings: Button
var _btn_action: Button
var _btn_shift: Button
var _btn_phone: Button
var _lbl_phone_badge: Label
var _phone_popup: PanelContainer
var _btn_game: Button
var _btn_call_bf: Button
var _btn_phone_answer: Button
var _btn_career: Button
var _btn_ward: Button
var _btn_kos: Button
var _tl_card: Control
var _tr_vbox: VBoxContainer
var _tc_center: CenterContainer
var _br_vbox: VBoxContainer
var _stars_row: HBoxContainer
var _safe_margins: Dictionary = {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
var _last_prompt_key := ""
var _last_dock_action_key := ""
var _dlg_hbox: HBoxContainer
var _ob_card: PanelContainer
var _title_card: PanelContainer
var _dock_labels: Dictionary = {}
var _dock_icons: Dictionary = {}
var _dock_badges: Dictionary = {}
var _spotlight_target_ctrl: Control
var _active_slot := 1
var _confirm_delete_slot := 0
var _title_wrap: Control
var _title_btn_continue: Button
var _title_btn_new: Button
var _title_btn_slots: Button
var _title_btn_settings: Button
var _title_btn_news: Button
var _capture_title := false
var _capture_phone := false
var _capture_dialogue := false
var _dialogue_bar: PanelContainer
var _dlg_portrait_wrap: Control
var _dlg_portrait: TextureRect
var _dlg_phone_badge: Label
var _dlg_speaker: Label
var _dlg_body: Label
var _dlg_next: Label
var _dlg_queue: Array = []
var _dlg_on_done: Callable
var _spotlight_wrap: Control
var _spotlight_ring: Panel
var _spotlight_hand: Control
var _spotlight_hand_base_pos := Vector2.ZERO
var _spotlight_card: PanelContainer
var _spotlight_title: Label
var _spotlight_body: Label
var _spotlight_btn_ok: Button
var _spotlight_btn_skip: Button
var _spotlight_t := 0.0
var _phone_os_wrap: Control
var _phone_os_bezel: PanelContainer
var _phone_os_bal: Label
var _phone_os_clock: Label
var _phone_os_body: VBoxContainer
var _phone_os_app := "home"
var _phone_os_nav_back: Button
var _phone_os_nav_home: Button
var _phone_os_nav_close: Button
var _hp_bottom_left: Control
var _ob_col_btns: Array = []
var _courier_toast: PanelContainer
var _courier_lbl: Label
var _courier_bar: ProgressBar
var _courier_claim_btn: Button
var _ob_season_lbl: Label
var _ob_btn_back: Button
var _npcs_root: Node3D
var _onboarding_wrap: Control
var _ob_title: Label
var _ob_story: Label
var _ob_skin_lbl: Label
var _ob_name_edit: LineEdit
var _ob_btn_cepol: Button
var _ob_btn_hijab: Button
var _ob_btn_start: Button
var _ob_btn_lang: Button
var _ob_skin_btns: Array = []
var _ob_style := "cepol"
var _ob_skin := "#B87A4B"
var _ob_color := "#4E7D63"
var _call_banner: PanelContainer
var _call_portrait: TextureRect
var _lbl_call_title: Label
var _bar_call: ProgressBar
var _btn_answer: Button
var _chore_bar_wrap: PanelContainer
var _lbl_chore_prog: Label
var _bar_chore: ProgressBar
var _toast_lbl: Label
var _toast_portrait: TextureRect
var _toast_panel: PanelContainer
var _toast_timer := 0.0
var _tutorial_panel: PanelContainer
var _lbl_tutorial: Label
var _btn_tutorial_skip: Button
var _world_prompt: Button
var _modal_backdrop: ColorRect
var _modal_card: PanelContainer
var _modal_scroll: ScrollContainer
var _modal_title: Label
var _modal_list: VBoxContainer
var _btn_modal_close: Button
var _joy_base: Panel
var _joy_knob: Panel
var _joy_touch_idx := -1
var _joy_active := false

var _capture_path := ""
var _capture_shift := false
var _capture_street := false
var _capture_rain := false
var _capture_onboarding := false
var _capture_tier := ""
var _skip_onboarding := false
var _smoke_mode := false
var _frame_cnt := 0
var _captured := false

func _ready() -> void:
	_npcs_root = Node3D.new()
	_npcs_root.name = "NPCs"
	add_child(_npcs_root)

	_traffic_root = Node3D.new()
	_traffic_root.name = "StreetTraffic"
	add_child(_traffic_root)

	_build_rain_particles()

	_wav_coin = AudioSynth.make_coin_chime()
	_wav_ring = AudioSynth.make_phone_ring()
	_wav_sweep = AudioSynth.make_broom_sweep()
	_wav_fanfare = AudioSynth.make_level_up_fanfare()
	_wav_buzz = AudioSynth.make_warning_buzz()
	_wav_bgm = AudioSynth.make_cozy_bgm_loop()
	_wav_rain = AudioSynth.make_rain_loop()
	_wav_click = AudioSynth.make_ui_click()
	_wav_door = AudioSynth.make_door_chime()
	_wav_chore_tick = AudioSynth.make_chore_tick()
	_wav_step = AudioSynth.make_footstep_tick()
	_wav_prayer = AudioSynth.make_prayer_chime()
	_wav_sleep = AudioSynth.make_sleep_lullaby()
	_wav_dish = AudioSynth.make_dish_splash()
	_wav_sizzle = AudioSynth.make_wok_sizzle()
	_wav_cloth = AudioSynth.make_cloth_snap()
	_wav_thunder = AudioSynth.make_thunder_rumble()

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	_bgm_player.stream = _wav_bgm
	_bgm_player.volume_db = -18.0
	add_child(_bgm_player)

	_rain_player = AudioStreamPlayer.new()
	_rain_player.name = "RainPlayer"
	_rain_player.stream = _wav_rain
	_rain_player.volume_db = -22.0
	add_child(_rain_player)

	_step_player = AudioStreamPlayer.new()
	_step_player.name = "StepPlayer"
	_step_player.stream = _wav_step
	_step_player.volume_db = -14.0
	add_child(_step_player)

	if player != null and not player.arrived_at_target.is_connected(_on_player_arrived):
		player.arrived_at_target.connect(_on_player_arrived)

	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke-test":
			_smoke_mode = true
		elif arg == "--skip-onboarding":
			_skip_onboarding = true
		elif arg.begins_with("--capture="):
			_capture_path = arg.substr("--capture=".length())
		elif arg.begins_with("--capture-shift="):
			_capture_path = arg.substr("--capture-shift=".length())
			_capture_shift = true
		elif arg.begins_with("--capture-street="):
			_capture_path = arg.substr("--capture-street=".length())
			_capture_street = true
		elif arg == "--capture-rain":
			_capture_rain = true
		elif arg.begins_with("--capture-onboarding="):
			_capture_path = arg.substr("--capture-onboarding=".length())
			_capture_onboarding = true
		elif arg.begins_with("--capture-title="):
			_capture_path = arg.substr("--capture-title=".length())
			_capture_title = true
		elif arg.begins_with("--capture-phone="):
			_capture_path = arg.substr("--capture-phone=".length())
			_capture_phone = true
		elif arg.begins_with("--capture-dialogue="):
			_capture_path = arg.substr("--capture-dialogue=".length())
			_capture_dialogue = true
		elif arg.begins_with("--capture-tier="):
			_capture_tier = arg.substr("--capture-tier=".length())

	_save = SaveStore.load_from_slot(_active_slot)
	var today_s := _today_date_str()
	_save = Retention.sync_daily_login(_save, today_s)["save"]
	_save = Retention.evaluate_badges(_save)["save"]
	_muted = bool(_save.get("muted", false))
	_build_hud()
	_apply_mobile_safe_area()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	Settings.apply_graphics_quality(sun_light, world_env.environment if world_env != null else null, String(_save.get("gfx_quality", "high")))

	if _smoke_mode:
		_run_headless_smoke_test()
		return

	if _capture_shift:
		_save["onboarding_done"] = true
		_save["guide_seen"] = true
		_save["tutorial_step"] = 4
		if _capture_tier != "":
			_save["xp"] = 2000
			_save = Progression.select_job_tier(_save, _capture_tier)["save"]
			if _capture_tier == "cluster_elite":
				_save = Progression.equip_outfit(_save, "housekeeper_elite", "#1E3442")["save"]
		_sync_player_outfit()
		_start_shift()
		_call_state = MajikanCall.start_call(_call_state, _t("Tolong bantu cek pintu depan!", "Please check the front gate!"))
		_refresh_hud()
		return

	if _capture_street:
		_save["onboarding_done"] = true
		_save["guide_seen"] = true
		_save["tutorial_step"] = 4
		if _capture_rain:
			_save["day"] = 3
			_save["weather_fx"] = true
		if _capture_tier != "":
			_save["xp"] = 2000
			_save = Progression.select_job_tier(_save, _capture_tier)["save"]
		_sync_player_outfit()
		_enter_street_mode()
		_refresh_hud()
		return

	_enter_home_mode()
	_sync_player_outfit()
	if _capture_title:
		_open_title_screen()
	elif _capture_phone:
		_save["onboarding_done"] = true
		_save["guide_seen"] = true
		_save["tutorial_step"] = 4
		_open_phone_os("home")
	elif _capture_dialogue:
		_save["onboarding_done"] = true
		_save["guide_seen"] = false
		_save["tutorial_step"] = 4
		_start_intro_cutscene()
	elif _capture_onboarding:
		_open_onboarding()
	elif _capture_path != "":
		_save["onboarding_done"] = true
		_save["guide_seen"] = true
		_save["tutorial_step"] = 4
		_sync_player_outfit()
	else:
		_open_title_screen()
	_on_viewport_size_changed()
	_refresh_hud()

func _loc() -> String:
	return String(_save.get("locale", "id"))

func _today_date_str() -> String:
	return Time.get_date_string_from_system()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _phone_os_wrap != null and _phone_os_wrap.visible:
			_phone_os_wrap.visible = false
			_refresh_hud()
		elif _modal_backdrop != null and _modal_backdrop.visible:
			_modal_backdrop.visible = false
			_refresh_tutorial_banner()
		elif _dialogue_bar != null and _dialogue_bar.visible:
			_advance_dialogue()
		elif _onboarding_wrap == null or not _onboarding_wrap.visible:
			if _title_wrap == null or not _title_wrap.visible:
				_open_settings_modal()

func _apply_mobile_safe_area() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		vp = Vector2(1280.0, 720.0)
	if not _smoke_mode and DisplayServer.get_name() != "headless":
		var safe := DisplayServer.get_display_safe_area()
		var win := Vector2(DisplayServer.window_get_size())
		_safe_margins = Atmosphere.compute_hud_safe_margins(Rect2(safe), win, vp)
	else:
		_safe_margins = {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	var pad_l := float(_safe_margins.get("left", 0.0))
	var pad_t := float(_safe_margins.get("top", 0.0))
	var pad_r := float(_safe_margins.get("right", 0.0))
	var pad_b := float(_safe_margins.get("bottom", 0.0))
	if _tl_card != null:
		_tl_card.position = Vector2(14.0 + pad_l, 10.0 + pad_t)
	if _tr_vbox != null:
		_tr_vbox.offset_right = -16.0 - pad_r
		_tr_vbox.offset_top = 10.0 + pad_t
	if _br_vbox != null:
		_br_vbox.offset_right = -14.0 - pad_r
		_br_vbox.offset_bottom = -12.0 - pad_b
	if _joy_base != null:
		_joy_base.offset_left = 16.0 + pad_l
		_joy_base.offset_right = 114.0 + pad_l
		_joy_base.offset_bottom = -14.0 - pad_b
		_joy_base.offset_top = -112.0 - pad_b
	if _tc_center != null:
		var tl_w := maxf(304.0, _tl_card.size.x if _tl_card != null else 304.0)
		var tr_w := maxf(396.0, _tr_vbox.size.x if _tr_vbox != null else 396.0)
		var tc_b := Atmosphere.compute_top_center_bounds(vp.x, tl_w, tr_w, pad_l, pad_r)
		_tc_center.offset_left = float(tc_b["offset_left"])
		_tc_center.offset_right = float(tc_b["offset_right"])
		_tc_center.offset_top = 10.0 + pad_t
	if _dialogue_bar != null:
		var dlg_w := minf(1080.0, maxf(320.0, vp.x - pad_l - pad_r - 24.0))
		_dialogue_bar.offset_left = -dlg_w * 0.5
		_dialogue_bar.offset_right = dlg_w * 0.5
		_dialogue_bar.offset_bottom = -pad_b
		_dialogue_bar.offset_top = -132.0 - pad_b
	if _title_card != null:
		_title_card.offset_left = 24.0 + pad_l
		_title_card.offset_bottom = -20.0 - pad_b
	if _ob_card != null:
		if vp.x < vp.y:
			_ob_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			_ob_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
			_ob_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
			_ob_card.offset_left = 14.0 + pad_l
			_ob_card.offset_right = -14.0 - pad_r
			_ob_card.offset_bottom = -14.0 - pad_b
			_ob_card.offset_top = -minf(490.0, vp.y * 0.50) - pad_b
		else:
			_ob_card.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
			_ob_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			_ob_card.grow_vertical = Control.GROW_DIRECTION_BOTH
			_ob_card.offset_right = -24.0 - pad_r
			_ob_card.offset_left = -520.0 - pad_r
			_ob_card.offset_top = -310.0
			_ob_card.offset_bottom = 310.0

func _set_control_focus_recursive(node: Node, enabled: bool) -> void:
	if node is Control:
		var c := node as Control
		if not enabled:
			if not c.has_meta("_saved_focus_mode"):
				c.set_meta("_saved_focus_mode", c.focus_mode)
			c.focus_mode = Control.FOCUS_NONE
		elif c.has_meta("_saved_focus_mode"):
			c.focus_mode = int(c.get_meta("_saved_focus_mode"))
	for ch in node.get_children():
		_set_control_focus_recursive(ch, enabled)

func _set_hud_focus_enabled(enabled: bool) -> void:
	for ctrl in [_tl_card, _tr_vbox, _br_vbox, _hp_bottom_left]:
		if ctrl != null:
			_set_control_focus_recursive(ctrl, enabled)

func _t(id_str: String, en_str: String) -> String:
	return en_str if _loc() == "en" else id_str

func _play_sfx(wav: AudioStreamWAV) -> void:
	if _muted or _smoke_mode or not _audio_unlocked or wav == null or sfx == null:
		return
	sfx.stream = wav
	sfx.play()

func _get_player_portrait_tex(mood: String = "neutral") -> Texture2D:
	return Portraits.get_player_portrait(
		String(_save.get("skin_hex", "#B87A4B")),
		String(_save.get("outfit_color_hex", "#4E7D63")),
		String(_save.get("starter_style", "cepol")),
		mood
	)

func _show_toast(msg: String, speaker_id: String = "", mood: String = "happy") -> void:
	if _toast_lbl == null or _toast_panel == null:
		return
	if _call_banner != null and _call_banner.visible:
		_toast_panel.visible = false
		return
	_toast_lbl.text = msg
	if _toast_portrait != null:
		if speaker_id == "player":
			_toast_portrait.texture = _get_player_portrait_tex(mood)
			_toast_portrait.visible = true
		elif speaker_id != "":
			_toast_portrait.texture = Portraits.get_portrait(speaker_id, mood)
			_toast_portrait.visible = true
		else:
			_toast_portrait.visible = false
	_toast_panel.visible = true
	_toast_timer = 3.2

func _spawn_float_popup(world_pos: Vector3, text: String, col: Color = Color(0.98, 0.84, 0.28)) -> void:
	if hud == null or cam == null or _smoke_mode:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.08, 0.10))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(lbl)
	var scr := cam.unproject_position(world_pos)
	lbl.position = scr - Vector2(60, 12)
	_float_popups.append({"node": lbl, "elapsed": 0.0, "dur": 1.35, "start_y": lbl.position.y})

func _burst_chore_sparkles(world_pos: Vector3) -> void:
	if _smoke_mode or hotspots_root == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = 18
	p.lifetime = 0.65
	p.position = world_pos + Vector3(0.0, 0.9, 0.0)
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 65.0
	p.initial_velocity_min = 1.4
	p.initial_velocity_max = 2.8
	p.gravity = Vector3(0.0, -3.5, 0.0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.86, 0.30)
	mesh.material = mat
	p.mesh = mesh
	hotspots_root.add_child(p)
	p.emitting = true

func _build_rain_particles() -> void:
	_rain_particles = CPUParticles3D.new()
	_rain_particles.name = "RainParticles"
	_rain_particles.amount = 85
	_rain_particles.lifetime = 0.75
	_rain_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain_particles.emission_box_extents = Vector3(6.5, 0.2, 4.5)
	_rain_particles.position = Vector3(0.0, 4.8, 0.5)
	_rain_particles.direction = Vector3(-0.1, -1.0, 0.0)
	_rain_particles.spread = 4.0
	_rain_particles.initial_velocity_min = 6.5
	_rain_particles.initial_velocity_max = 8.5
	_rain_particles.emitting = false
	var drop := BoxMesh.new()
	drop.size = Vector3(0.010, 0.36, 0.010)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.84, 0.92, 1.0, 0.50)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = dmat
	_rain_particles.amount = 180
	_rain_particles.lifetime = 0.65
	_rain_particles.mesh = drop
	add_child(_rain_particles)

func _unlock_audio() -> void:
	if _audio_unlocked:
		return
	_audio_unlocked = true
	_sync_ambient_audio()

func _sync_ambient_audio() -> void:
	if _smoke_mode or _muted or not _audio_unlocked:
		if _bgm_player != null and _bgm_player.playing:
			_bgm_player.stop()
		if _rain_player != null and _rain_player.playing:
			_rain_player.stop()
		return
	var want_bgm := bool(_save.get("bgm_enabled", true))
	if _bgm_player != null:
		if want_bgm and not _bgm_player.playing:
			_bgm_player.play()
		elif not want_bgm and _bgm_player.playing:
			_bgm_player.stop()
	var want_rain := (_world_mode == "street" and _cur_weather == "hujan")
	if _rain_player != null:
		if want_rain and not _rain_player.playing:
			_rain_player.play()
		elif not want_rain and _rain_player.playing:
			_rain_player.stop()

func _refresh_atmosphere() -> void:
	var day := int(_save.get("day", 1))
	var g_min := int(_save.get("game_minutes", 360))
	_cur_phase = LifeRhythm.get_phase_from_minutes(g_min)
	_cur_weather = Atmosphere.get_weather(day, bool(_save.get("weather_fx", true)))
	var env := world_env.environment if world_env != null else null
	Atmosphere.apply_lighting(sun_light, bounce_light, env, _cur_phase, _cur_weather, _world_mode)
	if sun_light != null:
		sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun_light.directional_shadow_max_distance = 16.0 if _world_mode == "street" else 11.0
		sun_light.shadow_blur = 0.85 if _world_mode == "street" else 0.72
	Atmosphere.sync_stage_lights(stage_root, _world_mode, _cur_phase)
	if _rain_particles != null:
		_rain_particles.emitting = (_world_mode == "street" and _cur_weather == "hujan")
	StreetPatrols.sync_player_umbrella(player, _world_mode == "street" and _cur_weather == "hujan")
	_sync_ambient_audio()

func _clear_street_traffic() -> void:
	_traffic_items.clear()
	_traffic_nodes.clear()
	if _traffic_root == null:
		return
	for c in _traffic_root.get_children():
		c.queue_free()

func _spawn_street_traffic(tier_id: String) -> void:
	_clear_street_traffic()
	if _traffic_root == null:
		return
	var cfg_list := StreetTraffic.get_traffic_config(tier_id)
	for item in cfg_list:
		var mpath := String(item.get("model_path", ""))
		if not ResourceLoader.exists(mpath):
			continue
		var ps: PackedScene = load(mpath)
		if ps == null:
			continue
		var v_inst := ps.instantiate() as Node3D
		v_inst.position = Vector3(float(item.get("x", 0.0)), 0.0, float(item.get("z", 2.55)))
		v_inst.rotation.y = 0.0 if int(item.get("dir", 1)) > 0 else PI
		StreetTraffic.apply_livery(v_inst, item.get("livery_color", Color("#1D84B5")))
		_traffic_root.add_child(v_inst)
		_traffic_items.append(item.duplicate(true))
		_traffic_nodes.append(v_inst)

func _ensure_outline() -> ShaderMaterial:
	if _outline_mat == null:
		_outline_mat = SceneVisuals.ensure_detail_outline_material()
	return _outline_mat

func _load_stage_glb(glb_path: String) -> void:
	_fan_blades.clear()
	_stage_mat_cache.clear()
	for c in stage_root.get_children():
		c.queue_free()
	var resolved := glb_path
	if not ResourceLoader.exists(resolved):
		resolved = "res://assets/models/kos_room.glb"
	var packed: PackedScene = load(resolved)
	if packed != null:
		var inst := packed.instantiate()
		stage_root.add_child(inst)
		var stage_base := resolved.get_file().get_basename()
		var lm_path := "res://assets/lightmaps/%s_lightmap.png" % stage_base
		var lm_tex: Texture2D = load(lm_path) as Texture2D if ResourceLoader.exists(lm_path) else null
		SceneVisuals.apply_unified_material_pass(inst, true, false, _ensure_outline(), _stage_mat_cache, lm_tex, true)
		if "kos_room" in resolved:
			Atmosphere.apply_kos_upgrades_visual(inst, _save.get("unlocked_kos_upgrades", []))
			for fb_name in ["FanBlade_0", "FanBlade_1", "FanBlade_2", "FanBlade_3"]:
				var fb := inst.find_child(fb_name, true, false)
				if fb is Node3D:
					_fan_blades.append(fb)

func _sync_player_outfit() -> void:
	var oid := String(_save.get("equipped_outfit_id", "starter_kasual"))
	var hex := String(_save.get("outfit_color_hex", "#4E7D63"))
	var skin_hex := String(_save.get("skin_hex", "#B87A4B"))
	var model_path := Progression.resolve_player_model_path(_save)
	player.load_outfit(oid, model_path, hex, skin_hex)
	SceneVisuals.apply_unified_material_pass(player, false, false, _ensure_outline(), _actor_mat_cache)
	player.reapply_tints()

func _clear_npcs() -> void:
	if _npcs_root == null:
		return
	for c in _npcs_root.get_children():
		c.queue_free()

func _spawn_npcs(npc_list: Array) -> void:
	_clear_npcs()
	if _npcs_root == null:
		return
	for npc in npc_list:
		var mpath := String(npc.get("model_path", ""))
		if not ResourceLoader.exists(mpath):
			continue
		var ps: PackedScene = load(mpath)
		if ps == null:
			continue
		var holder := Node3D.new()
		holder.position = npc.get("pos", Vector3.ZERO)
		holder.rotation.y = float(npc.get("rot_y", 0.0))
		var inst := ps.instantiate() as Node3D
		inst.scale = Vector3(0.92, 0.92, 0.92)
		holder.add_child(inst)
		SceneVisuals.apply_unified_material_pass(inst, false, false, _ensure_outline(), _actor_mat_cache)
		SceneVisuals.attach_contact_shadow(holder, 0.36)

		var target_anim := String(npc.get("anim", "Idle")).to_lower()
		var ap := _find_anim_player_recursive(inst)
		if ap != null:
			var alist := ap.get_animation_list()
			var picked := ""
			for a_name in alist:
				if a_name.to_lower() == target_anim or a_name.to_lower().begins_with(target_anim + "_"):
					picked = a_name
					break
			if picked == "":
				for a_name in alist:
					if target_anim in a_name.to_lower():
						picked = a_name
						break
			if picked == "" and not alist.is_empty():
				for a_name in alist:
					if "idle" in a_name.to_lower():
						picked = a_name
						break
				if picked == "":
					picked = alist[0]
			if picked != "":
				ap.play(picked)

		var badge := Label3D.new()
		badge.name = "_Label3D"
		badge.text = String(npc.get("label_en") if _loc() == "en" else npc.get("label_id"))
		badge.position = Vector3(0.0, 1.92, 0.0)
		badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		badge.font_size = 18
		badge.pixel_size = 0.0026
		badge.modulate = Color(0.98, 0.84, 0.34)
		badge.outline_modulate = Color(0.06, 0.07, 0.09)
		badge.outline_size = 6
		badge.visible = false
		holder.add_child(badge)
		_npcs_root.add_child(holder)
		if npc is Dictionary:
			npc["node"] = holder
			npc["anim_player"] = ap

func _find_anim_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var f := _find_anim_player_recursive(c)
		if f != null:
			return f
	return null

func _spawn_portal(pid: String, pos: Vector3, color: Color, label_id: String, label_en: String) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.set_meta("portal_id", pid)
	holder.set_meta("label_id", label_id)
	holder.set_meta("label_en", label_en)

	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.28
	disc.bottom_radius = 0.30
	disc.height = 0.004
	disc.radial_segments = 24
	ring.mesh = disc
	ring.position.y = 0.015
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.22)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.20
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	holder.add_child(ring)

	var badge := Label3D.new()
	badge.name = "_Label3D"
	badge.text = label_en if _loc() == "en" else label_id
	badge.position = Vector3(0.0, 0.36, 0.0)
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.font_size = 20
	badge.pixel_size = 0.0028
	badge.modulate = color.lightened(0.25)
	badge.outline_modulate = Color(0.06, 0.07, 0.09)
	badge.outline_size = 6
	badge.visible = false
	holder.add_child(badge)

	hotspots_root.add_child(holder)
	_portal_nodes.append(holder)

func _enter_home_mode() -> void:
	if _world_mode != "home" and _audio_unlocked:
		_play_sfx(_wav_door)
	_world_mode = "home"
	_in_shift = false
	_active_chore_id = ""
	_pending_auto_chore_id = ""
	_street_npcs_data = []
	_shift_npcs_data = []
	player.set_cleaning(false)
	StreetPatrols.sync_chore_tool(player, "")
	if _chore_bar_wrap != null:
		_chore_bar_wrap.visible = false
	_toast_timer = 0.0
	if _toast_panel != null:
		_toast_panel.visible = false
	_clear_hotspots()
	_clear_shift_events()
	_portal_nodes.clear()
	var tier_id := String(_save.get("active_tier_id", "kamar_kos"))
	var tier := CareerTiers.get_tier(tier_id)
	var prof := MajikanProfiles.get_profile(String(_save.get("active_profile_id", "ibu_kos_melati")))
	var home_glb := "res://assets/models/kos_room.glb"
	if bool(tier.get("live_in_room_provided", false)):
		home_glb = String(prof.get("kamar_art_scene", "res://assets/models/kos_room.glb"))
	_load_stage_glb(home_glb)
	player.set_walk_bounds(-2.0, 2.0, -1.8, 1.7)
	player.position = Vector3(0.0, 0.0, 0.35)
	player.cancel_movement()
	_spawn_npcs(NpcRoster.get_home_npcs(tier_id))
	_clear_street_traffic()
	var is_small_art := "kamar_art_small" in home_glb
	_spawn_portal("exit_street", Vector3(0.08, 0.0, 1.15) if is_small_art else Vector3(0.45, 0.0, 1.15), Color(0.96, 0.78, 0.24), "Keluar Kamar", "Step Outside")
	_spawn_portal("sleep_bed", Vector3(-0.95, 0.0, -0.85), Color(0.45, 0.74, 0.96), "Tidur di Kasur", "Sleep to Recharge")
	if bool(_save.get("prayer_reminders", true)):
		_spawn_portal("pray_mat", Vector3(0.65, 0.0, 0.95) if is_small_art else Vector3(1.20, 0.0, 0.95), Color(0.32, 0.84, 0.62), "Sholat / Doa", "Pray")
	_refresh_atmosphere()
	_refresh_hud()

func _enter_street_mode(from_mode: String = "home") -> void:
	if _is_sleeping:
		return
	if _audio_unlocked:
		_play_sfx(_wav_door)
	_world_mode = "street"
	_in_shift = false
	_active_chore_id = ""
	_pending_auto_chore_id = ""
	_shift_npcs_data = []
	player.set_cleaning(false)
	StreetPatrols.sync_chore_tool(player, "")
	if _chore_bar_wrap != null:
		_chore_bar_wrap.visible = false
	_toast_timer = 0.0
	if _toast_panel != null:
		_toast_panel.visible = false
	_clear_hotspots()
	_clear_shift_events()
	_portal_nodes.clear()

	var tier_id := String(_save.get("active_tier_id", "kamar_kos"))
	_street_cfg = NpcRoster.get_street_config(tier_id)
	_load_stage_glb(String(_street_cfg.get("street_scene", "res://assets/models/kampung_gang.glb")))

	var wrect: Rect2 = _street_cfg.get("walk_rect", Rect2(-5.2, 0.35, 10.4, 1.70))
	player.set_walk_bounds(wrect.position.x, wrect.end.x, wrect.position.y, wrect.end.y)
	var spawn_pos: Vector3 = _street_cfg.get("player_spawn", Vector3(-1.4, 0.0, 1.25))
	if from_mode == "shift":
		var pw: Vector3 = _street_cfg.get("portal_work", spawn_pos)
		spawn_pos = Vector3(pw.x, 0.0, minf(wrect.end.y - 0.15, pw.z + 0.65))
	player.position = spawn_pos
	player.cancel_movement()

	_street_npcs_data = StreetPatrols.create_runtime_npcs(_street_cfg.get("street_npcs", []))
	_spawn_npcs(_street_npcs_data)
	_spawn_street_traffic(tier_id)
	_spawn_portal("enter_home", _street_cfg.get("portal_home", Vector3(-3.9, 0.0, 0.55)), Color(0.96, 0.78, 0.24), "Masuk Kamar", "Enter Room")
	_spawn_portal("enter_work", _street_cfg.get("portal_work", Vector3(2.9, 0.0, 0.55)), Color(0.28, 0.86, 0.50), "Rumah Majikan", "Work Shift")
	if int(_save.get("tutorial_step", 0)) < 1:
		_save = WishlistStory.advance_tutorial(_save, 1)
		SaveStore.save_to_slot(_save, _active_slot)
	_refresh_atmosphere()
	_show_toast(_t("Di gang luar — sapa tetangga atau masuk Rumah Majikan.", "Outside on the street — greet neighbors or enter Work Shift."))
	_refresh_hud()

func _start_shift(force_low_energy: bool = false) -> void:
	var max_e := Progression.get_max_energy(_save)
	var cur_e := clampi(int(_save.get("energy", max_e)), 0, max_e)
	if not force_low_energy and cur_e < 20:
		_open_low_energy_modal(cur_e)
		return
	if _audio_unlocked:
		_play_sfx(_wav_door)
	var tier_id := String(_save.get("active_tier_id", "kamar_kos"))
	var prof := MajikanProfiles.get_profile(String(_save.get("active_profile_id", "ibu_kos_melati")))
	if prof.is_empty():
		prof = MajikanProfiles.get_profile("ibu_kos_melati")
	_shift = ChoreEngine.create_shift(tier_id, prof, max_e, cur_e)
	_shift_event = Retention.get_shift_event(int(_save.get("day", 1)), tier_id, _loc())
	var start_mood := Progression.get_shift_starting_mood(_save)
	_call_state = MajikanCall.create_state(prof, start_mood)
	_call_state["patience_mult"] = float(_shift_event.get("patience_mult", 1.0))
	_world_mode = "shift"
	_in_shift = true
	_shift_elapsed_s = 0.0
	_phone_open = false
	_call_cooldown = 12.0
	_active_chore_id = ""
	_pending_auto_chore_id = ""
	_chore_boosts_used = 0
	_chore_boost_cd = 0.0
	_street_npcs_data = []
	_chatted_shift_npcs = {}
	_portal_nodes.clear()
	StreetPatrols.sync_chore_tool(player, "")

	var work_glb := String(prof.get("work_interior_scene", "res://assets/models/room_majikan_living.glb"))
	_load_stage_glb(work_glb)
	if "elite_living" in work_glb:
		player.set_walk_bounds(-3.4, 3.4, -2.5, 2.3)
		player.position = Vector3(0.35, 0.0, 1.35)
	elif "majikan_living" in work_glb:
		player.set_walk_bounds(-2.8, 2.8, -2.1, 1.8)
		player.position = Vector3(0.0, 0.0, -0.5)
	elif "kampung_house" in work_glb:
		player.set_walk_bounds(-2.1, 2.1, -1.8, 1.7)
		player.position = Vector3(0.0, 0.0, 0.35)
	else:
		player.set_walk_bounds(-2.0, 2.0, -1.8, 1.7)
		player.position = Vector3(0.0, 0.0, 0.25)
	player.cancel_movement()
	_spawn_hotspots(work_glb)
	_shift_npcs_data = HouseholdSchedules.create_runtime_shift_npcs(NpcRoster.get_shift_npcs(tier_id), tier_id)
	_spawn_npcs(_shift_npcs_data)
	_clear_street_traffic()
	_clear_shift_events()
	_shift_clue = HouseholdClues.pick_clue_for_shift(tier_id, _save.get("unlocked_clues", []), int(_save.get("day", 1)))
	if not _shift_clue.is_empty():
		_spawn_clue_marker(HouseholdClues.get_clue_pos(tier_id))
	if int(_save.get("tutorial_step", 0)) < 2:
		_save = WishlistStory.advance_tutorial(_save, 2)
		SaveStore.save_to_slot(_save, _active_slot)
	_refresh_atmosphere()
	var emp_lbl := String(prof.get("name", prof.get("label_id", "")))
	var ev_title := String(_shift_event.get("title", ""))
	if String(_shift_event.get("id", "normal")) != "normal" and ev_title != "":
		_show_toast(_t("Shift %s: %s" % [emp_lbl, ev_title], "%s Shift: %s" % [emp_lbl, ev_title]))
	else:
		_show_toast(_t("Shift di %s dimulai! Kerjakan tugas & jawab panggilan." % emp_lbl, "Shift at %s started! Finish chores & answer calls." % emp_lbl))
	_refresh_hud()

func _clear_hotspots() -> void:
	for c in hotspots_root.get_children():
		c.queue_free()

func _clear_shift_events() -> void:
	_jemuran_state = {}
	_jemuran_triggered_shift = false
	if _jemuran_node != null and is_instance_valid(_jemuran_node):
		_jemuran_node.queue_free()
	_jemuran_node = null
	_shift_clue = {}
	if _clue_node != null and is_instance_valid(_clue_node):
		_clue_node.queue_free()
	_clue_node = null
	_dilemma_triggered_shift = false

func _spawn_clue_marker(pos: Vector3) -> void:
	if _clue_node != null and is_instance_valid(_clue_node):
		_clue_node.queue_free()
	_clue_node = Node3D.new()
	_clue_node.position = Vector3(pos.x, 0.35, pos.z)
	var gem := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.16, 0.16, 0.16)
	gem.mesh = pm
	gem.rotation_degrees = Vector3(35.0, 45.0, 35.0)
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.99, 0.84, 0.28)
	mat.emission_enabled = true
	mat.emission = Color(0.99, 0.80, 0.22)
	mat.emission_energy_multiplier = 0.85
	gem.material_override = mat
	_clue_node.add_child(gem)
	add_child(_clue_node)

func _spawn_jemuran_marker(pos: Vector3) -> void:
	if _jemuran_node != null and is_instance_valid(_jemuran_node):
		_jemuran_node.queue_free()
	_jemuran_node = Node3D.new()
	_jemuran_node.position = Vector3(pos.x, 0.04, pos.z)
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.46
	cm.height = 0.02
	ring.mesh = cm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.78, 0.98)
	mat.emission_enabled = true
	mat.emission = Color(0.24, 0.82, 0.99)
	mat.emission_energy_multiplier = 0.95
	ring.material_override = mat
	_jemuran_node.add_child(ring)
	var rack := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.60, 0.08, 0.12)
	rack.mesh = bm
	rack.position = Vector3(0.0, 0.78, 0.0)
	rack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.96, 0.92, 0.82)
	rack.material_override = rmat
	_jemuran_node.add_child(rack)
	add_child(_jemuran_node)

func _play_chore_foley(cid: String) -> void:
	match cid:
		"wash_dishes", "water_plants":
			_play_sfx(_wav_dish)
		"cook_rice":
			_play_sfx(_wav_sizzle)
		"iron_laundry", "make_bed":
			_play_sfx(_wav_cloth)
		_:
			_play_sfx(_wav_sweep)

func _near_jemuran() -> bool:
	return _world_mode == "shift" and bool(_jemuran_state.get("active", false)) and _jemuran_node != null and is_instance_valid(_jemuran_node) and Vector2(player.position.x - _jemuran_node.position.x, player.position.z - _jemuran_node.position.z).length() <= 1.55

func _near_clue() -> bool:
	return _world_mode == "shift" and not _shift_clue.is_empty() and _clue_node != null and is_instance_valid(_clue_node) and Vector2(player.position.x - _clue_node.position.x, player.position.z - _clue_node.position.z).length() <= 1.45

func _rescue_jemuran() -> void:
	var res := JemuranEvent.rescue(_jemuran_state)
	_jemuran_state = res["state"]
	if not bool(res["ok"]):
		return
	if _jemuran_node != null and is_instance_valid(_jemuran_node):
		_jemuran_node.queue_free()
	_jemuran_node = null
	var bonus_rp := int(res["bonus_rp"])
	_shift["earned_rp"] = int(_shift.get("earned_rp", 0)) + bonus_rp
	_shift["xp_earned"] = int(_shift.get("xp_earned", 0)) + int(res["xp"])
	_call_state["mood"] = clampi(int(_call_state.get("mood", 60)) + int(res["mood_bonus"]), 0, 100)
	_call_state["trust"] = clampi(int(_call_state.get("trust", 60)) + int(res["trust_bonus"]), 0, 100)
	_play_sfx(_wav_fanfare)
	_cam_punch = 0.28
	_burst_chore_sparkles(player.position)
	_spawn_float_popup(player.position + Vector3(0.0, 1.95, 0.0), _t("Jemuran Aman! +%s" % I18n.format_balance(bonus_rp, "id"), "Laundry Saved! +%s" % I18n.format_balance(bonus_rp, "en")), Color(0.45, 0.96, 0.99))
	_show_toast(_t("Hebat! Jemuran berhasil diselamatkan sebelum hujan (+%s)!" % I18n.format_balance(bonus_rp, "id"), "Heroic save! Laundry rescued before rain (+%s)!" % I18n.format_balance(bonus_rp, "en")), "player", "happy")
	_refresh_hud()

func _collect_shift_clue() -> void:
	if _shift_clue.is_empty():
		return
	var cid := String(_shift_clue.get("id", ""))
	var res := HouseholdClues.collect_clue(_save, cid)
	_shift_clue = {}
	if _clue_node != null and is_instance_valid(_clue_node):
		_clue_node.queue_free()
	_clue_node = null
	if not bool(res["ok"]):
		return
	_save = res["save"]
	SaveStore.save_to_slot(_save, _active_slot)
	var clue: Dictionary = res["clue"]
	var title_c := String(clue["title_en"] if _loc() == "en" else clue["title_id"])
	var story_c := String(clue["story_en"] if _loc() == "en" else clue["story_id"])
	_play_sfx(_wav_coin)
	_burst_chore_sparkles(player.position)
	_spawn_float_popup(player.position + Vector3(0.0, 1.9, 0.0), _t("Jejak Cerita! +20 XP", "Story Clue! +20 XP"), Color(0.99, 0.86, 0.34))
	_show_toast("✨ %s: %s" % [title_c, story_c], String(_save.get("active_profile_id", "player")), "happy")
	_refresh_hud()

func _get_chore_positions(work_glb: String) -> Dictionary:
	if "elite_living" in work_glb:
		return {
			"make_bed": Vector3(-2.35, 0.0, -1.65),
			"sweep_floor": Vector3(0.35, 0.0, 1.60),
			"wash_dishes": Vector3(2.25, 0.0, -0.35),
			"cook_rice": Vector3(2.45, 0.0, -1.45),
			"iron_laundry": Vector3(1.85, 0.0, 1.45),
			"water_plants": Vector3(-2.35, 0.0, 1.55),
		}
	if "kampung_house" in work_glb:
		return {
			"make_bed": Vector3(-1.35, 0.0, -1.15),
			"sweep_floor": Vector3(0.05, 0.0, 0.95),
			"wash_dishes": Vector3(0.95, 0.0, -0.55),
			"cook_rice": Vector3(1.55, 0.0, -0.55),
			"iron_laundry": Vector3(1.15, 0.0, 1.15),
			"water_plants": Vector3(-1.35, 0.0, 0.95),
		}
	if "kos_neighbor_room" in work_glb:
		return {
			"make_bed": Vector3(0.75, 0.0, -0.88),
			"sweep_floor": Vector3(-0.20, 0.0, 0.35),
			"water_plants": Vector3(1.45, 0.0, 0.95),
		}
	return CHORE_POSITIONS

func _spawn_hotspots(work_glb: String = "") -> void:
	_clear_hotspots()
	var pos_map := _get_chore_positions(work_glb)
	var assigned: Array = _shift.get("assigned_ids", [])
	for cid in assigned:
		var s_cid := String(cid)
		if not ChoreEngine.CHORES.has(s_cid):
			continue
		var cfg: Dictionary = ChoreEngine.CHORES[s_cid]
		var pos: Vector3 = pos_map.get(s_cid, Vector3(0.0, 0.0, 0.0))
		var hs := ChoreHotspotScene.new()
		hs.setup(s_cid, String(cfg["label_id"]), String(cfg["label_en"]), pos)
		hotspots_root.add_child(hs)

func _nearest_hotspot() -> ChoreHotspotScene:
	var best: ChoreHotspotScene = null
	var best_d := 1.45
	for c in hotspots_root.get_children():
		if c is ChoreHotspotScene and not c.completed:
			var d: float = player.position.distance_to(c.position)
			if d < best_d:
				best_d = d
				best = c
	return best

func _nearest_portal() -> Node3D:
	var best: Node3D = null
	var best_d := 1.45
	for p in _portal_nodes:
		if is_instance_valid(p):
			var d := player.position.distance_to(p.position)
			if d < best_d:
				best_d = d
				best = p
	return best

func _nearest_street_npc() -> Dictionary:
	if _world_mode != "street":
		return {}
	var best: Dictionary = {}
	var best_d := 1.75
	for npc in _street_npcs_data:
		var np: Vector3 = npc.get("pos", Vector3.ZERO)
		var d := player.position.distance_to(np)
		if d < best_d:
			best_d = d
			best = npc
	return best

func _talk_to_street_npc(npc: Dictionary) -> void:
	var nid := String(npc.get("id", "ibu_sari"))
	var nname := String(npc.get("label_en") if _loc() == "en" else npc.get("label_id"))
	var date_key := "day_%d" % int(_save.get("day", 1))
	var res := Neighborhood.claim_tip(_save, nid, date_key)
	_save = res["state"]
	if bool(res.get("claimed", false)):
		_save["mood"] = clampi(int(_save.get("mood", 65)) + 12, 0, 100)
		_save = Retention.record_mission_progress(_save, "neighbors", 1, _today_date_str())
		_save = Retention.evaluate_badges(_save)["save"]
		var tip_rp := int(res.get("tip_rp", 0))
		_save = Settings.append_daily_log(_save, {
			"day": int(_save.get("day", 1)),
			"kind": "chat",
			"title_id": "Sapa %s" % nname,
			"title_en": "Chatted w/ %s" % nname,
			"delta_rp": tip_rp,
		})
		SaveStore.save_to_slot(_save, _active_slot)
		_play_sfx(_wav_coin)
		var cur_tier := String(_save.get("active_tier_id", "kamar_kos"))
		var greet := Neighborhood.get_reactive_greeting(nid, cur_tier, _cur_phase, _cur_weather, _loc())
		_spawn_float_popup(player.position + Vector3(0.0, 1.85, 0.0), "+%s  +4 XP" % I18n.format_balance(tip_rp, _loc()))
		_show_toast("%s: \"%s\" (+%s, +12 %s)" % [nname, greet, I18n.format_balance(tip_rp, _loc()), _t("Semangat", "Mood")], nid, "happy")
	else:
		var cur_tier_idle := String(_save.get("active_tier_id", "kamar_kos"))
		var greet_idle := Neighborhood.get_reactive_greeting(nid, cur_tier_idle, _cur_phase, _cur_weather, _loc())
		_show_toast("%s: \"%s\"" % [nname, greet_idle], nid, "neutral")
	_refresh_hud()

func _nearest_shift_npc(max_dist: float = 1.75) -> Dictionary:
	if _world_mode != "shift":
		return {}
	var best: Dictionary = {}
	var best_d := max_dist
	for npc in _shift_npcs_data:
		var n3 = npc.get("node", null)
		var pos: Vector3 = (n3 as Node3D).position if (n3 != null and is_instance_valid(n3)) else npc.get("pos", Vector3.ZERO)
		var d := Vector2(player.position.x - pos.x, player.position.z - pos.z).length()
		if d < best_d:
			best_d = d
			best = npc
	return best

func _talk_to_shift_npc(npc: Dictionary) -> void:
	var nid := String(npc.get("id", "ibu_melati"))
	var nname := String(npc.get("label_en") if _loc() == "en" else npc.get("label_id"))
	var node3d = npc.get("node", null)
	if node3d != null and is_instance_valid(node3d):
		var to_p := Vector2(player.position.x - (node3d as Node3D).position.x, player.position.z - (node3d as Node3D).position.z)
		if to_p.length() > 0.05:
			(node3d as Node3D).rotation.y = atan2(to_p.x, to_p.y)
	var react := NpcRoster.get_shift_npc_reaction(nid, _loc())
	var line := String(react.get("text", _t("Semangat kerjanya ya!", "Keep up the good work!")))
	if not _chatted_shift_npcs.has(nid):
		_chatted_shift_npcs[nid] = true
		_call_state["trust"] = clampi(int(_call_state.get("trust", 60)) + int(react.get("trust", 4)), 0, 100)
		_call_state["mood"] = clampi(int(_call_state.get("mood", 60)) + int(react.get("mood", 6)), 0, 100)
		_play_sfx(_wav_coin)
		_show_toast("%s: \"%s\" (+%d Trust, +%d %s)" % [nname, line, int(react.get("trust", 4)), int(react.get("mood", 6)), _t("Semangat", "Mood")], nid, "happy")
	else:
		_play_sfx(_wav_click)
		_show_toast("%s: \"%s\"" % [nname, line], nid, "neutral")
	_refresh_hud()

func _on_player_arrived() -> void:
	if _pending_auto_chore_id != "" and _world_mode == "shift" and _active_chore_id == "":
		var target_cid := _pending_auto_chore_id
		_pending_auto_chore_id = ""
		var near := _nearest_hotspot()
		if near != null and near.chore_id == target_cid:
			_begin_nearest_chore()

func _try_tap_boost() -> void:
	if _active_chore_id == "" or _chore_boost_cd > 0.0:
		return
	var max_b := Progression.get_max_boosts_for_save(_save)
	if _chore_boosts_used >= max_b:
		return
	_chore_boosts_used += 1
	_chore_boost_cd = 0.35
	var ratio := _chore_progress / maxf(0.1, _chore_duration)
	var ev := ChoreEngine.evaluate_tap_boost(_active_chore_id, ratio)
	var boost_s := Progression.get_boost_seconds_for_save(_save) * float(ev.get("mult", 1.0))
	_chore_progress += boost_s
	var sweet_bonus := int(ev.get("bonus_rp", 0))
	if sweet_bonus > 0 and not _shift.is_empty():
		_shift["earned_rp"] = int(_shift.get("earned_rp", 0)) + sweet_bonus
	_save["shift_boost_count"] = int(_save.get("shift_boost_count", 0)) + 1
	_save = Retention.record_mission_progress(_save, "boosts", 1, _today_date_str())
	if bool(ev.get("perfect", false)):
		_play_sfx(_wav_coin)
	else:
		_play_chore_foley(_active_chore_id)
	_cam_punch = maxf(_cam_punch, 0.28 if bool(ev.get("perfect", false)) else 0.22)
	if player != null:
		var pop_txt := _t("Pas Banget! +%s" % I18n.format_balance(sweet_bonus, "id"), "Perfect! +%s" % I18n.format_balance(sweet_bonus, "en")) if bool(ev.get("perfect", false)) else _t("+Cepat!", "+Boost!")
		var pop_col := Color(0.45, 0.98, 0.56) if bool(ev.get("perfect", false)) else Color(0.99, 0.86, 0.28)
		_spawn_float_popup(player.position + Vector3(0.0, 1.85, 0.0), pop_txt, pop_col)
		var tool_prop := player.find_child("ChoreToolProp", true, false) as Node3D
		if tool_prop != null and tool_prop.visible:
			var tw_tool := create_tween()
			tool_prop.scale = Vector3(1.28, 1.28, 1.28)
			tw_tool.tween_property(tool_prop, "scale", Vector3.ONE, 0.14)

func _trigger_world_action() -> void:
	if _is_sleeping:
		return
	if _world_mode == "shift":
		if bool(_call_state.get("active_call", false)):
			_on_answer_call()
			return
		if _active_chore_id != "":
			_try_tap_boost()
			return
		if _near_jemuran():
			_rescue_jemuran()
			return
		if _near_clue():
			_collect_shift_clue()
			return
		if _nearest_hotspot() != null:
			_begin_nearest_chore()
			return
		var sn_shift := _nearest_shift_npc()
		if not sn_shift.is_empty():
			_talk_to_shift_npc(sn_shift)
			return
		_begin_nearest_chore()
		return
	var p := _nearest_portal()
	if p != null:
		var pid := String(p.get_meta("portal_id", ""))
		if pid == "exit_street":
			_enter_street_mode("home")
			return
		elif pid == "sleep_bed":
			_perform_sleep_recharge()
			return
		elif pid == "pray_mat":
			_trigger_prayer_action()
			return
		elif pid == "enter_home":
			_enter_home_mode()
			return
		elif pid == "enter_work":
			_start_shift()
			return
	if _world_mode == "street":
		var snpc := _nearest_street_npc()
		if not snpc.is_empty():
			_talk_to_street_npc(snpc)
			return
		_enter_home_mode()
	elif _world_mode == "home":
		_enter_street_mode("home")

func _begin_nearest_chore() -> void:
	if not _in_shift or _active_chore_id != "":
		return
	var hs := _nearest_hotspot()
	if hs == null:
		_show_toast(_t("Dekati lingkaran hijau untuk mengerjakan tugas.", "Walk near a green ring to start a chore."))
		return
	var cfg: Dictionary = ChoreEngine.CHORES[hs.chore_id]
	if int(_shift.get("energy", 0)) < int(cfg["energy"]):
		_show_toast(_t("Energi habis! Selesaikan shift atau istirahat.", "Low energy! Finish shift to rest."))
		return
	var skill_key := String(cfg["skill"])
	var sk_xp := int(_save.get("skill_xp", {}).get(skill_key, 0))
	var sk_lvl := Progression.skill_level_from_xp(sk_xp)
	var cur_mood := int(_call_state.get("mood", 60))
	_active_chore_id = hs.chore_id
	_chore_duration = ChoreEngine.effective_duration(hs.chore_id, sk_lvl, cur_mood)
	_chore_progress = 0.0
	_chore_boosts_used = 0
	_chore_boost_cd = 0.0
	player.set_cleaning(true)
	StreetPatrols.sync_chore_tool(player, String(ChoreEngine.CHORE_TOOLS.get(_active_chore_id, "broom")))
	_play_chore_foley(_active_chore_id)

func _finish_active_chore() -> void:
	var cid := _active_chore_id
	_active_chore_id = ""
	player.set_cleaning(false)
	StreetPatrols.sync_chore_tool(player, "")
	var tier := CareerTiers.get_tier(String(_save.get("active_tier_id", "kamar_kos")))
	var pay_mult := float(tier.get("pay_multiplier", 1.0))
	var cfg: Dictionary = ChoreEngine.CHORES[cid]
	var sk_lvl := Progression.skill_level_from_xp(int(_save.get("skill_xp", {}).get(String(cfg["skill"]), 0)))
	var res := ChoreEngine.complete_chore(_shift, cid, pay_mult, sk_lvl)
	if res["ok"]:
		_shift = res["shift"]
		_save = Retention.record_mission_progress(_save, "chores", 1, _today_date_str())
		var ev_xp_mult := float(_shift_event.get("xp_mult", 1.0))
		if ev_xp_mult > 1.0:
			var extra_xp := int(round(float(res["xp_gain"]) * (ev_xp_mult - 1.0)))
			_shift["xp_earned"] = int(_shift.get("xp_earned", 0)) + extra_xp
		var ev_e_mult := float(_shift_event.get("energy_mult", 1.0))
		if ev_e_mult < 1.0:
			var saved_e := int(round(float(cfg["energy"]) * (1.0 - ev_e_mult)))
			_shift["energy"] = mini(int(_shift.get("max_energy", 100)), int(_shift.get("energy", 0)) + saved_e)
		var boost_rp := 0
		if _chore_boosts_used >= 2:
			boost_rp = ChoreEngine.TAP_BOOST_BONUS_RP
			_shift["earned_rp"] = int(_shift.get("earned_rp", 0)) + boost_rp
		_call_state = MajikanCall.consume_chore_mood(_call_state, 6)
		for c in hotspots_root.get_children():
			if c is ChoreHotspotScene and c.chore_id == cid:
				c.mark_completed()
		_play_sfx(_wav_coin)
		var total_c_rp := int(res["payout_rp"]) + boost_rp
		var popup_txt := "+%s  +%d XP%s" % [I18n.format_balance(total_c_rp, _loc()), int(res["xp_gain"]), " ⚡" if boost_rp > 0 else ""]
		_spawn_float_popup(player.position + Vector3(0.0, 1.85, 0.0), popup_txt)
		_burst_chore_sparkles(player.position)
		_cam_punch = 0.24
		_show_toast(popup_txt)
		for npc in _shift_npcs_data:
			var n3d = npc.get("node", null)
			if n3d != null and is_instance_valid(n3d):
				var to_p := Vector2(player.position.x - (n3d as Node3D).position.x, player.position.z - (n3d as Node3D).position.z)
				if to_p.length() > 0.05 and to_p.length() < 4.5:
					(n3d as Node3D).rotation.y = atan2(to_p.x, to_p.y)
		if ChoreEngine.is_shift_complete(_shift):
			player.play_celebrate()
			_play_sfx(_wav_fanfare)
			_show_toast(_t("Semua tugas beres! Tekan Selesai Shift untuk gajian.", "All chores done! Tap End Shift to collect pay."))
			if int(_save.get("tutorial_step", 0)) < 3:
				_save = WishlistStory.advance_tutorial(_save, 3)
				SaveStore.save_to_slot(_save, _active_slot)
	_refresh_hud()

func _finish_shift() -> void:
	if not _in_shift:
		return
	var final_clean_pct := ChoreEngine.compute_room_cleanliness(_shift)
	_clear_shift_events()
	var prev_lv := Progression.level_from_xp(int(_save.get("xp", 0)))
	var prev_xp := int(_save.get("xp", 0))
	var res := Progression.settle_shift(_save, _shift, _call_state)
	if not res["ok"]:
		return
	res["clean_pct"] = final_clean_pct
	_save = res["save"]
	_shift = res["shift"]
	if bool(res.get("aborted", false)):
		SaveStore.save_to_slot(_save, _active_slot)
		_enter_street_mode("shift")
		_show_toast(_t("Belum ada tugas selesai — shift dibatalkan (tanpa bayaran).", "No chores completed — shift cancelled (no pay)."))
		return
	var ev_bonus_rp := 0
	if not bool(res.get("fired", false)):
		_save = Retention.record_mission_progress(_save, "shifts", 1, _today_date_str())
		var ev_pm := float(_shift_event.get("pay_mult", 1.0))
		if ev_pm > 1.0:
			ev_bonus_rp += int(round(float(res.get("payout_rp", 0)) * (ev_pm - 1.0)))
		ev_bonus_rp += int(_shift_event.get("flat_bonus_rp", 0))
		if ev_bonus_rp > 0:
			_save["balance_rp"] = int(_save.get("balance_rp", 0)) + ev_bonus_rp
			_save["total_earnings_rp"] = int(_save.get("total_earnings_rp", 0)) + ev_bonus_rp
			res["payout_rp"] = int(res.get("payout_rp", 0)) + ev_bonus_rp
	var bg_eval := Retention.evaluate_badges(_save)
	_save = bg_eval["save"]
	for nb in (bg_eval.get("newly_unlocked", []) as Array):
		var b_lbl := String(nb.get("label_en" if _loc() == "en" else "label_id", ""))
		_show_toast(_t("Lencana Baru: %s (+25 XP)!" % b_lbl, "New Badge: %s (+25 XP)!" % b_lbl), "player", "happy")
	_save = Settings.append_daily_log(_save, {
		"day": int(_save.get("day", 1)) - 1,
		"kind": "fired" if bool(res.get("fired", false)) else "shift",
		"title_id": "Dipecat di shift" if bool(res.get("fired", false)) else "Shift selesai",
		"title_en": "Fired on shift" if bool(res.get("fired", false)) else "Shift completed",
		"delta_rp": int(res.get("payout_rp", 0)),
	})
	if int(_save.get("tutorial_step", 0)) < 4:
		_save = WishlistStory.advance_tutorial(_save, 4)
	SaveStore.save_to_slot(_save, _active_slot)
	var new_lv := Progression.level_from_xp(int(_save.get("xp", 0)))
	_pending_story_tier = WishlistStory.get_newly_unlocked_chapter_tier(prev_xp, int(_save.get("xp", 0)), _save)
	_pending_level_unlocks = Progression.get_xp_unlocks(prev_xp, int(_save.get("xp", 0)), _loc()) if new_lv > prev_lv else []
	if new_lv > prev_lv:
		_play_sfx(_wav_fanfare)
	else:
		_play_sfx(_wav_coin)
	_enter_home_mode()
	var tier := CareerTiers.get_tier(String(_save.get("active_tier_id", "kamar_kos")))
	if Progression.should_collect_weekly_rent(_save, tier):
		_open_rent_modal(res, new_lv if new_lv > prev_lv else 0)
	elif new_lv > prev_lv:
		_open_levelup_modal(new_lv, res)
	else:
		_open_summary_modal(res)
	if not bool(tier.get("live_in_room_provided", false)) and int(_save.get("day", 1)) in [5, 6]:
		var rent_fmt := I18n.format_balance(120000, _loc())
		_show_toast(_t("Ingat: Sewa kos %s jatuh tempo Hari 7!" % rent_fmt, "Reminder: %s kos rent due on Day 7!" % rent_fmt))

func _process(delta: float) -> void:
	if _capture_path != "" and not _captured:
		_frame_cnt += 1
		if _frame_cnt >= 4:
			_captured = true
			call_deferred("_do_capture")

	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and _toast_panel != null:
			_toast_panel.visible = false

	if _chore_boost_cd > 0.0:
		_chore_boost_cd = maxf(0.0, _chore_boost_cd - delta)

	if _float_popups.size() > 0:
		for fi in range(_float_popups.size() - 1, -1, -1):
			var fp: Dictionary = _float_popups[fi]
			var lbl: Label = fp["node"]
			fp["elapsed"] = float(fp["elapsed"]) + delta
			var ratio := float(fp["elapsed"]) / float(fp["dur"])
			if not is_instance_valid(lbl) or ratio >= 1.0:
				if is_instance_valid(lbl):
					lbl.queue_free()
				_float_popups.remove_at(fi)
			else:
				lbl.position.y = float(fp["start_y"]) - ratio * 46.0
				lbl.modulate.a = clampf(1.0 - ratio * 0.9, 0.0, 1.0)

	if _footstep_cd > 0.0:
		_footstep_cd = maxf(0.0, _footstep_cd - delta)
	if not _muted and not _smoke_mode and _audio_unlocked and _active_chore_id == "" and player.velocity.length() > 0.5 and _footstep_cd <= 0.0:
		_footstep_cd = 0.36
		if _step_player != null and _wav_step != null:
			_step_player.play()

	var ui_cover := (_title_wrap != null and _title_wrap.visible) or (_onboarding_wrap != null and _onboarding_wrap.visible) or (_modal_backdrop != null and _modal_backdrop.visible) or (_dialogue_bar != null and _dialogue_bar.visible) or (_phone_os_wrap != null and _phone_os_wrap.visible)
	if _spotlight_wrap != null and _spotlight_wrap.visible and _spotlight_hand != null:
		_spotlight_t += delta * 5.0
		_spotlight_hand.position.y = _spotlight_hand_base_pos.y + sin(_spotlight_t) * 6.0
	if not ui_cover and bool(_save.get("onboarding_done", false)):
		var prev_orders: Array = _save.get("courier_orders", [])
		if not prev_orders.is_empty():
			_save = Progression.tick_courier_orders(_save, delta)
			_refresh_courier_toast()
		_clock_accum += delta * 2.0
		if _clock_accum >= 1.0:
			var step_m := int(_clock_accum)
			_clock_accum -= float(step_m)
			var prev_m := int(_save.get("game_minutes", 360))
			var cur_m := mini(1439, prev_m + step_m)
			if cur_m != prev_m:
				_save["game_minutes"] = cur_m
				var cur_day := int(_save.get("day", 1))
				var trig := LifeRhythm.check_prayer_trigger(prev_m, cur_m, int(_save.get("prayed_day", cur_day)), cur_day, _save.get("prayed_today", []), bool(_save.get("prayer_reminders", true)))
				if bool(trig.get("triggered", false)):
					_last_prayer_id = String(trig["id"])
					_play_sfx(_wav_coin)
					var p_lbl := String(trig["label_en" if _loc() == "en" else "label_id"])
					if _last_prayer_id == "maghrib" and LifeRhythm.get_season(cur_day) == "ramadhan":
						_show_toast(_t("Adzan Maghrib! Waktunya Sholat & Buka Puasa Takjil (Menu / Sajadah).", "Maghrib time! Time to pray & break fast (Menu / Prayer Mat)."), "player", "happy")
					else:
						_show_toast(_t("Waktu Sholat %s tiba! (+12 Mood lewat Menu/Kamar)" % p_lbl, "%s prayer time! (+12 Mood via Menu/Room)" % p_lbl), "player", "happy")
				elif LifeRhythm.is_late_night(cur_m) and _late_night_warned_day != cur_day:
					_late_night_warned_day = cur_day
					_show_toast(_t("Sudah larut malam (21:30)! Pulang ke kamar & Tidur di Kasur.", "Late night (21:30)! Head back & sleep in your bed."))
				if LifeRhythm.get_phase_from_minutes(cur_m) != _cur_phase:
					_refresh_atmosphere()
				if _lbl_meta != null:
					_lbl_meta.text = _format_meta_clock()

	# Smooth camera follow (or close-up turntable framing during Onboarding!)
	if _onboarding_wrap != null and _onboarding_wrap.visible:
		var ob_vp := get_viewport().get_visible_rect().size
		var ob_is_port := ob_vp.x < ob_vp.y
		var ob_cam_target := player.position + (Vector3(0.0, 1.38, 2.75) if ob_is_port else Vector3(0.65, 1.36, 2.78))
		var ob_look_target := player.position + (Vector3(0.0, 0.56, 0.0) if ob_is_port else Vector3(0.62, 0.84, 0.0))
		cam.position = cam.position.lerp(ob_cam_target, minf(1.0, delta * 6.0))
		cam.look_at(ob_look_target, Vector3.UP)
		return

	if _cam_punch > 0.0:
		_cam_punch = maxf(0.0, _cam_punch - delta * 1.45)

	var cam_offset := Vector3(2.90, 2.95, 3.85) if _world_mode == "street" else Vector3(3.15, 3.10, 3.50)
	cam_offset *= (1.0 - _cam_punch * 0.14)
	var cam_target := player.position + cam_offset
	cam.position = cam.position.lerp(cam_target, minf(1.0, delta * 5.0))
	cam.look_at(player.position + Vector3(0.0, 0.80, -0.35), Vector3.UP)

	if _world_mode == "home" and _fan_blades.size() > 0 and ("kipas_angin" in _save.get("unlocked_kos_upgrades", [])):
		for fb in _fan_blades:
			if is_instance_valid(fb):
				(fb as Node3D).rotate_z(delta * 5.5)

	if _world_mode == "street" and _traffic_items.size() > 0:
		StreetTraffic.step_vehicles(_traffic_items, delta, player.position)
		for ti in range(mini(_traffic_items.size(), _traffic_nodes.size())):
			var tn: Node3D = _traffic_nodes[ti]
			if is_instance_valid(tn):
				StreetTraffic.sync_vehicle_node(tn, _traffic_items[ti], _cur_phase == "malam")

	if _world_mode == "street" and _street_npcs_data.size() > 0:
		StreetPatrols.step_patrols(_street_npcs_data, _street_cfg, player.position, delta, _cur_weather == "hujan")

	var np := _nearest_portal()
	var sn := _nearest_street_npc()
	var modal_cover := _modal_backdrop != null and _modal_backdrop.visible
	# Wayfinding Label3D fade: hide during UI overlays/dialogue/phone/spotlight, overlapping player, or when _world_prompt announces the portal
	var hide_labels := ui_cover or modal_cover or (_dialogue_bar != null and _dialogue_bar.visible) or (_phone_os_wrap != null and _phone_os_wrap.visible) or (_spotlight_wrap != null and _spotlight_wrap.visible)
	for pnode in _portal_nodes:
		if is_instance_valid(pnode):
			var p_lbl3d := pnode.find_child("_Label3D", false, false) as Label3D
			if p_lbl3d != null:
				var pdist: float = (pnode as Node3D).position.distance_to(player.position)
				p_lbl3d.visible = (not hide_labels) and pnode != np and pdist >= 0.85 and pdist <= 3.2
	for s_npc in _street_npcs_data:
		var sn_node = s_npc.get("node", null)
		if sn_node != null and is_instance_valid(sn_node):
			var n_lbl3d := sn_node.find_child("_Label3D", false, false) as Label3D
			if n_lbl3d != null:
				n_lbl3d.visible = (not hide_labels) and sn_node.position.distance_to(player.position) <= 3.2

	var show_key := _show_keyboard_hints()
	if ui_cover or modal_cover or (_dialogue_bar != null and _dialogue_bar.visible) or (_phone_os_wrap != null and _phone_os_wrap.visible):
		if _world_prompt != null:
			_world_prompt.visible = false
	elif not _in_shift:
		if _world_prompt != null:
			if np != null and not cam.is_position_behind(np.global_position):
				var p_lbl := String(np.get_meta("label_en" if _loc() == "en" else "label_id", ""))
				var pk := "p:" + p_lbl + ":" + str(show_key)
				if pk != _last_prompt_key:
					_last_prompt_key = pk
					_world_prompt.text = Atmosphere.format_action_prompt(p_lbl, _loc(), show_key)
				_position_world_prompt(np.global_position + Vector3(0.0, 0.72, 0.0))
				_world_prompt.visible = true
				var short_lbl := p_lbl.split(" ")[0] if p_lbl.length() > 8 else p_lbl
				if _last_dock_action_key != short_lbl:
					_last_dock_action_key = short_lbl
					_set_dock_label("action", short_lbl)
			elif not sn.is_empty():
				var npos: Vector3 = sn.get("pos", Vector3.ZERO)
				if not cam.is_position_behind(npos):
					var n_lbl := String(sn.get("label_en") if _loc() == "en" else sn.get("label_id"))
					var nk := "s:" + n_lbl + ":" + str(show_key)
					if nk != _last_prompt_key:
						_last_prompt_key = nk
						_world_prompt.text = Atmosphere.format_action_prompt("%s %s" % [_t("Ngobrol:", "Chat:"), n_lbl], _loc(), show_key)
					_position_world_prompt(npos + Vector3(0.0, 1.55, 0.0))
					_world_prompt.visible = true
					var chat_lbl := _t("Ngobrol", "Chat")
					if _last_dock_action_key != chat_lbl:
						_last_dock_action_key = chat_lbl
						_set_dock_label("action", chat_lbl)
				else:
					_world_prompt.visible = false
			else:
				_world_prompt.visible = false
				var idle_lbl := _t("Masuk", "Enter") if _world_mode == "street" else _t("Keluar", "Outside")
				if _last_dock_action_key != idle_lbl:
					_last_dock_action_key = idle_lbl
					_set_dock_label("action", idle_lbl)
		return

	_shift_elapsed_s += delta
	var next_phase := Atmosphere.get_phase(_world_mode, int(_save.get("day", 1)), _shift_elapsed_s)
	if next_phase != _cur_phase:
		_refresh_atmosphere()
	_lbl_meta.text = _format_meta_clock()

	# Highlight nearest chore & float world prompt
	var near := _nearest_hotspot()
	for c in hotspots_root.get_children():
		if c is ChoreHotspotScene:
			c.set_highlighted(c == near)
	if _world_prompt != null:
		if ui_cover or modal_cover or (_dialogue_bar != null and _dialogue_bar.visible) or (_phone_os_wrap != null and _phone_os_wrap.visible):
			_world_prompt.visible = false
		elif _near_jemuran() and _active_chore_id == "" and not cam.is_position_behind(_jemuran_node.global_position):
			var j_sec := int(ceil(float(_jemuran_state.get("remaining_s", 0.0))))
			var j_lbl := _t("Selamatkan Jemuran! (%dd)" % j_sec, "Save Laundry! (%ds)" % j_sec)
			_last_prompt_key = "j:" + str(j_sec)
			_world_prompt.text = Atmosphere.format_action_prompt(j_lbl, _loc(), show_key)
			_position_world_prompt(_jemuran_node.global_position + Vector3(0.0, 0.95, 0.0))
			_world_prompt.visible = true
			var j_btn_lbl := _t("Jemuran", "Rescue")
			if _last_dock_action_key != j_btn_lbl:
				_last_dock_action_key = j_btn_lbl
				_set_dock_label("action", j_btn_lbl)
		elif _near_clue() and _active_chore_id == "" and not cam.is_position_behind(_clue_node.global_position):
			var cl_lbl := _t("Periksa Jejak Cerita", "Inspect Clue")
			var clk := "cl:" + cl_lbl + ":" + str(show_key)
			if clk != _last_prompt_key:
				_last_prompt_key = clk
				_world_prompt.text = Atmosphere.format_action_prompt(cl_lbl, _loc(), show_key)
			_position_world_prompt(_clue_node.global_position + Vector3(0.0, 0.45, 0.0))
			_world_prompt.visible = true
			var cl_btn_lbl := _t("Periksa", "Inspect")
			if _last_dock_action_key != cl_btn_lbl:
				_last_dock_action_key = cl_btn_lbl
				_set_dock_label("action", cl_btn_lbl)
		elif near != null and _active_chore_id == "" and not cam.is_position_behind(near.global_position):
			var w_lbl: String = near.label_en if _loc() == "en" else near.label_id
			var wk := "c:" + w_lbl + ":" + str(show_key)
			if wk != _last_prompt_key:
				_last_prompt_key = wk
				_world_prompt.text = Atmosphere.format_action_prompt(w_lbl, _loc(), show_key)
			_position_world_prompt(near.global_position + Vector3(0.0, 0.65, 0.0))
			_world_prompt.visible = true
			var ch_lbl := _t("Kerjakan", "Chore")
			if _last_dock_action_key != ch_lbl:
				_last_dock_action_key = ch_lbl
				_set_dock_label("action", ch_lbl)
		elif _active_chore_id == "":
			var sn_sh := _nearest_shift_npc()
			if not sn_sh.is_empty():
				var sh_pos: Vector3 = sn_sh.get("pos", Vector3.ZERO)
				if not cam.is_position_behind(sh_pos):
					var sh_lbl := String(sn_sh.get("label_en") if _loc() == "en" else sn_sh.get("label_id"))
					var shk := "sh:" + sh_lbl + ":" + str(show_key)
					if shk != _last_prompt_key:
						_last_prompt_key = shk
						_world_prompt.text = Atmosphere.format_action_prompt("%s %s" % [_t("Sapa:", "Greet:"), sh_lbl], _loc(), show_key)
					_position_world_prompt(sh_pos + Vector3(0.0, 1.55, 0.0))
					_world_prompt.visible = true
					var gr_lbl := _t("Sapa", "Greet")
					if _last_dock_action_key != gr_lbl:
						_last_dock_action_key = gr_lbl
						_set_dock_label("action", gr_lbl)
				else:
					_world_prompt.visible = false
			else:
				_world_prompt.visible = false
				var ch_idle := _t("Kerjakan", "Chore")
				if _last_dock_action_key != ch_idle:
					_last_dock_action_key = ch_idle
					_set_dock_label("action", ch_idle)
		else:
			_world_prompt.visible = false
			var max_b_dock := Progression.get_max_boosts_for_save(_save)
			var fast_lbl := _t("Cepat! %d/%d" % [_chore_boosts_used, max_b_dock], "Fast! %d/%d" % [_chore_boosts_used, max_b_dock])
			if _last_dock_action_key != fast_lbl:
				_last_dock_action_key = fast_lbl
				_set_dock_label("action", fast_lbl)

	# Active chore progress
	if _active_chore_id != "":
		_chore_progress += delta
		_chore_bar_wrap.visible = true
		_bar_chore.max_value = _chore_duration
		_bar_chore.value = _chore_progress
		var cfg: Dictionary = ChoreEngine.CHORES[_active_chore_id]
		var ratio_bar := _chore_progress / maxf(0.1, _chore_duration)
		for hs_m in hotspots_root.get_children():
			if hs_m is ChoreHotspotScene and hs_m.chore_id == _active_chore_id:
				hs_m.set_progress(ratio_bar)
		var is_sweet_now := bool(ChoreEngine.evaluate_tap_boost(_active_chore_id, ratio_bar).get("perfect", false))
		var max_b_hint := Progression.get_max_boosts_for_save(_save)
		var tap_hint := ""
		if _chore_boosts_used < max_b_hint:
			if is_sweet_now:
				tap_hint = _t("  ★ PAS! Ketuk!", "  ★ SWEET SPOT!")
			else:
				tap_hint = _t("  [Tekan E = Cepat!]", "  [Press E = Boost!]") if show_key else _t("  [Ketuk \"Cepat!\" = Boost!]", "  [Tap \"Fast!\" = Boost!]")
		else:
			tap_hint = "  ⚡"
		_lbl_chore_prog.text = "%s%s" % [String(cfg["label_en"] if _loc() == "en" else cfg["label_id"]), tap_hint]
		if _chore_progress >= _chore_duration:
			_chore_bar_wrap.visible = false
			_finish_active_chore()
	else:
		_chore_bar_wrap.visible = false

	if _clue_node != null and is_instance_valid(_clue_node):
		_clue_node.rotation.y += delta * 2.2
	if _jemuran_node != null and is_instance_valid(_jemuran_node):
		_jemuran_node.scale = Vector3.ONE * (1.0 + sin(_shift_elapsed_s * 7.0) * 0.08)

	if _in_shift and _shift_npcs_data.size() > 0:
		HouseholdSchedules.step_shift_npcs(_shift_npcs_data, player.position, delta, ui_cover or modal_cover)

	if _in_shift and not ui_cover and not bool(_call_state.get("fired", false)):
		var tier_id_j := String(_save.get("active_tier_id", "kamar_kos"))
		var done_j := (_shift.get("completed_ids", []) as Array).size()
		var tot_j := (_shift.get("assigned_ids", []) as Array).size()
		if not _jemuran_triggered_shift and JemuranEvent.should_trigger(tier_id_j, _shift_elapsed_s, _jemuran_triggered_shift, done_j, tot_j):
			_jemuran_triggered_shift = true
			var jpos := JemuranEvent.get_stage_pos(tier_id_j)
			_jemuran_state = JemuranEvent.create_state(jpos)
			_spawn_jemuran_marker(jpos)
			_play_sfx(_wav_thunder)
			_cam_punch = 0.25
			_show_toast(_t("⚡ GUNTUR! Jemuran mau kehujanan — lari ke teras & selamatkan (15d)!", "⚡ THUNDER! Laundry outside is about to get soaked — rescue it (15s)!"), "player", "worried")
		elif bool(_jemuran_state.get("active", false)):
			_jemuran_state = JemuranEvent.tick_state(_jemuran_state, delta)
			if bool(_jemuran_state.get("failed", false)):
				if _jemuran_node != null and is_instance_valid(_jemuran_node):
					_jemuran_node.queue_free()
				_jemuran_node = null
				_call_state["mood"] = maxi(0, int(_call_state.get("mood", 60)) - 6)
				_call_state["trust"] = maxi(0, int(_call_state.get("trust", 60)) - 5)
				_play_sfx(_wav_buzz)
				_show_toast(_t("Yah! Jemuran keburu kehujanan (-5 Trust).", "Oh no! Laundry got soaked in the rain (-5 Trust)."), "player", "worried")
		var blocked_dil := ui_cover or modal_cover or bool(_call_state.get("active_call", false)) or bool(_jemuran_state.get("active", false)) or not _active_chore_id.is_empty()
		if not _smoke_mode and _capture_path == "" and HouseholdDilemmas.should_trigger(tier_id_j, _shift_elapsed_s, _dilemma_triggered_shift, done_j, blocked_dil):
			_dilemma_triggered_shift = true
			_open_dilemma_modal(HouseholdDilemmas.pick_for_tier(tier_id_j))

	# Majikan call & distraction loop (active strictly during shifts, never on Title/Home/Modals!)
	if _in_shift and not ui_cover and bool(_call_state.get("active_call", false)):
		var prev_warn := int(_call_state.get("warnings", 0))
		_call_state = MajikanCall.tick_call(_call_state, delta)
		if not bool(_call_state.get("active_call", false)) and int(_call_state.get("warnings", 0)) > prev_warn:
			_play_sfx(_wav_buzz)
			var w_txt := String(_call_state.get("last_warning_text_en" if _loc() == "en" else "last_warning_text", ""))
			_show_toast(w_txt)
			if bool(_call_state.get("fired", false)):
				_finish_shift()
				return
			_refresh_hud()
			return
		_refresh_call_banner()
	elif _in_shift and not ui_cover and not bool(_call_state.get("fired", false)):
		_call_cooldown -= delta
		if _call_cooldown <= 0.0:
			_call_cooldown = 16.0
			var reason := _t("Tolong bantu cek pintu depan sebentar!", "Please check the front gate right now!")
			_call_state = MajikanCall.start_call(_call_state, reason)
			_play_sfx(_wav_ring)
			_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		_unlock_audio()
	if _is_sleeping or (_onboarding_wrap != null and _onboarding_wrap.visible) or (_modal_backdrop != null and _modal_backdrop.visible):
		return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_E, KEY_SPACE]:
		if _in_shift and bool(_call_state.get("active_call", false)):
			_on_answer_call()
		else:
			_trigger_world_action()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _modal_backdrop != null and _modal_backdrop.visible:
			return
		var from := cam.project_ray_origin(event.position)
		var dir := cam.project_ray_normal(event.position)
		if absf(dir.y) > 0.01:
			var t := -from.y / dir.y
			if t > 0.0 and t < 40.0:
				var hit := from + dir * t
				_pending_auto_chore_id = ""
				if _world_mode == "shift" and _active_chore_id == "":
					for c in hotspots_root.get_children():
						if c is ChoreHotspotScene and not c.completed:
							if Vector2(hit.x - c.position.x, hit.z - c.position.z).length() <= 0.75:
								_pending_auto_chore_id = c.chore_id
								hit = Vector3(c.position.x, 0.0, c.position.z)
								break
				player.set_tap_target(hit)
	elif event is InputEventScreenTouch and event.pressed:
		if _modal_backdrop != null and _modal_backdrop.visible:
			return
		var from := cam.project_ray_origin(event.position)
		var dir := cam.project_ray_normal(event.position)
		if absf(dir.y) > 0.01:
			var t := -from.y / dir.y
			if t > 0.0 and t < 40.0:
				var hit := from + dir * t
				_pending_auto_chore_id = ""
				if _world_mode == "shift" and _active_chore_id == "":
					for c in hotspots_root.get_children():
						if c is ChoreHotspotScene and not c.completed:
							if Vector2(hit.x - c.position.x, hit.z - c.position.z).length() <= 0.75:
								_pending_auto_chore_id = c.chore_id
								hit = Vector3(c.position.x, 0.0, c.position.z)
								break
				player.set_tap_target(hit)

func _on_joy_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_joy_active = true
			_joy_touch_idx = event.index
			_update_joystick(event.position)
		elif event.index == _joy_touch_idx:
			_reset_joystick()
	elif event is InputEventScreenDrag and event.index == _joy_touch_idx:
		_update_joystick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_joy_active = true
			_update_joystick(event.position)
		else:
			_reset_joystick()
	elif event is InputEventMouseMotion and _joy_active:
		_update_joystick(event.position)

func _update_joystick(local_pos: Vector2) -> void:
	var center := Vector2(56.0, 56.0)
	var delta := local_pos - center
	var max_r := 40.0
	if delta.length() > max_r:
		delta = delta.normalized() * max_r
	_joy_knob.position = center + delta - Vector2(20.0, 20.0)
	player.joystick_input = delta / max_r

func _reset_joystick() -> void:
	_joy_active = false
	_joy_touch_idx = -1
	_joy_knob.position = Vector2(36.0, 36.0)
	player.joystick_input = Vector2.ZERO

func _on_answer_call() -> void:
	if not bool(_call_state.get("active_call", false)):
		return
	var prev_warn := int(_call_state.get("warnings", 0))
	_call_state = MajikanCall.respond_to_call(_call_state)
	if int(_call_state.get("warnings", 0)) > prev_warn:
		_play_sfx(_wav_buzz)
		_show_toast(String(_call_state.get("last_warning_text_en" if _loc() == "en" else "last_warning_text", "")))
	else:
		_play_sfx(_wav_coin)
		_save["calls_answered_count"] = int(_save.get("calls_answered_count", 0)) + 1
		_save = Retention.record_mission_progress(_save, "calls", 1, _today_date_str())
		_show_toast(_t("Sigap! Trust naik & bonus +%s" % I18n.format_balance(5000, "id"), "Quick answer! Trust up & +%s tip!" % I18n.format_balance(5000, "en")))
	_refresh_hud()

func _on_distract(activity_id: String) -> void:
	if not _in_shift:
		_show_toast(_t("Mulai shift dulu sebelum main HP.", "Start a shift first."))
		return
	if int(_call_state.get("distractions_used", 0)) >= MajikanCall.MAX_DISTRACTIONS_PER_SHIFT:
		_show_toast(_t("HP dipakai maksimal 2x per shift agar tidak ketahuan Majikan!", "Phone limit reached (2x per shift)!"))
		return
	_call_state = MajikanCall.apply_distraction(_call_state, activity_id)
	_shift = ChoreEngine.rest_recover(_shift, 8)
	_play_sfx(_wav_click)
	_show_toast(_t("Semangat +Energi naik! Hati-hati panggilan Majikan.", "Mood + Energy up! Watch for employer calls."))
	_refresh_hud()

func _on_viewport_size_changed() -> void:
	var win_node := get_window()
	if win_node != null and DisplayServer.get_name() != "headless":
		var w_sz := Vector2(DisplayServer.window_get_size())
		if w_sz.x > 0.0 and w_sz.y > 0.0:
			var target_scale := Vector2i(720, clampi(int(round(720.0 * w_sz.y / w_sz.x)), 960, 1800)) if w_sz.x < w_sz.y else Vector2i(1280, 720)
			if win_node.content_scale_size != target_scale:
				win_node.content_scale_size = target_scale
	_apply_mobile_safe_area()
	if _phone_os_wrap != null and _phone_os_wrap.visible:
		_render_phone_app()
	_refresh_hud()

func _effective_window_size() -> Vector2:
	var scale := maxf(1.0, DisplayServer.screen_get_scale())
	var win := Vector2(DisplayServer.window_get_size()) / scale
	if win.x > 0.0 and win.y > 0.0:
		return win
	return get_viewport().get_visible_rect().size

func _show_keyboard_hints() -> bool:
	return Atmosphere.should_show_keyboard_hints(_effective_window_size(), DisplayServer.is_touchscreen_available(), OS.has_feature("mobile"))

func _position_world_prompt(world_pos: Vector3) -> void:
	if _world_prompt == null or cam == null:
		return
	var scr := cam.unproject_position(world_pos)
	var vp := get_viewport().get_visible_rect().size
	var sz := _world_prompt.get_combined_minimum_size().max(_world_prompt.size)
	_world_prompt.position = Atmosphere.clamp_world_prompt_pos(scr, sz, vp, _safe_margins)

func _format_meta_clock() -> String:
	return LifeRhythm.format_clock(int(_save.get("game_minutes", 360))).replace(":", ".")

func _set_dock_label(key: String, txt: String) -> void:
	if _dock_labels.has(key):
		var lbl := _dock_labels[key] as Label
		if lbl != null:
			lbl.text = txt

func _set_dock_badge(key: String, count_txt: String) -> void:
	if _dock_badges.has(key):
		var b := _dock_badges[key] as Label
		if b != null:
			b.text = count_txt
			b.visible = not count_txt.is_empty()

func _refresh_hud() -> void:
	var title_active := _title_wrap != null and _title_wrap.visible
	var ob_active := _onboarding_wrap != null and _onboarding_wrap.visible
	var dlg_active := _dialogue_bar != null and _dialogue_bar.visible
	var phone_os_active := _phone_os_wrap != null and _phone_os_wrap.visible
	var modal_active := _modal_backdrop != null and _modal_backdrop.visible
	var ui_cover := title_active or ob_active
	var overlay_cover := ui_cover or dlg_active or phone_os_active or modal_active
	var vp := _effective_window_size()
	var canvas_sz := get_viewport().get_visible_rect().size
	if canvas_sz.x <= 1.0:
		canvas_sz = Vector2(1280.0, 720.0)
	var show_joy := Atmosphere.should_show_virtual_joystick(vp, DisplayServer.is_touchscreen_available(), OS.has_feature("mobile"))
	var pad_l := float(_safe_margins.get("left", 0.0))
	var pad_b := float(_safe_margins.get("bottom", 0.0))
	if _npcs_root != null:
		_npcs_root.visible = not ob_active
	if hotspots_root != null:
		hotspots_root.visible = not ui_cover
	if _tl_card != null:
		_tl_card.visible = not ui_cover
	if _tr_vbox != null:
		_tr_vbox.visible = not ui_cover
	if _br_vbox != null:
		_br_vbox.visible = (not ui_cover) and (not dlg_active) and (not phone_os_active)
	if _joy_base != null:
		_joy_base.visible = show_joy and (not ui_cover) and (not dlg_active) and (not phone_os_active)
	if _hp_bottom_left != null:
		_hp_bottom_left.visible = (not ui_cover) and (not dlg_active) and (not phone_os_active)
		if show_joy and canvas_sz.x >= 920.0:
			_hp_bottom_left.offset_left = 122.0 + pad_l
			_hp_bottom_left.offset_right = 192.0 + pad_l
			_hp_bottom_left.offset_top = -90.0 - pad_b
			_hp_bottom_left.offset_bottom = -12.0 - pad_b
		elif show_joy:
			_hp_bottom_left.offset_left = 14.0 + pad_l
			_hp_bottom_left.offset_right = 84.0 + pad_l
			_hp_bottom_left.offset_top = -196.0 - pad_b
			_hp_bottom_left.offset_bottom = -118.0 - pad_b
		else:
			_hp_bottom_left.offset_left = 14.0 + pad_l
			_hp_bottom_left.offset_right = 84.0 + pad_l
			_hp_bottom_left.offset_top = -90.0 - pad_b
			_hp_bottom_left.offset_bottom = -12.0 - pad_b
	if _courier_toast != null:
		_courier_toast.offset_left = 14.0 + pad_l
		if show_joy and canvas_sz.x < 920.0:
			_courier_toast.offset_bottom = -206.0 - pad_b
			_courier_toast.offset_top = -274.0 - pad_b
		elif show_joy:
			_courier_toast.offset_bottom = -120.0 - pad_b
			_courier_toast.offset_top = -188.0 - pad_b
		else:
			_courier_toast.offset_bottom = -98.0 - pad_b
			_courier_toast.offset_top = -166.0 - pad_b
	_set_hud_focus_enabled(not overlay_cover)

	var xp := int(_save.get("xp", 0))
	var lv := Progression.level_from_xp(xp)
	var tier := CareerTiers.get_tier(String(_save.get("active_tier_id", "kamar_kos")))
	var p_name := String(_save.get("player_name", "Mbak Sari"))
	if _lbl_level_badge != null:
		_lbl_level_badge.text = "Lv %d" % lv
	_lbl_balance.text = I18n.format_balance(int(_save.get("balance_rp", 0)), _loc())
	_lbl_meta.text = LifeRhythm.format_clock(int(_save.get("game_minutes", 360))).replace(":", ".")
	if _lbl_day_sub != null:
		var cur_day := maxi(1, int(_save.get("day", 1)))
		var w_icon := "🌧" if _cur_weather == "hujan" else ("🌙" if _cur_phase == "malam" else "☀")
		_lbl_day_sub.text = "%s %d · %s" % [_t("HARI", "DAY"), cur_day, w_icon]

	var star_score := int(_call_state.get("trust", 60)) if _in_shift else clampi(40 + lv * 8, 40, 100)
	var filled_stars := clampi(int(round(float(star_score) / 20.0)), 1, 5)
	if _stars_row != null:
		for si in range(_stars_row.get_child_count()):
			var st_ic := _stars_row.get_child(si) as TextureRect
			if st_ic != null:
				st_ic.texture = Portraits.get_ui_icon("star_filled" if si < filled_stars else "star_empty")

	if _in_shift:
		var e_val := int(_shift.get("energy", 0))
		var e_max := maxi(1, int(_shift.get("max_energy", 100)))
		var e_pct := int(round(100.0 * float(e_val) / float(e_max)))
		var m_val := int(_call_state.get("mood", 60))
		_lbl_energy.text = "%s %d%%" % [_t("ENERGI", "ENERGY"), e_pct]
		_bar_energy.max_value = e_max
		_bar_energy.value = e_val
		if _lbl_mood != null:
			var bonus_tag := _t(" (+15%!)", " (+15%!)") if m_val >= 80 else (_t(" (Lelah)", " (Tired)") if m_val <= 25 else "")
			_lbl_mood.text = "%s %d%%%s" % [_t("SEMANGAT", "MOOD"), m_val, bonus_tag]
			_lbl_mood.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34) if m_val >= 80 else (Color(0.96, 0.56, 0.34) if m_val <= 25 else Color(0.76, 0.92, 1.0)))
		if _bar_mood != null:
			_bar_mood.max_value = 100
			_bar_mood.value = m_val
		_lbl_trust.text = "%s · %s" % [p_name, Economy.get_career_rank(xp, _loc())]

		var done_n := (_shift.get("completed_ids", []) as Array).size()
		var tot_n := (_shift.get("assigned_ids", []) as Array).size()
		var active_r := (_chore_progress / maxf(0.1, _chore_duration)) if _active_chore_id != "" else 0.0
		var clean_pct := ChoreEngine.compute_room_cleanliness(_shift, _active_chore_id, active_r)
		var arrow := " ▼" if _tasks_collapsed else " ▲"
		_lbl_tasks_hdr.text = "%d/%d %s · %d%%%s" % [done_n, tot_n, _t("BERSIH", "CLEAN"), clean_pct, arrow]
		if _btn_tasks_toggle != null:
			_btn_tasks_toggle.text = _lbl_tasks_hdr.text
		for c in _tasks_list.get_children():
			c.queue_free()
		for item in ChoreEngine.get_checklist_items(_shift, _loc()):
			var cid := String(item.get("id", ""))
			var row := Label.new()
			var mark := "✓" if bool(item["done"]) else "○"
			var reward_rp := int(ChoreEngine.CHORES.get(cid, {}).get("base_rp", 12000))
			row.text = "%s %s (%s)" % [mark, String(item["label"]), I18n.format_balance(reward_rp, _loc())]
			row.add_theme_font_size_override("font_size", 12)
			row.add_theme_color_override("font_color", Color(0.50, 0.95, 0.52) if bool(item["done"]) else Color(0.95, 0.94, 0.90))
			_tasks_list.add_child(row)
		var hint_row := Label.new()
		hint_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_row.text = Atmosphere.format_tasks_hint(_loc(), _show_keyboard_hints())
		hint_row.add_theme_font_size_override("font_size", 11)
		hint_row.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
		_tasks_list.add_child(hint_row)
		_tasks_list.visible = not _tasks_collapsed
		_tasks_card.visible = true

		_set_dock_label("shift", _t("Selesai", "Finish") if done_n >= tot_n else (_t("Pulang", "Leave") if done_n > 0 else _t("Batal", "Cancel")))
		if _dock_icons.has("shift"):
			(_dock_icons["shift"] as TextureRect).texture = Portraits.get_ui_icon("icon_door")
		_btn_action.visible = true
		if _dock_icons.has("action"):
			(_dock_icons["action"] as TextureRect).texture = Portraits.get_ui_icon("icon_broom")
		_set_dock_label("action", _t("Kerjakan", "Chore"))
	else:
		var max_e := Progression.get_max_energy(_save)
		var cur_e := clampi(int(_save.get("energy", max_e)), 0, max_e)
		var cur_e_pct := int(round(100.0 * float(cur_e) / float(maxi(1, max_e))))
		var tier_label := String(tier.get("house_type_en", tier.get("house_type", "")) if _loc() == "en" else tier.get("house_type", ""))
		var h_mood := clampi(int(_save.get("mood", 65)) + Progression.get_mood_bonus(_save), 0, 100)
		_lbl_energy.text = "%s %d%%" % [_t("ENERGI", "ENERGY"), cur_e_pct]
		_bar_energy.max_value = max_e
		_bar_energy.value = cur_e
		if _lbl_mood != null:
			var h_bonus := _t(" (+15%!)", " (+15%!)") if h_mood >= 80 else ""
			_lbl_mood.text = "%s %d%%%s" % [_t("SEMANGAT", "MOOD"), h_mood, h_bonus]
			_lbl_mood.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34) if h_mood >= 80 else Color(0.76, 0.92, 1.0))
		if _bar_mood != null:
			_bar_mood.max_value = 100
			_bar_mood.value = h_mood
		_lbl_trust.text = "%s · %s" % [p_name, tier_label]
		_tasks_card.visible = false
		if _dock_icons.has("shift"):
			(_dock_icons["shift"] as TextureRect).texture = Portraits.get_ui_icon("icon_broom")
		_set_dock_label("shift", _t("Shift", "Shift"))
		_btn_action.visible = true
		if _world_mode == "street":
			var near_p := _nearest_portal()
			var near_n := _nearest_street_npc()
			if near_p != null:
				var p_raw := String(near_p.get_meta("label_en" if _loc() == "en" else "label_id", _t("Masuk", "Enter")))
				_set_dock_label("action", p_raw.split(" ")[0] if p_raw.length() > 8 else p_raw)
				if _dock_icons.has("action"):
					(_dock_icons["action"] as TextureRect).texture = Portraits.get_ui_icon("icon_door")
			elif not near_n.is_empty():
				_set_dock_label("action", _t("Ngobrol", "Chat"))
				if _dock_icons.has("action"):
					(_dock_icons["action"] as TextureRect).texture = Portraits.get_ui_icon("app_chat")
			else:
				_set_dock_label("action", _t("Ngobrol", "Chat"))
				if _dock_icons.has("action"):
					(_dock_icons["action"] as TextureRect).texture = Portraits.get_ui_icon("app_chat")
		else:
			if _dock_icons.has("action"):
				(_dock_icons["action"] as TextureRect).texture = Portraits.get_ui_icon("icon_door")
			_set_dock_label("action", _t("Keluar", "Outside"))
	if _world_prompt != null and ui_cover:
		_world_prompt.visible = false

	if _btn_map != null:
		_btn_map.text = _t("Peta", "Map")
	if _btn_settings != null:
		var has_rw := Retention.has_unclaimed_daily_reward(_save, _today_date_str())
		_btn_settings.text = _t("Menu ★" if has_rw else "Menu", "Menu ★" if has_rw else "Menu")

	var badge_n := MajikanCall.get_phone_badge_count(_call_state) if _in_shift else 0
	var ready_orders := 0
	for ord in _save.get("courier_orders", []):
		if typeof(ord) == TYPE_DICTIONARY and float(ord.get("remaining_s", 1.0)) <= 0.01:
			ready_orders += 1
	var rem_st := WishlistStory.get_remittance_goal_status(_save, _loc())
	var tot_phone_badge := badge_n + ready_orders + (0 if bool(rem_st["completed"]) else 1)
	_lbl_phone_badge.text = str(tot_phone_badge) if tot_phone_badge <= 9 else "9+"
	_lbl_phone_badge.visible = tot_phone_badge > 0

	var affordable_ups := 0
	var bal_now := int(_save.get("balance_rp", 0))
	var owned_ups: Array = _save.get("unlocked_kos_upgrades", [])
	for ruid in Progression.KOS_UPGRADES.keys():
		if not (String(ruid) in owned_ups) and bal_now >= int(Progression.KOS_UPGRADES[ruid]["cost_rp"]):
			affordable_ups += 1
	_set_dock_badge("upgrade", str(affordable_ups) if affordable_ups > 0 else "")
	var has_claim_ret := Retention.has_unclaimed_daily_reward(_save, _today_date_str())
	_set_dock_badge("career", "!" if has_claim_ret else "")

	if _phone_popup != null:
		_phone_popup.visible = false
	_set_dock_label("career", _t("Karier", "Career"))
	_set_dock_label("wardrobe", _t("Seragam", "Outfits"))
	_set_dock_label("upgrade", _t("Upgrade", "Upgrade"))
	_btn_modal_close.text = _t("Tutup", "Close")
	_refresh_courier_toast()
	_refresh_tutorial_banner()
	_refresh_onboarding_texts()
	_refresh_call_banner()

func _refresh_tutorial_banner() -> void:
	if _tutorial_panel != null:
		_tutorial_panel.visible = false
	_refresh_spotlight()

func _auto_style_modal_buttons(node: Node) -> void:
	for ch in node.get_children():
		if ch is Button:
			var b := ch as Button
			if not b.has_meta("skip_autowrap"):
				b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 44.0)
			if not b.has_theme_stylebox_override("normal") and not b.has_meta("skip_auto_style"):
				var bg_c := Color(0.12, 0.15, 0.22) if b.disabled else Color(0.15, 0.19, 0.27)
				var bd_c := Color(0.38, 0.42, 0.50, 0.70) if b.disabled else Color(0.95, 0.78, 0.26, 0.85)
				var fg_c := Color(0.76, 0.78, 0.84) if b.disabled else Color(0.96, 0.95, 0.92)
				_style_btn(b, bg_c, bd_c, fg_c)
		elif ch.get_child_count() > 0:
			_auto_style_modal_buttons(ch)

func _fit_modal_scroll_height() -> void:
	if _modal_scroll == null or _modal_list == null:
		return
	var canvas_sz := get_viewport().get_visible_rect().size
	if canvas_sz.x <= 1.0 or canvas_sz.y <= 1.0:
		canvas_sz = Vector2(1280.0, 720.0)
	var scroll_w := (canvas_sz.x - 64.0) if canvas_sz.x < 720.0 else minf(740.0, canvas_sz.x - 144.0)
	_modal_scroll.custom_minimum_size = Vector2(scroll_w, 0.0)
	_modal_list.custom_minimum_size = Vector2(scroll_w - 8.0, 0.0)
	var measured_h := _modal_list.size.y if _modal_list.size.x >= scroll_w * 0.85 else _modal_list.get_combined_minimum_size().y
	var content_h := minf(measured_h, _modal_list.get_combined_minimum_size().y) + 12.0 if _modal_list.size.x >= scroll_w * 0.85 else _modal_list.get_combined_minimum_size().y + 12.0
	var max_h := minf(700.0, maxf(200.0, canvas_sz.y - 135.0))
	_modal_scroll.custom_minimum_size = Vector2(scroll_w, clampf(content_h, 48.0, max_h))
	if _modal_card != null:
		_modal_card.reset_size()
	if _modal_list.size.x < scroll_w * 0.85 and _modal_backdrop != null and _modal_backdrop.visible:
		call_deferred("_fit_modal_scroll_height")

func _show_modal() -> void:
	if _is_sleeping:
		return
	var canvas_sz := get_viewport().get_visible_rect().size
	if canvas_sz.x <= 1.0 or canvas_sz.y <= 1.0:
		canvas_sz = Vector2(1280.0, 720.0)
	if _modal_card != null:
		var card_w := (canvas_sz.x - 32.0) if canvas_sz.x < 720.0 else minf(780.0, canvas_sz.x - 100.0)
		_modal_card.custom_minimum_size = Vector2(card_w, 0.0)
	if _modal_list != null:
		_auto_style_modal_buttons(_modal_list)
	if _modal_scroll != null:
		_fit_modal_scroll_height()
	if _modal_backdrop != null:
		_modal_backdrop.visible = true
	_set_hud_focus_enabled(false)
	_refresh_courier_toast()
	call_deferred("_fit_modal_scroll_height")
	if _btn_modal_close != null and _btn_modal_close.visible:
		_btn_modal_close.call_deferred("grab_focus")
	elif _modal_list != null and _modal_list.get_child_count() > 0:
		for ch in _modal_list.get_children():
			if ch is Button and not (ch as Button).disabled:
				(ch as Button).call_deferred("grab_focus")
				break
	_refresh_tutorial_banner()

func _refresh_call_banner() -> void:
	var active_call := _in_shift and bool(_call_state.get("active_call", false))
	_call_banner.visible = active_call
	if active_call and _toast_panel != null:
		_toast_panel.visible = false
	_refresh_tutorial_banner()
	if active_call:
		var pers := MajikanProfiles.get_personality(String(_call_state.get("personality", "ramah")))
		var pat := float(pers.get("call_patience_s", 12.0)) * float(_call_state.get("patience_mult", 1.0))
		var rem := maxf(0.0, pat - float(_call_state.get("call_elapsed_s", 0.0)))
		if _call_portrait != null:
			var prof_id := String(_save.get("active_profile_id", "ibu_kos_melati"))
			var spk := "ibu_melati" if "melati" in prof_id else ("ibu_citra" if "citra" in prof_id else ("pak_hendra" if "hendra" in prof_id else ("pak_budi" if "budi" in prof_id else "ibu_sari")))
			_call_portrait.texture = Portraits.get_portrait(spk, "strict")
		_lbl_call_title.text = "%s: %s (%.0fs)" % [_t("MAJIKAN", "EMPLOYER"), String(_call_state.get("call_reason", "")), rem]
		_bar_call.max_value = pat
		_bar_call.value = rem
		_btn_answer.text = _t("Jawab Cepat!", "Answer Now!")

func _clear_modal() -> void:
	if _btn_modal_close != null:
		_btn_modal_close.visible = true
	if _modal_list != null:
		for c in _modal_list.get_children():
			_modal_list.remove_child(c)
			c.queue_free()

func _open_career_modal() -> void:
	_clear_modal()
	_modal_title.text = _t("Papan Lowongan & Tingkatan Karier", "Career Tiers & Job Board")
	var xp := int(_save.get("xp", 0))
	var xpp := Progression.get_xp_progress(xp)
	var rank_str := Economy.get_career_rank(xp, _loc())
	var bonus_pct := int(round(Progression.get_level_tip_bonus(xp) * 100.0))
	var rank_lbl := Label.new()
	rank_lbl.text = "%s • Lv.%d (%d/%d XP) • +%d%% %s" % [rank_str, int(xpp["level"]), int(xpp["xp_in_level"]), int(xpp["xp_needed"]), bonus_pct, _t("Kontrak", "Contract")]
	rank_lbl.add_theme_font_size_override("font_size", 12)
	rank_lbl.add_theme_color_override("font_color", Color(0.55, 0.96, 0.72))
	_modal_list.add_child(rank_lbl)
	var xp_bar := ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(400, 10)
	xp_bar.max_value = int(xpp["xp_needed"])
	xp_bar.value = int(xpp["xp_in_level"])
	xp_bar.show_percentage = false
	_style_bar(xp_bar, Color(0.96, 0.78, 0.26), Color(0.16, 0.19, 0.24))
	_modal_list.add_child(xp_bar)
	var sk: Dictionary = _save.get("skill_xp", {})
	var sk_lbl := Label.new()
	sk_lbl.text = "%s: %s Lv.%d • %s Lv.%d • %s Lv.%d • %s Lv.%d" % [
		_t("Keahlian", "Skills"),
		_t("Menyapu", "Sweep"), Progression.skill_level_from_xp(int(sk.get("sweeping", 0))),
		_t("Rapikan", "Tidy"), Progression.skill_level_from_xp(int(sk.get("tidiness", 0))),
		_t("Masak", "Cook"), Progression.skill_level_from_xp(int(sk.get("cooking", 0))),
		_t("Setrika", "Iron"), Progression.skill_level_from_xp(int(sk.get("laundry", 0))),
	]
	sk_lbl.add_theme_font_size_override("font_size", 12)
	sk_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34))
	_modal_list.add_child(sk_lbl)
	var perk_lbl := Label.new()
	perk_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perk_lbl.text = _t(
		"Perk Lv.3: Sapu (+1 Boost) • Rapikan (0.85s Boost) • Masak (Bekal Gratis) • Setrika (+10% Tip)",
		"Lv.3 Perks: Sweep (+1 Boost) • Tidy (0.85s Boost) • Cook (Free Meal) • Iron (+10% Tip)"
	)
	perk_lbl.add_theme_font_size_override("font_size", 11)
	perk_lbl.add_theme_color_override("font_color", Color(0.76, 0.88, 0.94))
	_modal_list.add_child(perk_lbl)
	var xp_cur_career := int(_save.get("xp", 0))
	var cur_id := String(_save.get("active_tier_id", "kamar_kos"))
	for t in CareerTiers.get_all_tiers():
		var tid := String(t["id"])
		var unlocked := CareerTiers.can_access_tier(tid, xp_cur_career)
		var btn := Button.new()
		var badge := "✓ " if tid == cur_id else ("" if unlocked else "🔒 ")
		var room_tag := _t(" + Kamar ART", " + Live-In Room") if bool(t["live_in_room_provided"]) else ""
		var h_name := String(t.get("house_type_en", t["house_type"]) if _loc() == "en" else t["house_type"])
		var act_tag := _t(" [Aktif]", " [Active]") if tid == cur_id else ""
		btn.text = "%s%s (%d XP • %.1fx%s)%s" % [badge, h_name, int(t["min_xp"]), float(t["pay_multiplier"]), room_tag, act_tag]
		btn.disabled = not unlocked
		if tid == cur_id:
			_style_btn(btn, Color(0.18, 0.44, 0.36), Color(0.98, 0.84, 0.34))
		elif unlocked:
			_style_btn(btn, Color(0.15, 0.20, 0.28), Color(0.95, 0.78, 0.26, 0.85))
		btn.pressed.connect(func():
			var res := Progression.select_job_tier(_save, tid)
			if res["ok"]:
				_save = res["save"]
				SaveStore.save_to_slot(_save, _active_slot)
				_modal_backdrop.visible = false
				if not _in_shift:
					_enter_home_mode()
				_refresh_hud()
				_maybe_show_chapter_modal(tid)
		)
		_modal_list.add_child(btn)
	var row_extra := HBoxContainer.new()
	row_extra.add_theme_constant_override("separation", 8)
	var btn_wish := Button.new()
	btn_wish.text = _t("★ Impian ART (%d/4)" % (_save.get("unlocked_wishlist", []) as Array).size(), "★ ART Dreams (%d/4)" % (_save.get("unlocked_wishlist", []) as Array).size())
	btn_wish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_btn(btn_wish, Color(0.20, 0.44, 0.56), Color(0.96, 0.78, 0.26))
	btn_wish.pressed.connect(_open_wishlist_modal)
	var btn_book := Button.new()
	btn_book.text = _t("Buku Cerita", "Story Book")
	btn_book.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_btn(btn_book, Color(0.32, 0.28, 0.48), Color(0.96, 0.78, 0.26))
	btn_book.pressed.connect(_open_storybook_modal)
	var btn_misi := Button.new()
	btn_misi.text = _t("Misi & Streak", "Missions & Streak")
	btn_misi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_btn(btn_misi, Color(0.18, 0.48, 0.34), Color(0.96, 0.78, 0.26))
	btn_misi.pressed.connect(_open_retention_modal)
	row_extra.add_child(btn_wish)
	row_extra.add_child(btn_book)
	row_extra.add_child(btn_misi)
	_modal_list.add_child(row_extra)
	_show_modal()

func _open_retention_modal() -> void:
	_clear_modal()
	var today_s := _today_date_str()
	_save = Retention.sync_daily_login(_save, today_s)["save"]
	_modal_title.text = _t("MISI HARIAN, STREAK & LENCANA", "DAILY MISSIONS, STREAK & BADGES")

	var streak_day := clampi(int(_save.get("login_streak", 1)), 1, 7)
	var rw: Dictionary = Retention.STREAK_REWARDS[streak_day - 1]
	var can_claim := String(_save.get("streak_claimed_date", "")) != today_s
	var btn_streak := Button.new()
	var rw_lbl := String(rw["label_en"] if _loc() == "en" else rw["label_id"])
	var rw_prefix := "Day %d: " % streak_day if _loc() == "en" else "Hari %d: " % streak_day
	if rw_lbl.begins_with(rw_prefix):
		rw_lbl = rw_lbl.substr(rw_prefix.length())
	if can_claim:
		btn_streak.text = _t("★ Klaim Streak Hari %d: %s (+%s, +%d XP)" % [streak_day, rw_lbl, I18n.format_balance(int(rw["rp"]), "id"), int(rw["xp"])], "★ Claim Day %d Streak: %s (+%s, +%d XP)" % [streak_day, rw_lbl, I18n.format_balance(int(rw["rp"]), "en"), int(rw["xp"])])
		_style_btn(btn_streak, Color(0.22, 0.56, 0.38), Color(0.98, 0.84, 0.34))
	else:
		btn_streak.text = _t("✓ Streak Hari %d/7 Sudah Diklaim Hari Ini" % streak_day, "✓ Day %d/7 Streak Claimed Today" % streak_day)
		btn_streak.disabled = true
		_style_btn(btn_streak, Color(0.14, 0.22, 0.19), Color(0.42, 0.54, 0.48), Color(0.84, 0.92, 0.86))
	btn_streak.pressed.connect(func():
		var cl := Retention.claim_streak_reward(_save, _today_date_str())
		if cl["ok"]:
			_save = cl["save"]
			SaveStore.save_to_slot(_save, _active_slot)
			_play_sfx(_wav_fanfare)
			_show_toast(_t("Bonus Streak Hari %d diklaim!" % streak_day, "Day %d Streak bonus claimed!" % streak_day), "player", "happy")
			call_deferred("_open_retention_modal")
			_refresh_hud()
	)
	_modal_list.add_child(btn_streak)

	for m in Retention.get_active_missions(_save, today_s, _loc()):
		var mid := String(m["id"])
		var btn_m := Button.new()
		if bool(m["claimed"]):
			btn_m.text = "✓ %s (%s)" % [String(m["label"]), _t("Selesai", "Claimed")]
			btn_m.disabled = true
		elif bool(m["done"]):
			btn_m.text = "★ %s (%d/%d) — %s +%s" % [String(m["label"]), int(m["current"]), int(m["target"]), _t("Klaim", "Claim"), I18n.format_balance(int(m["rp"]), _loc())]
			_style_btn(btn_m, Color(0.20, 0.44, 0.56), Color(0.98, 0.84, 0.34))
		else:
			btn_m.text = "○ %s (%d/%d) • +%s" % [String(m["label"]), int(m["current"]), int(m["target"]), I18n.format_balance(int(m["rp"]), _loc())]
			btn_m.disabled = true
		btn_m.pressed.connect(func():
			var cm := Retention.claim_mission_reward(_save, mid, _today_date_str())
			if cm["ok"]:
				_save = cm["save"]
				SaveStore.save_to_slot(_save, _active_slot)
				_play_sfx(_wav_coin)
				call_deferred("_open_retention_modal")
				_refresh_hud()
		)
		_modal_list.add_child(btn_m)

	var unlocked_bd: Array = _save.get("unlocked_badges", [])
	var bd_card := PanelContainer.new()
	bd_card.add_theme_stylebox_override("panel", _make_box(Color(0.12, 0.16, 0.22), Color(0.96, 0.78, 0.26, 0.65), 10, 12, 8))
	var bd_v := VBoxContainer.new()
	bd_v.add_theme_constant_override("separation", 4)
	var bd_lbl := Label.new()
	var bd_names: Array = []
	for raw_bid in unlocked_bd:
		var bid := String(raw_bid)
		if Retention.BADGES.has(bid):
			bd_names.append(String(Retention.BADGES[bid]["label_en" if _loc() == "en" else "label_id"]))
	bd_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bd_lbl.text = "🏅 %s (%d/%d): %s" % [_t("Lencana", "Badges"), unlocked_bd.size(), Retention.BADGES.size(), ", ".join(bd_names) if bd_names.size() > 0 else _t("Belum ada", "None yet")]
	bd_lbl.add_theme_font_size_override("font_size", 12)
	bd_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34))
	var bd_bar := ProgressBar.new()
	bd_bar.custom_minimum_size = Vector2(0, 8)
	bd_bar.max_value = maxi(1, Retention.BADGES.size())
	bd_bar.value = unlocked_bd.size()
	bd_bar.show_percentage = false
	_style_bar(bd_bar, Color(0.96, 0.78, 0.26), Color(0.08, 0.10, 0.14))
	bd_v.add_child(bd_lbl)
	bd_v.add_child(bd_bar)
	bd_card.add_child(bd_v)
	_modal_list.add_child(bd_card)
	_show_modal()

func _perform_sleep_recharge() -> void:
	if _is_sleeping:
		return
	_is_sleeping = true
	player.cancel_movement()
	player.movement_locked = true
	_reset_joystick()
	var prev_pos := player.position
	var prev_rot := player.rotation
	# Cozy bed-lay pose cleanly atop single bed mattress (Godot -1.62, 0.66, -1.32)
	var cs_p := player.find_child("_ContactShadow", false, false) as Node3D
	if cs_p != null:
		cs_p.visible = false
	player.position = Vector3(-1.62, 0.66, -1.32)
	player.rotation = Vector3(-PI * 0.50, 0.0, 0.0)
	_play_sfx(_wav_sleep)
	_spawn_float_popup(player.position + Vector3(0.0, 0.45, 0.0), "Zzz...", Color(0.68, 0.88, 1.0))
	await get_tree().create_timer(0.85).timeout
	player.rotation = prev_rot
	player.position = Vector3(-0.95, 0.0, -0.85) if _world_mode == "home" else prev_pos
	if cs_p != null:
		cs_p.visible = true
	player.movement_locked = false
	_is_sleeping = false

	var sl := LifeRhythm.sleep_in_bed(_save, _save.get("unlocked_kos_upgrades", []))
	_save = sl["save"]
	_save = Progression.tick_courier_orders(_save, 9999.0)
	var rem_chk := WishlistStory.check_remittance_deadline(_save)
	_save = rem_chk["save"]
	_last_prayer_id = ""
	SaveStore.save_to_slot(_save, _active_slot)
	_play_sfx(_wav_fanfare)
	_refresh_atmosphere()
	_refresh_hud()
	if bool(rem_chk.get("penalty_applied", false)):
		_show_toast(_t("Batas kiriman kampung Hari 10 terlewat — semangat berkurang!", "Day-10 village remittance deadline missed — mood dropped!"), "ibu_kampung", "worried")
	var thr := int(sl.get("thr_bonus_rp", 0))
	var passive_inc := int(sl.get("passive_income_rp", 0))
	var season := String(sl.get("season", "biasa"))
	if thr > 0:
		_show_toast(_t("Selamat Lebaran! Dapat THR Majikan +%s & Energi 100%%!" % I18n.format_balance(thr, "id"), "Happy Eid! Employer THR +%s & Energy 100%%!" % I18n.format_balance(thr, "en")), "player", "happy")
	elif passive_inc > 0:
		_show_toast(_t("Selamat pagi Hari %d! Usaha milikmu menghasilkan +%s pasif!" % [int(sl["day"]), I18n.format_balance(passive_inc, "id")], "Morning Day %d! Your businesses earned +%s passive income!" % [int(sl["day"]), I18n.format_balance(passive_inc, "en")]), "player", "happy")
	elif season == "ramadhan":
		_show_toast(_t("Sahur & Tidur nyenyak! Bulan Ramadhan Hari %d — Energi 100%%." % int(sl["day"]), "Suhoor & rested! Ramadhan Day %d — Energy 100%%." % int(sl["day"])), "player", "happy")
	else:
		_show_toast(_t("Tidur nyenyak! Hari %d dimulai — Energi 100%% & Mood segar." % int(sl["day"]), "Well rested! Day %d begins — Energy 100%% & fresh Mood." % int(sl["day"])), "player", "happy")
	var sleep_tier := CareerTiers.get_tier(String(_save.get("active_tier_id", "kamar_kos")))
	if Progression.should_collect_weekly_rent(_save, sleep_tier):
		_open_rent_modal()

func _trigger_prayer_action() -> void:
	var cur_day := maxi(1, int(_save.get("day", 1)))
	var g_min := int(_save.get("game_minutes", 360))
	var pid := _last_prayer_id
	if pid == "":
		if g_min < 630:
			pid = "subuh"
		elif g_min < 870:
			pid = "dzuhur"
		elif g_min < 1080:
			pid = "ashar"
		elif g_min < 1155:
			pid = "maghrib"
		else:
			pid = "isya"
	var res := LifeRhythm.perform_prayer(_save, pid, cur_day)
	if not bool(res["ok"]):
		_show_toast(_t("Sudah sholat untuk waktu ini — tetap semangat ya!", "Already prayed for this time — stay blessed!"))
		return
	_save = res["save"]
	if _in_shift:
		_call_state["mood"] = clampi(int(_call_state.get("mood", 60)) + 12, 0, 100)
	SaveStore.save_to_slot(_save, _active_slot)
	_play_sfx(_wav_prayer)
	_refresh_hud()
	if bool(res.get("got_takjil", false)):
		_show_toast(_t("Alhamdulillah Sholat Maghrib & Buka Puasa! (+20 Energi, +27 Mood)", "Maghrib prayer & Iftar! (+20 Energy, +27 Mood)"), "player", "happy")
	elif _in_shift:
		_show_toast(_t("Majikan izin sholat sebentar! (+12 Mood, +5 XP)", "Employer gave prayer break! (+12 Mood, +5 XP)"), "player", "happy")
	else:
		_show_toast(_t("Hati tenang selesai sholat! (+12 Mood, +5 XP)", "Peaceful after prayer! (+12 Mood, +5 XP)"), "player", "happy")

func _open_low_energy_modal(cur_e: int) -> void:
	_clear_modal()
	_modal_title.text = _t("ENERGI MENIPIS (%d%%)" % cur_e, "LOW ENERGY (%d%%)" % cur_e)
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.text = _t("Energi tinggal %d%%! Sebaiknya pulang ke kamar dan Tidur di Kasur (Gratis, 100%%) sebelum kerja shift baru." % cur_e, "Energy is at %d%%! Head to your room and sleep in bed (Free, 100%%) before starting a shift." % cur_e)
	_modal_list.add_child(lbl)
	var b_home := Button.new()
	b_home.text = _t("Pulang ke Kamar untuk Tidur", "Go Back to Room to Sleep")
	_style_btn(b_home, Color(0.20, 0.48, 0.56), Color(0.98, 0.84, 0.34))
	b_home.pressed.connect(func():
		_modal_backdrop.visible = false
		_enter_home_mode()
	)
	_modal_list.add_child(b_home)
	var b_go := Button.new()
	b_go.text = _t("Tetap Mulai Shift Sekarang", "Start Shift Anyway")
	b_go.pressed.connect(func():
		_modal_backdrop.visible = false
		_start_shift(true)
	)
	_modal_list.add_child(b_go)
	_show_modal()

func _open_storybook_modal() -> void:
	_clear_modal()
	_modal_title.text = _t("BUKU CERITA PERJALANAN ART", "ART JOURNEY STORY BOOK")
	var sub := Label.new()
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.text = _t("Setiap langkah kariermu dari kamar kos hingga Cluster Elite tercatat di sini.", "Every milestone from your simple kos room to Cluster Elite is recorded here.")
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.84, 0.88, 0.94))
	_modal_list.add_child(sub)
	for entry in WishlistStory.get_storybook_entries(_save, _loc()):
		var btn := Button.new()
		var ok_u := bool(entry["unlocked"])
		if ok_u:
			btn.text = "📖 %s — %s" % [String(entry["title"]), _t("Baca", "Read")]
			_style_btn(btn, Color(0.16, 0.38, 0.32), Color(0.96, 0.78, 0.26))
			var ch_dict: Dictionary = entry["chapter"]
			btn.pressed.connect(func(): _open_chapter_modal(ch_dict))
		else:
			btn.text = "🔒 %s (%s %d XP)" % [String(entry["title"]), _t("Buka di", "Unlocks at"), int(entry["min_xp"])]
			btn.disabled = true
			_style_btn(btn, Color(0.14, 0.16, 0.20), Color(0.45, 0.45, 0.48))
		_modal_list.add_child(btn)
	var unlocked_cl: Array = _save.get("unlocked_clues", [])
	_add_modal_section(_t("JEJAK RUMAH & CERITA WARGA (%d/%d)" % [unlocked_cl.size(), HouseholdClues.CLUES.size()], "HOUSEHOLD CLUES & STORIES (%d/%d)" % [unlocked_cl.size(), HouseholdClues.CLUES.size()]))
	if unlocked_cl.is_empty():
		var empty_cl := Label.new()
		empty_cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_cl.text = _t("Cari kilauan emas saat shift untuk menemukan cerita hangat di balik rumah majikan.", "Inspect golden sparkles during shifts to uncover hidden stories inside each household.")
		empty_cl.add_theme_color_override("font_color", Color(0.84, 0.88, 0.94))
		_modal_list.add_child(empty_cl)
	else:
		for raw_cid in unlocked_cl:
			var scid := String(raw_cid)
			if not HouseholdClues.CLUES.has(scid):
				continue
			var cl_d: Dictionary = HouseholdClues.CLUES[scid]
			var cl_card := PanelContainer.new()
			cl_card.add_theme_stylebox_override("panel", _make_box(Color(0.11, 0.16, 0.24), Color(0.96, 0.78, 0.26, 0.65), 10, 10, 8))
			var cl_v := VBoxContainer.new()
			cl_v.add_theme_constant_override("separation", 3)
			var cl_t := Label.new()
			cl_t.text = "✨ %s" % String(cl_d["title_en" if _loc() == "en" else "title_id"])
			cl_t.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34))
			var cl_b := Label.new()
			cl_b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cl_b.text = String(cl_d["story_en" if _loc() == "en" else "story_id"])
			cl_b.add_theme_font_size_override("font_size", 11)
			cl_b.add_theme_color_override("font_color", Color(0.92, 0.92, 0.90))
			cl_v.add_child(cl_t)
			cl_v.add_child(cl_b)
			cl_card.add_child(cl_v)
			_modal_list.add_child(cl_card)
	var cult_btn := Button.new()
	cult_btn.text = _t("🌏 Kamus Budaya Indonesia (Global Notes)", "🌏 Indonesian Cultural Notes (Glossary)")
	_style_btn(cult_btn, Color(0.14, 0.24, 0.42), Color(0.96, 0.78, 0.26))
	cult_btn.pressed.connect(func(): call_deferred("_open_cultural_notes_modal"))
	_modal_list.add_child(cult_btn)
	_show_modal()

func _open_dilemma_modal(dilemma: Dictionary) -> void:
	if dilemma.is_empty():
		return
	_clear_modal()
	if _btn_modal_close != null:
		_btn_modal_close.visible = false
	var did := String(dilemma.get("id", ""))
	_modal_title.text = String(dilemma["title_en" if _loc() == "en" else "title_id"])
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_box(Color(0.12, 0.16, 0.24), Color(0.96, 0.78, 0.26, 0.85), 12, 12, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var p_frame := PanelContainer.new()
	p_frame.custom_minimum_size = Vector2(68, 68)
	p_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p_frame.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.12, 0.18), Color(0.96, 0.78, 0.26), 10, 2, 2))
	var p_rect := TextureRect.new()
	p_rect.texture = Portraits.get_portrait(String(dilemma.get("speaker_id", "player")), "neutral")
	p_rect.custom_minimum_size = Vector2(62, 62)
	p_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	p_frame.add_child(p_rect)
	row.add_child(p_frame)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = String(dilemma["prompt_en" if _loc() == "en" else "prompt_id"])
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
	row.add_child(body)
	card.add_child(row)
	_modal_list.add_child(card)
	var choices: Array = dilemma.get("choices", [])
	for ci in range(choices.size()):
		var ch: Dictionary = choices[ci]
		var cbtn := Button.new()
		cbtn.text = String(ch["label_en" if _loc() == "en" else "label_id"])
		_style_btn(cbtn, Color(0.18, 0.36, 0.32) if ci == 0 else Color(0.18, 0.22, 0.30), Color(0.96, 0.78, 0.26))
		cbtn.pressed.connect(func():
			var res := HouseholdDilemmas.resolve_choice(_save, _call_state, _shift, did, ci)
			if bool(res["ok"]):
				_save = res["save"]
				_call_state = res["call_state"]
				_shift = res["shift"]
				if int(res["delta_rp"]) != 0:
					_save = Settings.append_daily_log(_save, {
						"day": int(_save.get("day", 1)),
						"kind": "dilemma",
						"title_id": String(dilemma["title_id"]),
						"title_en": String(dilemma["title_en"]),
						"delta_rp": int(res["delta_rp"]),
					})
				SaveStore.save_to_slot(_save, _active_slot)
				_modal_backdrop.visible = false
				_play_sfx(_wav_coin)
				_show_toast(String(res["outcome_en" if _loc() == "en" else "outcome_id"]), String(res.get("speaker_id", "player")), "happy")
				_refresh_hud()
		)
		_modal_list.add_child(cbtn)
	_show_modal()

func _open_cultural_notes_modal() -> void:
	_clear_modal()
	_modal_title.text = _t("CATATAN BUDAYA INDONESIA", "INDONESIAN CULTURAL NOTES")
	var sub := Label.new()
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.text = _t("Mengenal istilah khas kehidupan perantau & rumah tangga Indonesia.", "A warm guide to authentic Indonesian daily life & household traditions in Cozy Homekeeper.")
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.84, 0.88, 0.94))
	_modal_list.add_child(sub)
	for note in CulturalNotes.get_notes(_loc()):
		var nc := PanelContainer.new()
		nc.add_theme_stylebox_override("panel", _make_box(Color(0.11, 0.16, 0.24), Color(0.96, 0.78, 0.26, 0.65), 10, 10, 8))
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", 3)
		var nt := Label.new()
		nt.text = "🌏 %s" % String(note["title"])
		nt.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34))
		var nb := Label.new()
		nb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nb.text = String(note["body"])
		nb.add_theme_font_size_override("font_size", 11)
		nb.add_theme_color_override("font_color", Color(0.93, 0.93, 0.90))
		nv.add_child(nt)
		nv.add_child(nb)
		nc.add_child(nv)
		_modal_list.add_child(nc)
	_show_modal()

func _maybe_show_chapter_modal(tier_id: String) -> void:
	if _smoke_mode or _capture_path != "" or not bool(_save.get("onboarding_done", false)):
		return
	var ch := WishlistStory.get_unseen_chapter(_save, tier_id)
	if ch.is_empty():
		return
	_open_chapter_modal(ch)

func _open_chapter_modal(ch: Dictionary) -> void:
	_clear_modal()
	_save = WishlistStory.mark_chapter_seen(_save, String(ch.get("id", "")))
	SaveStore.save_to_slot(_save, _active_slot)
	_modal_title.text = String(ch["title_en"] if _loc() == "en" else ch["title_id"])
	var story_card := PanelContainer.new()
	story_card.add_theme_stylebox_override("panel", _make_box(Color(0.12, 0.16, 0.24), Color(0.96, 0.78, 0.26, 0.80), 12, 12, 10))
	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 12)
	var p_frame := PanelContainer.new()
	p_frame.custom_minimum_size = Vector2(72, 72)
	p_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p_frame.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.12, 0.18), Color(0.96, 0.78, 0.26), 10, 2, 2))
	var p_rect := TextureRect.new()
	p_rect.texture = _get_player_portrait_tex("happy")
	p_rect.custom_minimum_size = Vector2(66, 66)
	p_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	p_frame.add_child(p_rect)
	hdr_row.add_child(p_frame)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = String(ch["body_en"] if _loc() == "en" else ch["body_id"])
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
	hdr_row.add_child(body)
	story_card.add_child(hdr_row)
	_modal_list.add_child(story_card)
	var ch_tier := String(ch.get("tier_id", "kamar_kos"))
	var q_txt := WishlistStory.get_tier_milestone_quote(ch_tier, _loc())
	if q_txt != "":
		var q_card := PanelContainer.new()
		q_card.add_theme_stylebox_override("panel", _make_box(Color(0.18, 0.14, 0.08), Color(0.96, 0.80, 0.34, 0.75), 10, 12, 8))
		var qlbl := Label.new()
		qlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		qlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qlbl.text = q_txt
		qlbl.add_theme_font_size_override("font_size", 13)
		qlbl.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42))
		q_card.add_child(qlbl)
		_modal_list.add_child(q_card)
	_show_modal()

func _open_wishlist_modal() -> void:
	_clear_modal()
	_modal_title.text = _t("IMPIAN ART & TARGET TABUNGAN", "ART DREAMS & MILESTONE GOALS")
	var w_bal := Label.new()
	w_bal.text = "%s: %s" % [_t("Saldo Dompet", "Wallet Balance"), I18n.format_balance(int(_save.get("balance_rp", 0)), _loc())]
	w_bal.add_theme_font_size_override("font_size", 12)
	w_bal.add_theme_color_override("font_color", Color(0.45, 0.94, 0.44))
	_modal_list.add_child(w_bal)
	var unlocked: Array = _save.get("unlocked_wishlist", [])
	var bal_now_w := int(_save.get("balance_rp", 0))
	for raw_wid in WishlistStory.WISHLIST_ITEMS.keys():
		var wid := String(raw_wid)
		var item: Dictionary = WishlistStory.WISHLIST_ITEMS[wid]
		var is_done := wid in unlocked
		var cost_w := int(item["cost_rp"])
		var can_buy_w := (not is_done) and bal_now_w >= cost_w
		var title := String(item["label_en"] if _loc() == "en" else item["label_id"])
		var desc := String(item["desc_en"] if _loc() == "en" else item["desc_id"])
		var w_card := PanelContainer.new()
		w_card.add_theme_stylebox_override("panel", _make_box(Color(0.14, 0.28, 0.22) if is_done else Color(0.12, 0.16, 0.22), Color(0.96, 0.78, 0.26) if can_buy_w else Color(0.36, 0.40, 0.48), 10, 10, 6))
		var wv := VBoxContainer.new()
		wv.add_theme_constant_override("separation", 4)
		var btn := Button.new()
		var status := _t("✓ Tercapai", "✓ Achieved") if is_done else (_t("★ Wujudkan · %s (+%d XP)" % [I18n.format_balance(cost_w, _loc()), int(item["xp_bonus"])], "★ Fulfill · %s (+%d XP)" % [I18n.format_balance(cost_w, _loc()), int(item["xp_bonus"])]) if can_buy_w else ("%s (+%d XP, +%d%% %s)" % [I18n.format_balance(cost_w, _loc()), int(item["xp_bonus"]), int(item["mood_bonus"]), _t("Semangat", "Mood")]))
		btn.text = "%s — %s\n%s" % [title, status, desc]
		btn.disabled = is_done or not can_buy_w
		if can_buy_w:
			_style_btn(btn, Color(0.20, 0.50, 0.34), Color(0.98, 0.84, 0.34))
		btn.pressed.connect(func():
			var res := WishlistStory.buy_wishlist_item(_save, wid)
			if res["ok"]:
				_save = res["save"]
				_save = Settings.append_daily_log(_save, {
					"day": int(_save.get("day", 1)),
					"kind": "wishlist",
					"title_id": "Impian: %s" % String(item["label_id"]),
					"title_en": "Dream: %s" % String(item["label_en"]),
					"delta_rp": -cost_w,
				})
				SaveStore.save_to_slot(_save, _active_slot)
				_play_sfx(_wav_fanfare)
				_show_toast(_t("Impian tercapai: %s! (+%d XP)" % [title, int(item["xp_bonus"])], "Dream achieved: %s! (+%d XP)" % [title, int(item["xp_bonus"])]), "player", "happy")
				var ep := WishlistStory.get_unseen_epilogue(_save)
				if not ep.is_empty():
					call_deferred("_open_chapter_modal", ep)
				else:
					call_deferred("_open_wishlist_modal")
				_refresh_hud()
		)
		wv.add_child(btn)
		if not is_done:
			var wp := ProgressBar.new()
			wp.custom_minimum_size = Vector2(0, 6)
			wp.max_value = maxi(1, cost_w)
			wp.value = mini(bal_now_w, cost_w)
			wp.show_percentage = false
			_style_bar(wp, Color(0.36, 0.88, 0.48) if can_buy_w else Color(0.96, 0.78, 0.26), Color(0.08, 0.10, 0.14))
			wv.add_child(wp)
		w_card.add_child(wv)
		_modal_list.add_child(w_card)
	if WishlistStory.is_epilogue_unlocked(_save):
		_add_modal_section(_t("PROYEK MASA DEPAN (JURAGAN MANDIRI)", "FUTURE INVESTMENTS (PASSIVE INCOME)"))
		var inv_owned: Array = _save.get("unlocked_investments", [])
		for raw_iid in WishlistStory.FUTURE_INVESTMENTS.keys():
			var iid := String(raw_iid)
			var inv_item: Dictionary = WishlistStory.FUTURE_INVESTMENTS[iid]
			var owned_flag := iid in inv_owned
			var icost := int(inv_item["cost_rp"])
			var can_inv := (not owned_flag) and bal_now_w >= icost
			var ititle := String(inv_item["label_en"] if _loc() == "en" else inv_item["label_id"])
			var idesc := String(inv_item["desc_en"] if _loc() == "en" else inv_item["desc_id"])
			var ibtn := Button.new()
			var istatus := _t("✓ Aktif (+%s/hari)" % I18n.format_balance(int(inv_item["daily_income_rp"]), "id"), "✓ Active (+%s/day)" % I18n.format_balance(int(inv_item["daily_income_rp"]), "en")) if owned_flag else I18n.format_balance(icost, _loc())
			ibtn.text = "%s — %s\n%s" % [ititle, istatus, idesc]
			ibtn.disabled = owned_flag or not can_inv
			if can_inv:
				_style_btn(ibtn, Color(0.20, 0.50, 0.34), Color(0.98, 0.84, 0.34))
			ibtn.pressed.connect(func():
				var ires := WishlistStory.buy_investment(_save, iid)
				if bool(ires["ok"]):
					_save = ires["save"]
					SaveStore.save_to_slot(_save, _active_slot)
					_play_sfx(_wav_fanfare)
					_show_toast(_t("Usaha dibuka: %s!" % ititle, "Business opened: %s!" % ititle), "player", "happy")
					call_deferred("_open_wishlist_modal")
					_refresh_hud()
			)
			_modal_list.add_child(ibtn)
	_show_modal()

func _open_wardrobe_modal() -> void:
	_clear_modal()
	_modal_title.text = _t("Lemari Seragam & Kustomisasi Warna", "Wardrobe & Color Customization")
	var xp := int(_save.get("xp", 0))
	var cur_oid := String(_save.get("equipped_outfit_id", "starter_kasual"))
	var cur_col := String(_save.get("outfit_color_hex", "#4E7D63"))
	var pv_row := HBoxContainer.new()
	pv_row.add_theme_constant_override("separation", 10)
	var pv_frame := PanelContainer.new()
	pv_frame.custom_minimum_size = Vector2(56, 56)
	pv_frame.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.12, 0.18), Color(0.96, 0.78, 0.26), 10, 2, 2))
	var pv_tex := TextureRect.new()
	pv_tex.texture = _get_player_portrait_tex("happy")
	pv_tex.custom_minimum_size = Vector2(50, 50)
	pv_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pv_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pv_frame.add_child(pv_tex)
	var pv_lbl := Label.new()
	pv_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cur_o_lbl := cur_oid
	for ot in CareerTiers.OUTFIT_TIERS:
		if String(ot.get("id", "")) == cur_oid:
			cur_o_lbl = String(ot.get("label_en" if _loc() == "en" else "label_id", cur_oid))
			break
	pv_lbl.text = _t("Seragam Aktif: %s • Warna: %s" % [cur_o_lbl, Progression.get_color_label(cur_col, "id")], "Active Uniform: %s • Color: %s" % [cur_o_lbl, Progression.get_color_label(cur_col, "en")])
	pv_lbl.add_theme_font_size_override("font_size", 12)
	pv_lbl.add_theme_color_override("font_color", Color(0.95, 0.94, 0.90))
	pv_row.add_child(pv_frame)
	pv_row.add_child(pv_lbl)
	_modal_list.add_child(pv_row)
	for o in CareerTiers.OUTFIT_TIERS:
		var oid := String(o["id"])
		var unlocked := CareerTiers.can_equip_outfit(oid, xp)
		var lbl := Label.new()
		var name_txt := String(o["label_en"] if _loc() == "en" else o["label_id"])
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.text = "%s%s (%d XP)%s" % ["" if unlocked else "🔒 ", name_txt, int(o["min_xp"]), " ✓" if oid == cur_oid else ""]
		lbl.add_theme_color_override("font_color", Color(0.98, 0.86, 0.38) if unlocked else Color(0.76, 0.78, 0.84))
		_modal_list.add_child(lbl)
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		for hex in o["customizable_colors"]:
			var ch := String(hex)
			var col_val := Color.html(ch)
			var is_light := col_val.get_luminance() > 0.32
			var b := Button.new()
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var is_cur_swatch := (oid == cur_oid and ch.to_upper() == cur_col.to_upper())
			b.text = ("✓ " if is_cur_swatch else "") + Progression.get_color_label(ch, _loc())
			b.disabled = not unlocked
			_style_btn(b, col_val, Color(0.96, 0.78, 0.26) if unlocked else Color(0.45, 0.45, 0.48), Color(0.10, 0.08, 0.06) if is_light else Color(0.98, 0.97, 0.94))
			b.pressed.connect(func():
				var res := Progression.equip_outfit(_save, oid, ch)
				if res["ok"]:
					_save = res["save"]
					SaveStore.save_to_slot(_save, _active_slot)
					_sync_player_outfit()
					_modal_backdrop.visible = false
					_refresh_hud()
			)
			hbox.add_child(b)
		_modal_list.add_child(hbox)
	_show_modal()

func _open_kos_modal() -> void:
	_clear_modal()
	var tier := CareerTiers.get_tier(String(_save.get("active_tier_id", "kamar_kos")))
	_modal_title.text = Progression.get_room_upgrade_title(tier, _loc())
	var k_bal := Label.new()
	k_bal.text = "%s: %s  •  %s: %d" % [_t("Saldo Dompet", "Wallet"), I18n.format_balance(int(_save.get("balance_rp", 0)), _loc()), _t("Maks Energi", "Max Energy"), int(Progression.get_max_energy(_save))]
	k_bal.add_theme_font_size_override("font_size", 12)
	k_bal.add_theme_color_override("font_color", Color(0.45, 0.94, 0.44))
	_modal_list.add_child(k_bal)
	var owned: Array = _save.get("unlocked_kos_upgrades", [])
	for raw_uid in Progression.KOS_UPGRADES.keys():
		var uid := String(raw_uid)
		var u: Dictionary = Progression.KOS_UPGRADES[uid]
		var is_owned: bool = uid in owned
		var cost_u := int(u["cost_rp"])
		var can_buy_u := (not is_owned) and int(_save.get("balance_rp", 0)) >= cost_u
		var btn := Button.new()
		var lbl := String(u["label_en"] if _loc() == "en" else u["label_id"])
		var price_txt := _t("✓ Terpasang", "✓ Installed") if is_owned else (_t("Beli · %s" % I18n.format_price(cost_u, "id"), "Buy · %s" % I18n.format_price(cost_u, "en")) if can_buy_u else I18n.format_price(cost_u, _loc()))
		btn.text = "%s — %s" % [lbl, price_txt]
		btn.disabled = is_owned or not can_buy_u
		if is_owned:
			_style_btn(btn, Color(0.14, 0.28, 0.22), Color(0.42, 0.72, 0.54), Color(0.75, 0.96, 0.82))
		elif can_buy_u:
			_style_btn(btn, Color(0.18, 0.42, 0.34), Color(0.98, 0.84, 0.34))
		btn.pressed.connect(func():
			_open_confirm_purchase_modal(
				lbl,
				int(u["cost_rp"]),
				func():
					var res := Progression.buy_kos_upgrade(_save, uid)
					if res["ok"]:
						_save = res["save"]
						_save = Settings.append_daily_log(_save, {
							"day": int(_save.get("day", 1)),
							"kind": "upgrade",
							"title_id": "Beli %s" % String(u["label_id"]),
							"title_en": "Bought %s" % String(u["label_en"]),
							"delta_rp": -int(u["cost_rp"]),
						})
						SaveStore.save_to_slot(_save, _active_slot)
						if _world_mode == "home" and stage_root.get_child_count() > 0:
							Atmosphere.apply_kos_upgrades_visual(stage_root.get_child(0), _save.get("unlocked_kos_upgrades", []))
						_play_sfx(_wav_coin)
						call_deferred("_open_kos_modal")
						_refresh_hud()
			)
		)
		_modal_list.add_child(btn)
	_show_modal()

func _open_summary_modal(res: Dictionary) -> void:
	_clear_modal()
	_modal_title.text = _t("RINGKASAN SHIFT SELESAI", "SHIFT SUMMARY")
	var l1 := Label.new()
	l1.text = "%s: %s" % [_t("Total Pendapatan", "Total Earned"), I18n.format_balance(int(res["payout_rp"]), _loc())]
	l1.add_theme_color_override("font_color", Color(0.45, 0.94, 0.44))
	var l2 := Label.new()
	l2.text = "+%d XP (Lv.%d)" % [int(res["xp_gained"]), Progression.level_from_xp(int(_save.get("xp", 0)))]
	l2.add_theme_color_override("font_color", Color(0.96, 0.84, 0.36))
	var l3 := Label.new()
	l3.text = _t("Status: Dipecat (gaji kontrak hangus)" if bool(res["fired"]) else "Status: Shift Bagus!", "Status: Fired (contract forfeited)" if bool(res["fired"]) else "Status: Great Shift!")
	l3.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
	_modal_list.add_child(l1)
	_modal_list.add_child(l2)
	_modal_list.add_child(l3)
	var clean_sum := int(res.get("clean_pct", 100))
	var l_clean := Label.new()
	l_clean.text = _t("✨ Kebersihan Rumah: 0%% → %d%% %s" % [clean_sum, "BERKILAU!" if clean_sum >= 100 else ""], "✨ Room Cleanliness: 0%% → %d%% %s" % [clean_sum, "SPARKLING!" if clean_sum >= 100 else ""])
	l_clean.add_theme_color_override("font_color", Color(0.45, 0.96, 0.90))
	_modal_list.add_child(l_clean)
	var meal_rp := int(res.get("meal_cost_rp", 0))
	if meal_rp > 0:
		var l_meal := Label.new()
		l_meal.text = _t("Uang Makan & Transport: -%s" % I18n.format_balance(meal_rp, "id"), "Daily Meal & Commute: -%s" % I18n.format_balance(meal_rp, "en"))
		l_meal.add_theme_color_override("font_color", Color(0.96, 0.62, 0.42))
		_modal_list.add_child(l_meal)
	_show_modal()

func _open_levelup_modal(new_lv: int, res: Dictionary) -> void:
	_clear_modal()
	_modal_title.text = _t("SELAMAT! NAIK KE LEVEL %d" % new_lv, "LEVEL UP! NOW LEVEL %d" % new_lv)
	var sub := Label.new()
	sub.text = _t("Majikan makin menghargai kerja keras %s." % String(_save.get("player_name", "Mbak Sari")), "Employers appreciate %s's hard work!" % String(_save.get("player_name", "Mbak Sari")))
	sub.add_theme_color_override("font_color", Color(0.95, 0.94, 0.90))
	var pay_lbl := Label.new()
	var st_txt := _t("Dipecat" if bool(res.get("fired", false)) else "Shift Bagus!", "Fired" if bool(res.get("fired", false)) else "Great Shift!")
	pay_lbl.text = "%s: %s  •  +%d XP (%s)" % [_t("Pendapatan Shift", "Shift Earnings"), I18n.format_balance(int(res.get("payout_rp", 0)), _loc()), int(res.get("xp_gained", 0)), st_txt]
	pay_lbl.add_theme_color_override("font_color", Color(0.45, 0.94, 0.44))
	_modal_list.add_child(sub)
	_modal_list.add_child(pay_lbl)
	for ul in _pending_level_unlocks:
		var ul_lbl := Label.new()
		ul_lbl.text = "★ %s" % String(ul)
		ul_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34))
		_modal_list.add_child(ul_lbl)
	_pending_level_unlocks = []
	_show_modal()

func _open_rent_modal(res: Dictionary = {}, leveled_up_to: int = 0) -> void:
	_clear_modal()
	_modal_title.text = _t("IBU MELATI MENAGIH SEWA KOS", "IBU MELATI: WEEKLY KOS RENT")
	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 10)
	var p_rect := TextureRect.new()
	p_rect.texture = Portraits.get_portrait("ibu_melati", "strict")
	p_rect.custom_minimum_size = Vector2(64, 64)
	p_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hdr_row.add_child(p_rect)
	var quote_lbl := Label.new()
	quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quote_lbl.text = _t("\"Waktunya bayar sewa kamar mingguan ya, Neng.\"", "\"Time for your weekly kos room rent.\"")
	quote_lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.65))
	hdr_row.add_child(quote_lbl)
	_modal_list.add_child(hdr_row)
	if leveled_up_to > 0:
		var lv_lbl := Label.new()
		lv_lbl.text = _t("★ NAIK KE LEVEL %d!" % leveled_up_to, "★ LEVEL UP TO %d!" % leveled_up_to)
		lv_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34))
		_modal_list.add_child(lv_lbl)
		for ul in _pending_level_unlocks:
			var ul_lbl := Label.new()
			ul_lbl.text = "• %s" % String(ul)
			ul_lbl.add_theme_color_override("font_color", Color(0.55, 0.96, 0.72))
			_modal_list.add_child(ul_lbl)
		_pending_level_unlocks = []
	if not res.is_empty():
		var sum_lbl := Label.new()
		var st_txt := _t("Dipecat" if bool(res.get("fired", false)) else "Shift Bagus", "Fired" if bool(res.get("fired", false)) else "Great Shift")
		sum_lbl.text = "%s: +%s  •  +%d XP (%s)" % [_t("Hasil Shift", "Shift Result"), I18n.format_balance(int(res.get("payout_rp", 0)), _loc()), int(res.get("xp_gained", 0)), st_txt]
		sum_lbl.add_theme_color_override("font_color", Color(0.45, 0.94, 0.44))
		_modal_list.add_child(sum_lbl)
	var pending := int(_save.get("pending_rent_rp", 0))
	var rent_rp := pending if pending > 0 else 120000
	var bal := int(_save.get("balance_rp", 0))
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.text = _t(
		"Tagihan sewa kamar kos: %s.\nSaldo dompetmu: %s." % [I18n.format_balance(rent_rp, "id"), I18n.format_balance(bal, "id")],
		"Kos room rent due: %s.\nYour wallet: %s." % [I18n.format_balance(rent_rp, "en"), I18n.format_balance(bal, "en")]
	)
	info.add_theme_color_override("font_color", Color(0.95, 0.94, 0.90))
	_modal_list.add_child(info)

	var btn_pay := Button.new()
	btn_pay.text = _t("Bayar Sekarang (%s)" % I18n.format_balance(rent_rp, "id"), "Pay Now (%s)" % I18n.format_balance(rent_rp, "en"))
	btn_pay.disabled = bal < rent_rp
	_style_btn(btn_pay, Color(0.96, 0.78, 0.24), Color(0.99, 0.88, 0.42), Color(0.11, 0.09, 0.06))
	btn_pay.pressed.connect(func():
		var pr := Progression.pay_weekly_rent(_save, true, 120000)
		if pr["ok"]:
			_save = pr["save"]
			_save = Settings.append_daily_log(_save, {
				"day": int(_save.get("day", 1)),
				"kind": "rent",
				"title_id": "Bayar Sewa Kos",
				"title_en": "Paid Kos Rent",
				"delta_rp": -rent_rp,
			})
			SaveStore.save_to_slot(_save, _active_slot)
			_play_sfx(_wav_coin)
			_modal_backdrop.visible = false
			_refresh_hud()
	)
	var btn_later := Button.new()
	btn_later.text = _t("Bayar Nanti (+Denda %s)" % I18n.format_balance(15000, "id"), "Pay Later (+%s Fee)" % I18n.format_balance(15000, "en"))
	_style_btn(btn_later, Color(0.18, 0.20, 0.24), Color(0.55, 0.56, 0.60))
	btn_later.pressed.connect(func():
		var pr := Progression.pay_weekly_rent(_save, false, 120000)
		_save = pr["save"]
		_save = Settings.append_daily_log(_save, {
			"day": int(_save.get("day", 1)),
			"kind": "rent_late",
			"title_id": "Tunda Sewa (+Denda)",
			"title_en": "Deferred Rent (+Fee)",
			"delta_rp": 0,
		})
		SaveStore.save_to_slot(_save, _active_slot)
		_modal_backdrop.visible = false
		_refresh_hud()
	)
	_modal_list.add_child(btn_pay)
	_modal_list.add_child(btn_later)
	if _btn_modal_close != null:
		_btn_modal_close.visible = false
	_show_modal()
	btn_pay.call_deferred("grab_focus") if not btn_pay.disabled else btn_later.call_deferred("grab_focus")

func _open_map_modal() -> void:
	if _is_sleeping:
		return
	_clear_modal()
	_modal_title.text = _t("PETA LINGKUNGAN & WILAYAH KERJA", "NEIGHBORHOOD & DISTRICT MAP")
	var nodes := Portraits.get_map_destinations(_save, _world_mode)
	var place_lbl := Label.new()
	place_lbl.text = _t("Lokasi Saat Ini (Ketuk untuk pindah):", "Nearby Places (Tap to travel):")
	place_lbl.add_theme_font_size_override("font_size", 12)
	place_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34))
	_modal_list.add_child(place_lbl)
	var place_row := HBoxContainer.new()
	place_row.add_theme_constant_override("separation", 8)
	for node in nodes:
		if String(node.get("kind", "")) != "place":
			continue
		var act := String(node.get("action", "kos"))
		var is_act := bool(node.get("active", false))
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lbl := String(node["label_en"] if _loc() == "en" else node["label_id"])
		b.text = ("%s ✓" if is_act else "%s") % lbl
		_style_btn(b, Color(0.22, 0.58, 0.42) if is_act else Color(0.16, 0.18, 0.22), Color(0.96, 0.78, 0.26))
		b.disabled = _in_shift and act != "shift"
		b.pressed.connect(func():
			_modal_backdrop.visible = false
			if act == "kos" and not _in_shift:
				_enter_home_mode()
			elif act == "street" and not _in_shift:
				_enter_street_mode(_world_mode)
			elif act == "shift" and not _in_shift:
				_start_shift()
		)
		place_row.add_child(b)
	_modal_list.add_child(place_row)

	var dist_lbl := Label.new()
	dist_lbl.text = _t("Peta Distrik Karier:", "Career District Map:")
	dist_lbl.add_theme_font_size_override("font_size", 12)
	dist_lbl.add_theme_color_override("font_color", Color(0.68, 0.88, 0.98))
	_modal_list.add_child(dist_lbl)
	for node in nodes:
		if String(node.get("kind", "")) != "district":
			continue
		var tid := String(node.get("tier_id", "kamar_kos"))
		var unl := bool(node.get("unlocked", false))
		var is_act := bool(node.get("active", false))
		var lbl := String(node["label_en"] if _loc() == "en" else node["label_id"])
		var b := Button.new()
		b.text = "%s%s (%d XP)%s" % ["📍 " if is_act else ("• " if unl else "🔒 "), lbl, int(node["min_xp"]), _t(" [Lokasi Aktif]", " [Active]") if is_act else ""]
		b.disabled = (not unl) or _in_shift
		if is_act:
			_style_btn(b, Color(0.18, 0.46, 0.36), Color(0.98, 0.86, 0.36))
		elif unl:
			_style_btn(b, Color(0.15, 0.20, 0.28), Color(0.45, 0.72, 0.88))
		b.pressed.connect(func():
			var res := Progression.select_job_tier(_save, tid)
			if res["ok"]:
				_save = res["save"]
				SaveStore.save_to_slot(_save, _active_slot)
				_modal_backdrop.visible = false
				if _world_mode == "street":
					_enter_street_mode("home")
				else:
					_enter_home_mode()
				_refresh_hud()
				_maybe_show_chapter_modal(tid)
		)
		_modal_list.add_child(b)
	_show_modal()

func _open_log_modal() -> void:
	_clear_modal()
	_modal_title.text = _t("CATATAN HARIAN ART", "DAILY ART ACTIVITY LOG")
	var entries := Settings.get_daily_log(_save)
	if entries.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = _t("Belum ada catatan hari ini. Sapa tetangga atau mulai shift!", "No activity logged yet. Chat with neighbors or start a shift!")
		empty_lbl.add_theme_color_override("font_color", Color(0.88, 0.87, 0.83))
		_modal_list.add_child(empty_lbl)
	else:
		for idx in range(entries.size() - 1, -1, -1):
			var e: Dictionary = entries[idx]
			var row := Label.new()
			var title := String(e["title_en"] if _loc() == "en" else e["title_id"])
			var drp := int(e.get("delta_rp", 0))
			var rp_txt := ""
			if drp > 0:
				rp_txt = "  +%s" % I18n.format_balance(drp, _loc())
			elif drp < 0:
				rp_txt = "  -%s" % I18n.format_balance(absi(drp), _loc())
			row.text = "%s %d • %s%s" % [_t("Hari", "Day"), int(e["day"]), title, rp_txt]
			row.add_theme_font_size_override("font_size", 12)
			row.add_theme_color_override("font_color", Color(0.45, 0.94, 0.44) if drp > 0 else (Color(0.96, 0.62, 0.42) if drp < 0 else Color(0.95, 0.94, 0.90)))
			_modal_list.add_child(row)
	var btn_back := Button.new()
	btn_back.text = _t("Kembali ke Menu", "Back to Menu")
	_style_btn(btn_back, Color(0.16, 0.18, 0.22), Color(0.96, 0.78, 0.26))
	btn_back.pressed.connect(_open_settings_modal)
	_modal_list.add_child(btn_back)
	_show_modal()

func _add_modal_section(title_txt: String) -> void:
	var sec := Label.new()
	sec.text = title_txt
	sec.add_theme_font_size_override("font_size", 11)
	sec.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34))
	_modal_list.add_child(sec)

func _open_settings_modal() -> void:
	if _is_sleeping:
		return
	_clear_modal()
	_reset_confirm = false
	_modal_title.text = _t("MENU, PENGATURAN & CATATAN", "MENU, SETTINGS & LOG")
	_add_modal_section(_t("AKUN & PROGRES", "ACCOUNT & PROGRESS"))

	var btn_prof := Button.new()
	btn_prof.text = _t("Edit Profil & Karakter ART", "Edit ART Profile & Look")
	btn_prof.icon = Portraits.get_ui_icon("icon_wardrobe")
	btn_prof.expand_icon = true
	btn_prof.add_theme_constant_override("icon_max_width", 24)
	btn_prof.disabled = _in_shift
	btn_prof.pressed.connect(func():
		_modal_backdrop.visible = false
		_open_onboarding()
		_refresh_hud()
	)
	_modal_list.add_child(btn_prof)

	var btn_log := Button.new()
	btn_log.text = _t("Catatan Harian ART (%d)" % Settings.get_daily_log(_save).size(), "Daily ART Log (%d)" % Settings.get_daily_log(_save).size())
	btn_log.icon = Portraits.get_ui_icon("app_debt")
	btn_log.expand_icon = true
	btn_log.add_theme_constant_override("icon_max_width", 24)
	btn_log.pressed.connect(_open_log_modal)
	_modal_list.add_child(btn_log)

	var btn_wish := Button.new()
	btn_wish.text = _t("Impian ART (%d/4)" % (_save.get("unlocked_wishlist", []) as Array).size(), "ART Dreams (%d/4)" % (_save.get("unlocked_wishlist", []) as Array).size())
	btn_wish.icon = Portraits.get_ui_icon("app_dreams")
	btn_wish.expand_icon = true
	btn_wish.add_theme_constant_override("icon_max_width", 24)
	btn_wish.pressed.connect(_open_wishlist_modal)
	_modal_list.add_child(btn_wish)

	var btn_book := Button.new()
	btn_book.text = _t("Buku Cerita ART", "ART Story Book")
	btn_book.icon = Portraits.get_ui_icon("app_story")
	btn_book.expand_icon = true
	btn_book.add_theme_constant_override("icon_max_width", 24)
	btn_book.pressed.connect(_open_storybook_modal)
	_modal_list.add_child(btn_book)

	var btn_ret := Button.new()
	btn_ret.text = _t("★ Misi Harian, Streak & Lencana" if Retention.has_unclaimed_daily_reward(_save, _today_date_str()) else "Misi Harian, Streak & Lencana", "★ Daily Missions, Streak & Badges" if Retention.has_unclaimed_daily_reward(_save, _today_date_str()) else "Daily Missions, Streak & Badges")
	btn_ret.icon = Portraits.get_ui_icon("app_missions")
	btn_ret.expand_icon = true
	btn_ret.add_theme_constant_override("icon_max_width", 24)
	btn_ret.pressed.connect(_open_retention_modal)
	_modal_list.add_child(btn_ret)

	_add_modal_section(_t("AKTIVITAS & IBADAH", "ACTIVITIES & REMINDERS"))
	var pray_on := bool(_save.get("prayer_reminders", true))
	if pray_on:
		var btn_pray_now := Button.new()
		btn_pray_now.text = _t("Sholat / Doa (+12 Semangat)" + (" & Buka Puasa" if LifeRhythm.get_season(int(_save.get("day", 1))) == "ramadhan" else ""), "Pray (+12 Mood)" + (" & Break Fast" if LifeRhythm.get_season(int(_save.get("day", 1))) == "ramadhan" else ""))
		btn_pray_now.icon = Portraits.get_ui_icon("star_filled")
		btn_pray_now.expand_icon = true
		btn_pray_now.add_theme_constant_override("icon_max_width", 24)
		btn_pray_now.pressed.connect(func():
			_modal_backdrop.visible = false
			_trigger_prayer_action()
		)
		_modal_list.add_child(btn_pray_now)

	var btn_pr_tog := Button.new()
	btn_pr_tog.text = _t("Pengingat Waktu Sholat: Aktif" if pray_on else "Pengingat Waktu Sholat: Mati", "Prayer Reminders: On" if pray_on else "Prayer Reminders: Off")
	btn_pr_tog.icon = Portraits.get_ui_icon("app_guide")
	btn_pr_tog.expand_icon = true
	btn_pr_tog.add_theme_constant_override("icon_max_width", 24)
	btn_pr_tog.pressed.connect(func():
		_save["prayer_reminders"] = not pray_on
		SaveStore.save_to_slot(_save, _active_slot)
		if _world_mode == "home":
			_enter_home_mode()
		_open_settings_modal()
	)
	_modal_list.add_child(btn_pr_tog)

	_add_modal_section(_t("PENGATURAN SISTEM", "SYSTEM SETTINGS"))
	var btn_lang := Button.new()
	btn_lang.text = _t("Bahasa: Indonesia (Ubah ke EN)", "Language: English (Switch to ID)")
	btn_lang.icon = Portraits.get_ui_icon("app_map")
	btn_lang.expand_icon = true
	btn_lang.add_theme_constant_override("icon_max_width", 24)
	btn_lang.pressed.connect(func():
		_play_sfx(_wav_click)
		_save["locale"] = "en" if _loc() == "id" else "id"
		SaveStore.save_to_slot(_save, _active_slot)
		_refresh_hud()
		_open_settings_modal()
	)
	_modal_list.add_child(btn_lang)

	var btn_sfx := Button.new()
	btn_sfx.text = _t("Efek Suara: Mati" if _muted else "Efek Suara: Aktif", "Sound SFX: Off" if _muted else "Sound SFX: On")
	btn_sfx.icon = Portraits.get_ui_icon("icon_phone")
	btn_sfx.expand_icon = true
	btn_sfx.add_theme_constant_override("icon_max_width", 24)
	btn_sfx.pressed.connect(func():
		_muted = not _muted
		_save["muted"] = _muted
		SaveStore.save_to_slot(_save, _active_slot)
		_sync_ambient_audio()
		_open_settings_modal()
	)
	_modal_list.add_child(btn_sfx)

	var bgm_on := bool(_save.get("bgm_enabled", true))
	var btn_bgm := Button.new()
	btn_bgm.text = _t("Musik Latar (BGM): Aktif" if bgm_on else "Musik Latar (BGM): Mati", "Background Music: On" if bgm_on else "Background Music: Off")
	btn_bgm.icon = Portraits.get_ui_icon("app_chat")
	btn_bgm.expand_icon = true
	btn_bgm.add_theme_constant_override("icon_max_width", 24)
	btn_bgm.pressed.connect(func():
		_play_sfx(_wav_click)
		_save["bgm_enabled"] = not bgm_on
		SaveStore.save_to_slot(_save, _active_slot)
		_sync_ambient_audio()
		_open_settings_modal()
	)
	_modal_list.add_child(btn_bgm)

	var q_cur := String(_save.get("gfx_quality", "high"))
	var btn_gfx := Button.new()
	btn_gfx.text = _t("Grafis: Ringan (HP)" if q_cur == "low" else "Grafis: Tinggi (Bayangan)", "Graphics: Low (Mobile)" if q_cur == "low" else "Graphics: High (Shadows)")
	btn_gfx.pressed.connect(func():
		_play_sfx(_wav_click)
		var nxt_q := "low" if q_cur == "high" else "high"
		_save["gfx_quality"] = nxt_q
		SaveStore.save_to_slot(_save, _active_slot)
		Settings.apply_graphics_quality(sun_light, world_env.environment if world_env != null else null, nxt_q)
		_open_settings_modal()
	)
	_modal_list.add_child(btn_gfx)

	var w_on := bool(_save.get("weather_fx", true))
	var btn_wfx := Button.new()
	btn_wfx.text = _t("Cuaca Hujan: Aktif" if w_on else "Cuaca Hujan: Cerah Saja", "Rain Weather: On" if w_on else "Rain Weather: Always Clear")
	btn_wfx.pressed.connect(func():
		_save["weather_fx"] = not w_on
		SaveStore.save_to_slot(_save, _active_slot)
		_refresh_atmosphere()
		_refresh_hud()
		_open_settings_modal()
	)
	_modal_list.add_child(btn_wfx)

	var btn_rst := Button.new()
	btn_rst.text = _t("Mulai Ulang Karier (Reset Save)", "Reset Career Save")
	btn_rst.disabled = _in_shift
	_style_btn(btn_rst, Color(0.55, 0.16, 0.16), Color(0.95, 0.65, 0.45))
	btn_rst.pressed.connect(func():
		if _in_shift:
			return
		if not _reset_confirm:
			_reset_confirm = true
			btn_rst.text = _t("Ketuk Sekali Lagi untuk KONFIRMASI RESET", "Tap Again to CONFIRM RESET")
			return
		_save = Progression.create_player_save()
		_muted = bool(_save.get("muted", false))
		_shift = {}
		_call_state = {}
		_active_chore_id = ""
		_shift_elapsed_s = 0.0
		_in_shift = false
		SaveStore.save_to_slot(_save, _active_slot)
		Settings.apply_graphics_quality(sun_light, world_env.environment if world_env != null else null, String(_save.get("gfx_quality", "high")))
		_modal_backdrop.visible = false
		_enter_home_mode()
		_sync_player_outfit()
		_open_onboarding()
		_refresh_hud()
	)
	_modal_list.add_child(btn_rst)
	_show_modal()

func _make_box(bg: Color, border: Color, radius: int = 12, pad_h: int = 12, pad_v: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb

func _style_btn(btn: Button, bg: Color, border: Color, txt: Color = Color(0.98, 0.97, 0.94)) -> void:
	btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, 44.0)
	btn.add_theme_stylebox_override("normal", _make_box(bg, border, 10, 12, 7))
	btn.add_theme_stylebox_override("hover", _make_box(bg.lightened(0.10), border, 10, 12, 7))
	btn.add_theme_stylebox_override("focus", _make_box(bg.lightened(0.08), border.lightened(0.12), 10, 12, 7))
	btn.add_theme_stylebox_override("pressed", _make_box(bg.darkened(0.12), border, 10, 12, 7))
	btn.add_theme_stylebox_override("disabled", _make_box(Color(0.11, 0.14, 0.20, 0.94), Color(0.36, 0.40, 0.48, 0.80), 10, 12, 7))
	btn.add_theme_color_override("font_color", txt)
	btn.add_theme_color_override("font_hover_color", txt)
	btn.add_theme_color_override("font_focus_color", txt)
	btn.add_theme_color_override("font_pressed_color", txt)
	btn.add_theme_color_override("font_disabled_color", Color(0.84, 0.86, 0.90))

func _style_bar(bar: ProgressBar, fill_col: Color, bg_col: Color = Color(0.08, 0.08, 0.08, 0.65)) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_col
	bg.set_corner_radius_all(6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill_col
	fg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)

func _shadow_label(lbl: Label, sz: int, col: Color, outline_sz: int = 5) -> void:
	lbl.add_theme_font_size_override("font_size", sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 0.96))
	lbl.add_theme_constant_override("outline_size", outline_sz)

func _make_dock_icon_btn(key: String, icon_name: String, badge_col: Color = Color(0.86, 0.18, 0.16)) -> Dictionary:
	var wrap := VBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override("separation", 1)
	var ic_box := Control.new()
	ic_box.custom_minimum_size = Vector2(54, 48)
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", _make_box(Color(1, 1, 1, 0.12), Color(0.98, 0.84, 0.34, 0.65), 14, 2, 2))
	btn.add_theme_stylebox_override("pressed", _make_box(Color(0, 0, 0, 0.18), Color(0.98, 0.84, 0.34, 0.95), 14, 2, 2))
	var icon_rect := TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.offset_left = 2
	icon_rect.offset_right = -2
	icon_rect.offset_top = 0
	icon_rect.offset_bottom = 0
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = Portraits.get_ui_icon(icon_name)
	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	badge.position = Vector2(34, -2)
	badge.custom_minimum_size = Vector2(18, 18)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_stylebox_override("normal", _make_box(badge_col, Color(1, 1, 1), 9, 4, 1))
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", Color(1, 1, 1))
	ic_box.add_child(btn)
	ic_box.add_child(icon_rect)
	ic_box.add_child(badge)
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(58, 0)
	_shadow_label(lbl, 11, Color(0.98, 0.97, 0.94), 5)
	wrap.add_child(ic_box)
	wrap.add_child(lbl)
	_dock_labels[key] = lbl
	_dock_icons[key] = icon_rect
	_dock_badges[key] = badge
	return {"wrap": wrap, "btn": btn, "badge": badge, "lbl": lbl}

func _build_hud() -> void:
	var vig := ColorRect.new()
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v_sh := Shader.new()
	v_sh.code = "shader_type canvas_item;\nvoid fragment() {\n	float d = length((UV - 0.5) * vec2(1.0, 0.85));\n	float a = smoothstep(0.45, 1.05, d) * 0.22;\n	COLOR = vec4(0.03, 0.04, 0.07, a);\n}\n"
	var v_mat := ShaderMaterial.new()
	v_mat.shader = v_sh
	vig.material = v_mat
	hud.add_child(vig)

	var obsidian_gold := _make_box(Color(0.08, 0.09, 0.12, 0.92), Color(0.95, 0.78, 0.26, 0.92), 14, 14, 10)
	var gold_pill := _make_box(Color(0.96, 0.78, 0.24, 1.0), Color(0.99, 0.89, 0.48, 1.0), 10, 14, 7)
	var dark_ink := Color(0.11, 0.09, 0.06)
	var light_ink := Color(0.97, 0.96, 0.93)

	# 1. TOP-LEFT COHESIVE GLASS HUD (Big Clock + 5 Stars + Both ENERGI & SEMANGAT Bars)
	var tl_panel := PanelContainer.new()
	tl_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tl_panel.position = Vector2(14, 10)
	tl_panel.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.08, 0.12, 0.74), Color(0.95, 0.78, 0.26, 0.42), 12, 10, 6))
	_tl_card = tl_panel
	var tl_v := VBoxContainer.new()
	tl_v.add_theme_constant_override("separation", 4)

	var clock_row := HBoxContainer.new()
	clock_row.add_theme_constant_override("separation", 10)
	_lbl_meta = Label.new()
	_shadow_label(_lbl_meta, 25, light_ink, 6)
	var day_col := VBoxContainer.new()
	day_col.add_theme_constant_override("separation", 1)
	_lbl_day_sub = Label.new()
	_shadow_label(_lbl_day_sub, 12, Color(0.98, 0.86, 0.42), 5)
	_lbl_trust = Label.new()
	_shadow_label(_lbl_trust, 12, Color(0.92, 0.94, 0.98), 5)
	day_col.add_child(_lbl_day_sub)
	day_col.add_child(_lbl_trust)
	clock_row.add_child(_lbl_meta)
	clock_row.add_child(day_col)

	_stars_row = HBoxContainer.new()
	_stars_row.add_theme_constant_override("separation", 5)
	for _si in range(5):
		var st := TextureRect.new()
		st.custom_minimum_size = Vector2(18, 18)
		st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		st.texture = Portraits.get_ui_icon("star_empty")
		_stars_row.add_child(st)

	var bars_row := HBoxContainer.new()
	bars_row.add_theme_constant_override("separation", 12)
	var e_col := VBoxContainer.new()
	e_col.add_theme_constant_override("separation", 2)
	_lbl_energy = Label.new()
	_shadow_label(_lbl_energy, 11, Color(0.45, 0.96, 0.48), 5)
	_bar_energy = ProgressBar.new()
	_bar_energy.custom_minimum_size = Vector2(120, 10)
	_bar_energy.show_percentage = false
	_style_bar(_bar_energy, Color(0.32, 0.88, 0.40), Color(0.06, 0.08, 0.10, 0.65))
	e_col.add_child(_lbl_energy)
	e_col.add_child(_bar_energy)

	var m_col := VBoxContainer.new()
	m_col.add_theme_constant_override("separation", 2)
	_lbl_mood = Label.new()
	_shadow_label(_lbl_mood, 11, Color(0.76, 0.92, 1.0), 5)
	_bar_mood = ProgressBar.new()
	_bar_mood.custom_minimum_size = Vector2(120, 10)
	_bar_mood.show_percentage = false
	_style_bar(_bar_mood, Color(0.98, 0.78, 0.24), Color(0.06, 0.08, 0.10, 0.65))
	m_col.add_child(_lbl_mood)
	m_col.add_child(_bar_mood)

	bars_row.add_child(e_col)
	bars_row.add_child(m_col)

	tl_v.add_child(clock_row)
	tl_v.add_child(_stars_row)
	tl_v.add_child(bars_row)
	_tl_card.add_child(tl_v)
	hud.add_child(_tl_card)

	# 2. TOP-RIGHT FRAMELESS BALANCE + LEVEL BADGE + COMPACT MENU + TASKS DROPDOWN
	_tr_vbox = VBoxContainer.new()
	_tr_vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tr_vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tr_vbox.offset_right = -16
	_tr_vbox.offset_top = 12
	_tr_vbox.add_theme_constant_override("separation", 6)

	var top_r_row := HBoxContainer.new()
	top_r_row.alignment = BoxContainer.ALIGNMENT_END
	top_r_row.add_theme_constant_override("separation", 10)

	var lv_pill := PanelContainer.new()
	lv_pill.add_theme_stylebox_override("panel", _make_box(Color(0.96, 0.78, 0.24, 0.96), Color(0.99, 0.92, 0.60), 10, 10, 4))
	_lbl_level_badge = Label.new()
	_lbl_level_badge.add_theme_font_size_override("font_size", 13)
	_lbl_level_badge.add_theme_color_override("font_color", dark_ink)
	lv_pill.add_child(_lbl_level_badge)

	var bal_pill := PanelContainer.new()
	bal_pill.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.08, 0.12, 0.74), Color(0.95, 0.78, 0.26, 0.42), 10, 10, 4))
	_lbl_balance = Label.new()
	_shadow_label(_lbl_balance, 21, Color(0.44, 0.96, 0.44), 5)
	bal_pill.add_child(_lbl_balance)

	_btn_map = Button.new()
	_btn_settings = Button.new()
	_btn_map.custom_minimum_size = Vector2(64, 44)
	_btn_settings.custom_minimum_size = Vector2(76, 44)
	_style_btn(_btn_map, Color(0.10, 0.13, 0.18, 0.82), Color(0.95, 0.78, 0.26, 0.75))
	_style_btn(_btn_settings, Color(0.10, 0.13, 0.18, 0.82), Color(0.95, 0.78, 0.26, 0.75))
	_btn_map.pressed.connect(_open_map_modal)
	_btn_settings.pressed.connect(_open_settings_modal)
	top_r_row.add_child(lv_pill)
	top_r_row.add_child(bal_pill)
	top_r_row.add_child(_btn_map)
	top_r_row.add_child(_btn_settings)
	_tr_vbox.add_child(top_r_row)

	_tasks_card = PanelContainer.new()
	_tasks_card.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.10, 0.14, 0.86), Color(0.95, 0.78, 0.26, 0.75), 12, 10, 6))
	var tk_v := VBoxContainer.new()
	tk_v.add_theme_constant_override("separation", 3)
	_lbl_tasks_hdr = Label.new()
	_lbl_tasks_hdr.visible = false
	_btn_tasks_toggle = Button.new()
	_btn_tasks_toggle.custom_minimum_size = Vector2(180, 44)
	_btn_tasks_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_btn_tasks_toggle.add_theme_font_size_override("font_size", 13)
	_btn_tasks_toggle.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34))
	_btn_tasks_toggle.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_btn_tasks_toggle.add_theme_stylebox_override("hover", _make_box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 4, 4, 2))
	_btn_tasks_toggle.pressed.connect(func():
		_tasks_collapsed = not _tasks_collapsed
		_refresh_hud()
	)
	_tasks_list = VBoxContainer.new()
	_tasks_list.add_theme_constant_override("separation", 2)
	tk_v.add_child(_btn_tasks_toggle)
	tk_v.add_child(_lbl_tasks_hdr)
	tk_v.add_child(_tasks_list)
	_tasks_card.add_child(tk_v)
	_tr_vbox.add_child(_tasks_card)
	hud.add_child(_tr_vbox)

	# 3. TOP-CENTER OPEN SKY (Urgent Call Banner + Toast — bounded clear of TL/TR HUD!)
	var tc_center := CenterContainer.new()
	_tc_center = tc_center
	tc_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var tc_b := Atmosphere.compute_top_center_bounds(1280.0, 304.0, 396.0, 0.0, 0.0)
	tc_center.offset_left = float(tc_b["offset_left"])
	tc_center.offset_right = float(tc_b["offset_right"])
	tc_center.offset_top = 10
	tc_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tc_v := VBoxContainer.new()
	tc_v.add_theme_constant_override("separation", 8)
	tc_v.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_call_banner = PanelContainer.new()
	_call_banner.visible = false
	_call_banner.add_theme_stylebox_override("panel", _make_box(Color(0.76, 0.22, 0.18, 0.96), Color(0.98, 0.86, 0.65), 14, 10, 7))
	var call_h := HBoxContainer.new()
	call_h.add_theme_constant_override("separation", 8)
	_call_portrait = TextureRect.new()
	_call_portrait.custom_minimum_size = Vector2(44, 44)
	_call_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_call_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	call_h.add_child(_call_portrait)
	var call_text_v := VBoxContainer.new()
	call_text_v.add_theme_constant_override("separation", 3)
	_lbl_call_title = Label.new()
	_lbl_call_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_call_title.custom_minimum_size = Vector2(180, 0)
	_lbl_call_title.add_theme_font_size_override("font_size", 12)
	_lbl_call_title.add_theme_color_override("font_color", light_ink)
	_bar_call = ProgressBar.new()
	_bar_call.custom_minimum_size = Vector2(180, 9)
	_bar_call.show_percentage = false
	_style_bar(_bar_call, Color(0.98, 0.80, 0.30), Color(0.32, 0.10, 0.08, 0.7))
	call_text_v.add_child(_lbl_call_title)
	call_text_v.add_child(_bar_call)
	_btn_answer = Button.new()
	_btn_answer.custom_minimum_size = Vector2(96, 44)
	_style_btn(_btn_answer, Color(0.18, 0.66, 0.42), Color(0.95, 0.90, 0.72))
	_btn_answer.pressed.connect(_on_answer_call)
	call_h.add_child(call_text_v)
	call_h.add_child(_btn_answer)
	_call_banner.add_child(call_h)
	tc_v.add_child(_call_banner)

	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.add_theme_stylebox_override("panel", _make_box(Color(0.10, 0.13, 0.16, 0.92), Color(0.95, 0.78, 0.26, 0.75), 14, 14, 7))
	var toast_h := HBoxContainer.new()
	toast_h.add_theme_constant_override("separation", 8)
	_toast_portrait = TextureRect.new()
	_toast_portrait.visible = false
	_toast_portrait.custom_minimum_size = Vector2(38, 38)
	_toast_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_toast_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_toast_lbl = Label.new()
	_toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_lbl.custom_minimum_size = Vector2(220, 0)
	_toast_lbl.add_theme_color_override("font_color", light_ink)
	toast_h.add_child(_toast_portrait)
	toast_h.add_child(_toast_lbl)
	_toast_panel.add_child(toast_h)
	tc_v.add_child(_toast_panel)

	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.visible = false
	_lbl_tutorial = Label.new()
	_btn_tutorial_skip = Button.new()
	tc_v.add_child(_tutorial_panel)

	tc_center.add_child(tc_v)
	hud.add_child(tc_center)

	# World floating prompt for nearest chore/portal/NPC (tappable on mobile & clickable on desktop!)
	_world_prompt = Button.new()
	_world_prompt.visible = false
	_world_prompt.focus_mode = Control.FOCUS_NONE
	_world_prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	_world_prompt.custom_minimum_size = Vector2(0, 44)
	_style_btn(_world_prompt, Color(0.14, 0.54, 0.38, 0.95), Color(0.96, 0.84, 0.42), light_ink)
	_world_prompt.pressed.connect(_trigger_world_action)
	hud.add_child(_world_prompt)

	# Chore progress bar (anchored bottom-center)
	var bc_prog := CenterContainer.new()
	bc_prog.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bc_prog.offset_bottom = -88
	bc_prog.offset_top = -152
	bc_prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chore_bar_wrap = PanelContainer.new()
	_chore_bar_wrap.visible = false
	_chore_bar_wrap.add_theme_stylebox_override("panel", obsidian_gold)
	var ch_v := VBoxContainer.new()
	_lbl_chore_prog = Label.new()
	_lbl_chore_prog.add_theme_color_override("font_color", light_ink)
	_bar_chore = ProgressBar.new()
	_bar_chore.custom_minimum_size = Vector2(260, 14)
	_bar_chore.show_percentage = false
	_style_bar(_bar_chore, Color(0.24, 0.84, 0.48))
	ch_v.add_child(_lbl_chore_prog)
	ch_v.add_child(_bar_chore)
	_chore_bar_wrap.add_child(ch_v)
	bc_prog.add_child(_chore_bar_wrap)
	hud.add_child(bc_prog)

	# 4. BOTTOM-LEFT SLEEK TRANSLUCENT VIRTUAL JOYSTICK
	_joy_base = Panel.new()
	_joy_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joy_base.offset_left = 18
	_joy_base.offset_bottom = -16
	_joy_base.offset_top = -114
	_joy_base.offset_right = 116
	_joy_base.custom_minimum_size = Vector2(98, 98)
	_joy_base.add_theme_stylebox_override("panel", _make_box(Color(0.10, 0.12, 0.14, 0.24), Color(0.94, 0.90, 0.78, 0.42), 49, 0, 0))
	_joy_base.gui_input.connect(_on_joy_gui_input)
	_joy_knob = Panel.new()
	_joy_knob.custom_minimum_size = Vector2(34, 34)
	_joy_knob.size = Vector2(34, 34)
	_joy_knob.position = Vector2(32, 32)
	_joy_knob.add_theme_stylebox_override("panel", _make_box(Color(0.95, 0.78, 0.28, 0.75), Color(0.98, 0.96, 0.90), 17, 0, 0))
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.add_child(_joy_knob)
	hud.add_child(_joy_base)

	# 4B. STANDALONE BOTTOM-LEFT HP (SMARTPHONE OS) BUTTON (Anchored cleanly!)
	var d_ph := _make_dock_icon_btn("phone", "icon_phone")
	_btn_phone = d_ph["btn"]
	_lbl_phone_badge = d_ph["badge"]
	_set_dock_label("phone", "HP")
	_btn_phone.pressed.connect(func():
		if _is_sleeping:
			return
		_open_phone_os("home")
	)
	var hp_panel := PanelContainer.new()
	hp_panel.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.08, 0.12, 0.74), Color(0.95, 0.78, 0.26, 0.42), 12, 6, 4))
	hp_panel.add_child(d_ph["wrap"])
	_hp_bottom_left = hp_panel
	_hp_bottom_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hp_bottom_left.offset_left = 14
	_hp_bottom_left.offset_right = 88
	_hp_bottom_left.offset_top = -100
	_hp_bottom_left.offset_bottom = -12
	hud.add_child(_hp_bottom_left)

	# 5. BOTTOM-RIGHT FRAMELESS 3D PROP ICON DOCK (Warung Life Pattern!)
	_br_vbox = VBoxContainer.new()
	_br_vbox.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_br_vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_br_vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_br_vbox.offset_right = -14
	_br_vbox.offset_bottom = -12
	_br_vbox.add_theme_constant_override("separation", 8)

	_phone_popup = PanelContainer.new()
	_phone_popup.visible = false
	_btn_phone_answer = Button.new()
	_btn_game = Button.new()
	_btn_call_bf = Button.new()
	_br_vbox.add_child(_phone_popup)

	var dock := HBoxContainer.new()
	dock.alignment = BoxContainer.ALIGNMENT_END
	dock.add_theme_constant_override("separation", 6)

	var d_act := _make_dock_icon_btn("action", "icon_door")
	_btn_action = d_act["btn"]
	_btn_action.pressed.connect(_trigger_world_action)

	var d_shift := _make_dock_icon_btn("shift", "icon_broom")
	_btn_shift = d_shift["btn"]
	_btn_shift.pressed.connect(func():
		if _in_shift:
			_finish_shift()
		else:
			_start_shift()
	)

	var d_car := _make_dock_icon_btn("career", "icon_career")
	_btn_career = d_car["btn"]
	_btn_career.pressed.connect(_open_career_modal)

	var d_ward := _make_dock_icon_btn("wardrobe", "icon_wardrobe")
	_btn_ward = d_ward["btn"]
	_btn_ward.pressed.connect(_open_wardrobe_modal)

	var d_up := _make_dock_icon_btn("upgrade", "icon_upgrade", Color(0.18, 0.64, 0.36))
	_btn_kos = d_up["btn"]
	_btn_kos.pressed.connect(_open_kos_modal)

	for dw in [d_act["wrap"], d_shift["wrap"], d_car["wrap"], d_ward["wrap"], d_up["wrap"]]:
		dock.add_child(dw)
	var dock_scrim := PanelContainer.new()
	dock_scrim.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.08, 0.12, 0.76), Color(0.95, 0.78, 0.26, 0.42), 14, 8, 4))
	dock_scrim.add_child(dock)
	_br_vbox.add_child(dock_scrim)
	hud.add_child(_br_vbox)

	_build_courier_toast()

	# Modal Backdrop (Dark Obsidian + 2px Gold Border + ScrollContainer for Mobile Landscape)
	_modal_backdrop = ColorRect.new()
	_modal_backdrop.color = Color(0.03, 0.04, 0.06, 0.74)
	_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_card = PanelContainer.new()
	_modal_card.custom_minimum_size = Vector2(490, 260)
	_modal_card.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.09, 0.12, 0.96), Color(0.96, 0.78, 0.26), 16, 18, 14))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	var hdr_pill := PanelContainer.new()
	hdr_pill.add_theme_stylebox_override("panel", gold_pill)
	_modal_title = Label.new()
	_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_title.add_theme_font_size_override("font_size", 15)
	_modal_title.add_theme_color_override("font_color", dark_ink)
	hdr_pill.add_child(_modal_title)
	_modal_scroll = ScrollContainer.new()
	_modal_scroll.custom_minimum_size = Vector2(454, 240)
	_modal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_modal_list = VBoxContainer.new()
	_modal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_list.add_theme_constant_override("separation", 8)
	_modal_scroll.add_child(_modal_list)
	_btn_modal_close = Button.new()
	_style_btn(_btn_modal_close, Color(0.96, 0.78, 0.24), Color(0.99, 0.89, 0.48), dark_ink)
	_btn_modal_close.pressed.connect(func():
		_play_sfx(_wav_click)
		_modal_backdrop.visible = false
		_refresh_tutorial_banner()
		if _pending_story_tier != "":
			var pt := _pending_story_tier
			_pending_story_tier = ""
			_maybe_show_chapter_modal(pt)
		elif not _smoke_mode and _capture_path == "" and bool(_save.get("onboarding_done", false)):
			var ep := WishlistStory.get_unseen_epilogue(_save)
			if not ep.is_empty():
				_open_chapter_modal(ep)
	)
	vb.add_child(hdr_pill)
	vb.add_child(_modal_scroll)
	vb.add_child(_btn_modal_close)
	_modal_card.add_child(vb)
	center.add_child(_modal_card)
	_modal_backdrop.add_child(center)
	hud.add_child(_modal_backdrop)

	_build_dialogue_bar()
	_build_spotlight_overlay()
	_build_phone_os_overlay()
	_build_onboarding_overlay(obsidian_gold, gold_pill, dark_ink, light_ink)
	_build_title_overlay(obsidian_gold, dark_ink, light_ink)

func _build_onboarding_overlay(card_sb: StyleBoxFlat, gold_pill: StyleBoxFlat, dark_ink: Color, light_ink: Color) -> void:
	_onboarding_wrap = Control.new()
	_onboarding_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_onboarding_wrap.visible = false

	var right_card := PanelContainer.new()
	_ob_card = right_card
	right_card.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	right_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	right_card.offset_right = -24
	right_card.offset_left = -520
	right_card.offset_top = -310
	right_card.offset_bottom = 310
	right_card.add_theme_stylebox_override("panel", card_sb)

	var outer_v := VBoxContainer.new()
	outer_v.add_theme_constant_override("separation", 8)

	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 6)
	_ob_btn_back = Button.new()
	_ob_btn_back.custom_minimum_size = Vector2(76, 44)
	_style_btn(_ob_btn_back, Color(0.14, 0.16, 0.20), Color(0.55, 0.58, 0.65))
	_ob_btn_back.pressed.connect(func():
		if _onboarding_wrap != null:
			_onboarding_wrap.visible = false
		_open_title_screen()
	)
	var hdr_pill := PanelContainer.new()
	hdr_pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_pill.add_theme_stylebox_override("panel", gold_pill)
	_ob_title = Label.new()
	_ob_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ob_title.add_theme_font_size_override("font_size", 14)
	_ob_title.add_theme_color_override("font_color", dark_ink)
	hdr_pill.add_child(_ob_title)
	_ob_btn_lang = Button.new()
	_ob_btn_lang.custom_minimum_size = Vector2(52, 44)
	_style_btn(_ob_btn_lang, Color(0.14, 0.16, 0.20), Color(0.96, 0.78, 0.26))
	_ob_btn_lang.pressed.connect(func():
		_save["locale"] = "en" if _loc() == "id" else "id"
		SaveStore.save_to_slot(_save, _active_slot)
		_refresh_hud()
	)
	hdr_row.add_child(_ob_btn_back)
	hdr_row.add_child(hdr_pill)
	hdr_row.add_child(_ob_btn_lang)
	outer_v.add_child(hdr_row)

	var ob_sc := ScrollContainer.new()
	ob_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ob_sc.custom_minimum_size = Vector2(468, 430)
	ob_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)

	_ob_story = Label.new()
	_ob_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ob_story.add_theme_font_size_override("font_size", 13)
	_ob_story.add_theme_color_override("font_color", Color(0.94, 0.94, 0.90))
	vb.add_child(_ob_story)

	_ob_name_edit = LineEdit.new()
	_ob_name_edit.custom_minimum_size = Vector2(0, 44)
	_ob_name_edit.max_length = 24
	_ob_name_edit.add_theme_stylebox_override("normal", _make_box(Color(0.14, 0.16, 0.20), Color(0.95, 0.78, 0.26, 0.8), 10, 10, 6))
	_ob_name_edit.add_theme_color_override("font_color", light_ink)
	vb.add_child(_ob_name_edit)

	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override("separation", 8)
	_ob_btn_cepol = Button.new()
	_ob_btn_cepol.custom_minimum_size = Vector2(0, 44)
	_ob_btn_cepol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ob_btn_hijab = Button.new()
	_ob_btn_hijab.custom_minimum_size = Vector2(0, 44)
	_ob_btn_hijab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ob_btn_cepol.pressed.connect(func():
		_ob_style = "cepol"
		_preview_onboarding_character()
	)
	_ob_btn_hijab.pressed.connect(func():
		_ob_style = "hijab"
		_preview_onboarding_character()
	)
	style_row.add_child(_ob_btn_cepol)
	style_row.add_child(_ob_btn_hijab)
	vb.add_child(style_row)

	_ob_skin_lbl = Label.new()
	_ob_skin_lbl.add_theme_font_size_override("font_size", 12)
	_ob_skin_lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.34))
	vb.add_child(_ob_skin_lbl)
	var skin_row := HBoxContainer.new()
	skin_row.add_theme_constant_override("separation", 8)
	_ob_skin_btns.clear()
	for sk_cfg in [
		{"id": "Kuning", "en": "Fair", "hex": "#D49E72"},
		{"id": "Sawo Matang", "en": "Tan", "hex": "#B87A4B"},
		{"id": "Manis", "en": "Deep", "hex": "#8F5733"},
	]:
		var sb := Button.new()
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.custom_minimum_size = Vector2(0, 44)
		var h := String(sk_cfg["hex"])
		var sk_c := Color.html(h)
		_style_btn(sb, sk_c, Color(0.98, 0.94, 0.86), dark_ink if sk_c.get_luminance() > 0.24 else light_ink)
		sb.pressed.connect(func():
			_ob_skin = h
			_preview_onboarding_character()
		)
		skin_row.add_child(sb)
		_ob_skin_btns.append({"btn": sb, "id": String(sk_cfg["id"]), "en": String(sk_cfg["en"])})
	vb.add_child(skin_row)

	var col_grid := GridContainer.new()
	col_grid.columns = 2
	col_grid.add_theme_constant_override("h_separation", 8)
	col_grid.add_theme_constant_override("v_separation", 8)
	_ob_col_btns.clear()
	for c_cfg in [
		{"hex": "#4E7D63", "id": "Hijau Batik", "en": "Batik Sage"},
		{"hex": "#C9855E", "id": "Koral Hangat", "en": "Warm Coral"},
		{"hex": "#5A6D8C", "id": "Biru Denim", "en": "Denim Blue"},
		{"hex": "#8C4A5E", "id": "Marun", "en": "Maroon"},
	]:
		var cb := Button.new()
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.custom_minimum_size = Vector2(0, 44)
		var ch := String(c_cfg["hex"])
		var cval := Color.html(ch)
		_style_btn(cb, cval, Color(0.96, 0.88, 0.65), dark_ink if cval.get_luminance() > 0.32 else light_ink)
		cb.pressed.connect(func():
			_ob_color = ch
			_preview_onboarding_character()
		)
		col_grid.add_child(cb)
		_ob_col_btns.append({"btn": cb, "hex": ch, "id": String(c_cfg["id"]), "en": String(c_cfg["en"])})
	vb.add_child(col_grid)
	ob_sc.add_child(vb)
	outer_v.add_child(ob_sc)

	_ob_btn_start = Button.new()
	_ob_btn_start.custom_minimum_size = Vector2(0, 48)
	_style_btn(_ob_btn_start, Color(0.96, 0.78, 0.24), Color(0.99, 0.89, 0.48), dark_ink)
	_ob_btn_start.pressed.connect(_finish_onboarding)
	outer_v.add_child(_ob_btn_start)

	_ob_season_lbl = Label.new()
	_ob_season_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ob_season_lbl.add_theme_font_size_override("font_size", 12)
	_ob_season_lbl.add_theme_color_override("font_color", Color(0.84, 0.94, 1.0))
	outer_v.add_child(_ob_season_lbl)

	right_card.add_child(outer_v)
	_onboarding_wrap.add_child(right_card)
	hud.add_child(_onboarding_wrap)

func _build_title_overlay(card_sb: StyleBoxFlat, dark_ink: Color, light_ink: Color) -> void:
	_title_wrap = Control.new()
	_title_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_wrap.visible = false

	var title_card := PanelContainer.new()
	_title_card = title_card
	title_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	title_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	title_card.offset_left = 24
	title_card.offset_bottom = -20
	title_card.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.08, 0.12, 0.86), Color(0.96, 0.78, 0.26, 0.85), 16, 16, 14))
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 10)

	var logo := TextureRect.new()
	logo.custom_minimum_size = Vector2(280, 114)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture = Portraits.get_ui_icon("logo_art_simulator")
	left_col.add_child(logo)

	_title_btn_continue = Button.new()
	_title_btn_continue.custom_minimum_size = Vector2(280, 48)
	_style_btn(_title_btn_continue, Color(0.96, 0.78, 0.24), Color(0.99, 0.89, 0.48), dark_ink)
	_title_btn_continue.pressed.connect(func():
		_unlock_audio()
		if _title_wrap != null:
			_title_wrap.visible = false
		if bool(_save.get("onboarding_done", false)):
			_enter_home_mode()
			_sync_player_outfit()
			if not bool(_save.get("guide_seen", false)):
				_open_guide_modal(0)
			_refresh_hud()
		else:
			_open_onboarding()
			_refresh_hud()
	)

	_title_btn_new = Button.new()
	_title_btn_new.custom_minimum_size = Vector2(280, 46)
	_style_btn(_title_btn_new, Color(0.14, 0.17, 0.23, 0.92), Color(0.95, 0.78, 0.26))
	_title_btn_new.pressed.connect(func():
		_unlock_audio()
		_save = Progression.create_player_save()
		if _title_wrap != null:
			_title_wrap.visible = false
		_open_onboarding()
		_refresh_hud()
	)

	_title_btn_slots = Button.new()
	_title_btn_slots.custom_minimum_size = Vector2(280, 44)
	_style_btn(_title_btn_slots, Color(0.12, 0.14, 0.20, 0.92), Color(0.95, 0.78, 0.26, 0.75))
	_title_btn_slots.pressed.connect(_open_save_slots_modal)

	_title_btn_settings = Button.new()
	_title_btn_settings.custom_minimum_size = Vector2(280, 44)
	_style_btn(_title_btn_settings, Color(0.12, 0.14, 0.20, 0.92), Color(0.95, 0.78, 0.26, 0.75))
	_title_btn_settings.pressed.connect(_open_settings_modal)

	for tb in [_title_btn_continue, _title_btn_new, _title_btn_slots, _title_btn_settings]:
		left_col.add_child(tb)
	title_card.add_child(left_col)
	_title_wrap.add_child(title_card)

	var br_info := VBoxContainer.new()
	br_info.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br_info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	br_info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	br_info.offset_right = -24
	br_info.offset_bottom = -20
	br_info.add_theme_constant_override("separation", 8)
	var ver_pill := PanelContainer.new()
	ver_pill.size_flags_horizontal = Control.SIZE_SHRINK_END
	ver_pill.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.10, 0.14, 0.90), Color(0.95, 0.78, 0.26, 0.75), 8, 12, 5))
	var ver_lbl := Label.new()
	ver_lbl.text = _t("Versi 1.6 (HD)", "Version 1.6 (HD)")
	ver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver_lbl.add_theme_font_size_override("font_size", 12)
	ver_lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	ver_pill.add_child(ver_lbl)
	_title_btn_news = Button.new()
	_title_btn_news.custom_minimum_size = Vector2(148, 44)
	_style_btn(_title_btn_news, Color(0.14, 0.17, 0.24, 0.94), Color(0.95, 0.78, 0.26))
	_title_btn_news.pressed.connect(_open_whats_new_modal)
	br_info.add_child(ver_pill)
	br_info.add_child(_title_btn_news)
	_title_wrap.add_child(br_info)
	hud.add_child(_title_wrap)

func _open_title_screen() -> void:
	if _title_wrap == null:
		return
	_title_wrap.visible = true
	if _onboarding_wrap != null:
		_onboarding_wrap.visible = false
	var has_save := bool(_save.get("onboarding_done", false))
	_title_btn_continue.visible = has_save
	_title_btn_continue.text = _t("LANJUTKAN (Hari %d)" % int(_save.get("day", 1)), "CONTINUE (Day %d)" % int(_save.get("day", 1)))
	_title_btn_new.text = _t("MULAI BARU", "NEW GAME")
	if has_save:
		_style_btn(_title_btn_new, Color(0.14, 0.17, 0.23, 0.92), Color(0.95, 0.78, 0.26))
		_title_btn_continue.call_deferred("grab_focus")
	else:
		_style_btn(_title_btn_new, Color(0.96, 0.78, 0.24), Color(0.99, 0.89, 0.48), Color(0.11, 0.09, 0.06))
		_title_btn_new.call_deferred("grab_focus")
	_title_btn_slots.text = _t("MUAT SAVE (3 SLOT)", "LOAD SAVE (3 SLOTS)")
	_title_btn_settings.text = _t("PENGATURAN", "SETTINGS")
	_title_btn_news.text = _t("Info Terbaru", "What's New")
	cam.position = player.position + Vector3(1.85, 2.05, 3.05)
	cam.look_at(player.position + Vector3(0.0, 0.90, -0.35), Vector3.UP)
	_refresh_hud()

func _open_save_slots_modal() -> void:
	_clear_modal()
	_modal_title.text = _t("PILIH SLOT SIMPANAN (3 SLOT)", "CHOOSE SAVE SLOT (3 SLOTS)")
	for entry in SaveStore.list_save_slots(_loc()):
		var slot_idx := int(entry.get("slot", 1))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if bool(entry.get("exists", false)) and bool(entry.get("onboarding_done", false)):
			btn.text = "Slot %d · %s · %s %d · Lv.%d · %s" % [
				slot_idx, String(entry["player_name"]), _t("Hari", "Day"), int(entry["day"]),
				int(entry["level"]), I18n.format_balance(int(entry["balance_rp"]), _loc())
			]
			_style_btn(btn, Color(0.18, 0.44, 0.36), Color(0.95, 0.78, 0.26))
		else:
			btn.text = _t("Slot %d · Kosong (Buat Baru)" % slot_idx, "Slot %d · Empty (Start New)" % slot_idx)
			_style_btn(btn, Color(0.14, 0.16, 0.22), Color(0.65, 0.68, 0.75))
		btn.pressed.connect(func():
			_active_slot = slot_idx
			_save = SaveStore.load_from_slot(_active_slot)
			_modal_backdrop.visible = false
			if _title_wrap != null:
				_title_wrap.visible = false
			if bool(_save.get("onboarding_done", false)):
				_enter_home_mode()
				_sync_player_outfit()
				_refresh_hud()
			else:
				_open_onboarding()
				_refresh_hud()
		)
		row.add_child(btn)
		if SaveStore.should_show_slot_delete(entry):
			var del_b := Button.new()
			var is_arm := _confirm_delete_slot == slot_idx
			del_b.custom_minimum_size = Vector2(96, 44)
			del_b.set_meta("skip_autowrap", true)
			del_b.text = _t("Yakin Hapus?" if is_arm else "Hapus", "Confirm Del?" if is_arm else "Delete")
			_style_btn(del_b, Color(0.76, 0.16, 0.16) if is_arm else Color(0.58, 0.18, 0.18), Color(0.98, 0.80, 0.45) if is_arm else Color(0.95, 0.65, 0.55))
			del_b.pressed.connect(func():
				if _confirm_delete_slot != slot_idx:
					_confirm_delete_slot = slot_idx
					call_deferred("_open_save_slots_modal")
					return
				_confirm_delete_slot = 0
				SaveStore.delete_slot(slot_idx)
				if slot_idx == _active_slot:
					_save = SaveStore.load_from_slot(_active_slot)
				call_deferred("_open_save_slots_modal")
			)
			row.add_child(del_b)
		_modal_list.add_child(row)
	_show_modal()

func _open_whats_new_modal() -> void:
	_clear_modal()
	_modal_title.text = _t("INFO TERBARU — VERSI 1.6 HD", "WHAT'S NEW — VERSION 1.6 HD")
	for line in [
		_t("• Potret 3D Cycles & Ikon Bergambar di seluruh menu dan HP Sari.", "• 3D Cycles Portraits & Illustrated Icons across HUD and Smartphone OS."),
		_t("• Bank Desaku dengan target kiriman kampung & batas waktu Hari ke-10.", "• Bank Desaku with family remittance goal & Day-10 deadline."),
		_t("• Toko Belanja Perlengkapan + Kurir Pengantar + Catatan Kasbon.", "• Supply Shop + Live Courier Delivery Countdown + Debt Ledger."),
		_t("• Musholla kampung, zebra cross, dan detail dapur Cluster Elite.", "• Neighborhood Musholla, zebra crossing, and rich kitchen clutter."),
	]:
		var lbl := Label.new()
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.text = line
		lbl.add_theme_color_override("font_color", Color(0.95, 0.94, 0.90))
		_modal_list.add_child(lbl)
	_show_modal()

func _build_dialogue_bar() -> void:
	_dialogue_bar = PanelContainer.new()
	_dialogue_bar.visible = false
	_dialogue_bar.anchor_left = 0.5
	_dialogue_bar.anchor_right = 0.5
	_dialogue_bar.anchor_top = 1.0
	_dialogue_bar.anchor_bottom = 1.0
	_dialogue_bar.offset_left = -520
	_dialogue_bar.offset_right = 520
	_dialogue_bar.offset_top = -132
	_dialogue_bar.offset_bottom = 0
	_dialogue_bar.add_theme_stylebox_override("panel", _make_box(Color(0.06, 0.08, 0.12, 0.94), Color(0.96, 0.78, 0.26, 0.92), 0, 22, 12))
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	_dlg_portrait_wrap = PanelContainer.new()
	_dlg_portrait_wrap.custom_minimum_size = Vector2(96, 96)
	_dlg_portrait_wrap.add_theme_stylebox_override("panel", _make_box(Color(0.10, 0.16, 0.22), Color(0.96, 0.80, 0.34), 14, 3, 3))
	var p_over := Control.new()
	p_over.custom_minimum_size = Vector2(90, 90)
	_dlg_portrait = TextureRect.new()
	_dlg_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dlg_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dlg_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	p_over.add_child(_dlg_portrait)
	_dlg_portrait_wrap.add_child(p_over)

	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 6)
	var spk_row := HBoxContainer.new()
	spk_row.add_theme_constant_override("separation", 8)
	_dlg_speaker = Label.new()
	_dlg_speaker.add_theme_font_size_override("font_size", 15)
	_dlg_speaker.add_theme_color_override("font_color", Color(0.36, 0.88, 0.98))
	_dlg_phone_badge = Label.new()
	_dlg_phone_badge.text = _t("📞 TELP", "📞 CALL")
	_dlg_phone_badge.add_theme_stylebox_override("normal", _make_box(Color(0.10, 0.54, 0.32, 0.94), Color(0.96, 0.84, 0.34), 6, 6, 2))
	_dlg_phone_badge.add_theme_font_size_override("font_size", 11)
	_dlg_phone_badge.add_theme_color_override("font_color", Color(1, 1, 1))
	spk_row.add_child(_dlg_speaker)
	spk_row.add_child(_dlg_phone_badge)
	_dlg_body = Label.new()
	_dlg_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_body.add_theme_font_size_override("font_size", 15)
	_dlg_body.add_theme_color_override("font_color", Color(0.97, 0.96, 0.93))
	_dlg_next = Label.new()
	_dlg_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dlg_next.add_theme_font_size_override("font_size", 13)
	_dlg_next.add_theme_color_override("font_color", Color(0.99, 0.88, 0.36))
	tv.add_child(spk_row)
	tv.add_child(_dlg_body)
	tv.add_child(_dlg_next)

	hbox.add_child(_dlg_portrait_wrap)
	hbox.add_child(tv)
	var click_btn := Button.new()
	click_btn.flat = true
	click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	click_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	click_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	click_btn.pressed.connect(_advance_dialogue)
	_dialogue_bar.add_child(hbox)
	_dialogue_bar.add_child(click_btn)
	hud.add_child(_dialogue_bar)

func _start_intro_cutscene() -> void:
	_dlg_queue = WishlistStory.get_intro_cutscene_beats(String(_save.get("player_name", "Mbak Sari")), _loc())
	_dlg_on_done = func():
		if not bool(_save.get("guide_seen", false)):
			_open_guide_modal(0)
	_advance_dialogue()

func _advance_dialogue() -> void:
	if _dlg_queue.is_empty():
		if _dialogue_bar != null:
			_dialogue_bar.visible = false
		_refresh_hud()
		if _dlg_on_done.is_valid():
			var cb := _dlg_on_done
			_dlg_on_done = Callable()
			cb.call()
		return
	var beat: Dictionary = _dlg_queue.pop_front()
	var is_ph := bool(beat.get("phone", false))
	var spk_id := String(beat.get("speaker_id", "player"))
	_dlg_phone_badge.visible = is_ph
	_dlg_portrait.texture = _get_player_portrait_tex("happy") if spk_id == "player" else Portraits.get_portrait(spk_id, "happy")
	_dlg_speaker.text = String(beat.get("speaker", ""))
	_dlg_body.text = String(beat.get("text", ""))
	_dlg_next.text = _t("KETUK UNTUK LANJUT ▸", "TAP TO CONTINUE ▸")
	_dialogue_bar.visible = true
	if is_ph:
		_play_sfx(_wav_ring)
	_refresh_hud()

func _open_guide_modal(guide_idx: int = 0) -> void:
	var guides := WishlistStory.get_onboarding_guides(_save, _loc())
	if guide_idx >= guides.size():
		_save["guide_seen"] = true
		SaveStore.save_to_slot(_save, _active_slot)
		_modal_backdrop.visible = false
		_refresh_hud()
		return
	var g: Dictionary = guides[guide_idx]
	_clear_modal()
	_modal_title.text = "%s · %s" % [String(g["step_label"]), String(g["title"])]
	var bank_card := PanelContainer.new()
	bank_card.add_theme_stylebox_override("panel", _make_box(Color(0.10, 0.28, 0.54), Color(0.95, 0.78, 0.26), 12, 14, 12))
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	var bh := Label.new()
	bh.text = String(g["card_header"])
	bh.add_theme_font_size_override("font_size", 12)
	bh.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
	var bb := Label.new()
	bb.text = String(g["card_balance"])
	bb.add_theme_font_size_override("font_size", 20)
	bb.add_theme_color_override("font_color", Color(1, 1, 1))
	var gt := Label.new()
	gt.text = String(g["goal_title"])
	gt.add_theme_font_size_override("font_size", 13)
	gt.add_theme_color_override("font_color", Color(0.98, 0.86, 0.36))
	var gp := Label.new()
	gp.text = String(g["goal_progress"])
	gp.add_theme_font_size_override("font_size", 12)
	gp.add_theme_color_override("font_color", Color(0.85, 0.96, 0.88))
	bv.add_child(bh)
	bv.add_child(bb)
	bv.add_child(gt)
	bv.add_child(gp)
	bank_card.add_child(bv)
	_modal_list.add_child(bank_card)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = String(g["body"])
	body.add_theme_color_override("font_color", Color(0.95, 0.94, 0.90))
	_modal_list.add_child(body)

	var next_b := Button.new()
	next_b.text = _t("Lanjut (2/2)" if guide_idx == 0 else "Mengerti, Mulai!", "Next (2/2)" if guide_idx == 0 else "Got it, Let's Go!")
	_style_btn(next_b, Color(0.22, 0.64, 0.38), Color(0.96, 0.78, 0.26))
	next_b.pressed.connect(func(): _open_guide_modal(guide_idx + 1))
	_modal_list.add_child(next_b)
	var cult_g_b := Button.new()
	cult_g_b.text = _t("🌏 Catatan Budaya Indonesia", "🌏 Indonesian Cultural Notes")
	_style_btn(cult_g_b, Color(0.14, 0.24, 0.42), Color(0.96, 0.78, 0.26))
	cult_g_b.pressed.connect(func(): call_deferred("_open_cultural_notes_modal"))
	_modal_list.add_child(cult_g_b)
	_show_modal()
	if _btn_modal_close != null:
		_btn_modal_close.visible = false

func _build_spotlight_overlay() -> void:
	_spotlight_wrap = Control.new()
	_spotlight_wrap.visible = false
	_spotlight_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spotlight_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_spotlight_ring = Panel.new()
	_spotlight_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spotlight_ring.add_theme_stylebox_override("panel", _make_box(Color(0, 0, 0, 0), Color(0.98, 0.84, 0.24, 0.98), 16, 0, 0))
	_spotlight_wrap.add_child(_spotlight_ring)

	var hand_badge := PanelContainer.new()
	hand_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_badge.custom_minimum_size = Vector2(56, 56)
	hand_badge.size = Vector2(56, 56)
	hand_badge.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.10, 0.14, 0.90), Color(0.98, 0.84, 0.24, 0.98), 28, 6, 6))
	var hand_tex := TextureRect.new()
	hand_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_tex.flip_v = true
	hand_tex.modulate = Color(1.0, 0.90, 0.42, 1.0)
	hand_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand_tex.texture = Portraits.get_ui_icon("icon_hand_pointer")
	hand_badge.add_child(hand_tex)
	_spotlight_hand = hand_badge
	_spotlight_wrap.add_child(_spotlight_hand)

	_spotlight_card = PanelContainer.new()
	_spotlight_card.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.10, 0.14, 0.94), Color(0.96, 0.80, 0.28), 14, 14, 10))
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	_spotlight_title = Label.new()
	_spotlight_title.add_theme_font_size_override("font_size", 13)
	_spotlight_title.add_theme_color_override("font_color", Color(0.98, 0.84, 0.32))
	_spotlight_body = Label.new()
	_spotlight_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spotlight_body.custom_minimum_size = Vector2(230, 0)
	_spotlight_body.add_theme_font_size_override("font_size", 12)
	_spotlight_body.add_theme_color_override("font_color", Color(0.95, 0.94, 0.90))
	var btn_r := HBoxContainer.new()
	btn_r.add_theme_constant_override("separation", 8)
	_spotlight_btn_ok = Button.new()
	_style_btn(_spotlight_btn_ok, Color(0.22, 0.66, 0.38), Color(0.95, 0.90, 0.72))
	_spotlight_btn_ok.pressed.connect(func():
		_save = WishlistStory.advance_tutorial(_save)
		SaveStore.save_to_slot(_save, _active_slot)
		_refresh_spotlight()
	)
	_spotlight_btn_skip = Button.new()
	_style_btn(_spotlight_btn_skip, Color(0.16, 0.18, 0.22), Color(0.60, 0.62, 0.68))
	_spotlight_btn_skip.pressed.connect(func():
		_save = WishlistStory.advance_tutorial(_save, 4)
		SaveStore.save_to_slot(_save, _active_slot)
		_refresh_spotlight()
	)
	btn_r.add_child(_spotlight_btn_ok)
	btn_r.add_child(_spotlight_btn_skip)
	sv.add_child(_spotlight_title)
	sv.add_child(_spotlight_body)
	sv.add_child(btn_r)
	_spotlight_card.add_child(sv)
	_spotlight_wrap.add_child(_spotlight_card)
	_spotlight_wrap.move_child(_spotlight_hand, _spotlight_wrap.get_child_count() - 1)
	hud.add_child(_spotlight_wrap)

func _refresh_spotlight() -> void:
	if _spotlight_wrap == null:
		return
	var blocked := (_title_wrap != null and _title_wrap.visible) or (_onboarding_wrap != null and _onboarding_wrap.visible) or (_modal_backdrop != null and _modal_backdrop.visible) or (_dialogue_bar != null and _dialogue_bar.visible) or (_phone_os_wrap != null and _phone_os_wrap.visible) or (_in_shift and bool(_call_state.get("active_call", false))) or not bool(_save.get("onboarding_done", false)) or not bool(_save.get("guide_seen", false)) or _capture_path != ""
	var step := int(_save.get("tutorial_step", 0))
	if blocked or step >= 4:
		_spotlight_wrap.visible = false
		return
	var steps := Progression.get_spotlight_tutorial_steps(_loc())
	if step < 0 or step >= steps.size():
		_spotlight_wrap.visible = false
		return
	var st: Dictionary = steps[step]
	var tgt_ctrl: Control = _btn_shift
	match String(st["target"]):
		"tasks":
			tgt_ctrl = _tasks_card if (_tasks_card != null and _tasks_card.visible) else _btn_shift
		"phone":
			tgt_ctrl = _btn_phone
		"upgrade":
			tgt_ctrl = _btn_kos
		_:
			tgt_ctrl = _btn_shift
	if tgt_ctrl == null:
		_spotlight_target_ctrl = null
		_spotlight_wrap.visible = false
		return
	_spotlight_target_ctrl = tgt_ctrl
	_spotlight_title.text = String(st["title"])
	_spotlight_body.text = String(st["text"])
	_spotlight_btn_ok.text = _t("Mengerti", "Got it")
	_spotlight_btn_skip.text = _t("Lewati", "Skip")
	_spotlight_wrap.visible = true
	_position_spotlight_widgets()
	call_deferred("_position_spotlight_widgets")

func _position_spotlight_widgets() -> void:
	if _spotlight_wrap == null or not _spotlight_wrap.visible or _spotlight_target_ctrl == null or not is_instance_valid(_spotlight_target_ctrl):
		return
	var r := _spotlight_target_ctrl.get_global_rect().grow(6.0)
	var vp := get_viewport().get_visible_rect().size
	_spotlight_ring.position = r.position
	_spotlight_ring.size = r.size
	_spotlight_hand_base_pos = Vector2(clampf(r.position.x + r.size.x * 0.5 - 28.0, 8.0, vp.x - 64.0), clampf(r.position.y - 62.0, 8.0, vp.y - 64.0))
	_spotlight_hand.size = Vector2(56, 56)
	_spotlight_hand.position = _spotlight_hand_base_pos
	var card_w := 268.0
	var card_x := clampf(r.position.x - card_w + 24.0, 14.0, vp.x - card_w - 14.0)
	var card_y := clampf(r.position.y - 262.0, 56.0, vp.y - 210.0)
	_spotlight_card.position = Vector2(card_x, card_y)

func _build_courier_toast() -> void:
	_courier_toast = PanelContainer.new()
	_courier_toast.visible = false
	_courier_toast.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_courier_toast.offset_left = 128
	_courier_toast.offset_bottom = -16
	_courier_toast.offset_top = -86
	_courier_toast.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.12, 0.18, 0.94), Color(0.28, 0.68, 0.96), 12, 10, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(36, 36)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = Portraits.get_ui_icon("icon_courier_box")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_courier_lbl = Label.new()
	_courier_lbl.add_theme_font_size_override("font_size", 11)
	_courier_lbl.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	_courier_bar = ProgressBar.new()
	_courier_bar.custom_minimum_size = Vector2(150, 8)
	_courier_bar.show_percentage = false
	_style_bar(_courier_bar, Color(0.28, 0.76, 0.98))
	v.add_child(_courier_lbl)
	v.add_child(_courier_bar)
	_courier_claim_btn = Button.new()
	_style_btn(_courier_claim_btn, Color(0.20, 0.64, 0.38), Color(0.95, 0.88, 0.56))
	_courier_claim_btn.pressed.connect(func():
		var orders: Array = _save.get("courier_orders", [])
		for o in orders:
			if typeof(o) == TYPE_DICTIONARY and float(o.get("remaining_s", 1.0)) <= 0.01:
				var cl := Progression.claim_courier_delivery(_save, String(o["id"]))
				if bool(cl["ok"]):
					_save = cl["save"]
					SaveStore.save_to_slot(_save, _active_slot)
					_play_sfx(_wav_fanfare)
					_show_toast(_t("Paket kurir tiba! +%d Energi, +%d%% Semangat!" % [int(cl["energy_gain"]), int(cl["mood_gain"])], "Courier parcel arrived! +%d Energy, +%d%% Mood!" % [int(cl["energy_gain"]), int(cl["mood_gain"])]), "kurir_paket", "happy")
					_refresh_hud()
				break
	)
	h.add_child(ic)
	h.add_child(v)
	h.add_child(_courier_claim_btn)
	_courier_toast.add_child(h)
	hud.add_child(_courier_toast)

func _refresh_courier_toast() -> void:
	if _courier_toast == null:
		return
	var ui_cover := (_title_wrap != null and _title_wrap.visible) or (_onboarding_wrap != null and _onboarding_wrap.visible) or (_dialogue_bar != null and _dialogue_bar.visible) or (_modal_backdrop != null and _modal_backdrop.visible) or (_phone_os_wrap != null and _phone_os_wrap.visible)
	var orders: Array = _save.get("courier_orders", [])
	if ui_cover or orders.is_empty():
		_courier_toast.visible = false
		return
	var ord: Dictionary = orders[0]
	var rem := float(ord.get("remaining_s", 0.0))
	_courier_toast.visible = true
	if rem <= 0.01:
		_courier_lbl.text = _t("Kurir tiba: %s!" % String(ord.get("label_id", "Paket")), "Courier arrived: %s!" % String(ord.get("label_en", "Pack")))
		_courier_bar.value = 100.0
		_courier_claim_btn.visible = true
		_courier_claim_btn.text = _t("Ambil!", "Claim!")
	else:
		_courier_lbl.text = _t("Kurir mengantar... %d dtk" % int(ceilf(rem)), "Courier arriving... %ds" % int(ceilf(rem)))
		_courier_bar.value = clampf((16.0 - rem) / 16.0 * 100.0, 0.0, 100.0)
		_courier_claim_btn.visible = false

func _open_confirm_purchase_modal(item_label: String, cost_rp: int, on_confirm: Callable) -> void:
	var pv := Progression.preview_balance_after(_save, cost_rp)
	_clear_modal()
	_modal_title.text = _t("KONFIRMASI PEMBELIAN", "CONFIRM PURCHASE")
	var info_card := PanelContainer.new()
	info_card.add_theme_stylebox_override("panel", _make_box(Color(0.11, 0.15, 0.22), Color(0.96, 0.78, 0.26, 0.70), 12, 14, 10))
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	var item_l := Label.new()
	item_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_l.text = item_label
	item_l.add_theme_font_size_override("font_size", 15)
	item_l.add_theme_color_override("font_color", Color(0.98, 0.86, 0.36))
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "%s: %s\n%s: %s" % [
		_t("Harga", "Amount to pay"), I18n.format_balance(int(pv["cost_rp"]), _loc()),
		_t("Sisa uang setelah beli", "Money left after buying"), I18n.format_balance(int(pv["balance_after"]), _loc()),
	]
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", Color(0.95, 0.94, 0.90))
	iv.add_child(item_l)
	iv.add_child(info)
	info_card.add_child(iv)
	_modal_list.add_child(info_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var b_no := Button.new()
	b_no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_no.text = _t("Batal", "Cancel")
	_style_btn(b_no, Color(0.18, 0.20, 0.24), Color(0.60, 0.62, 0.68))
	b_no.pressed.connect(func():
		_modal_backdrop.visible = false
		_refresh_hud()
	)
	var b_yes := Button.new()
	b_yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_yes.text = _t("Ya, Beli", "Yes, Buy")
	b_yes.disabled = not bool(pv["can_afford"])
	_style_btn(b_yes, Color(0.96, 0.78, 0.24), Color(0.99, 0.89, 0.48), Color(0.11, 0.09, 0.06))
	b_yes.pressed.connect(func():
		_modal_backdrop.visible = false
		if on_confirm.is_valid():
			on_confirm.call()
	)
	row.add_child(b_no)
	row.add_child(b_yes)
	_modal_list.add_child(row)
	_show_modal()
	if _btn_modal_close != null:
		_btn_modal_close.visible = false
	b_yes.call_deferred("grab_focus")

func _build_phone_os_overlay() -> void:
	_phone_os_wrap = ColorRect.new()
	_phone_os_wrap.visible = false
	_phone_os_wrap.color = Color(0.02, 0.03, 0.05, 0.74)
	_phone_os_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ctr := CenterContainer.new()
	ctr.set_anchors_preset(Control.PRESET_FULL_RECT)

	_phone_os_bezel = PanelContainer.new()
	_phone_os_bezel.custom_minimum_size = Vector2(360, 480)
	_phone_os_bezel.add_theme_stylebox_override("panel", _make_box(Color(0.07, 0.08, 0.11, 0.99), Color(0.32, 0.36, 0.44), 28, 12, 10))
	var shell_v := VBoxContainer.new()
	shell_v.add_theme_constant_override("separation", 6)
	var speaker_bar := HBoxContainer.new()
	speaker_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	speaker_bar.add_theme_constant_override("separation", 8)
	var cam_dot := Panel.new()
	cam_dot.custom_minimum_size = Vector2(8, 8)
	cam_dot.add_theme_stylebox_override("panel", _make_box(Color(0.18, 0.36, 0.62), Color(0.42, 0.56, 0.80), 4, 0, 0))
	var ear_slot := Panel.new()
	ear_slot.custom_minimum_size = Vector2(46, 5)
	ear_slot.add_theme_stylebox_override("panel", _make_box(Color(0.18, 0.20, 0.26), Color(0, 0, 0, 0), 3, 0, 0))
	speaker_bar.add_child(cam_dot)
	speaker_bar.add_child(ear_slot)
	shell_v.add_child(speaker_bar)

	var screen_panel := PanelContainer.new()
	screen_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_panel.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.13, 0.22, 1.0), Color(0.95, 0.78, 0.26, 0.55), 18, 12, 10))
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)

	# Status bar
	var status_row := HBoxContainer.new()
	_phone_os_clock = Label.new()
	_phone_os_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phone_os_clock.add_theme_font_size_override("font_size", 13)
	_phone_os_clock.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	_phone_os_bal = Label.new()
	_phone_os_bal.add_theme_font_size_override("font_size", 13)
	_phone_os_bal.add_theme_color_override("font_color", Color(0.44, 0.96, 0.44))
	status_row.add_child(_phone_os_clock)
	status_row.add_child(_phone_os_bal)
	pv.add_child(status_row)

	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(332, 340)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_phone_os_body = VBoxContainer.new()
	_phone_os_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phone_os_body.add_theme_constant_override("separation", 8)
	sc.add_child(_phone_os_body)
	pv.add_child(sc)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	_phone_os_nav_back = Button.new()
	_phone_os_nav_back.custom_minimum_size = Vector2(0, 44)
	_phone_os_nav_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_btn(_phone_os_nav_back, Color(0.16, 0.20, 0.28), Color(0.95, 0.78, 0.26, 0.75))
	_phone_os_nav_back.pressed.connect(func(): _open_phone_os("home"))
	_phone_os_nav_home = Button.new()
	_phone_os_nav_home.custom_minimum_size = Vector2(0, 44)
	_phone_os_nav_home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_btn(_phone_os_nav_home, Color(0.16, 0.20, 0.28), Color(0.95, 0.78, 0.26, 0.75))
	_phone_os_nav_home.pressed.connect(func(): _open_phone_os("home"))
	_phone_os_nav_close = Button.new()
	_phone_os_nav_close.custom_minimum_size = Vector2(0, 44)
	_phone_os_nav_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_btn(_phone_os_nav_close, Color(0.64, 0.20, 0.20), Color(0.95, 0.78, 0.26, 0.90))
	_phone_os_nav_close.pressed.connect(func():
		_phone_os_wrap.visible = false
		_refresh_hud()
	)
	nav.add_child(_phone_os_nav_back)
	nav.add_child(_phone_os_nav_home)
	nav.add_child(_phone_os_nav_close)
	pv.add_child(nav)

	screen_panel.add_child(pv)
	shell_v.add_child(screen_panel)
	_phone_os_bezel.add_child(shell_v)
	ctr.add_child(_phone_os_bezel)
	_phone_os_wrap.add_child(ctr)
	hud.add_child(_phone_os_wrap)

func _open_phone_os(app_id: String = "home") -> void:
	_play_sfx(_wav_click)
	_phone_os_app = app_id
	_phone_os_wrap.visible = true
	_render_phone_app()
	_refresh_hud()
	if _phone_os_nav_close != null:
		_phone_os_nav_close.call_deferred("grab_focus")

func _render_phone_app() -> void:
	for c in _phone_os_body.get_children():
		_phone_os_body.remove_child(c)
		c.queue_free()
	var vp := _effective_window_size()
	var canvas_sz := get_viewport().get_visible_rect().size
	if canvas_sz.x <= 1.0 or canvas_sz.y <= 1.0:
		canvas_sz = Vector2(1280.0, 720.0)
	var layout_mode := Progression.get_phone_layout_mode(vp)
	var is_land := layout_mode == "landscape"
	if _phone_os_bezel != null:
		_phone_os_bezel.custom_minimum_size = Vector2(minf(860.0, canvas_sz.x - 100.0), minf(560.0, canvas_sz.y - 72.0)) if is_land else Vector2(minf(920.0, canvas_sz.x - 100.0), clampf(canvas_sz.y - 200.0, 500.0, 1180.0))
	var sc := _phone_os_body.get_parent() as ScrollContainer
	if sc != null:
		sc.custom_minimum_size = Vector2(minf(812.0, canvas_sz.x - 148.0), minf(415.0, canvas_sz.y - 215.0)) if is_land else Vector2(minf(872.0, canvas_sz.x - 148.0), clampf(canvas_sz.y - 360.0, 350.0, 960.0))
	_phone_os_clock.text = "%s · 4G" % LifeRhythm.format_clock(int(_save.get("game_minutes", 360)))
	_phone_os_bal.text = I18n.format_balance(int(_save.get("balance_rp", 0)), _loc())
	_phone_os_nav_back.text = _t("Kembali", "Back")
	_phone_os_nav_back.disabled = (_phone_os_app == "home")
	_phone_os_nav_home.text = _t("Beranda", "Home")
	_phone_os_nav_close.text = _t("Tutup HP", "Close")

	if _phone_os_app == "home":
		var grid := GridContainer.new()
		grid.columns = 5 if is_land else 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 14)
		var apps := [
			{"id": "bank", "ic": "app_bank", "id_lbl": "Bank Desaku", "en_lbl": "Village Bank"},
			{"id": "shop", "ic": "app_shop", "id_lbl": "Belanja", "en_lbl": "Supply Shop"},
			{"id": "chat", "ic": "app_chat", "id_lbl": "Pesan & Telp", "en_lbl": "Messages"},
			{"id": "debt", "ic": "app_debt", "id_lbl": "Buku Kasbon", "en_lbl": "Debt Book"},
			{"id": "log", "ic": "icon_career", "id_lbl": "Catatan Harian", "en_lbl": "Daily Log"},
			{"id": "dreams", "ic": "app_dreams", "id_lbl": "Impian ART", "en_lbl": "Dreams"},
			{"id": "story", "ic": "app_story", "id_lbl": "Buku Cerita", "en_lbl": "Story Book"},
			{"id": "missions", "ic": "app_missions", "id_lbl": "Misi Harian", "en_lbl": "Missions"},
			{"id": "map", "ic": "app_map", "id_lbl": "Peta", "en_lbl": "Map"},
			{"id": "guide", "ic": "app_guide", "id_lbl": "Panduan", "en_lbl": "Guide"},
		]
		for app in apps:
			var aid := String(app["id"])
			var tile := VBoxContainer.new()
			tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tile.alignment = BoxContainer.ALIGNMENT_CENTER
			var b := Button.new()
			b.custom_minimum_size = Vector2(92, 92)
			b.flat = true
			var ic := TextureRect.new()
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ic.set_anchors_preset(Control.PRESET_FULL_RECT)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.texture = Portraits.get_ui_icon(String(app["ic"]))
			b.add_child(ic)
			b.pressed.connect(func():
				if aid == "dreams":
					_phone_os_wrap.visible = false
					_open_wishlist_modal()
				elif aid == "story":
					_phone_os_wrap.visible = false
					_open_storybook_modal()
				elif aid == "missions":
					_phone_os_wrap.visible = false
					_open_retention_modal()
				elif aid == "map":
					_phone_os_wrap.visible = false
					_open_map_modal()
				elif aid == "guide":
					_phone_os_wrap.visible = false
					_open_guide_modal(0)
				elif aid == "log":
					_phone_os_wrap.visible = false
					_open_log_modal()
				else:
					_open_phone_os(aid)
			)
			var l := Label.new()
			l.text = String(app["en_lbl"] if _loc() == "en" else app["id_lbl"])
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_font_size_override("font_size", 12)
			l.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
			tile.add_child(b)
			tile.add_child(l)
			grid.add_child(tile)
		_phone_os_body.add_child(grid)
	elif _phone_os_app == "bank":
		var st := WishlistStory.get_remittance_goal_status(_save, _loc())
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _make_box(Color(0.10, 0.28, 0.54), Color(0.95, 0.78, 0.26), 12, 12, 10))
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		var hdr := Label.new()
		hdr.text = _t("Bank Desaku · Kirim ke Kampung", "Village Bank · Send Home")
		hdr.add_theme_color_override("font_color", Color(0.98, 0.86, 0.36))
		var stat := Label.new()
		stat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stat.text = _t(
			"Terkirim: %s / %s\nBatas Waktu: Hari %d (%d hari lagi)" % [I18n.format_balance(int(st["sent_rp"]), "id"), I18n.format_balance(int(st["target_rp"]), "id"), int(st["deadline_day"]), int(st["days_left"])],
			"Sent: %s / %s\nDeadline: Day %d (%d days left)" % [I18n.format_balance(int(st["sent_rp"]), "en"), I18n.format_balance(int(st["target_rp"]), "en"), int(st["deadline_day"]), int(st["days_left"])]
		)
		stat.add_theme_color_override("font_color", Color(1, 1, 1))
		var bank_bar := ProgressBar.new()
		bank_bar.custom_minimum_size = Vector2(0, 10)
		bank_bar.max_value = maxi(1, int(st["target_rp"]))
		bank_bar.value = mini(int(st["sent_rp"]), int(st["target_rp"]))
		bank_bar.show_percentage = false
		_style_bar(bank_bar, Color(0.36, 0.90, 0.52), Color(0.06, 0.14, 0.28))
		cv.add_child(hdr)
		cv.add_child(stat)
		cv.add_child(bank_bar)
		card.add_child(cv)
		_phone_os_body.add_child(card)
		if bool(st["completed"]):
			var ok_l := Label.new()
			ok_l.text = _t("✓ Target kiriman kampung bulan ini lunas!", "✓ This month's village remittance goal is complete!")
			ok_l.add_theme_color_override("font_color", Color(0.45, 0.96, 0.52))
			_phone_os_body.add_child(ok_l)
		else:
			var rem_left := int(st["remaining_rp"])
			var amts: Array = [25000, 50000]
			if rem_left > 0 and not (rem_left in amts):
				amts.append(rem_left)
			for raw_amt in amts:
				var amt := int(raw_amt)
				var send_b := Button.new()
				send_b.text = _t("Kirim %s ke Kampung" % I18n.format_balance(amt, "id"), "Send %s Home" % I18n.format_balance(amt, "en"))
				send_b.disabled = int(_save.get("balance_rp", 0)) < amt
				_style_btn(send_b, Color(0.22, 0.62, 0.38), Color(0.96, 0.78, 0.26))
				send_b.pressed.connect(func():
					var sr := WishlistStory.send_remittance(_save, amt)
					if bool(sr["ok"]):
						_save = sr["save"]
						SaveStore.save_to_slot(_save, _active_slot)
						_play_sfx(_wav_fanfare if bool(sr["goal_completed"]) else _wav_coin)
						_show_toast(_t("Berhasil kirim %s ke Kampung!" % I18n.format_balance(int(sr["sent_rp"]), "id"), "Sent %s home!" % I18n.format_balance(int(sr["sent_rp"]), "en")), "ibu_kampung", "happy")
						_render_phone_app()
						_refresh_hud()
				)
				_phone_os_body.add_child(send_b)
	elif _phone_os_app == "shop":
		var hdr := Label.new()
		hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hdr.text = _t("Belanja Perlengkapan (Antar Kurir 16 dtk)", "Supply Shop (16s Courier Delivery)")
		hdr.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34))
		_phone_os_body.add_child(hdr)
		for raw_id in Progression.SUPPLY_SHOP_ITEMS.keys():
			var it_id := String(raw_id)
			var it: Dictionary = Progression.SUPPLY_SHOP_ITEMS[it_id]
			var row_b := Button.new()
			row_b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var lbl := String(it["label_en"] if _loc() == "en" else it["label_id"])
			row_b.text = "%s — %s\n%s" % [lbl, I18n.format_balance(int(it["cost_rp"]), _loc()), String(it["desc_en"] if _loc() == "en" else it["desc_id"])]
			row_b.disabled = int(_save.get("balance_rp", 0)) < int(it["cost_rp"])
			_style_btn(row_b, Color(0.16, 0.22, 0.30), Color(0.95, 0.78, 0.26, 0.8))
			row_b.pressed.connect(func():
				_phone_os_wrap.visible = false
				_open_confirm_purchase_modal(
					lbl,
					int(it["cost_rp"]),
					func():
						var co := Progression.checkout_supply_cart(_save, {it_id: 1})
						if bool(co["ok"]):
							_save = co["save"]
							SaveStore.save_to_slot(_save, _active_slot)
							_play_sfx(_wav_coin)
							_show_toast(_t("Kurir berangkat mengantar %s!" % lbl, "Courier on the way with %s!" % lbl), "kurir_paket", "happy")
							_refresh_hud()
				)
			)
			_phone_os_body.add_child(row_b)
	elif _phone_os_app == "chat":
		var chat_card := PanelContainer.new()
		chat_card.add_theme_stylebox_override("panel", _make_box(Color(0.11, 0.24, 0.36), Color(0.95, 0.78, 0.26, 0.80), 12, 12, 8))
		var cv_chat := VBoxContainer.new()
		cv_chat.add_theme_constant_override("separation", 4)
		var ch_hdr := Label.new()
		ch_hdr.text = _t("Pesan & Aktivitas HP", "Messages & Phone Activities")
		ch_hdr.add_theme_color_override("font_color", Color(0.98, 0.86, 0.36))
		var ch_sub := Label.new()
		ch_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ch_sub.text = _t("Jawab panggilan majikan atau pulihkan semangat di waktu luang.", "Answer employer calls or recharge your mood during free time.")
		ch_sub.add_theme_font_size_override("font_size", 12)
		ch_sub.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))
		cv_chat.add_child(ch_hdr)
		cv_chat.add_child(ch_sub)
		chat_card.add_child(cv_chat)
		_phone_os_body.add_child(chat_card)
		if _in_shift and bool(_call_state.get("active_call", false)):
			var ans := Button.new()
			ans.text = _t("Jawab Panggilan Majikan!", "Answer Employer Call!")
			_style_btn(ans, Color(0.76, 0.24, 0.20), Color(0.98, 0.86, 0.65))
			ans.pressed.connect(func():
				_phone_os_wrap.visible = false
				_on_answer_call()
			)
			_phone_os_body.add_child(ans)
		var g_b := Button.new()
		g_b.text = _t("Main Game Santai (+8 Semangat)", "Play Mini-Game (+8 Mood)")
		_style_btn(g_b, Color(0.24, 0.44, 0.66), Color(0.95, 0.78, 0.26))
		g_b.pressed.connect(func():
			_phone_os_wrap.visible = false
			if _in_shift:
				_on_distract("playing_game")
			else:
				_save["mood"] = clampi(int(_save.get("mood", 65)) + 8, 0, 100)
				SaveStore.save_to_slot(_save, _active_slot)
				_refresh_hud()
		)
		var bf_b := Button.new()
		bf_b.text = _t("Telp Keluarga / Pacar (+10 Semangat)", "Call Family / Partner (+10 Mood)")
		_style_btn(bf_b, Color(0.56, 0.30, 0.46), Color(0.95, 0.78, 0.26))
		bf_b.pressed.connect(func():
			_phone_os_wrap.visible = false
			if _in_shift:
				_on_distract("calling_boyfriend")
			else:
				_save["mood"] = clampi(int(_save.get("mood", 65)) + 10, 0, 100)
				SaveStore.save_to_slot(_save, _active_slot)
				_refresh_hud()
		)
		_phone_os_body.add_child(g_b)
		_phone_os_body.add_child(bf_b)
	elif _phone_os_app == "debt":
		var debts: Array = _save.get("debt_book", [])
		var unpaid := Progression.get_unpaid_kasbon_total(_save)
		var d_card := PanelContainer.new()
		d_card.add_theme_stylebox_override("panel", _make_box(Color(0.11, 0.16, 0.24), Color(0.95, 0.78, 0.26, 0.70), 12, 12, 10))
		var dv := VBoxContainer.new()
		dv.add_theme_constant_override("separation", 5)
		var d_hdr := Label.new()
		d_hdr.text = _t("Buku Catatan Kasbon (%s / Maks %s)" % [I18n.format_balance(unpaid, "id"), I18n.format_balance(Progression.MAX_KASBON_DEBT_RP, "id")], "Debt Ledger (%s / Cap %s)" % [I18n.format_balance(unpaid, "en"), I18n.format_balance(Progression.MAX_KASBON_DEBT_RP, "en")])
		d_hdr.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34))
		var d_bar := ProgressBar.new()
		d_bar.custom_minimum_size = Vector2(0, 8)
		d_bar.max_value = maxi(1, Progression.MAX_KASBON_DEBT_RP)
		d_bar.value = unpaid
		d_bar.show_percentage = false
		_style_bar(d_bar, Color(0.94, 0.56, 0.26), Color(0.07, 0.09, 0.14))
		dv.add_child(d_hdr)
		dv.add_child(d_bar)
		d_card.add_child(dv)
		_phone_os_body.add_child(d_card)
		if debts.is_empty():
			var em := Label.new()
			em.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			em.text = _t("Belum ada catatan kasbon. Bisa pinjam darurat di Warung Bu Tini jika butuh ongkos.", "No kasbon records yet. You can take a small emergency loan if needed.")
			em.add_theme_color_override("font_color", Color(0.86, 0.86, 0.84))
			_phone_os_body.add_child(em)
		else:
			for row in debts:
				if typeof(row) != TYPE_DICTIONARY:
					continue
				var did := String(row["id"])
				var paid := bool(row.get("paid", false))
				var amt := int(row.get("amount_rp", 0))
				var rb := Button.new()
				rb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_style_btn(rb, Color(0.16, 0.22, 0.30), Color(0.95, 0.78, 0.26, 0.75))
				if paid:
					rb.text = "✓ %s · %s (%s)" % [String(row["who"]), I18n.format_balance(amt, _loc()), _t("Lunas", "Paid")]
					rb.disabled = true
				else:
					rb.text = "%s · %s — %s (+8 XP)" % [String(row["who"]), I18n.format_balance(amt, _loc()), _t("Lunasi", "Pay Off")]
					rb.disabled = int(_save.get("balance_rp", 0)) < amt
					rb.pressed.connect(func():
						var pk := Progression.pay_kasbon(_save, did)
						if bool(pk["ok"]):
							_save = pk["save"]
							SaveStore.save_to_slot(_save, _active_slot)
							_play_sfx(_wav_coin)
							_render_phone_app()
							_refresh_hud()
					)
				_phone_os_body.add_child(rb)
		var borrow_b := Button.new()
		borrow_b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		borrow_b.text = _t("Pinjam Darurat %s (Warung Bu Tini)" % I18n.format_balance(25000, "id"), "Emergency Loan %s (Warung)" % I18n.format_balance(25000, "en"))
		borrow_b.disabled = unpaid + 25000 > Progression.MAX_KASBON_DEBT_RP
		_style_btn(borrow_b, Color(0.46, 0.32, 0.18), Color(0.95, 0.78, 0.26))
		borrow_b.pressed.connect(func():
			var rk := Progression.record_kasbon(_save, "Warung Bu Tini", 25000)
			if bool(rk["ok"]):
				_save = rk["save"]
				SaveStore.save_to_slot(_save, _active_slot)
				_play_sfx(_wav_coin)
				_render_phone_app()
				_refresh_hud()
		)
		_phone_os_body.add_child(borrow_b)
	elif _phone_os_app == "log":
		var hdr := Label.new()
		hdr.text = _t("CATATAN HARIAN & KEUANGAN", "DAILY ACTIVITY & FINANCE LOG")
		hdr.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34))
		_phone_os_body.add_child(hdr)
		var logs: Array = Settings.get_daily_log(_save)
		if logs.is_empty():
			var em_log := Label.new()
			em_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			em_log.text = _t("Belum ada catatan transaksi hari ini. Selesaikan shift, bayar sewa, atau belanja untuk melihat riwayat.", "No log entries yet. Complete a shift, pay rent, or shop to record activity.")
			em_log.add_theme_color_override("font_color", Color(0.86, 0.86, 0.84))
			_phone_os_body.add_child(em_log)
		else:
			for idx_l in range(logs.size() - 1, -1, -1):
				var entry = logs[idx_l]
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				var eday := int(entry.get("day", 1))
				var etitle := String(entry.get("title_en" if _loc() == "en" else "title_id", ""))
				var edelta := int(entry.get("delta_rp", 0))
				var card_l := PanelContainer.new()
				card_l.add_theme_stylebox_override("panel", _make_box(Color(0.11, 0.16, 0.24), Color(0.95, 0.78, 0.26, 0.55), 10, 10, 8))
				var row_l := HBoxContainer.new()
				row_l.add_theme_constant_override("separation", 8)
				var lbl_l := Label.new()
				lbl_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				lbl_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				lbl_l.text = "%s %d · %s" % [_t("Hari", "Day"), eday, etitle]
				lbl_l.add_theme_color_override("font_color", Color(0.94, 0.94, 0.90))
				var amt_l := Label.new()
				if edelta > 0:
					amt_l.text = "+%s" % I18n.format_balance(edelta, _loc())
					amt_l.add_theme_color_override("font_color", Color(0.45, 0.96, 0.54))
				elif edelta < 0:
					amt_l.text = "-%s" % I18n.format_balance(absi(edelta), _loc())
					amt_l.add_theme_color_override("font_color", Color(0.98, 0.54, 0.52))
				else:
					amt_l.text = "•"
					amt_l.add_theme_color_override("font_color", Color(0.76, 0.78, 0.84))
				row_l.add_child(lbl_l)
				row_l.add_child(amt_l)
				card_l.add_child(row_l)
				_phone_os_body.add_child(card_l)

func _open_onboarding() -> void:
	if _title_wrap != null:
		_title_wrap.visible = false
	_ob_style = String(_save.get("starter_style", "cepol"))
	_ob_skin = String(_save.get("skin_hex", "#B87A4B"))
	_ob_color = String(_save.get("outfit_color_hex", "#4E7D63"))
	if _ob_name_edit != null:
		_ob_name_edit.text = String(_save.get("player_name", "Mbak Sari"))
	if _onboarding_wrap != null:
		_onboarding_wrap.visible = true
	_apply_mobile_safe_area()
	var ob_vp := get_viewport().get_visible_rect().size
	var ob_is_port := ob_vp.x < ob_vp.y
	cam.position = player.position + (Vector3(0.0, 1.38, 2.75) if ob_is_port else Vector3(0.65, 1.36, 2.78))
	cam.look_at(player.position + (Vector3(0.0, 0.56, 0.0) if ob_is_port else Vector3(0.62, 0.84, 0.0)), Vector3.UP)
	_preview_onboarding_character()
	_refresh_onboarding_texts()
	if _ob_btn_start != null:
		_ob_btn_start.call_deferred("grab_focus")

func _preview_onboarding_character() -> void:
	var mpath := "res://assets/models/char_art_hijab.glb" if _ob_style == "hijab" else "res://assets/models/char_art.glb"
	player.load_outfit(String(_save.get("equipped_outfit_id", "starter_kasual")), mpath, _ob_color, _ob_skin)
	SceneVisuals.apply_unified_material_pass(player, false, false, _ensure_outline(), _actor_mat_cache)
	player.reapply_tints()
	_refresh_onboarding_texts()

func _refresh_onboarding_texts() -> void:
	if _onboarding_wrap == null or not _onboarding_wrap.visible:
		return
	_ob_title.text = _t("BUAT KARAKTER ART", "CREATE ART CHARACTER")
	_ob_story.text = _t(
		"Merantau ke kota demi masa depan lebih baik. Mulai dari kamar kos sederhana, bantu rumah Majikan, raih reputasi ★5!",
		"Arriving in the city for a brighter future. Start from a cozy kos room, help employers, and earn a ★5 reputation!"
	)
	if _ob_skin_lbl != null:
		_ob_skin_lbl.text = _t("Warna Kulit & Daster", "Skin Tone & Outfit")
	for entry in _ob_skin_btns:
		var b: Button = entry["btn"]
		b.text = String(entry["en"] if _loc() == "en" else entry["id"])
	for c_entry in _ob_col_btns:
		var cb: Button = c_entry["btn"]
		var ch := String(c_entry["hex"])
		var nm := String(c_entry["en"] if _loc() == "en" else c_entry["id"])
		var is_sel := (_ob_color == ch)
		cb.text = ("✓ " + nm) if is_sel else nm
		var cval_o := Color.html(ch)
		_style_btn(cb, cval_o, Color(0.99, 0.90, 0.36) if is_sel else Color(0.32, 0.36, 0.42), Color(0.11, 0.09, 0.06) if cval_o.get_luminance() > 0.32 else Color(0.97, 0.96, 0.93))
	_ob_btn_lang.text = "EN" if _loc() == "id" else "ID"
	_ob_btn_cepol.text = _t("Cepol (Daster)", "Bun (Daster)")
	_ob_btn_hijab.text = _t("Hijab (Bergo)", "Hijab (Bergo)")
	if _ob_btn_back != null:
		_ob_btn_back.text = _t("← Judul", "← Title")
	_style_btn(_ob_btn_cepol, Color(0.22, 0.56, 0.40) if _ob_style == "cepol" else Color(0.14, 0.16, 0.20), Color(0.96, 0.78, 0.26))
	_style_btn(_ob_btn_hijab, Color(0.22, 0.56, 0.40) if _ob_style == "hijab" else Color(0.14, 0.16, 0.20), Color(0.96, 0.78, 0.26))
	_ob_btn_start.text = _t("Mulai Kerja! (Hari 1)", "Start Working! (Day 1)")
	if _ob_season_lbl != null:
		_ob_season_lbl.text = _t("Musim 1: Karier ART (Lv 1-20)  ·  Musim 2: Segera Hadir", "Season 1: Homekeeper (Lv 1-20)  ·  Season 2: Coming Soon")
	if _ob_btn_back != null:
		_ob_btn_back.text = _t("Kembali ke Layar Judul", "Back to Title Screen")

func _finish_onboarding() -> void:
	_unlock_audio()
	var nm := _ob_name_edit.text if _ob_name_edit != null else "Mbak Sari"
	var res := Progression.complete_onboarding(_save, nm, _ob_style, _ob_skin, _ob_color)
	_save = res["save"]
	SaveStore.save_to_slot(_save, _active_slot)
	if _onboarding_wrap != null:
		_onboarding_wrap.visible = false
	_sync_player_outfit()
	_play_sfx(_wav_fanfare)
	_refresh_hud()
	if not _smoke_mode and _capture_path == "":
		_start_intro_cutscene()
	else:
		_maybe_show_chapter_modal(String(_save.get("active_tier_id", "kamar_kos")))

func _run_headless_smoke_test() -> void:
	_save = Progression.create_player_save()
	_enter_home_mode()
	assert(_world_mode == "home")
	_enter_street_mode("home")
	assert(_world_mode == "street")
	assert(_street_npcs_data.size() >= 2)
	_talk_to_street_npc(_street_npcs_data[0])
	assert(int(_save["mood"]) == 77)
	var bal_before_abort := int(_save["balance_rp"])
	_start_shift()
	assert(_in_shift)
	_finish_shift()
	assert(int(_save["balance_rp"]) == bal_before_abort)
	_start_shift()
	assert(_in_shift)
	_on_distract("playing_game")
	_call_state = MajikanCall.start_call(_call_state, "Smoke check call")
	_on_answer_call()
	for cid in (_shift["assigned_ids"] as Array).duplicate():
		_active_chore_id = String(cid)
		_finish_active_chore()
	_finish_shift()
	assert(not _in_shift)
	assert(int(_save["balance_rp"]) > 0)
	assert(int(_save["xp"]) > 0)
	SaveStore.save_to_path(_save, "user://smoke_test_v1.json")
	print("MAIN_GAME SMOKE TEST PASS: balance=%d xp=%d mood=%d" % [int(_save["balance_rp"]), int(_save["xp"]), int(_save["mood"])])
	get_tree().quit(0)

func _do_capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_capture_path)
	print("MAIN_GAME CAPTURED:", _capture_path)
	get_tree().quit(0)
