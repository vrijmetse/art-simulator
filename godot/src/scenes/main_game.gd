extends Node3D

const I18n := preload("res://src/core/i18n.gd")
const CareerTiers := preload("res://src/core/career_tiers.gd")
const MajikanProfiles := preload("res://src/core/majikan_profiles.gd")
const MajikanCall := preload("res://src/core/majikan_call.gd")
const ChoreEngine := preload("res://src/core/chore_engine.gd")
const Progression := preload("res://src/core/progression.gd")
const SaveStore := preload("res://src/core/save_store.gd")
const AudioSynth := preload("res://src/core/audio_synth.gd")
const SceneVisuals := preload("res://src/core/scene_visuals.gd")
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

var _save: Dictionary = {}
var _shift: Dictionary = {}
var _call_state: Dictionary = {}
var _in_shift := false
var _muted := false
var _active_chore_id := ""
var _chore_progress := 0.0
var _chore_duration := 3.5
var _call_cooldown := 14.0
var _shift_elapsed_s := 0.0
var _phone_open := false

var _wav_coin: AudioStreamWAV
var _wav_ring: AudioStreamWAV
var _wav_sweep: AudioStreamWAV
var _wav_fanfare: AudioStreamWAV
var _wav_buzz: AudioStreamWAV

# HUD nodes
var _lbl_balance: Label
var _lbl_meta: Label
var _lbl_energy: Label
var _bar_energy: ProgressBar
var _lbl_trust: Label
var _lbl_tasks_hdr: Label
var _tasks_list: VBoxContainer
var _tasks_card: PanelContainer
var _btn_lang: Button
var _btn_mute: Button
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
var _call_banner: PanelContainer
var _lbl_call_title: Label
var _bar_call: ProgressBar
var _btn_answer: Button
var _chore_bar_wrap: PanelContainer
var _lbl_chore_prog: Label
var _bar_chore: ProgressBar
var _toast_lbl: Label
var _toast_panel: PanelContainer
var _toast_timer := 0.0
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
var _capture_tier := ""
var _smoke_mode := false
var _frame_cnt := 0
var _captured := false

func _ready() -> void:
	_wav_coin = AudioSynth.make_coin_chime()
	_wav_ring = AudioSynth.make_phone_ring()
	_wav_sweep = AudioSynth.make_broom_sweep()
	_wav_fanfare = AudioSynth.make_level_up_fanfare()
	_wav_buzz = AudioSynth.make_warning_buzz()

	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke-test":
			_smoke_mode = true
		elif arg.begins_with("--capture="):
			_capture_path = arg.substr("--capture=".length())
		elif arg.begins_with("--capture-shift="):
			_capture_path = arg.substr("--capture-shift=".length())
			_capture_shift = true
		elif arg.begins_with("--capture-tier="):
			_capture_tier = arg.substr("--capture-tier=".length())

	_save = SaveStore.load_from_path()
	_build_hud()

	if _smoke_mode:
		_run_headless_smoke_test()
		return

	if _capture_shift:
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

	_enter_home_mode()
	_sync_player_outfit()
	_refresh_hud()

func _loc() -> String:
	return String(_save.get("locale", "id"))

func _t(id_str: String, en_str: String) -> String:
	return en_str if _loc() == "en" else id_str

func _play_sfx(wav: AudioStreamWAV) -> void:
	if _muted or _smoke_mode or wav == null or sfx == null:
		return
	sfx.stream = wav
	sfx.play()

func _show_toast(msg: String) -> void:
	if _toast_lbl == null or _toast_panel == null:
		return
	_toast_lbl.text = msg
	_toast_panel.visible = true
	_toast_timer = 3.2

func _load_stage_glb(glb_path: String) -> void:
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

func _sync_player_outfit() -> void:
	var oid := String(_save.get("equipped_outfit_id", "starter_kasual"))
	var hex := String(_save.get("outfit_color_hex", "#4E7D63"))
	var model_path := "res://assets/models/char_art.glb"
	for o in CareerTiers.OUTFIT_TIERS:
		if o["id"] == oid:
			model_path = String(o["model_path"])
			break
	player.load_outfit(oid, model_path, hex)

