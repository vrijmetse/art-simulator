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
var _bgm_player: AudioStreamPlayer
var _rain_player: AudioStreamPlayer
var _step_player: AudioStreamPlayer
var _audio_unlocked := false
var _pending_story_tier := ""
var _pending_level_unlocks: Array = []
var _shift_event: Dictionary = {}
var _clock_accum := 0.0
var _late_night_warned_day := 0
var _last_prayer_id := ""
var _is_sleeping := false
var _tasks_collapsed := false
var _btn_tasks_toggle: Button

# HUD nodes
var _lbl_balance: Label
var _lbl_meta: Label
var _lbl_energy: Label
var _bar_energy: ProgressBar
var _lbl_mood: Label
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
var _tl_card: PanelContainer
var _tr_vbox: VBoxContainer
var _br_vbox: VBoxContainer
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
var _world_prompt: PanelContainer
var _lbl_world_prompt: Label
var _modal_backdrop: ColorRect
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
		elif arg.begins_with("--capture-tier="):
			_capture_tier = arg.substr("--capture-tier=".length())

	_save = SaveStore.load_from_path()
	var today_s := _today_date_str()
	_save = Retention.sync_daily_login(_save, today_s)["save"]
	_save = Retention.evaluate_badges(_save)["save"]
	_muted = bool(_save.get("muted", false))
	_build_hud()
	_apply_mobile_safe_area()
	Settings.apply_graphics_quality(sun_light, world_env.environment if world_env != null else null, String(_save.get("gfx_quality", "high")))

	if _smoke_mode:
		_run_headless_smoke_test()
		return

	if _capture_shift:
		_save["onboarding_done"] = true
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
	if _capture_onboarding or (not _skip_onboarding and not bool(_save.get("onboarding_done", false))):
		_open_onboarding()
	_refresh_hud()

func _loc() -> String:
	return String(_save.get("locale", "id"))

func _today_date_str() -> String:
	return Time.get_date_string_from_system()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _modal_backdrop != null and _modal_backdrop.visible:
			_modal_backdrop.visible = false
			_refresh_tutorial_banner()
		elif _phone_open:
			_phone_open = false
			_refresh_hud()
		elif _onboarding_wrap == null or not _onboarding_wrap.visible:
			_open_settings_modal()

func _apply_mobile_safe_area() -> void:
	if _smoke_mode or DisplayServer.get_name() == "headless":
		return
	var safe := DisplayServer.get_display_safe_area()
	var win := get_viewport().get_visible_rect().size
	if safe.size.x <= 0 or win.x <= 0:
		return
	var scale_x := win.x / maxf(1.0, float(DisplayServer.window_get_size().x))
	var pad_left := clampf(float(safe.position.x) * scale_x, 0.0, 48.0)
	if _tl_card != null:
		_tl_card.position.x = 14.0 + pad_left

func _t(id_str: String, en_str: String) -> String:
	return en_str if _loc() == "en" else id_str

func _play_sfx(wav: AudioStreamWAV) -> void:
	if _muted or _smoke_mode or wav == null or sfx == null:
		return
	sfx.stream = wav
	sfx.play()

func _get_player_portrait_tex(mood: String = "neutral") -> ImageTexture:
	return Portraits.get_player_portrait(
		String(_save.get("skin_hex", "#B87A4B")),
		String(_save.get("outfit_color_hex", "#4E7D63")),
		String(_save.get("avatar_style", "cepol")),
		mood
	)

func _show_toast(msg: String, speaker_id: String = "", mood: String = "happy") -> void:
	if _toast_lbl == null or _toast_panel == null:
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
	drop.size = Vector3(0.018, 0.26, 0.018)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.72, 0.86, 0.98, 0.65)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = dmat
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
	Atmosphere.apply_lighting(sun_light, bounce_light, env, _cur_phase, _cur_weather)
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

func _load_stage_glb(glb_path: String) -> void:
	_fan_blades.clear()
	for c in stage_root.get_children():
		c.queue_free()
	var resolved := glb_path
	if not ResourceLoader.exists(resolved):
		resolved = "res://assets/models/kos_room.glb"
	var packed: PackedScene = load(resolved)
	if packed != null:
		var inst := packed.instantiate()
		stage_root.add_child(inst)
		SceneVisuals.apply_baked_ao(inst)
		if "kos_room" in resolved:
			if ResourceLoader.exists("res://assets/lightmaps/kos_room_lightmap.png"):
				var lm_tex := load("res://assets/lightmaps/kos_room_lightmap.png") as Texture2D
				if lm_tex != null:
					SceneVisuals.apply_lightmap(inst, lm_tex)
			Atmosphere.apply_kos_upgrades_visual(inst, _save.get("unlocked_kos_upgrades", []))
			for fb_name in ["FanBlade_0", "FanBlade_1", "FanBlade_2", "FanBlade_3"]:
				var fb := inst.find_child(fb_name, true, false)
				if fb is Node3D:
					_fan_blades.append(fb)
		elif "kampung_gang" in resolved:
			if ResourceLoader.exists("res://assets/lightmaps/kampung_gang_lightmap.png"):
				var gang_lm := load("res://assets/lightmaps/kampung_gang_lightmap.png") as Texture2D
				if gang_lm != null:
					SceneVisuals.apply_lightmap(inst, gang_lm)

func _sync_player_outfit() -> void:
	var oid := String(_save.get("equipped_outfit_id", "starter_kasual"))
	var hex := String(_save.get("outfit_color_hex", "#4E7D63"))
	var skin_hex := String(_save.get("skin_hex", "#B87A4B"))
	var model_path := Progression.resolve_player_model_path(_save)
	player.load_outfit(oid, model_path, hex, skin_hex)

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
		SceneVisuals.apply_character_polish(inst)
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
	badge.position = Vector3(0.0, 0.90, 0.0)
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
	_clear_hotspots()
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
	_spawn_portal("exit_street", Vector3(0.45, 0.0, 1.15), Color(0.96, 0.78, 0.24), "Keluar Kamar", "Step Outside")
	_spawn_portal("sleep_bed", Vector3(-0.95, 0.0, -0.85), Color(0.45, 0.74, 0.96), "Tidur di Kasur", "Sleep to Recharge")
	if bool(_save.get("prayer_reminders", true)):
		_spawn_portal("pray_mat", Vector3(1.20, 0.0, 0.95), Color(0.32, 0.84, 0.62), "Sholat / Doa", "Pray")
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
	_clear_hotspots()
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
		SaveStore.save_to_path(_save)
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
	_shift_npcs_data = NpcRoster.get_shift_npcs(tier_id)
	_spawn_npcs(_shift_npcs_data)
	_clear_street_traffic()
	if int(_save.get("tutorial_step", 0)) < 2:
		_save = WishlistStory.advance_tutorial(_save, 2)
		SaveStore.save_to_path(_save)
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
		SaveStore.save_to_path(_save)
		_play_sfx(_wav_coin)
		var greet := _t("Semangat kerja hari ini ya!", "Have a great shift today!")
		for spec in Neighborhood.NEIGHBORS:
			if String(spec.get("id", "")) == nid:
				greet = String(spec.get("greeting_en" if _loc() == "en" else "greeting_id", greet))
				break
		_show_toast("%s: \"%s\" (+%s, +12 %s)" % [nname, greet, I18n.format_balance(tip_rp, _loc()), _t("Semangat", "Mood")], nid, "happy")
	else:
		_show_toast("%s: \"%s\"" % [nname, _t("Semangat kerjanya hari ini ya!", "Have a great shift today!")], nid, "neutral")
	_refresh_hud()

func _nearest_shift_npc(max_dist: float = 1.75) -> Dictionary:
	if _world_mode != "shift":
		return {}
	var best: Dictionary = {}
	var best_d := max_dist
	for npc in _shift_npcs_data:
		var pos: Vector3 = npc.get("pos", Vector3.ZERO)
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
	if _chore_boosts_used >= ChoreEngine.MAX_TAP_BOOSTS_PER_CHORE:
		return
	_chore_boosts_used += 1
	_chore_boost_cd = 0.35
	_chore_progress += ChoreEngine.TAP_BOOST_SECONDS
	_save["shift_boost_count"] = int(_save.get("shift_boost_count", 0)) + 1
	_save = Retention.record_mission_progress(_save, "boosts", 1, _today_date_str())
	_play_sfx(_wav_chore_tick)

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
	_play_sfx(_wav_sweep)

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
				SaveStore.save_to_path(_save)
	_refresh_hud()

func _finish_shift() -> void:
	if not _in_shift:
		return
	var prev_lv := Progression.level_from_xp(int(_save.get("xp", 0)))
	var prev_xp := int(_save.get("xp", 0))
	var res := Progression.settle_shift(_save, _shift, _call_state)
	if not res["ok"]:
		return
	_save = res["save"]
	_shift = res["shift"]
	if bool(res.get("aborted", false)):
		SaveStore.save_to_path(_save)
		_enter_street_mode("shift")
		_show_toast(_t("Belum ada tugas selesai — shift dibatalkan (Rp 0).", "No chores completed — shift cancelled (Rp 0)."))
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
	SaveStore.save_to_path(_save)
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
		_show_toast(_t("Ingat: Sewa kos Rp 120.000 jatuh tempo Hari 7!", "Reminder: Rp 120,000 kos rent due on Day 7!"))

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

	var modal_busy := (_onboarding_wrap != null and _onboarding_wrap.visible) or (_modal_backdrop != null and _modal_backdrop.visible)
	if not modal_busy and bool(_save.get("onboarding_done", false)):
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
		var ob_cam_target := player.position + Vector3(0.65, 1.42, 2.55)
		cam.position = cam.position.lerp(ob_cam_target, minf(1.0, delta * 6.0))
		cam.look_at(player.position + Vector3(0.62, 0.92, 0.0), Vector3.UP)
		return

	var cam_offset := Vector3(2.90, 2.95, 3.85) if _world_mode == "street" else Vector3(3.15, 3.10, 3.50)
	var cam_target := player.position + cam_offset
	cam.position = cam.position.lerp(cam_target, minf(1.0, delta * 5.0))
	cam.look_at(player.position + Vector3(0.0, 0.80, -0.35), Vector3.UP)

	if _world_mode == "home" and _fan_blades.size() > 0 and ("kipas_angin" in _save.get("unlocked_kos_upgrades", [])):
		for fb in _fan_blades:
			if is_instance_valid(fb):
				(fb as Node3D).rotate_z(delta * 5.5)

	if _world_mode == "street" and _traffic_items.size() > 0:
		StreetTraffic.step_vehicles(_traffic_items, delta)
		for ti in range(mini(_traffic_items.size(), _traffic_nodes.size())):
			var tn: Node3D = _traffic_nodes[ti]
			if is_instance_valid(tn):
				tn.position.x = float(_traffic_items[ti]["x"])

	if _world_mode == "street" and _street_npcs_data.size() > 0:
		StreetPatrols.step_patrols(_street_npcs_data, _street_cfg, player.position, delta, _cur_weather == "hujan")

	# Wayfinding Label3D fade: keep floor clean at distance, show cleanly within 3.2m
	for pnode in _portal_nodes:
		if is_instance_valid(pnode):
			var p_lbl3d := pnode.find_child("_Label3D", false, false) as Label3D
			if p_lbl3d != null:
				p_lbl3d.visible = pnode.position.distance_to(player.position) <= 3.2
	for s_npc in _street_npcs_data:
		var sn_node = s_npc.get("node", null)
		if sn_node != null and is_instance_valid(sn_node):
			var n_lbl3d := sn_node.find_child("_Label3D", false, false) as Label3D
			if n_lbl3d != null:
				n_lbl3d.visible = sn_node.position.distance_to(player.position) <= 3.2

	if not _in_shift:
		if _world_prompt != null:
			var np := _nearest_portal()
			var sn := _nearest_street_npc()
			if np != null and not cam.is_position_behind(np.global_position):
				var p_lbl := String(np.get_meta("label_en" if _loc() == "en" else "label_id", ""))
				_lbl_world_prompt.text = "[E] %s" % p_lbl
				var p_scr := cam.unproject_position(np.global_position + Vector3(0.0, 0.55, 0.0))
				_world_prompt.position = p_scr - _world_prompt.size * 0.5
				_world_prompt.visible = true
				if _btn_action != null:
					_btn_action.text = p_lbl
			elif not sn.is_empty():
				var npos: Vector3 = sn.get("pos", Vector3.ZERO)
				if not cam.is_position_behind(npos):
					var n_lbl := String(sn.get("label_en") if _loc() == "en" else sn.get("label_id"))
					_lbl_world_prompt.text = "[E] %s %s" % [_t("Ngobrol:", "Chat:"), n_lbl]
					var n_scr := cam.unproject_position(npos + Vector3(0.0, 1.35, 0.0))
					_world_prompt.position = n_scr - _world_prompt.size * 0.5
					_world_prompt.visible = true
					if _btn_action != null:
						_btn_action.text = _t("Ngobrol [E]", "Chat [E]")
				else:
					_world_prompt.visible = false
			else:
				_world_prompt.visible = false
				if _btn_action != null:
					_btn_action.text = _t("Masuk Kamar", "Enter Room") if _world_mode == "street" else _t("Keluar Kamar [E]", "Step Outside [E]")
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
		if near != null and _active_chore_id == "" and not cam.is_position_behind(near.global_position):
			var w_lbl: String = near.label_en if _loc() == "en" else near.label_id
			_lbl_world_prompt.text = "[E] %s" % w_lbl
			var scr := cam.unproject_position(near.global_position + Vector3(0.0, 0.45, 0.0))
			_world_prompt.position = scr - _world_prompt.size * 0.5
			_world_prompt.visible = true
			if _btn_action != null:
				_btn_action.text = _t("Kerjakan [E]", "Do Chore [E]")
		elif _active_chore_id == "":
			var sn_sh := _nearest_shift_npc()
			if not sn_sh.is_empty():
				var sh_pos: Vector3 = sn_sh.get("pos", Vector3.ZERO)
				if not cam.is_position_behind(sh_pos):
					var sh_lbl := String(sn_sh.get("label_en") if _loc() == "en" else sn_sh.get("label_id"))
					_lbl_world_prompt.text = "[E] %s %s" % [_t("Sapa:", "Greet:"), sh_lbl]
					var sh_scr := cam.unproject_position(sh_pos + Vector3(0.0, 1.35, 0.0))
					_world_prompt.position = sh_scr - _world_prompt.size * 0.5
					_world_prompt.visible = true
					if _btn_action != null:
						_btn_action.text = _t("Sapa [E]", "Greet [E]")
				else:
					_world_prompt.visible = false
			else:
				_world_prompt.visible = false
				if _btn_action != null:
					_btn_action.text = _t("Kerjakan [E]", "Do Chore [E]")
		else:
			_world_prompt.visible = false
			if _btn_action != null:
				_btn_action.text = _t("Ketuk Cepat! (%d/%d)" % [_chore_boosts_used, ChoreEngine.MAX_TAP_BOOSTS_PER_CHORE], "Tap Fast! (%d/%d)" % [_chore_boosts_used, ChoreEngine.MAX_TAP_BOOSTS_PER_CHORE])

	# Active chore progress
	if _active_chore_id != "":
		_chore_progress += delta
		_chore_bar_wrap.visible = true
		_bar_chore.max_value = _chore_duration
		_bar_chore.value = _chore_progress
		var cfg: Dictionary = ChoreEngine.CHORES[_active_chore_id]
		var tap_hint := _t("  [Ketuk E = Cepat!]", "  [Tap E = Boost!]") if _chore_boosts_used < ChoreEngine.MAX_TAP_BOOSTS_PER_CHORE else "  ⚡"
		_lbl_chore_prog.text = "%s%s" % [String(cfg["label_en"] if _loc() == "en" else cfg["label_id"]), tap_hint]
		if _chore_progress >= _chore_duration:
			_chore_bar_wrap.visible = false
			_finish_active_chore()
	else:
		_chore_bar_wrap.visible = false

	# Majikan call & distraction loop
	if bool(_call_state.get("active_call", false)):
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
	elif not bool(_call_state.get("fired", false)):
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
	_show_toast(_t("Semangat +Energi naik! Hati-hati panggilan Majikan.", "Mood + Energy up! Watch for employer calls."))
	_refresh_hud()