func _enter_home_mode() -> void:
	_in_shift = false
	_active_chore_id = ""
	player.set_cleaning(false)
	if _chore_bar_wrap != null:
		_chore_bar_wrap.visible = false
	_clear_hotspots()
	var tier := CareerTiers.get_tier(String(_save.get("active_tier_id", "kamar_kos")))
	var prof := MajikanProfiles.get_profile(String(_save.get("active_profile_id", "ibu_kos_melati")))
	var home_glb := "res://assets/models/kos_room.glb"
	if bool(tier.get("live_in_room_provided", false)):
		home_glb = String(prof.get("kamar_art_scene", "res://assets/models/kos_room.glb"))
	_load_stage_glb(home_glb)
	player.set_walk_bounds(-2.0, 2.0, -1.8, 1.7)
	player.position = Vector3(0.0, 0.0, 0.35)
	player.cancel_movement()
	_refresh_hud()

func _start_shift() -> void:
	var tier_id := String(_save.get("active_tier_id", "kamar_kos"))
	var prof := MajikanProfiles.get_profile(String(_save.get("active_profile_id", "ibu_kos_melati")))
	if prof.is_empty():
		prof = MajikanProfiles.get_profile("ibu_kos_melati")
	var max_e := Progression.get_max_energy(_save)
	_shift = ChoreEngine.create_shift(tier_id, prof, max_e)
	_call_state = MajikanCall.create_state(prof)
	_in_shift = true
	_shift_elapsed_s = 0.0
	_phone_open = false
	_call_cooldown = 12.0
	_active_chore_id = ""

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
		player.position = Vector3(0.0, 0.0, -0.5)
	player.cancel_movement()
	_spawn_hotspots(work_glb)
	_show_toast(_t("Shift dimulai! Kerjakan tugas & dengarkan panggilan Majikan.", "Shift started! Finish chores & answer employer calls."))
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
	_active_chore_id = hs.chore_id
	_chore_duration = ChoreEngine.effective_duration(hs.chore_id, sk_lvl)
	_chore_progress = 0.0
	player.set_cleaning(true)
	_play_sfx(_wav_sweep)

func _finish_active_chore() -> void:
	var cid := _active_chore_id
	_active_chore_id = ""
	player.set_cleaning(false)
	var tier := CareerTiers.get_tier(String(_save.get("active_tier_id", "kamar_kos")))
	var pay_mult := float(tier.get("pay_multiplier", 1.0))
	var cfg: Dictionary = ChoreEngine.CHORES[cid]
	var sk_lvl := Progression.skill_level_from_xp(int(_save.get("skill_xp", {}).get(String(cfg["skill"]), 0)))
	var res := ChoreEngine.complete_chore(_shift, cid, pay_mult, sk_lvl)
	if res["ok"]:
		_shift = res["shift"]
		for c in hotspots_root.get_children():
			if c is ChoreHotspotScene and c.chore_id == cid:
				c.mark_completed()
		_play_sfx(_wav_coin)
		_show_toast("+%s  +%d XP" % [I18n.format_balance(int(res["payout_rp"]), _loc()), int(res["xp_gain"])])
		if ChoreEngine.is_shift_complete(_shift):
			player.play_celebrate()
			_play_sfx(_wav_fanfare)
			_show_toast(_t("Semua tugas beres! Tekan Selesai Shift untuk gajian.", "All chores done! Tap End Shift to collect pay."))
	_refresh_hud()

func _finish_shift() -> void:
	if not _in_shift:
		return
	var prev_lv := Progression.level_from_xp(int(_save.get("xp", 0)))
	var res := Progression.settle_shift(_save, _shift, _call_state)
	if not res["ok"]:
		return
	_save = res["save"]
	_shift = res["shift"]
	SaveStore.save_to_path(_save)
	var new_lv := Progression.level_from_xp(int(_save.get("xp", 0)))
	if new_lv > prev_lv:
		_play_sfx(_wav_fanfare)
	else:
		_play_sfx(_wav_coin)
	_enter_home_mode()
	_open_summary_modal(res)

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

	# Smooth camera follow
	var cam_target := player.position + Vector3(3.4, 3.5, 3.8)
	cam.position = cam.position.lerp(cam_target, minf(1.0, delta * 5.0))
	cam.look_at(player.position + Vector3(0.0, 0.75, -0.2), Vector3.UP)

	if not _in_shift:
		if _world_prompt != null:
			_world_prompt.visible = false
		return

	_shift_elapsed_s += delta
	_lbl_meta.text = Progression.format_shift_clock(int(_save.get("day", 1)), _shift_elapsed_s, _loc())

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
		else:
			_world_prompt.visible = false

	# Active chore progress
	if _active_chore_id != "":
		_chore_progress += delta
		_chore_bar_wrap.visible = true
		_bar_chore.max_value = _chore_duration
		_bar_chore.value = _chore_progress
		var cfg: Dictionary = ChoreEngine.CHORES[_active_chore_id]
		_lbl_chore_prog.text = String(cfg["label_en"] if _loc() == "en" else cfg["label_id"])
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
	if event is InputEventKey and event.pressed and event.keycode in [KEY_E, KEY_SPACE]:
		if _in_shift and bool(_call_state.get("active_call", false)):
			_on_answer_call()
		elif _in_shift:
			_begin_nearest_chore()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _modal_backdrop != null and _modal_backdrop.visible:
			return
		var from := cam.project_ray_origin(event.position)
		var dir := cam.project_ray_normal(event.position)
		if absf(dir.y) > 0.01:
			var t := -from.y / dir.y
			if t > 0.0 and t < 40.0:
				var hit := from + dir * t
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
		_show_toast(_t("Sigap! Trust naik & bonus +%s" % I18n.format_balance(5000, "id"), "Quick answer! Trust up & +%s tip!" % I18n.format_balance(5000, "en")))
	_refresh_hud()

func _on_distract(activity_id: String) -> void:
	if not _in_shift:
		_show_toast(_t("Mulai shift dulu sebelum main HP.", "Start a shift first."))
		return
	_call_state = MajikanCall.apply_distraction(_call_state, activity_id)
	_shift = ChoreEngine.rest_recover(_shift, 8)
	_show_toast(_t("Mood +Energi naik! Hati-hati panggilan Majikan.", "Mood + Energy up! Watch for employer calls."))
	_refresh_hud()