func _format_meta_clock() -> String:
	var cur_day := maxi(1, int(_save.get("day", 1)))
	var g_min := int(_save.get("game_minutes", 360))
	var clock_s := LifeRhythm.format_clock(g_min)
	var season := LifeRhythm.get_season(cur_day)
	var s_tag := " Puasa" if season == "ramadhan" else (" Lebaran" if season == "lebaran" else "")
	var w_icon := "🌧" if _cur_weather == "hujan" else ("🌙" if _cur_phase == "malam" else "☀")
	return "%s%d • %s %s%s" % [_t("H", "D"), cur_day, clock_s, w_icon, s_tag]

func _refresh_hud() -> void:
	var ob_active := _onboarding_wrap != null and _onboarding_wrap.visible
	if _npcs_root != null:
		_npcs_root.visible = not ob_active
	if hotspots_root != null:
		hotspots_root.visible = not ob_active
	if _tl_card != null:
		_tl_card.visible = not ob_active
	if _tr_vbox != null:
		_tr_vbox.visible = not ob_active
	if _br_vbox != null:
		_br_vbox.visible = not ob_active
	if _joy_base != null:
		_joy_base.visible = not ob_active

	var xp := int(_save.get("xp", 0))
	var lv := Progression.level_from_xp(xp)
	var tier := CareerTiers.get_tier(String(_save.get("active_tier_id", "kamar_kos")))
	var p_name := String(_save.get("player_name", "Mbak Sari"))
	_lbl_balance.text = "%s %d • %s" % [_t("Lv", "Level"), lv, I18n.format_balance(int(_save.get("balance_rp", 0)), _loc())]
	_lbl_meta.text = _format_meta_clock()

	if _in_shift:
		var e_val := int(_shift.get("energy", 0))
		var e_max := maxi(1, int(_shift.get("max_energy", 100)))
		var e_pct := int(round(100.0 * float(e_val) / float(e_max)))
		var t_val := int(_call_state.get("trust", 60))
		var m_val := int(_call_state.get("mood", 60))
		_lbl_energy.text = "%s %d%%" % [_t("ENERGI", "ENERGY"), e_pct]
		_bar_energy.max_value = e_max
		_bar_energy.value = e_val
		if _lbl_mood != null:
			var bonus_tag := _t(" (+15% Bonus!)", " (+15% Bonus!)") if m_val >= 80 else (_t(" (Lelah)", " (Tired)") if m_val <= 25 else "")
			_lbl_mood.text = "%s %d%%%s" % [_t("SEMANGAT", "MOOD"), m_val, bonus_tag]
			_lbl_mood.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34) if m_val >= 80 else (Color(0.96, 0.56, 0.34) if m_val <= 25 else Color(0.68, 0.88, 0.98)))
		_lbl_trust.text = "%s • %s" % [p_name, Progression.trust_to_stars(t_val)]

		var done_n := (_shift.get("completed_ids", []) as Array).size()
		var tot_n := (_shift.get("assigned_ids", []) as Array).size()
		var arrow := " [+]" if _tasks_collapsed else " [-]"
		_lbl_tasks_hdr.text = "%d/%d %s%s" % [done_n, tot_n, _t("TUGAS", "TASKS"), arrow]
		if _btn_tasks_toggle != null:
			_btn_tasks_toggle.text = _lbl_tasks_hdr.text
		for c in _tasks_list.get_children():
			c.queue_free()
		for item in ChoreEngine.get_checklist_items(_shift, _loc()):
			var row := Label.new()
			var mark := "✓" if bool(item["done"]) else "○"
			row.text = "%s %s" % [mark, String(item["label"])]
			row.add_theme_font_size_override("font_size", 12)
			row.add_theme_color_override("font_color", Color(0.50, 0.95, 0.52) if bool(item["done"]) else Color(0.95, 0.94, 0.90))
			_tasks_list.add_child(row)
		_tasks_list.visible = not _tasks_collapsed
		_tasks_card.visible = true

		_btn_shift.text = _t("Selesai Shift", "End Shift") if done_n >= tot_n else (_t("Pulang Cepat", "Leave Early") if done_n > 0 else _t("Batal Shift", "Cancel Shift"))
		_btn_action.visible = true
		_btn_action.text = _t("Kerjakan [E]", "Do Chore [E]")
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
			var h_bonus := _t(" (+15% Siap!)", " (+15% Ready!)") if h_mood >= 80 else ""
			_lbl_mood.text = "%s %d%%%s" % [_t("SEMANGAT", "MOOD"), h_mood, h_bonus]
			_lbl_mood.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34) if h_mood >= 80 else Color(0.68, 0.88, 0.98))
		_lbl_trust.text = "%s • %s" % [p_name, tier_label]
		_tasks_card.visible = false
		_btn_shift.text = _t("Mulai Shift", "Start Shift")
		_btn_action.visible = true
		if _world_mode == "street":
			var near_p := _nearest_portal()
			var near_n := _nearest_street_npc()
			if near_p != null:
				_btn_action.text = String(near_p.get_meta("label_en" if _loc() == "en" else "label_id", _t("Masuk", "Enter")))
			elif not near_n.is_empty():
				_btn_action.text = _t("Ngobrol [E]", "Chat [E]")
			else:
				_btn_action.text = _t("Masuk Kamar", "Enter Room")
		else:
			_btn_action.text = _t("Keluar Kamar [E]", "Step Outside [E]")

	if _btn_map != null:
		_btn_map.text = _t("Peta", "Map")
	if _btn_settings != null:
		var has_rw := Retention.has_unclaimed_daily_reward(_save, _today_date_str())
		_btn_settings.text = _t("Menu ★" if has_rw else "Menu", "Menu ★" if has_rw else "Menu")
	_btn_phone.text = ""
	var badge_n := MajikanCall.get_phone_badge_count(_call_state) if _in_shift else 0
	_lbl_phone_badge.text = str(badge_n)
	_lbl_phone_badge.visible = badge_n > 0
	_phone_popup.visible = _phone_open and not ob_active
	_btn_game.text = _t("Main Game (+Mood)", "Play Game (+Mood)")
	_btn_call_bf.text = _t("Telp Pacar (+Mood)", "Call BF (+Mood)")
	_btn_phone_answer.visible = _in_shift and bool(_call_state.get("active_call", false))
	_btn_phone_answer.text = _t("Jawab Majikan!", "Answer Employer!")
	_btn_career.text = _t("Karier", "Career")
	_btn_ward.text = _t("Seragam", "Outfits")
	_btn_kos.text = Progression.get_room_upgrade_title(tier, _loc())
	_btn_modal_close.text = _t("Mantap!", "Awesome!")
	_refresh_tutorial_banner()
	_refresh_onboarding_texts()
	_refresh_call_banner()

func _refresh_tutorial_banner() -> void:
	if _tutorial_panel == null or _lbl_tutorial == null:
		return
	var ob_active := _onboarding_wrap != null and _onboarding_wrap.visible
	var modal_active := _modal_backdrop != null and _modal_backdrop.visible
	var call_active := _in_shift and bool(_call_state.get("active_call", false))
	var step := int(_save.get("tutorial_step", 0))
	var hint := WishlistStory.get_tutorial_hint(step, _loc())
	var show := (not ob_active) and (not modal_active) and (not call_active) and (hint != "") and bool(_save.get("onboarding_done", false))
	_tutorial_panel.visible = show
	if show:
		_lbl_tutorial.text = hint
		if _btn_tutorial_skip != null:
			_btn_tutorial_skip.text = _t("Lewati", "Skip")

func _show_modal() -> void:
	if _is_sleeping:
		return
	if _modal_backdrop != null:
		_modal_backdrop.visible = true
	_refresh_tutorial_banner()

func _refresh_call_banner() -> void:
	var active_call := _in_shift and bool(_call_state.get("active_call", false))
	_call_banner.visible = active_call
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
	for c in _modal_list.get_children():
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
	var xp_cur_career := int(_save.get("xp", 0))
	var cur_id := String(_save.get("active_tier_id", "kamar_kos"))
	for t in CareerTiers.get_all_tiers():
		var tid := String(t["id"])
		var unlocked := CareerTiers.can_access_tier(tid, xp_cur_career)
		var btn := Button.new()
		var badge := "✓ " if tid == cur_id else ""
		var room_tag := _t(" + Kamar ART", " + Live-In Room") if bool(t["live_in_room_provided"]) else ""
		var h_name := String(t.get("house_type_en", t["house_type"]) if _loc() == "en" else t["house_type"])
		btn.text = "%s%s (%d XP • %.1fx%s)" % [badge, h_name, int(t["min_xp"]), float(t["pay_multiplier"]), room_tag]
		btn.disabled = not unlocked
		btn.pressed.connect(func():
			var res := Progression.select_job_tier(_save, tid)
			if res["ok"]:
				_save = res["save"]
				SaveStore.save_to_path(_save)
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
	if can_claim:
		btn_streak.text = _t("★ Klaim Streak Hari %d: %s (+%s, +%d XP)" % [streak_day, rw_lbl, I18n.format_balance(int(rw["rp"]), "id"), int(rw["xp"])], "★ Claim Day %d Streak: %s (+%s, +%d XP)" % [streak_day, rw_lbl, I18n.format_balance(int(rw["rp"]), "en"), int(rw["xp"])])
		_style_btn(btn_streak, Color(0.22, 0.56, 0.38), Color(0.98, 0.84, 0.34))
	else:
		btn_streak.text = _t("✓ Streak Hari %d/7 Sudah Diklaim Hari Ini" % streak_day, "✓ Day %d/7 Streak Claimed Today" % streak_day)
		btn_streak.disabled = true
	btn_streak.pressed.connect(func():
		var cl := Retention.claim_streak_reward(_save, _today_date_str())
		if cl["ok"]:
			_save = cl["save"]
			SaveStore.save_to_path(_save)
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
				SaveStore.save_to_path(_save)
				_play_sfx(_wav_coin)
				call_deferred("_open_retention_modal")
				_refresh_hud()
		)
		_modal_list.add_child(btn_m)

	var unlocked_bd: Array = _save.get("unlocked_badges", [])
	var bd_lbl := Label.new()
	var bd_names: Array = []
	for raw_bid in unlocked_bd:
		var bid := String(raw_bid)
		if Retention.BADGES.has(bid):
			bd_names.append(String(Retention.BADGES[bid]["label_en" if _loc() == "en" else "label_id"]))
	bd_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bd_lbl.text = "%s (%d/%d): %s" % [_t("Lencana", "Badges"), unlocked_bd.size(), Retention.BADGES.size(), ", ".join(bd_names) if bd_names.size() > 0 else _t("Belum ada", "None yet")]
	bd_lbl.add_theme_font_size_override("font_size", 11)
	bd_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34))
	_modal_list.add_child(bd_lbl)
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
	_last_prayer_id = ""
	SaveStore.save_to_path(_save)
	_play_sfx(_wav_fanfare)
	_refresh_atmosphere()
	_refresh_hud()
	var thr := int(sl.get("thr_bonus_rp", 0))
	var season := String(sl.get("season", "biasa"))
	if thr > 0:
		_show_toast(_t("Selamat Lebaran! Dapat THR Majikan +%s & Energi 100%%!" % I18n.format_balance(thr, "id"), "Happy Eid! Employer THR +%s & Energy 100%%!" % I18n.format_balance(thr, "en")), "player", "happy")
	elif season == "ramadhan":
		_show_toast(_t("Sahur & Tidur nyenyak! Bulan Ramadhan Hari %d — Energi 100%%." % int(sl["day"]), "Suhoor & rested! Ramadhan Day %d — Energy 100%%." % int(sl["day"])), "player", "happy")
	else:
		_show_toast(_t("Tidur nyenyak! Hari %d dimulai — Energi 100%% & Mood segar." % int(sl["day"]), "Well rested! Day %d begins — Energy 100%% & fresh Mood." % int(sl["day"])), "player", "happy")

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
	SaveStore.save_to_path(_save)
	_play_sfx(_wav_coin)
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
	for entry in WishlistStory.get_storybook_entries(_save, _loc()):
		var btn := Button.new()
		var ok_u := bool(entry["unlocked"])
		if ok_u:
			btn.text = "✓ %s" % String(entry["title"])
			var ch_dict: Dictionary = entry["chapter"]
			btn.pressed.connect(func(): _open_chapter_modal(ch_dict))
		else:
			btn.text = "%s (%s %d XP)" % [String(entry["title"]), _t("Terkunci •", "Locked •"), int(entry["min_xp"])]
			btn.disabled = true
		_modal_list.add_child(btn)
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
	SaveStore.save_to_path(_save)
	_modal_title.text = String(ch["title_en"] if _loc() == "en" else ch["title_id"])
	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 10)
	var p_rect := TextureRect.new()
	p_rect.texture = _get_player_portrait_tex("happy")
	p_rect.custom_minimum_size = Vector2(48, 48)
	p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hdr_row.add_child(p_rect)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(360, 0)
	body.text = String(ch["body_en"] if _loc() == "en" else ch["body_id"])
	body.add_theme_color_override("font_color", Color(0.95, 0.94, 0.90))
	hdr_row.add_child(body)
	_modal_list.add_child(hdr_row)
	_show_modal()

func _open_wishlist_modal() -> void:
	_clear_modal()
	_modal_title.text = _t("IMPIAN ART & TARGET TABUNGAN", "ART DREAMS & MILESTONE GOALS")
	var unlocked: Array = _save.get("unlocked_wishlist", [])
	for raw_wid in WishlistStory.WISHLIST_ITEMS.keys():
		var wid := String(raw_wid)
		var item: Dictionary = WishlistStory.WISHLIST_ITEMS[wid]
		var is_done := wid in unlocked
		var title := String(item["label_en"] if _loc() == "en" else item["label_id"])
		var desc := String(item["desc_en"] if _loc() == "en" else item["desc_id"])
		var btn := Button.new()
		var status := _t("✓ Tercapai", "✓ Achieved") if is_done else ("%s (+%d XP, +%d%% Semangat)" % [I18n.format_balance(int(item["cost_rp"]), _loc()), int(item["xp_bonus"]), int(item["mood_bonus"])])
		btn.text = "%s — %s\n%s" % [title, status, desc]
		btn.disabled = is_done or int(_save.get("balance_rp", 0)) < int(item["cost_rp"])
		btn.pressed.connect(func():
			var res := WishlistStory.buy_wishlist_item(_save, wid)
			if res["ok"]:
				_save = res["save"]
				_save = Settings.append_daily_log(_save, {
					"day": int(_save.get("day", 1)),
					"kind": "wishlist",
					"title_id": "Impian: %s" % String(item["label_id"]),
					"title_en": "Dream: %s" % String(item["label_en"]),
					"delta_rp": -int(item["cost_rp"]),
				})
				SaveStore.save_to_path(_save)
				_play_sfx(_wav_fanfare)
				_show_toast(_t("Impian tercapai: %s! (+%d XP)" % [title, int(item["xp_bonus"])], "Dream achieved: %s! (+%d XP)" % [title, int(item["xp_bonus"])]), "player", "happy")
				var ep := WishlistStory.get_unseen_epilogue(_save)
				if not ep.is_empty():
					call_deferred("_open_chapter_modal", ep)
				else:
					call_deferred("_open_wishlist_modal")
				_refresh_hud()
		)
		_modal_list.add_child(btn)
	_show_modal()