func _refresh_hud() -> void:
	var xp := int(_save.get("xp", 0))
	var lv := Progression.level_from_xp(xp)
	var tier := CareerTiers.get_tier(String(_save.get("active_tier_id", "kamar_kos")))
	_lbl_balance.text = "LV %d  |  %s" % [lv, I18n.format_balance(int(_save.get("balance_rp", 0)), _loc())]
	_lbl_meta.text = Progression.format_shift_clock(int(_save.get("day", 1)), _shift_elapsed_s if _in_shift else 0.0, _loc())

	if _in_shift:
		var e_val := int(_shift.get("energy", 0))
		var e_max := maxi(1, int(_shift.get("max_energy", 100)))
		var e_pct := int(round(100.0 * float(e_val) / float(e_max)))
		var t_val := int(_call_state.get("trust", 60))
		_lbl_energy.text = "%s %d%%" % [_t("ENERGI", "ENERGY"), e_pct]
		_bar_energy.max_value = e_max
		_bar_energy.value = e_val
		_lbl_trust.text = "%s %s" % [_t("REPUTASI", "TRUST"), Progression.trust_to_stars(t_val)]

		var done_n := (_shift.get("completed_ids", []) as Array).size()
		var tot_n := (_shift.get("assigned_ids", []) as Array).size()
		_lbl_tasks_hdr.text = "%d/%d %s" % [done_n, tot_n, _t("TUGAS", "TASKS")]
		for c in _tasks_list.get_children():
			c.queue_free()
		for item in ChoreEngine.get_checklist_items(_shift, _loc()):
			var row := Label.new()
			var mark := "✓" if bool(item["done"]) else "○"
			row.text = "%s %s" % [mark, String(item["label"])]
			row.add_theme_font_size_override("font_size", 12)
			row.add_theme_color_override("font_color", Color(0.55, 0.96, 0.68) if bool(item["done"]) else Color(0.95, 0.94, 0.90))
			_tasks_list.add_child(row)
		_tasks_card.visible = true

		_btn_shift.text = _t("Selesai Shift", "End Shift")
		_btn_action.visible = true
		_btn_action.text = _t("Kerjakan [E]", "Do Chore [E]")
	else:
		var max_e := Progression.get_max_energy(_save)
		var tier_label := String(tier.get("house_type_en", tier.get("house_type", "")) if _loc() == "en" else tier.get("house_type", ""))
		_lbl_energy.text = "%s 100%%" % _t("ENERGI", "ENERGY")
		_bar_energy.max_value = max_e
		_bar_energy.value = max_e
		_lbl_trust.text = tier_label
		_tasks_card.visible = false
		_btn_shift.text = _t("Mulai Shift", "Start Shift")
		_btn_action.visible = false

	_btn_lang.text = "EN" if _loc() == "id" else "ID"
	_btn_mute.text = _t("Mati", "Off") if _muted else _t("Suara", "SFX")
	_btn_phone.text = "HP"
	var badge_n := MajikanCall.get_phone_badge_count(_call_state) if _in_shift else 0
	_lbl_phone_badge.text = str(badge_n)
	_lbl_phone_badge.visible = badge_n > 0
	_phone_popup.visible = _phone_open
	_btn_game.text = _t("Main Game (+Mood)", "Play Game (+Mood)")
	_btn_call_bf.text = _t("Telp Pacar (+Mood)", "Call BF (+Mood)")
	_btn_phone_answer.visible = _in_shift and bool(_call_state.get("active_call", false))
	_btn_phone_answer.text = _t("Jawab Majikan!", "Answer Employer!")
	_btn_career.text = _t("Karier", "Career")
	_btn_ward.text = _t("Seragam", "Outfits")
	_btn_kos.text = Progression.get_room_upgrade_title(tier, _loc())
	_btn_modal_close.text = _t("Tutup", "Close")
	_refresh_call_banner()

func _refresh_call_banner() -> void:
	var active_call := _in_shift and bool(_call_state.get("active_call", false))
	_call_banner.visible = active_call
	if active_call:
		var pers := MajikanProfiles.get_personality(String(_call_state.get("personality", "ramah")))
		var pat := float(pers.get("call_patience_s", 12.0))
		var rem := maxf(0.0, pat - float(_call_state.get("call_elapsed_s", 0.0)))
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
	var cur_id := String(_save.get("active_tier_id", "kamar_kos"))
	for t in CareerTiers.get_all_tiers():
		var tid := String(t["id"])
		var unlocked := CareerTiers.can_access_tier(tid, xp)
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
		)
		_modal_list.add_child(btn)
	_modal_backdrop.visible = true

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
	_modal_backdrop.visible = true

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
				SaveStore.save_to_path(_save)
				_play_sfx(_wav_coin)
				call_deferred("_open_kos_modal")
				_refresh_hud()
		)
		_modal_list.add_child(btn)
	_modal_backdrop.visible = true