func _open_wardrobe_modal() -> void:
	_clear_modal()
	_modal_title.text = _t("Lemari Seragam & Kustomisasi Warna", "Wardrobe & Color Customization")
	var xp := int(_save.get("xp", 0))
	var cur_oid := String(_save.get("equipped_outfit_id", "starter_kasual"))
	for o in CareerTiers.OUTFIT_TIERS:
		var oid := String(o["id"])
		var unlocked := CareerTiers.can_equip_outfit(oid, xp)
		var lbl := Label.new()
		var name_txt := String(o["label_en"] if _loc() == "en" else o["label_id"])
		lbl.text = "%s (%d XP)%s" % [name_txt, int(o["min_xp"]), " ✓" if oid == cur_oid else ""]
		_modal_list.add_child(lbl)
		var hbox := HBoxContainer.new()
		for hex in o["customizable_colors"]:
			var b := Button.new()
			b.text = String(hex)
			b.disabled = not unlocked
			b.modulate = Color.html(String(hex))
			b.pressed.connect(func():
				var res := Progression.equip_outfit(_save, oid, String(hex))
				if res["ok"]:
					_save = res["save"]
					SaveStore.save_to_path(_save)
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
	var owned: Array = _save.get("unlocked_kos_upgrades", [])
	for raw_uid in Progression.KOS_UPGRADES.keys():
		var uid := String(raw_uid)
		var u: Dictionary = Progression.KOS_UPGRADES[uid]
		var is_owned: bool = uid in owned
		var btn := Button.new()
		var lbl := String(u["label_en"] if _loc() == "en" else u["label_id"])
		var price_txt := _t("Sudah Dimiliki", "Owned") if is_owned else I18n.format_price(int(u["cost_rp"]), _loc())
		btn.text = "%s — %s" % [lbl, price_txt]
		btn.disabled = is_owned or int(_save.get("balance_rp", 0)) < int(u["cost_rp"])
		btn.pressed.connect(func():
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
				SaveStore.save_to_path(_save)
				if _world_mode == "home" and stage_root.get_child_count() > 0:
					Atmosphere.apply_kos_upgrades_visual(stage_root.get_child(0), _save.get("unlocked_kos_upgrades", []))
				_play_sfx(_wav_coin)
				call_deferred("_open_kos_modal")
				_refresh_hud()
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
	p_rect.custom_minimum_size = Vector2(48, 48)
	p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hdr_row.add_child(p_rect)
	var quote_lbl := Label.new()
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
			SaveStore.save_to_path(_save)
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
		SaveStore.save_to_path(_save)
		_modal_backdrop.visible = false
		_refresh_hud()
	)
	_modal_list.add_child(btn_pay)
	_modal_list.add_child(btn_later)
	_show_modal()

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
		b.text = "%s%s (%d XP)%s" % ["★ " if is_act else ("• " if unl else "[%s] " % _t("Terkunci", "Locked")), lbl, int(node["min_xp"]), _t(" [Aktif]", " [Active]") if is_act else ""]
		b.disabled = (not unl) or _in_shift
		b.pressed.connect(func():
			var res := Progression.select_job_tier(_save, tid)
			if res["ok"]:
				_save = res["save"]
				SaveStore.save_to_path(_save)
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

func _open_settings_modal() -> void:
	if _is_sleeping:
		return
	_clear_modal()
	_reset_confirm = false
	_modal_title.text = _t("MENU, PENGATURAN & CATATAN", "MENU, SETTINGS & LOG")

	var btn_prof := Button.new()
	btn_prof.text = _t("Edit Profil & Karakter ART", "Edit ART Profile & Look")
	btn_prof.disabled = _in_shift
	btn_prof.pressed.connect(func():
		_modal_backdrop.visible = false
		_open_onboarding()
		_refresh_hud()
	)
	_modal_list.add_child(btn_prof)

	var btn_log := Button.new()
	btn_log.text = _t("Catatan Harian ART (%d)" % Settings.get_daily_log(_save).size(), "Daily ART Log (%d)" % Settings.get_daily_log(_save).size())
	btn_log.pressed.connect(_open_log_modal)
	_modal_list.add_child(btn_log)

	var btn_wish := Button.new()
	btn_wish.text = _t("Impian ART (%d/4)" % (_save.get("unlocked_wishlist", []) as Array).size(), "ART Dreams (%d/4)" % (_save.get("unlocked_wishlist", []) as Array).size())
	btn_wish.pressed.connect(_open_wishlist_modal)
	_modal_list.add_child(btn_wish)

	var btn_book := Button.new()
	btn_book.text = _t("Buku Cerita ART", "ART Story Book")
	btn_book.pressed.connect(_open_storybook_modal)
	_modal_list.add_child(btn_book)

	var btn_ret := Button.new()
	btn_ret.text = _t("★ Misi Harian, Streak & Lencana" if Retention.has_unclaimed_daily_reward(_save, _today_date_str()) else "Misi Harian, Streak & Lencana", "★ Daily Missions, Streak & Badges" if Retention.has_unclaimed_daily_reward(_save, _today_date_str()) else "Daily Missions, Streak & Badges")
	btn_ret.pressed.connect(_open_retention_modal)
	_modal_list.add_child(btn_ret)

	var pray_on := bool(_save.get("prayer_reminders", true))
	if pray_on:
		var btn_pray_now := Button.new()
		btn_pray_now.text = _t("Sholat / Doa (+12 Mood)" + (" & Buka Puasa" if LifeRhythm.get_season(int(_save.get("day", 1))) == "ramadhan" else ""), "Pray (+12 Mood)" + (" & Break Fast" if LifeRhythm.get_season(int(_save.get("day", 1))) == "ramadhan" else ""))
		btn_pray_now.pressed.connect(func():
			_modal_backdrop.visible = false
			_trigger_prayer_action()
		)
		_modal_list.add_child(btn_pray_now)

	var btn_pr_tog := Button.new()
	btn_pr_tog.text = _t("Pengingat Waktu Sholat: Aktif" if pray_on else "Pengingat Waktu Sholat: Mati", "Prayer Reminders: On" if pray_on else "Prayer Reminders: Off")
	btn_pr_tog.pressed.connect(func():
		_save["prayer_reminders"] = not pray_on
		SaveStore.save_to_path(_save)
		if _world_mode == "home":
			_enter_home_mode()
		_open_settings_modal()
	)
	_modal_list.add_child(btn_pr_tog)

	var btn_lang := Button.new()
	btn_lang.text = _t("Bahasa: Indonesia (Ubah ke EN)", "Language: English (Switch to ID)")
	btn_lang.pressed.connect(func():
		_save["locale"] = "en" if _loc() == "id" else "id"
		SaveStore.save_to_path(_save)
		_refresh_hud()
		_open_settings_modal()
	)
	_modal_list.add_child(btn_lang)

	var btn_sfx := Button.new()
	btn_sfx.text = _t("Efek Suara: Mati" if _muted else "Efek Suara: Aktif", "Sound SFX: Off" if _muted else "Sound SFX: On")
	btn_sfx.pressed.connect(func():
		_muted = not _muted
		_save["muted"] = _muted
		SaveStore.save_to_path(_save)
		_sync_ambient_audio()
		_open_settings_modal()
	)
	_modal_list.add_child(btn_sfx)

	var bgm_on := bool(_save.get("bgm_enabled", true))
	var btn_bgm := Button.new()
	btn_bgm.text = _t("Musik Latar (BGM): Aktif" if bgm_on else "Musik Latar (BGM): Mati", "Background Music: On" if bgm_on else "Background Music: Off")
	btn_bgm.pressed.connect(func():
		_save["bgm_enabled"] = not bgm_on
		SaveStore.save_to_path(_save)
		_sync_ambient_audio()
		_open_settings_modal()
	)
	_modal_list.add_child(btn_bgm)

	var q_cur := String(_save.get("gfx_quality", "high"))
	var btn_gfx := Button.new()
	btn_gfx.text = _t("Grafis: Ringan (HP)" if q_cur == "low" else "Grafis: Tinggi (Bayangan)", "Graphics: Low (Mobile)" if q_cur == "low" else "Graphics: High (Shadows)")
	btn_gfx.pressed.connect(func():
		var nxt_q := "low" if q_cur == "high" else "high"
		_save["gfx_quality"] = nxt_q
		SaveStore.save_to_path(_save)
		Settings.apply_graphics_quality(sun_light, world_env.environment if world_env != null else null, nxt_q)
		_open_settings_modal()
	)
	_modal_list.add_child(btn_gfx)

	var w_on := bool(_save.get("weather_fx", true))
	var btn_wfx := Button.new()
	btn_wfx.text = _t("Cuaca Hujan: Aktif" if w_on else "Cuaca Hujan: Cerah Saja", "Rain Weather: On" if w_on else "Rain Weather: Always Clear")
	btn_wfx.pressed.connect(func():
		_save["weather_fx"] = not w_on
		SaveStore.save_to_path(_save)
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
		SaveStore.save_to_path(_save)
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
	btn.add_theme_stylebox_override("normal", _make_box(bg, border, 10, 12, 7))
	btn.add_theme_stylebox_override("hover", _make_box(bg.lightened(0.10), border, 10, 12, 7))
	btn.add_theme_stylebox_override("pressed", _make_box(bg.darkened(0.12), border, 10, 12, 7))
	btn.add_theme_stylebox_override("disabled", _make_box(Color(0.62, 0.60, 0.56, 0.65), Color(0.45, 0.43, 0.40), 10, 12, 7))
	btn.add_theme_color_override("font_color", txt)
	btn.add_theme_color_override("font_hover_color", txt)
	btn.add_theme_color_override("font_pressed_color", txt)

func _style_bar(bar: ProgressBar, fill_col: Color, bg_col: Color = Color(0.08, 0.08, 0.08, 0.65)) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_col
	bg.set_corner_radius_all(6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill_col
	fg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)

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

	var obsidian_gold := _make_box(Color(0.08, 0.09, 0.11, 0.88), Color(0.95, 0.78, 0.26, 0.90), 14, 14, 10)
	var gold_pill := _make_box(Color(0.96, 0.78, 0.24, 1.0), Color(0.99, 0.89, 0.48, 1.0), 10, 14, 7)
	var dark_ink := Color(0.11, 0.09, 0.06)
	var light_ink := Color(0.97, 0.96, 0.93)

	# 1. TOP-LEFT WARUNG-LIFE GLASS CLUSTER (Clock + Sky-Blue Location + 5-Star Reputasi + Bright Green ENERGI Bar)
	_tl_card = PanelContainer.new()
	_tl_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tl_card.position = Vector2(14, 12)
	_tl_card.add_theme_stylebox_override("panel", obsidian_gold)
	var tl_v := VBoxContainer.new()
	tl_v.add_theme_constant_override("separation", 4)

	_lbl_meta = Label.new()
	_lbl_meta.custom_minimum_size = Vector2(200, 0)
	_lbl_meta.clip_text = true
	_lbl_meta.add_theme_font_size_override("font_size", 14)
	_lbl_meta.add_theme_color_override("font_color", light_ink)

	_lbl_trust = Label.new()
	_lbl_trust.add_theme_font_size_override("font_size", 13)
	_lbl_trust.add_theme_color_override("font_color", Color(0.98, 0.82, 0.28))

	_lbl_energy = Label.new()
	_lbl_energy.add_theme_font_size_override("font_size", 12)
	_lbl_energy.add_theme_color_override("font_color", Color(0.45, 0.94, 0.44))
	_bar_energy = ProgressBar.new()
	_bar_energy.custom_minimum_size = Vector2(200, 10)
	_bar_energy.show_percentage = false
	_style_bar(_bar_energy, Color(0.32, 0.86, 0.36))
	_lbl_mood = Label.new()
	_lbl_mood.add_theme_font_size_override("font_size", 11)
	_lbl_mood.add_theme_color_override("font_color", Color(0.68, 0.88, 0.98))

	tl_v.add_child(_lbl_meta)
	tl_v.add_child(_lbl_trust)
	tl_v.add_child(_lbl_energy)
	tl_v.add_child(_bar_energy)
	tl_v.add_child(_lbl_mood)
	_tl_card.add_child(tl_v)
	hud.add_child(_tl_card)

	# 2. TOP-RIGHT CLUSTER (Gold Level + Bold Lime Rp + Utility + Live Task Checklist)
	_tr_vbox = VBoxContainer.new()
	_tr_vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tr_vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tr_vbox.offset_right = -14
	_tr_vbox.offset_top = 12
	_tr_vbox.add_theme_constant_override("separation", 6)

	var top_r_row := HBoxContainer.new()
	top_r_row.alignment = BoxContainer.ALIGNMENT_END
	top_r_row.add_theme_constant_override("separation", 8)

	var wallet_pill := PanelContainer.new()
	wallet_pill.add_theme_stylebox_override("panel", obsidian_gold)
	_lbl_balance = Label.new()
	_lbl_balance.add_theme_font_size_override("font_size", 16)
	_lbl_balance.add_theme_color_override("font_color", Color(0.46, 0.94, 0.44))
	wallet_pill.add_child(_lbl_balance)

	_btn_map = Button.new()
	_btn_settings = Button.new()
	_style_btn(_btn_map, Color(0.14, 0.16, 0.20, 0.90), Color(0.95, 0.78, 0.26, 0.85))
	_style_btn(_btn_settings, Color(0.14, 0.16, 0.20, 0.90), Color(0.95, 0.78, 0.26, 0.85))
	_btn_map.pressed.connect(_open_map_modal)
	_btn_settings.pressed.connect(_open_settings_modal)
	top_r_row.add_child(wallet_pill)
	top_r_row.add_child(_btn_map)
	top_r_row.add_child(_btn_settings)
	_tr_vbox.add_child(top_r_row)

	_tasks_card = PanelContainer.new()
	_tasks_card.add_theme_stylebox_override("panel", obsidian_gold)
	var tk_v := VBoxContainer.new()
	tk_v.add_theme_constant_override("separation", 3)
	_lbl_tasks_hdr = Label.new()
	_lbl_tasks_hdr.visible = false
	_btn_tasks_toggle = Button.new()
	_btn_tasks_toggle.custom_minimum_size = Vector2(180, 32)
	_btn_tasks_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_btn_tasks_toggle.add_theme_font_size_override("font_size", 13)
	_btn_tasks_toggle.add_theme_color_override("font_color", Color(0.98, 0.82, 0.28))
	_btn_tasks_toggle.add_theme_stylebox_override("normal", _make_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 4, 2))
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

	# 3. TOP-CENTER OPEN SKY (Urgent Call Banner + Toast, bounded cleanly between corners!)
	var tc_center := CenterContainer.new()
	tc_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tc_center.offset_left = 220
	tc_center.offset_right = -220
	tc_center.offset_top = 10
	tc_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tc_v := VBoxContainer.new()
	tc_v.add_theme_constant_override("separation", 8)
	tc_v.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_call_banner = PanelContainer.new()
	_call_banner.visible = false
	_call_banner.add_theme_stylebox_override("panel", _make_box(Color(0.76, 0.22, 0.18, 0.96), Color(0.98, 0.86, 0.65), 14, 12, 8))
	var call_h := HBoxContainer.new()
	call_h.add_theme_constant_override("separation", 10)
	_call_portrait = TextureRect.new()
	_call_portrait.custom_minimum_size = Vector2(44, 44)
	_call_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	call_h.add_child(_call_portrait)
	var call_text_v := VBoxContainer.new()
	call_text_v.add_theme_constant_override("separation", 3)
	_lbl_call_title = Label.new()
	_lbl_call_title.add_theme_font_size_override("font_size", 13)
	_lbl_call_title.add_theme_color_override("font_color", light_ink)
	_bar_call = ProgressBar.new()
	_bar_call.custom_minimum_size = Vector2(132, 10)
	_bar_call.show_percentage = false
	_style_bar(_bar_call, Color(0.98, 0.80, 0.30), Color(0.32, 0.10, 0.08, 0.7))
	call_text_v.add_child(_lbl_call_title)
	call_text_v.add_child(_bar_call)
	_btn_answer = Button.new()
	_style_btn(_btn_answer, Color(0.18, 0.66, 0.42), Color(0.95, 0.90, 0.72))
	_btn_answer.pressed.connect(_on_answer_call)
	call_h.add_child(call_text_v)
	call_h.add_child(_btn_answer)
	_call_banner.add_child(call_h)
	tc_v.add_child(_call_banner)

	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.add_theme_stylebox_override("panel", _make_box(Color(0.14, 0.18, 0.16, 0.90), Color(0.84, 0.72, 0.46), 12, 14, 6))
	var toast_h := HBoxContainer.new()
	toast_h.add_theme_constant_override("separation", 8)
	_toast_portrait = TextureRect.new()
	_toast_portrait.visible = false
	_toast_portrait.custom_minimum_size = Vector2(34, 34)
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
	_tutorial_panel.add_theme_stylebox_override("panel", _make_box(Color(0.10, 0.14, 0.18, 0.90), Color(0.32, 0.82, 0.62), 10, 12, 5))
	var tut_h := HBoxContainer.new()
	tut_h.add_theme_constant_override("separation", 8)
	_lbl_tutorial = Label.new()
	_lbl_tutorial.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_tutorial.custom_minimum_size = Vector2(180, 0)
	_lbl_tutorial.add_theme_font_size_override("font_size", 11)
	_lbl_tutorial.add_theme_color_override("font_color", Color(0.94, 0.96, 0.90))
	_btn_tutorial_skip = Button.new()
	_style_btn(_btn_tutorial_skip, Color(0.18, 0.22, 0.28), Color(0.75, 0.72, 0.56))
	_btn_tutorial_skip.pressed.connect(func():
		_save = WishlistStory.advance_tutorial(_save, 4)
		SaveStore.save_to_path(_save)
		_refresh_tutorial_banner()
	)
	tut_h.add_child(_lbl_tutorial)
	tut_h.add_child(_btn_tutorial_skip)
	_tutorial_panel.add_child(tut_h)
	tc_v.add_child(_tutorial_panel)

	tc_center.add_child(tc_v)
	hud.add_child(tc_center)

	# World floating prompt for nearest chore
	_world_prompt = PanelContainer.new()
	_world_prompt.visible = false
	_world_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_prompt.add_theme_stylebox_override("panel", _make_box(Color(0.16, 0.56, 0.40, 0.94), Color(0.96, 0.84, 0.42), 10, 10, 5))
	_lbl_world_prompt = Label.new()
	_lbl_world_prompt.add_theme_color_override("font_color", light_ink)
	_world_prompt.add_child(_lbl_world_prompt)
	hud.add_child(_world_prompt)

	# Chore progress bar (anchored bottom-center)
	var bc_prog := CenterContainer.new()
	bc_prog.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bc_prog.offset_bottom = -82
	bc_prog.offset_top = -148
	bc_prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chore_bar_wrap = PanelContainer.new()
	_chore_bar_wrap.visible = false
	_chore_bar_wrap.add_theme_stylebox_override("panel", obsidian_gold)
	var ch_v := VBoxContainer.new()
	_lbl_chore_prog = Label.new()
	_lbl_chore_prog.add_theme_color_override("font_color", light_ink)
	_bar_chore = ProgressBar.new()
	_bar_chore.custom_minimum_size = Vector2(260, 16)
	_style_bar(_bar_chore, Color(0.24, 0.84, 0.48))
	ch_v.add_child(_lbl_chore_prog)
	ch_v.add_child(_bar_chore)
	_chore_bar_wrap.add_child(ch_v)
	bc_prog.add_child(_chore_bar_wrap)
	hud.add_child(bc_prog)

	# 4. BOTTOM-LEFT VIRTUAL JOYSTICK (Anchored)
	_joy_base = Panel.new()
	_joy_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joy_base.offset_left = 18
	_joy_base.offset_bottom = -18
	_joy_base.offset_top = -130
	_joy_base.offset_right = 130
	_joy_base.custom_minimum_size = Vector2(112, 112)
	_joy_base.add_theme_stylebox_override("panel", _make_box(Color(0.14, 0.15, 0.16, 0.42), Color(0.92, 0.86, 0.72, 0.70), 56, 0, 0))
	_joy_base.gui_input.connect(_on_joy_gui_input)
	_joy_knob = Panel.new()
	_joy_knob.custom_minimum_size = Vector2(40, 40)
	_joy_knob.size = Vector2(40, 40)
	_joy_knob.position = Vector2(36, 36)
	_joy_knob.add_theme_stylebox_override("panel", _make_box(Color(0.24, 0.72, 0.48, 0.92), Color(0.98, 0.96, 0.90), 20, 0, 0))
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.add_child(_joy_knob)
	hud.add_child(_joy_base)

	# 5. BOTTOM-CENTER CLEAN DOCK + BOTTOM-RIGHT SMARTPHONE HP BUTTON (Warung Life pattern!)
	_br_vbox = VBoxContainer.new()
	_br_vbox.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_br_vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_br_vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_br_vbox.offset_right = -16
	_br_vbox.offset_bottom = -16
	_br_vbox.add_theme_constant_override("separation", 10)

	_phone_popup = PanelContainer.new()
	_phone_popup.visible = false
	_phone_popup.add_theme_stylebox_override("panel", obsidian_gold)
	var ph_v := VBoxContainer.new()
	ph_v.add_theme_constant_override("separation", 6)
	_btn_phone_answer = Button.new()
	_style_btn(_btn_phone_answer, Color(0.76, 0.24, 0.20), Color(0.98, 0.86, 0.65))
	_btn_phone_answer.pressed.connect(func():
		_phone_open = false
		_on_answer_call()
	)
	_btn_game = Button.new()
	_style_btn(_btn_game, Color(0.24, 0.44, 0.66), Color(0.95, 0.78, 0.26, 0.7))
	_btn_game.pressed.connect(func():
		_phone_open = false
		_on_distract("playing_game")
	)
	_btn_call_bf = Button.new()
	_style_btn(_btn_call_bf, Color(0.60, 0.32, 0.48), Color(0.95, 0.78, 0.26, 0.7))
	_btn_call_bf.pressed.connect(func():
		_phone_open = false
		_on_distract("calling_boyfriend")
	)
	for pb in [_btn_phone_answer, _btn_game, _btn_call_bf]:
		ph_v.add_child(pb)
	_phone_popup.add_child(ph_v)
	_br_vbox.add_child(_phone_popup)

	var dock := HBoxContainer.new()
	dock.alignment = BoxContainer.ALIGNMENT_END
	dock.add_theme_constant_override("separation", 5)
	_btn_action = Button.new()
	_style_btn(_btn_action, Color(0.22, 0.66, 0.40), Color(0.95, 0.78, 0.26))
	_btn_action.pressed.connect(_trigger_world_action)
	_btn_shift = Button.new()
	_style_btn(_btn_shift, Color(0.96, 0.78, 0.24), Color(0.99, 0.89, 0.48), dark_ink)
	_btn_shift.pressed.connect(func():
		if _in_shift:
			_finish_shift()
		else:
			_start_shift()
	)
	_btn_career = Button.new()
	_style_btn(_btn_career, Color(0.11, 0.13, 0.16, 0.92), Color(0.95, 0.78, 0.26, 0.85))
	_btn_career.pressed.connect(_open_career_modal)
	_btn_ward = Button.new()
	_style_btn(_btn_ward, Color(0.11, 0.13, 0.16, 0.92), Color(0.95, 0.78, 0.26, 0.85))
	_btn_ward.pressed.connect(_open_wardrobe_modal)
	_btn_kos = Button.new()
	_style_btn(_btn_kos, Color(0.11, 0.13, 0.16, 0.92), Color(0.95, 0.78, 0.26, 0.85))
	_btn_kos.pressed.connect(_open_kos_modal)

	var phone_wrap := Control.new()
	phone_wrap.custom_minimum_size = Vector2(72, 76)
	_btn_phone = Button.new()
	_btn_phone.set_anchors_preset(Control.PRESET_FULL_RECT)
	_btn_phone.text = ""
	_style_btn(_btn_phone, Color(0.11, 0.14, 0.20, 0.96), Color(0.96, 0.78, 0.26))
	_btn_phone.pressed.connect(func():
		if _is_sleeping:
			return
		_phone_open = not _phone_open
		_refresh_hud()
	)
	var ph_screen := PanelContainer.new()
	ph_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	ph_screen.offset_left = 10
	ph_screen.offset_right = -10
	ph_screen.offset_top = 8
	ph_screen.offset_bottom = -20
	ph_screen.add_theme_stylebox_override("panel", _make_box(Color(0.20, 0.36, 0.62), Color(0.76, 0.86, 0.98), 6, 4, 4))
	var app_grid := GridContainer.new()
	app_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app_grid.columns = 3
	app_grid.add_theme_constant_override("h_separation", 4)
	app_grid.add_theme_constant_override("v_separation", 4)
	for app_col in [
		Color(0.32, 0.84, 0.44), Color(0.96, 0.76, 0.24), Color(0.92, 0.34, 0.32),
		Color(0.32, 0.76, 0.96), Color(0.76, 0.48, 0.94), Color(0.98, 0.56, 0.26),
	]:
		var ic := ColorRect.new()
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.custom_minimum_size = Vector2(11, 11)
		ic.color = app_col
		app_grid.add_child(ic)
	ph_screen.add_child(app_grid)
	var ph_lbl := Label.new()
	ph_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph_lbl.text = "HP"
	ph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ph_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ph_lbl.offset_top = -18
	ph_lbl.add_theme_font_size_override("font_size", 11)
	ph_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88))

	_lbl_phone_badge = Label.new()
	_lbl_phone_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_phone_badge.position = Vector2(54, -6)
	_lbl_phone_badge.custom_minimum_size = Vector2(20, 20)
	_lbl_phone_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_phone_badge.add_theme_stylebox_override("normal", _make_box(Color(0.86, 0.18, 0.16), Color(1, 1, 1), 10, 4, 1))
	_lbl_phone_badge.add_theme_font_size_override("font_size", 11)
	_lbl_phone_badge.add_theme_color_override("font_color", Color(1, 1, 1))
	phone_wrap.add_child(_btn_phone)
	phone_wrap.add_child(ph_screen)
	phone_wrap.add_child(ph_lbl)
	phone_wrap.add_child(_lbl_phone_badge)

	for b in [_btn_action, _btn_shift, _btn_career, _btn_ward, _btn_kos, phone_wrap]:
		dock.add_child(b)
	_br_vbox.add_child(dock)
	hud.add_child(_br_vbox)

	# Modal Backdrop (Warung-Life Dark Obsidian + 2px Gold Border + Gold Pill Header + Gold Mantap CTA!)
	_modal_backdrop = ColorRect.new()
	_modal_backdrop.color = Color(0.03, 0.04, 0.06, 0.72)
	_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(500, 320)
	card.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.09, 0.11, 0.96), Color(0.96, 0.78, 0.26), 16, 20, 18))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	var hdr_pill := PanelContainer.new()
	hdr_pill.add_theme_stylebox_override("panel", gold_pill)
	_modal_title = Label.new()
	_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_title.add_theme_font_size_override("font_size", 16)
	_modal_title.add_theme_color_override("font_color", dark_ink)
	hdr_pill.add_child(_modal_title)
	_modal_list = VBoxContainer.new()
	_modal_list.add_theme_constant_override("separation", 8)
	_btn_modal_close = Button.new()
	_style_btn(_btn_modal_close, Color(0.96, 0.78, 0.24), Color(0.99, 0.89, 0.48), dark_ink)
	_btn_modal_close.pressed.connect(func():
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
	vb.add_child(_modal_list)
	vb.add_child(_btn_modal_close)
	card.add_child(vb)
	center.add_child(card)
	_modal_backdrop.add_child(center)
	hud.add_child(_modal_backdrop)

	_build_onboarding_overlay(obsidian_gold, gold_pill, dark_ink, light_ink)

func _build_onboarding_overlay(card_sb: StyleBoxFlat, gold_pill: StyleBoxFlat, dark_ink: Color, light_ink: Color) -> void:
	_onboarding_wrap = Control.new()
	_onboarding_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_onboarding_wrap.visible = false

	var right_card := PanelContainer.new()
	right_card.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	right_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	right_card.offset_right = -28
	right_card.offset_left = -450
	right_card.offset_top = -235
	right_card.offset_bottom = 235
	right_card.add_theme_stylebox_override("panel", card_sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)

	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 8)
	var hdr_pill := PanelContainer.new()
	hdr_pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_pill.add_theme_stylebox_override("panel", gold_pill)
	_ob_title = Label.new()
	_ob_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ob_title.add_theme_font_size_override("font_size", 15)
	_ob_title.add_theme_color_override("font_color", dark_ink)
	hdr_pill.add_child(_ob_title)
	_ob_btn_lang = Button.new()
	_style_btn(_ob_btn_lang, Color(0.14, 0.16, 0.20), Color(0.96, 0.78, 0.26))
	_ob_btn_lang.pressed.connect(func():
		_save["locale"] = "en" if _loc() == "id" else "id"
		SaveStore.save_to_path(_save)
		_refresh_hud()
	)
	hdr_row.add_child(hdr_pill)
	hdr_row.add_child(_ob_btn_lang)
	vb.add_child(hdr_row)

	_ob_story = Label.new()
	_ob_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ob_story.add_theme_font_size_override("font_size", 12)
	_ob_story.add_theme_color_override("font_color", Color(0.88, 0.87, 0.83))
	vb.add_child(_ob_story)

	_ob_name_edit = LineEdit.new()
	_ob_name_edit.max_length = 24
	_ob_name_edit.add_theme_stylebox_override("normal", _make_box(Color(0.14, 0.16, 0.20), Color(0.95, 0.78, 0.26, 0.8), 10, 10, 6))
	_ob_name_edit.add_theme_color_override("font_color", light_ink)
	vb.add_child(_ob_name_edit)

	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override("separation", 8)
	_ob_btn_cepol = Button.new()
	_ob_btn_cepol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ob_btn_hijab = Button.new()
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
		var h := String(sk_cfg["hex"])
		_style_btn(sb, Color.html(h), Color(0.98, 0.94, 0.86), Color(0.10, 0.08, 0.06))
		sb.pressed.connect(func():
			_ob_skin = h
			_preview_onboarding_character()
		)
		skin_row.add_child(sb)
		_ob_skin_btns.append({"btn": sb, "id": String(sk_cfg["id"]), "en": String(sk_cfg["en"])})
	vb.add_child(skin_row)

	var col_row := HBoxContainer.new()
	col_row.add_theme_constant_override("separation", 8)
	for c_hex in ["#4E7D63", "#C9855E", "#5A6D8C", "#8C4A5E"]:
		var cb := Button.new()
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.text = "●"
		var ch := String(c_hex)
		_style_btn(cb, Color.html(ch), Color(0.96, 0.88, 0.65))
		cb.pressed.connect(func():
			_ob_color = ch
			_preview_onboarding_character()
		)
		col_row.add_child(cb)
	vb.add_child(col_row)

	_ob_btn_start = Button.new()
	_style_btn(_ob_btn_start, Color(0.96, 0.78, 0.24), Color(0.99, 0.89, 0.48), dark_ink)
	_ob_btn_start.pressed.connect(_finish_onboarding)
	vb.add_child(_ob_btn_start)

	right_card.add_child(vb)
	_onboarding_wrap.add_child(right_card)
	hud.add_child(_onboarding_wrap)

func _open_onboarding() -> void:
	_ob_style = String(_save.get("starter_style", "cepol"))
	_ob_skin = String(_save.get("skin_hex", "#B87A4B"))
	_ob_color = String(_save.get("outfit_color_hex", "#4E7D63"))
	if _ob_name_edit != null:
		_ob_name_edit.text = String(_save.get("player_name", "Mbak Sari"))
	if _onboarding_wrap != null:
		_onboarding_wrap.visible = true
	cam.position = player.position + Vector3(0.65, 1.42, 2.55)
	cam.look_at(player.position + Vector3(0.62, 0.92, 0.0), Vector3.UP)
	_preview_onboarding_character()
	_refresh_onboarding_texts()

func _preview_onboarding_character() -> void:
	var mpath := "res://assets/models/char_art_hijab.glb" if _ob_style == "hijab" else "res://assets/models/char_art.glb"
	player.load_outfit(String(_save.get("equipped_outfit_id", "starter_kasual")), mpath, _ob_color, _ob_skin)
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
	_ob_btn_lang.text = "EN" if _loc() == "id" else "ID"
	_ob_btn_cepol.text = _t("Mba2 Cepol (Daster)", "Mba2 Bun (Daster)")
	_ob_btn_hijab.text = _t("Mba2 Hijab (Bergo)", "Mba2 Hijab (Bergo)")
	_style_btn(_ob_btn_cepol, Color(0.22, 0.56, 0.40) if _ob_style == "cepol" else Color(0.14, 0.16, 0.20), Color(0.96, 0.78, 0.26))
	_style_btn(_ob_btn_hijab, Color(0.22, 0.56, 0.40) if _ob_style == "hijab" else Color(0.14, 0.16, 0.20), Color(0.96, 0.78, 0.26))
	_ob_btn_start.text = _t("Mulai Kerja! (Hari 1)", "Start Working! (Day 1)")

func _finish_onboarding() -> void:
	_unlock_audio()
	var nm := _ob_name_edit.text if _ob_name_edit != null else "Mbak Sari"
	var res := Progression.complete_onboarding(_save, nm, _ob_style, _ob_skin, _ob_color)
	_save = res["save"]
	SaveStore.save_to_path(_save)
	if _onboarding_wrap != null:
		_onboarding_wrap.visible = false
	_sync_player_outfit()
	_play_sfx(_wav_fanfare)
	_show_toast(_t("Selamat datang %s! Ketuk Keluar Kamar untuk keluar ke gang atau Mulai Shift." % String(_save["player_name"]), "Welcome %s! Tap Step Outside to explore the street or Start Shift." % String(_save["player_name"])))
	_refresh_hud()
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