func _open_summary_modal(res: Dictionary) -> void:
	_clear_modal()
	_modal_title.text = _t("Ringkasan Shift Selesai", "Shift Summary")
	var l1 := Label.new()
	l1.text = "%s: %s" % [_t("Total Pendapatan", "Total Earned"), I18n.format_balance(int(res["payout_rp"]), _loc())]
	var l2 := Label.new()
	l2.text = "+%d XP (Lv.%d)" % [int(res["xp_gained"]), Progression.level_from_xp(int(_save.get("xp", 0)))]
	var l3 := Label.new()
	l3.text = _t("Status: Dipecat (gaji kontrak hangus)" if bool(res["fired"]) else "Status: Shift Bagus!", "Status: Fired (contract forfeited)" if bool(res["fired"]) else "Status: Great Shift!")
	_modal_list.add_child(l1)
	_modal_list.add_child(l2)
	_modal_list.add_child(l3)
	_modal_backdrop.visible = true

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
	var glass_dark := _make_box(Color(0.11, 0.12, 0.14, 0.78), Color(0.92, 0.84, 0.66, 0.45), 14, 12, 8)
	var cream_sb := _make_box(Color(0.98, 0.95, 0.88, 0.96), Color(0.45, 0.34, 0.24), 14, 14, 10)
	var dark_ink := Color(0.18, 0.14, 0.11)
	var light_ink := Color(0.97, 0.96, 0.93)

	# 1. TOP-LEFT WARUNG-STYLE GLASS CLUSTER (Clock + 5-Star Reputasi + Bright Green ENERGI Bar)
	var tl_card := PanelContainer.new()
	tl_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tl_card.position = Vector2(14, 12)
	tl_card.add_theme_stylebox_override("panel", glass_dark)
	var tl_v := VBoxContainer.new()
	tl_v.add_theme_constant_override("separation", 4)

	_lbl_meta = Label.new()
	_lbl_meta.add_theme_font_size_override("font_size", 13)
	_lbl_meta.add_theme_color_override("font_color", light_ink)

	_lbl_trust = Label.new()
	_lbl_trust.add_theme_font_size_override("font_size", 14)
	_lbl_trust.add_theme_color_override("font_color", Color(0.99, 0.82, 0.32))

	_lbl_energy = Label.new()
	_lbl_energy.add_theme_font_size_override("font_size", 12)
	_lbl_energy.add_theme_color_override("font_color", Color(0.55, 0.96, 0.65))
	_bar_energy = ProgressBar.new()
	_bar_energy.custom_minimum_size = Vector2(190, 10)
	_bar_energy.show_percentage = false
	_style_bar(_bar_energy, Color(0.24, 0.84, 0.44))

	tl_v.add_child(_lbl_meta)
	tl_v.add_child(_lbl_trust)
	tl_v.add_child(_lbl_energy)
	tl_v.add_child(_bar_energy)
	tl_card.add_child(tl_v)
	hud.add_child(tl_card)

	# 2. TOP-RIGHT CLUSTER (Level + Bold Rp + Compact Utility + Live Task Checklist)
	var tr_vbox := VBoxContainer.new()
	tr_vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr_vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr_vbox.offset_right = -14
	tr_vbox.offset_top = 12
	tr_vbox.add_theme_constant_override("separation", 6)

	var top_r_row := HBoxContainer.new()
	top_r_row.alignment = BoxContainer.ALIGNMENT_END
	top_r_row.add_theme_constant_override("separation", 8)

	var wallet_pill := PanelContainer.new()
	wallet_pill.add_theme_stylebox_override("panel", glass_dark)
	_lbl_balance = Label.new()
	_lbl_balance.add_theme_font_size_override("font_size", 16)
	_lbl_balance.add_theme_color_override("font_color", Color(0.52, 0.96, 0.62))
	wallet_pill.add_child(_lbl_balance)

	_btn_lang = Button.new()
	_btn_mute = Button.new()
	_style_btn(_btn_lang, Color(0.20, 0.24, 0.26, 0.85), Color(0.92, 0.84, 0.66, 0.5))
	_style_btn(_btn_mute, Color(0.20, 0.24, 0.26, 0.85), Color(0.92, 0.84, 0.66, 0.5))
	_btn_lang.pressed.connect(func():
		_save["locale"] = "en" if _loc() == "id" else "id"
		SaveStore.save_to_path(_save)
		_refresh_hud()
	)
	_btn_mute.pressed.connect(func():
		_muted = not _muted
		_refresh_hud()
	)
	top_r_row.add_child(wallet_pill)
	top_r_row.add_child(_btn_lang)
	top_r_row.add_child(_btn_mute)
	tr_vbox.add_child(top_r_row)

	_tasks_card = PanelContainer.new()
	_tasks_card.add_theme_stylebox_override("panel", glass_dark)
	var tk_v := VBoxContainer.new()
	tk_v.add_theme_constant_override("separation", 3)
	_lbl_tasks_hdr = Label.new()
	_lbl_tasks_hdr.add_theme_font_size_override("font_size", 13)
	_lbl_tasks_hdr.add_theme_color_override("font_color", Color(0.98, 0.86, 0.48))
	_tasks_list = VBoxContainer.new()
	_tasks_list.add_theme_constant_override("separation", 2)
	tk_v.add_child(_lbl_tasks_hdr)
	tk_v.add_child(_tasks_list)
	_tasks_card.add_child(tk_v)
	tr_vbox.add_child(_tasks_card)
	hud.add_child(tr_vbox)

	# 3. TOP-CENTER OPEN SKY (Urgent Call Banner + Toast, bounded cleanly between corners!)
	var tc_center := CenterContainer.new()
	tc_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tc_center.offset_left = 236
	tc_center.offset_right = -360
	tc_center.offset_top = 12
	tc_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tc_v := VBoxContainer.new()
	tc_v.add_theme_constant_override("separation", 8)
	tc_v.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_call_banner = PanelContainer.new()
	_call_banner.visible = false
	_call_banner.add_theme_stylebox_override("panel", _make_box(Color(0.76, 0.22, 0.18, 0.96), Color(0.98, 0.86, 0.65), 14, 12, 8))
	var call_h := HBoxContainer.new()
	call_h.add_theme_constant_override("separation", 10)
	var call_text_v := VBoxContainer.new()
	call_text_v.add_theme_constant_override("separation", 3)
	_lbl_call_title = Label.new()
	_lbl_call_title.add_theme_font_size_override("font_size", 13)
	_lbl_call_title.add_theme_color_override("font_color", light_ink)
	_bar_call = ProgressBar.new()
	_bar_call.custom_minimum_size = Vector2(210, 10)
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
	_toast_lbl = Label.new()
	_toast_lbl.add_theme_color_override("font_color", light_ink)
	_toast_panel.add_child(_toast_lbl)
	tc_v.add_child(_toast_panel)

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
	_chore_bar_wrap.add_theme_stylebox_override("panel", glass_dark)
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
	var br_vbox := VBoxContainer.new()
	br_vbox.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br_vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	br_vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	br_vbox.offset_right = -16
	br_vbox.offset_bottom = -16
	br_vbox.add_theme_constant_override("separation", 10)

	_phone_popup = PanelContainer.new()
	_phone_popup.visible = false
	_phone_popup.add_theme_stylebox_override("panel", _make_box(Color(0.13, 0.15, 0.18, 0.92), Color(0.92, 0.84, 0.66), 14, 12, 10))
	var ph_v := VBoxContainer.new()
	ph_v.add_theme_constant_override("separation", 6)
	_btn_phone_answer = Button.new()
	_style_btn(_btn_phone_answer, Color(0.76, 0.24, 0.20), Color(0.98, 0.86, 0.65))
	_btn_phone_answer.pressed.connect(func():
		_phone_open = false
		_on_answer_call()
	)
	_btn_game = Button.new()
	_style_btn(_btn_game, Color(0.28, 0.46, 0.68), Color(0.18, 0.30, 0.44))
	_btn_game.pressed.connect(func():
		_phone_open = false
		_on_distract("playing_game")
	)
	_btn_call_bf = Button.new()
	_style_btn(_btn_call_bf, Color(0.64, 0.36, 0.52), Color(0.42, 0.22, 0.32))
	_btn_call_bf.pressed.connect(func():
		_phone_open = false
		_on_distract("calling_boyfriend")
	)
	for pb in [_btn_phone_answer, _btn_game, _btn_call_bf]:
		ph_v.add_child(pb)
	_phone_popup.add_child(ph_v)
	br_vbox.add_child(_phone_popup)

	var dock := HBoxContainer.new()
	dock.alignment = BoxContainer.ALIGNMENT_END
	dock.add_theme_constant_override("separation", 8)
	_btn_action = Button.new()
	_style_btn(_btn_action, Color(0.18, 0.62, 0.42), Color(0.92, 0.88, 0.72))
	_btn_action.pressed.connect(_begin_nearest_chore)
	_btn_shift = Button.new()
	_style_btn(_btn_shift, Color(0.78, 0.44, 0.24), Color(0.92, 0.84, 0.66, 0.7))
	_btn_shift.pressed.connect(func():
		if _in_shift:
			_finish_shift()
		else:
			_start_shift()
	)
	_btn_career = Button.new()
	_style_btn(_btn_career, Color(0.18, 0.20, 0.22, 0.88), Color(0.92, 0.84, 0.66, 0.55))
	_btn_career.pressed.connect(_open_career_modal)
	_btn_ward = Button.new()
	_style_btn(_btn_ward, Color(0.18, 0.20, 0.22, 0.88), Color(0.92, 0.84, 0.66, 0.55))
	_btn_ward.pressed.connect(_open_wardrobe_modal)
	_btn_kos = Button.new()
	_style_btn(_btn_kos, Color(0.18, 0.20, 0.22, 0.88), Color(0.92, 0.84, 0.66, 0.55))
	_btn_kos.pressed.connect(_open_kos_modal)

	var phone_wrap := Control.new()
	phone_wrap.custom_minimum_size = Vector2(56, 42)
	_btn_phone = Button.new()
	_btn_phone.set_anchors_preset(Control.PRESET_FULL_RECT)
	_style_btn(_btn_phone, Color(0.24, 0.44, 0.64), Color(0.94, 0.88, 0.72))
	_btn_phone.pressed.connect(func():
		_phone_open = not _phone_open
		_refresh_hud()
	)
	_lbl_phone_badge = Label.new()
	_lbl_phone_badge.position = Vector2(40, -6)
	_lbl_phone_badge.custom_minimum_size = Vector2(20, 20)
	_lbl_phone_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_phone_badge.add_theme_stylebox_override("normal", _make_box(Color(0.86, 0.18, 0.16), Color(1, 1, 1), 10, 4, 1))
	_lbl_phone_badge.add_theme_font_size_override("font_size", 11)
	_lbl_phone_badge.add_theme_color_override("font_color", Color(1, 1, 1))
	phone_wrap.add_child(_btn_phone)
	phone_wrap.add_child(_lbl_phone_badge)

	for b in [_btn_action, _btn_shift, _btn_career, _btn_ward, _btn_kos, phone_wrap]:
		dock.add_child(b)
	br_vbox.add_child(dock)
	hud.add_child(br_vbox)

	# Modal Backdrop
	_modal_backdrop = ColorRect.new()
	_modal_backdrop.color = Color(0.05, 0.06, 0.08, 0.65)
	_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(480, 320)
	card.add_theme_stylebox_override("panel", _make_box(Color(0.97, 0.94, 0.87, 0.98), Color(0.45, 0.34, 0.24), 16, 18, 16))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_modal_title = Label.new()
	_modal_title.add_theme_color_override("font_color", dark_ink)
	_modal_list = VBoxContainer.new()
	_modal_list.add_theme_constant_override("separation", 8)
	_btn_modal_close = Button.new()
	_style_btn(_btn_modal_close, Color(0.55, 0.36, 0.26), Color(0.36, 0.22, 0.16))
	_btn_modal_close.pressed.connect(func(): _modal_backdrop.visible = false)
	vb.add_child(_modal_title)
	vb.add_child(_modal_list)
	vb.add_child(_btn_modal_close)
	card.add_child(vb)
	center.add_child(card)
	_modal_backdrop.add_child(center)
	hud.add_child(_modal_backdrop)

func _run_headless_smoke_test() -> void:
	_save = Progression.create_player_save()
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
	print("MAIN_GAME SMOKE TEST PASS: balance=%d xp=%d" % [int(_save["balance_rp"]), int(_save["xp"])])
	get_tree().quit(0)

func _do_capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_capture_path)
	print("MAIN_GAME CAPTURED:", _capture_path)
	get_tree().quit(0)
