extends SceneTree

const I18n := preload("res://src/core/i18n.gd")
const Economy := preload("res://src/core/economy.gd")
const Neighborhood := preload("res://src/core/neighborhood.gd")
const CareerTiers := preload("res://src/core/career_tiers.gd")
const MajikanProfiles := preload("res://src/core/majikan_profiles.gd")
const MajikanCall := preload("res://src/core/majikan_call.gd")
const ChoreEngine := preload("res://src/core/chore_engine.gd")
const Progression := preload("res://src/core/progression.gd")
const SaveStore := preload("res://src/core/save_store.gd")
const NpcRoster := preload("res://src/core/npc_roster.gd")
const PlayerControllerScene := preload("res://src/scenes/player_controller.gd")
const AudioSynth := preload("res://src/core/audio_synth.gd")
const ArtAtmosphere := preload("res://src/core/atmosphere.gd")
const ArtSettings := preload("res://src/core/settings_store.gd")
const ArtStreetTraffic := preload("res://src/core/street_traffic.gd")
const ArtPortraits := preload("res://src/core/portraits.gd")
const ArtWishlistStory := preload("res://src/core/wishlist_story.gd")
const ArtStreetPatrols := preload("res://src/core/street_patrols.gd")
const ArtRetention := preload("res://src/core/retention.gd")
const ArtLifeRhythm := preload("res://src/core/life_rhythm.gd")
const ArtSceneVisuals := preload("res://src/core/scene_visuals.gd")
const ChoreHotspotScene := preload("res://src/scenes/chore_hotspot.gd")

var _failed := 0
var _passed := 0

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		push_error("FAIL [%s]: expected %s, got %s" % [label, str(expected), str(actual)])

func _assert_true(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		push_error("FAIL [%s]: expected true" % label)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var found := _find_anim_player(c)
		if found != null:
			return found
	return null

func _local_xform_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != ancestor:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

func _count_mesh_verts(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var arr := mi.mesh.surface_get_arrays(s)
				if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] is PackedVector3Array:
					total += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for c in node.get_children():
		total += _count_mesh_verts(c)
	return total

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for c in node.get_children():
		var found := _find_skeleton(c)
		if found != null:
			return found
	return null

func _initialize() -> void:
	# 1. i18n formatting (Rp 0 balance vs Gratis price)
	_assert_eq(I18n.format_balance(0, "id"), "Rp 0", "balance zero id")
	_assert_eq(I18n.format_balance(0, "en"), "$0", "balance zero en")
	_assert_eq(I18n.format_balance(15000, "id"), "Rp 15.000", "balance 15k id")
	_assert_eq(I18n.format_price(0, "id"), "Gratis", "price zero id")
	_assert_eq(I18n.format_price(30000, "id"), "Rp 30.000", "price 30k id")

	# 2. Economy pure state
	var state: Dictionary = Economy.create_initial_state()
	_assert_eq(state["balance_rp"], 0, "initial balance 0")
	_assert_eq(state["xp"], 0, "initial xp 0")
	var updated: Dictionary = Economy.award_contract(state, 36750, 75)
	_assert_eq(updated["balance_rp"], 36750, "payout added")
	_assert_eq(updated["xp"], 75, "xp added")
	_assert_eq(Economy.get_career_rank(0, "id"), "ART Pemula", "rank 0")
	_assert_eq(Economy.get_career_rank(75, "id"), "ART Terampil", "rank 75")

	# 3. Neighborhood NPCs & 1x/day tip anti-farm
	var patrols: Array = Neighborhood.create_patrols()
	_assert_true(patrols.size() >= 3, "at least 3 NPCs")
	var xs: Array = []
	for p in patrols:
		xs.append(float(p["x"]))
	xs.sort()
	for i in range(1, xs.size()):
		_assert_true(xs[i] - xs[i - 1] >= 0.8, "npc non-clumping spacing %d" % i)

	var r1: Dictionary = Neighborhood.claim_tip(state, "ibu_sari", "2026-11-26")
	_assert_true(r1["claimed"], "first daily tip claimed")
	_assert_true(r1["state"]["balance_rp"] > 0, "tip added to wallet")
	var r2: Dictionary = Neighborhood.claim_tip(r1["state"], "ibu_sari", "2026-11-26")
	_assert_eq(r2["claimed"], false, "same-day repeat blocked")
	var r3: Dictionary = Neighborhood.claim_tip(r1["state"], "ibu_sari", "2026-11-27")
	_assert_true(r3["claimed"], "next-day tip allowed")
	var r_bad: Dictionary = Neighborhood.claim_tip(state, "ghost", "2026-11-26")
	_assert_eq(r_bad["claimed"], false, "unknown npc blocked")

	# 4. Indonesian housing tier progression (Kamar Kos -> Kampung walk/bike/motor -> Perumahan 36/72 -> 45/90 -> Elite 120+)
	var t_kos: Dictionary = CareerTiers.get_active_tier(0)
	_assert_eq(t_kos["id"], "kamar_kos", "starts with single-room kos cleaning gigs at 0 XP")
	_assert_eq(t_kos["car_allowed"], false, "kamar kos starter does not require car")
	_assert_eq(CareerTiers.can_access_tier("kampung", 50), false, "kampung locked at 50 XP")
	_assert_eq(CareerTiers.can_access_tier("kampung", 80), true, "kampung unlocked at 80 XP")
	var t_start: Dictionary = CareerTiers.get_active_tier(100)
	_assert_eq(t_start["id"], "kampung", "active tier is kampung at 100 XP")
	_assert_eq(t_start["car_allowed"], false, "kampung alley does not allow cars")
	_assert_true("walk" in t_start["access"], "kampung walkable")
	_assert_eq(CareerTiers.can_access_tier("perumahan_36", 50), false, "perumahan 36/72 locked at 50 XP")
	_assert_eq(CareerTiers.can_access_tier("perumahan_36", 200), true, "perumahan 36/72 unlocked at 200 XP")
	_assert_eq(CareerTiers.get_active_tier(250)["id"], "perumahan_36", "active tier is tipe 36/72 at 250 XP")
	_assert_eq(CareerTiers.get_active_tier(650)["id"], "perumahan_45", "active tier is tipe 45/90 at 650 XP")
	_assert_eq(CareerTiers.get_active_tier(1500)["id"], "cluster_elite", "active tier is elite 120+ at 1500 XP")
	_assert_true(CareerTiers.get_active_tier(1500)["pay_multiplier"] > t_kos["pay_multiplier"], "higher tier pays more")
	_assert_eq(t_start["live_in_room_provided"], false, "kampung daily job does not provide live-in room")
	_assert_eq(CareerTiers.get_active_tier(1500)["live_in_room_provided"], true, "cluster elite provides live-in ART room")

	# 5. ART Outfit progression & customization (Simple Kampung tee -> Perumahan apron -> Elite Housekeeper)
	var o0: Dictionary = CareerTiers.get_active_outfit(0)
	_assert_eq(o0["id"], "starter_kasual", "starts with simple everyday kampung outfit")
	_assert_eq(o0["has_apron"], false, "starter outfit has no apron yet")
	_assert_eq(CareerTiers.can_equip_outfit("seragam_perumahan", 50), false, "perumahan uniform locked at 50 XP")
	_assert_eq(CareerTiers.can_equip_outfit("seragam_perumahan", 200), true, "perumahan uniform unlocked at 200 XP")
	_assert_eq(CareerTiers.can_equip_outfit("housekeeper_elite", 1400), true, "elite uniform unlocked at 1400 XP")
	_assert_true(CareerTiers.get_unlocked_outfits(1500).size() >= 3, "all 3 outfit tiers unlocked at 1500 XP")
	_assert_true(o0["customizable_colors"].size() >= 3, "starter outfit has customizable shirt color options")

	# 6. Scalable Majikan Profiles & Kamar ART variants
	var p36: Array = MajikanProfiles.get_profiles_for_tier("perumahan_36")
	_assert_true(p36.size() >= 1, "perumahan_36 has employer profile")
	_assert_eq(p36[0]["kamar_art_variant"], "none", "perumahan_36 is live-out (no ART room)")
	var p45: Dictionary = MajikanProfiles.get_profile("bu_ratna_45")
	_assert_eq(p45["kamar_art_variant"], "small", "tipe 45/90 provides small ART room")
	var pelite: Dictionary = MajikanProfiles.get_profile("keluarga_wijaya_elite")
	_assert_eq(pelite["kamar_art_variant"], "large", "cluster elite provides large ART room")
	var pers: Dictionary = MajikanProfiles.get_personality(p45["personality"])
	_assert_true(float(pers["call_patience_s"]) < float(MajikanProfiles.get_personality("ramah")["call_patience_s"]), "perfeksionis less patient than ramah")

	# 7. Distraction (main game / telepon pacar) vs Majikan Call, Trust, Teguran & Fired Recovery
	var cs: Dictionary = MajikanCall.create_state(p45)
	_assert_eq(cs["trust"], int(p45["initial_trust"]), "initial trust matches profile")
	cs = MajikanCall.apply_distraction(cs, "playing_game")
	_assert_eq(cs["activity"], "playing_game", "activity set to playing_game")
	_assert_true(cs["mood"] > 50, "playing game boosts mood")

	# In-time call response boosts trust & tip; double-response is a safe no-op!
	cs = MajikanCall.start_call(cs, "Ambilkan paket di pagar!")
	_assert_eq(cs["active_call"], true, "call active")
	_assert_true(float(cs["call_elapsed_s"]) >= 2.0, "distraction adds reaction delay")
	cs = MajikanCall.respond_to_call(cs)
	_assert_eq(cs["active_call"], false, "call cleared after response")
	var trust_after_ok: int = int(cs["trust"])
	_assert_true(trust_after_ok > int(p45["initial_trust"]), "timely response raises trust")
	_assert_true(int(cs["tip_bonus_rp"]) > 0, "timely response grants tip bonus")
	var cs_dup: Dictionary = MajikanCall.respond_to_call(cs)
	_assert_eq(cs_dup["trust"], trust_after_ok, "double response is safe no-op")

	# Missing calls while calling boyfriend triggers Indonesian teguran, deduction, and eventual firing
	cs = MajikanCall.apply_distraction(cs, "calling_boyfriend")
	cs = MajikanCall.start_call(cs, "Kompor mau mendidih!")
	var cs_overlap: Dictionary = MajikanCall.start_call(cs, "Duplicate call")
	_assert_eq(cs_overlap["call_reason"], "Kompor mau mendidih!", "overlapping start_call rejected")
	cs = MajikanCall.tick_call(cs, 2.0)
	cs = MajikanCall.tick_call(cs, 2.0)
	cs = MajikanCall.tick_call(cs, 2.0)
	_assert_eq(cs["active_call"], false, "missed call resolves")
	_assert_eq(cs["warnings"], 1, "missed call adds 1 warning")
	_assert_true("pacar" in String(cs["last_warning_text"]).to_lower(), "warning mentions boyfriend call distraction")
	_assert_true("phone" in String(cs["last_warning_text_en"]).to_lower(), "EN warning mentions phone distraction")
	_assert_true(int(cs["pay_deduction_rp"]) > 0, "missed call deducts pay")

	# 2 more missed calls -> fired!
	for _i in range(2):
		cs = MajikanCall.start_call(cs, "Panggilan majikan!")
		for _t in range(6):
			cs = MajikanCall.tick_call(cs, 2.0)
	_assert_eq(cs["fired"], true, "3 warnings fires ART")
	_assert_true(MajikanCall.final_payout_rp(cs) >= 0, "payout never negative even with deductions")
	var cs_after_fire: Dictionary = MajikanCall.start_new_shift(cs, MajikanProfiles.get_profile("ibu_kos_melati"))
	_assert_eq(cs_after_fire["fired"], false, "new lower-tier shift allows recovery after firing")
	_assert_eq(cs_after_fire["warnings"], 0, "warnings reset on new shift")

	# 8. Bilingual EN variants on MajikanProfiles & Neighborhood (zero mixed copy)
	_assert_true(MajikanProfiles.get_personality("ramah").has("warning_template_en"), "personality has EN template")
	_assert_true(Neighborhood.NEIGHBORS[0].has("greeting_en"), "neighbor has EN greeting")

	# 9. ChoreEngine (shift chores, skill speed/pay scaling, idempotency, energy & bounds guards)
	var sh_kos: Dictionary = ChoreEngine.create_shift("kamar_kos", MajikanProfiles.get_profile("ibu_kos_melati"), 100)
	_assert_eq(sh_kos["assigned_ids"].size(), 3, "kamar_kos has 3 chores")
	_assert_eq(sh_kos["settled"], false, "shift starts unsettled")
	var sh_elite: Dictionary = ChoreEngine.create_shift("cluster_elite", pelite, 120)
	_assert_eq(sh_elite["assigned_ids"].size(), 6, "cluster_elite has 6 chores")
	_assert_true(ChoreEngine.effective_duration("sweep_floor", 3) < ChoreEngine.effective_duration("sweep_floor", 1), "higher skill speeds up chore")
	_assert_eq(ChoreEngine.effective_duration("sweep_floor", 0), ChoreEngine.effective_duration("sweep_floor", 1), "skill_level <= 0 clamped to 1")

	var first_cid: String = String(sh_kos["assigned_ids"][0])
	var ch_ok: Dictionary = ChoreEngine.complete_chore(sh_kos, first_cid, 1.0, 2)
	_assert_true(ch_ok["ok"], "first chore completes")
	sh_kos = ch_ok["shift"]
	_assert_true(int(sh_kos["earned_rp"]) > 0, "chore awards IDR")
	_assert_true(int(sh_kos["xp_earned"]) > 0, "chore awards XP")
	_assert_true(int(sh_kos["energy"]) < 100, "chore consumes energy")
	var ch_dup: Dictionary = ChoreEngine.complete_chore(sh_kos, first_cid, 1.0, 2)
	_assert_eq(ch_dup["ok"], false, "duplicate chore rejected")
	var ch_ghost: Dictionary = ChoreEngine.complete_chore(sh_kos, "invalid_chore", 1.0, 1)
	_assert_eq(ch_ghost["ok"], false, "unknown chore rejected")
	var sh_tired: Dictionary = ChoreEngine.create_shift("kamar_kos", MajikanProfiles.get_profile("ibu_kos_melati"), 10)
	sh_tired["energy"] = 2
	var ch_low: Dictionary = ChoreEngine.complete_chore(sh_tired, String(sh_tired["assigned_ids"][0]), 1.0, 1)
	_assert_eq(ch_low["ok"], false, "low energy blocks chore")
	_assert_eq(ch_low["reason"], "low_energy", "low energy reason returned")
	var sh_rested: Dictionary = ChoreEngine.rest_recover(sh_tired, 50)
	_assert_eq(sh_rested["energy"], 10, "rest_recover clamped to max_energy")

	# 10. Progression (Leveling, Skill Mastery, Kos Upgrades, Outfits, Career Promotion, Settle Shift)
	_assert_eq(Progression.level_from_xp(0), 1, "level 1 at 0 XP")
	_assert_true(Progression.level_from_xp(200) >= 3, "level >= 3 at 200 XP")
	_assert_eq(Progression.skill_level_from_xp(0), 1, "skill lv 1 at 0")
	_assert_true(Progression.skill_level_from_xp(180) >= 4, "skill lv >= 4 at 180")

	var sv: Dictionary = Progression.create_player_save()
	_assert_eq(sv["balance_rp"], 0, "new save balance 0")
	_assert_eq(sv["active_tier_id"], "kamar_kos", "new save tier kamar_kos")
	var buy_fail: Dictionary = Progression.buy_kos_upgrade(sv, "kipas_angin")
	_assert_eq(buy_fail["ok"], false, "cannot buy upgrade with Rp 0")
	sv["balance_rp"] = 100000
	var buy_ok: Dictionary = Progression.buy_kos_upgrade(sv, "kipas_angin")
	_assert_true(buy_ok["ok"], "upgrade purchased when affordable")
	sv = buy_ok["save"]
	_assert_eq(sv["balance_rp"], 55000, "cost deducted from balance")
	var buy_dup: Dictionary = Progression.buy_kos_upgrade(sv, "kipas_angin")
	_assert_eq(buy_dup["ok"], false, "duplicate upgrade blocked")
	_assert_true(Progression.get_max_energy(sv) > 100, "kipas_angin raises max energy")

	var eq_locked: Dictionary = Progression.equip_outfit(sv, "seragam_perumahan", "#237A75")
	_assert_eq(eq_locked["ok"], false, "locked outfit blocked at 0 XP")
	var eq_bad_hex: Dictionary = Progression.equip_outfit(sv, "starter_kasual", "NOTHEX")
	_assert_eq(eq_bad_hex["ok"], false, "invalid color hex rejected")
	var eq_ok: Dictionary = Progression.equip_outfit(sv, "starter_kasual", "#C9855E")
	_assert_true(eq_ok["ok"], "valid starter outfit + color equipped")
	sv = eq_ok["save"]

	var tier_locked: Dictionary = Progression.select_job_tier(sv, "perumahan_36")
	_assert_eq(tier_locked["ok"], false, "locked tier rejected")
	sv["xp"] = 250
	var tier_ok: Dictionary = Progression.select_job_tier(sv, "perumahan_36")
	_assert_true(tier_ok["ok"], "unlocked tier selectable")
	sv = tier_ok["save"]
	_assert_eq(sv["active_tier_id"], "perumahan_36", "active tier updated")

	# Settle shift: normal + double-settle guard + fired XP halving
	var sh_settle: Dictionary = ChoreEngine.create_shift("kamar_kos", MajikanProfiles.get_profile("ibu_kos_melati"), 100)
	for cid in sh_settle["assigned_ids"]:
		sh_settle = ChoreEngine.complete_chore(sh_settle, String(cid), 1.0, 1)["shift"]
	_assert_eq(ChoreEngine.is_shift_complete(sh_settle), true, "all chores completed")
	var cs_good: Dictionary = MajikanCall.create_state(MajikanProfiles.get_profile("ibu_kos_melati"))
	var st_res: Dictionary = Progression.settle_shift(sv, sh_settle, cs_good)
	_assert_true(st_res["ok"], "first settle succeeds")
	_assert_true(int(st_res["payout_rp"]) >= int(sh_settle["earned_rp"]) + 35000, "payout includes chores + base pay")
	var st_dup: Dictionary = Progression.settle_shift(st_res["save"], st_res["shift"], cs_good)
	_assert_eq(st_dup["ok"], false, "double settle blocked")

	var sh_fired: Dictionary = ChoreEngine.create_shift("kamar_kos", MajikanProfiles.get_profile("ibu_kos_melati"), 100)
	sh_fired = ChoreEngine.complete_chore(sh_fired, String(sh_fired["assigned_ids"][0]), 1.0, 1)["shift"]
	var cs_fired: Dictionary = MajikanCall.create_state(MajikanProfiles.get_profile("ibu_kos_melati"))
	cs_fired["fired"] = true
	var st_fired: Dictionary = Progression.settle_shift(sv, sh_fired, cs_fired)
	_assert_eq(st_fired["payout_rp"], 0, "fired shift forfeits all pay including chore wages")
	_assert_eq(st_fired["xp_gained"], 0, "fired shift forfeits XP")

	# 11. SaveStore JSON validation & round-trip persistence
	var json_str: String = SaveStore.serialize(sv)
	var loaded_ok: Dictionary = SaveStore.deserialize(json_str)
	_assert_eq(loaded_ok["active_tier_id"], "perumahan_36", "save serialize/deserialize preserves tier")
	var loaded_corrupt: Dictionary = SaveStore.deserialize("{bad json")
	_assert_eq(loaded_corrupt["balance_rp"], 0, "corrupt JSON safely falls back to clean save")
	var tampered_json := '{"balance_rp": -999, "xp": 10, "active_tier_id": "cluster_elite", "equipped_outfit_id": "housekeeper_elite", "outfit_color_hex": "bad"}'
	var sanitized: Dictionary = SaveStore.deserialize(tampered_json)
	_assert_eq(sanitized["balance_rp"], 0, "negative balance clamped to 0")
	_assert_eq(sanitized["active_tier_id"], "kamar_kos", "locked tier downgraded to unlocked tier for XP=10")
	_assert_eq(sanitized["equipped_outfit_id"], "starter_kasual", "locked outfit downgraded for XP=10")
	_assert_true(Color.html_is_valid(String(sanitized["outfit_color_hex"])), "invalid color replaced with valid hex")
	var tmp_save_path := "user://tdd_test_save_v1.json"
	_assert_true(SaveStore.save_to_path(sv, tmp_save_path), "save_to_path writes file")
	var reloaded: Dictionary = SaveStore.load_from_path(tmp_save_path)
	_assert_eq(reloaded["balance_rp"], sv["balance_rp"], "disk round-trip balance matches")

	# 12. Procedural AudioSynth WAV streams (explicit 16-bit mono 22050 Hz)
	var wav_coin: AudioStreamWAV = AudioSynth.make_coin_chime()
	var wav_ring: AudioStreamWAV = AudioSynth.make_phone_ring()
	_assert_eq(wav_coin.format, AudioStreamWAV.FORMAT_16_BITS, "coin chime 16-bit PCM")
	_assert_eq(wav_coin.mix_rate, 22050, "coin chime 22050 Hz")
	_assert_eq(wav_coin.stereo, false, "coin chime mono")
	_assert_true(wav_coin.data.size() > 1000, "coin chime has PCM bytes")
	_assert_true(wav_ring.data.size() > 2000, "phone ring has PCM bytes")

	# 13. All tier, outfit & employer GLB paths resolve cleanly on disk
	for t in CareerTiers.get_all_tiers():
		_assert_true(ResourceLoader.exists(String(t["street_scene"])), "tier street exists: " + String(t["id"]))
	for o in CareerTiers.OUTFIT_TIERS:
		_assert_true(ResourceLoader.exists(String(o["model_path"])), "outfit model exists: " + String(o["id"]))
	for p in MajikanProfiles.PROFILES:
		_assert_true(ResourceLoader.exists(String(p["work_scene"])), "profile work_scene exists: " + String(p["id"]))
		_assert_true(ResourceLoader.exists(String(p["work_interior_scene"])), "profile work_interior exists: " + String(p["id"]))
		_assert_true(ResourceLoader.exists(String(p["kamar_art_scene"])), "profile kamar_art exists: " + String(p["id"]))

	# 14. Unified Room Upgrade Title (works across Kos & Live-In ART) & Chore Checklist Helper
	_assert_eq(Progression.get_room_upgrade_title(CareerTiers.get_tier("kamar_kos"), "id"), "Upgrade Kamar", "live-out uses Upgrade Kamar ID")
	_assert_eq(Progression.get_room_upgrade_title(CareerTiers.get_tier("cluster_elite"), "id"), "Upgrade Kamar", "live-in uses Upgrade Kamar ID")
	_assert_eq(Progression.get_room_upgrade_title(CareerTiers.get_tier("cluster_elite"), "en"), "Upgrade Room", "unified Upgrade Room EN")
	var chk: Array = ChoreEngine.get_checklist_items(sh_kos, "id")
	_assert_eq(chk.size(), 3, "checklist returns 3 items for kos")
	_assert_eq(bool(chk[0]["done"]), true, "first completed chore marked done in checklist")

	# 15. Warung-Life style HUD formatters (5-star Trust, Indonesian Day Clock, HP Badge)
	_assert_eq(Progression.trust_to_stars(100), "★★★★★", "100 trust = 5 stars")
	_assert_eq(Progression.trust_to_stars(60), "★★★☆☆", "60 trust = 3 stars")
	_assert_eq(Progression.trust_to_stars(0), "☆☆☆☆☆", "0 trust = 0 stars")
	_assert_true("07." in Progression.format_shift_clock(1, 0.0, "id"), "shift starts at 07.xx")
	_assert_true("SENIN" in Progression.format_shift_clock(1, 0.0, "id"), "day 1 is SENIN in ID")
	_assert_true("MON" in Progression.format_shift_clock(1, 0.0, "en"), "day 1 is MON in EN")
	_assert_eq(MajikanCall.get_phone_badge_count(cs_good), 0, "no active call = 0 phone badge")
	var cs_ring := MajikanCall.start_call(cs_good, "Paket!")
	_assert_eq(MajikanCall.get_phone_badge_count(cs_ring), 1, "active call = 1 phone badge")

	# 16. Indonesian ART & NPC Roster (Mba2, Ibu2, Kakak2, Bapak2), clearance & animations
	_assert_true(ResourceLoader.exists("res://assets/models/char_kakak.glb"), "char_kakak.glb exists on disk")
	var char_models := [
		"res://assets/models/char_art.glb",
		"res://assets/models/char_art_hijab.glb",
		"res://assets/models/char_art_pro.glb",
		"res://assets/models/char_art_elite.glb",
		"res://assets/models/char_ibu.glb",
		"res://assets/models/char_kakak.glb",
		"res://assets/models/char_budi.glb",
	]
	for cm_path in char_models:
		var packed: PackedScene = load(cm_path)
		_assert_true(packed != null, "char glb loads: " + cm_path)
		if packed != null:
			var inst := packed.instantiate()
			root.add_child(inst)
			_assert_true(inst.find_child("*Icosphere*", true, false) == null, "no Icosphere bone-shape mesh in " + cm_path)
			var ap := _find_anim_player(inst)
			_assert_true(ap != null, "char has AnimationPlayer: " + cm_path)
			if ap != null:
				var anims_str := ",".join(ap.get_animation_list()).to_lower()
				for req_anim in ["idle", "walk", "clean", "talk", "celebrate"]:
					_assert_true(req_anim in anims_str, cm_path + " has anim " + req_anim)
			var skel := _find_skeleton(inst)
			_assert_true(skel != null, "char has Skeleton3D: " + cm_path)
			if skel != null:
				var i_sh := skel.find_bone("upperarm_l")
				var i_el := skel.find_bone("lowerarm_l")
				var i_wr := skel.find_bone("hand_l")
				var i_tip := skel.find_bone("middle_04_leaf_l")
				if i_tip < 0:
					i_tip = skel.find_bone("hand_l")
				var i_hip := skel.find_bone("thigh_l")
				var i_knee := skel.find_bone("calf_l")
				var i_foot := skel.find_bone("foot_l")
				var i_nk := skel.find_bone("neck_01")
				var i_hd := skel.find_bone("head_leaf")
				var using_head_base := false
				if i_hd < 0:
					i_hd = skel.find_bone("head")
					using_head_base = i_hd >= 0
				_assert_true(i_tip >= 0 and i_knee >= 0 and i_hd >= 0 and i_foot >= 0, "humanoid bones exist in " + cm_path)
				if ap != null and i_foot >= 0:
					for req_anim in ["idle", "walk", "clean", "talk", "celebrate"]:
						for a_name in ap.get_animation_list():
							if req_anim in a_name.to_lower():
								ap.play(a_name)
								ap.advance(0.25)
								var fp := (_local_xform_to(skel, inst) * skel.get_bone_global_pose(i_foot).origin)
								_assert_true(is_finite(fp.y) and fp.y >= -0.08 and fp.y <= 0.55, "%s %s foot_l.y=%.3f valid" % [cm_path, req_anim, fp.y])
								break
					for a_name in ap.get_animation_list():
						if "idle" in a_name.to_lower():
							ap.play(a_name)
							ap.advance(0.25)
							break
				if i_tip >= 0 and i_knee >= 0 and i_hd >= 0:
					var xf := _local_xform_to(skel, inst)
					var p_sh := xf * skel.get_bone_global_pose(i_sh).origin
					var p_el := xf * skel.get_bone_global_pose(i_el).origin
					var p_wr := xf * skel.get_bone_global_pose(i_wr).origin
					var p_tip := xf * skel.get_bone_global_pose(i_tip).origin
					var p_hip := xf * skel.get_bone_global_pose(i_hip).origin
					var p_knee := xf * skel.get_bone_global_pose(i_knee).origin
					var p_nk := xf * skel.get_bone_global_pose(i_nk).origin
					var p_hd := xf * skel.get_bone_global_pose(i_hd).origin
					var total_h := p_hd.y + (0.16 if using_head_base else 0.0)
					var arm_len := p_sh.distance_to(p_el) + p_el.distance_to(p_wr) + p_wr.distance_to(p_tip)
					_assert_true(total_h >= 1.55 and total_h <= 1.98, "%s height %.2fm in [1.55,1.98]" % [cm_path, total_h])
					_assert_true(p_hip.y / total_h >= 0.46, "%s hip/height %.3f >= 0.46 (human legs)" % [cm_path, p_hip.y / total_h])
					_assert_true(arm_len / total_h <= 0.41, "%s arm/height %.3f <= 0.41 (human arms)" % [cm_path, arm_len / total_h])
					_assert_true((p_tip.y - p_knee.y) / total_h >= 0.12, "%s (tip-knee)/height %.3f >= 0.12 in Idle" % [cm_path, (p_tip.y - p_knee.y) / total_h])
					_assert_true((p_hd.y - p_nk.y) / total_h <= 0.22, "%s head+neck/height %.3f <= 0.22 (6+ heads)" % [cm_path, (p_hd.y - p_nk.y) / total_h])
			_assert_true(_count_mesh_verts(inst) <= 14500, "%s vertex count <= 14500 for mobile WebGL2" % cm_path)
			root.remove_child(inst)
			inst.free()

	for t in CareerTiers.TIERS:
		var tid := String(t["id"])
		var npcs: Array = NpcRoster.get_shift_npcs(tid)
		_assert_true(npcs.size() >= 1, "shift has NPCs for tier " + tid)
		var bounds: Dictionary = NpcRoster.get_tier_bounds_and_chores(tid)
		var rect: Rect2 = bounds["walk_rect"]
		var spawn: Vector3 = bounds["player_spawn"]
		var chores: Dictionary = bounds["chores"]
		for npc in npcs:
			_assert_true(ResourceLoader.exists(String(npc["model_path"])), "npc model exists: " + String(npc["model_path"]))
			_assert_true(not String(npc["label_id"]).is_empty() and not String(npc["label_en"]).is_empty(), "npc label populated ID/EN: " + String(npc["id"]))
			var p: Vector3 = npc["pos"]
			_assert_true(rect.grow(-0.25).has_point(Vector2(p.x, p.z)), "npc inside safe walk_bounds for " + tid + ": " + String(npc["id"]))
			_assert_true(p.distance_to(spawn) >= 1.2, "npc >=1.2m from player_spawn in " + tid + ": " + String(npc["id"]))
			for ck in chores.keys():
				var cp: Vector3 = chores[ck]
				_assert_true(p.distance_to(cp) >= 0.9, "npc >=0.9m from chore " + String(ck) + " in " + tid)
		var st_npcs: Array = NpcRoster.get_street_config(tid).get("street_npcs", [])
		_assert_true(st_npcs.size() >= 2, "street hub has neighbor NPCs for tier " + tid)

	# 17. Runtime shirt tinting must NOT darken textured Batik / Daster materials
	var test_ctrl := PlayerControllerScene.new()
	var mi_batik := MeshInstance3D.new()
	var box_m := BoxMesh.new()
	var mat_batik := StandardMaterial3D.new()
	mat_batik.resource_name = "Shirt_Batik"
	var img_tx := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	mat_batik.albedo_texture = img_tx
	mat_batik.albedo_color = Color.WHITE
	box_m.material = mat_batik
	mi_batik.mesh = box_m
	test_ctrl._apply_outfit_tint(mi_batik, Color.html("#4E7D63"))
	var active_m := mi_batik.get_active_material(0) as StandardMaterial3D
	_assert_eq(active_m.albedo_color, Color.WHITE, "textured Batik/Daster Shirt keeps WHITE albedo_color on tint")
	mi_batik.free()
	test_ctrl.free()

	# 18. Onboarding / Character Creation & Weekly Kos Rent (Warung-Life style)
	var fresh_sv := Progression.create_player_save()
	_assert_eq(bool(fresh_sv.get("onboarding_done", true)), false, "new save starts with onboarding_done = false")
	_assert_eq(String(fresh_sv.get("player_name", "")), "Mbak Sari", "default player name is Mbak Sari")
	_assert_eq(Progression.resolve_player_model_path(fresh_sv), "res://assets/models/char_art.glb", "cepol starter resolves char_art.glb")
	var ob_res := Progression.complete_onboarding(fresh_sv, "  Mbak Ani  ", "hijab", "#A67349", "#4E7D63")
	_assert_eq(bool(ob_res["ok"]), true, "complete_onboarding succeeds")
	var ob_sv: Dictionary = ob_res["save"]
	_assert_eq(bool(ob_sv["onboarding_done"]), true, "onboarding_done becomes true")
	_assert_eq(String(ob_sv["player_name"]), "Mbak Ani", "player_name trimmed")
	_assert_eq(String(ob_sv["starter_style"]), "hijab", "starter_style saved")
	_assert_eq(Progression.resolve_player_model_path(ob_sv), "res://assets/models/char_art_hijab.glb", "hijab starter resolves char_art_hijab.glb")
	_assert_true(ResourceLoader.exists("res://assets/models/char_art_hijab.glb"), "char_art_hijab.glb exists on disk")
	var bad_ob := SaveStore.deserialize("{\"onboarding_done\": true, \"player_name\": \"\", \"starter_style\": \"hacker\", \"skin_hex\": \"bad\"}")
	_assert_eq(String(bad_ob["player_name"]), "Mbak Sari", "empty player_name falls back to Mbak Sari")
	_assert_eq(String(bad_ob["starter_style"]), "cepol", "invalid starter_style falls back to cepol")
	_assert_eq(Color.html_is_valid(String(bad_ob["skin_hex"])), true, "invalid skin_hex sanitized")

	var rent_sv := ob_sv.duplicate(true)
	rent_sv["day"] = 7
	rent_sv["balance_rp"] = 200000
	rent_sv["last_rent_day"] = 0
	_assert_eq(Progression.should_collect_weekly_rent(rent_sv, CareerTiers.get_tier("kamar_kos")), true, "day 7 live-out triggers weekly kos rent")
	_assert_eq(Progression.should_collect_weekly_rent(rent_sv, CareerTiers.get_tier("cluster_elite")), false, "live-in tier does not charge kos rent")
	var paid_rent := Progression.pay_weekly_rent(rent_sv, true, 120000)
	_assert_eq(bool(paid_rent["ok"]), true, "weekly kos rent payment succeeds")
	_assert_eq(int(paid_rent["save"]["balance_rp"]), 80000, "balance deducted by rent")
	_assert_eq(int(paid_rent["save"]["last_rent_day"]), 7, "last_rent_day updated")
	var later_rent := Progression.pay_weekly_rent(rent_sv, false, 120000)
	_assert_eq(int(later_rent["save"]["pending_rent_rp"]), 135000, "pay later accrues rent + 15000 late fee")
	_assert_eq(Progression.should_collect_weekly_rent(later_rent["save"], CareerTiers.get_tier("kamar_kos")), false, "pay later grants 3-day grace before re-prompting")
	var later_due: Dictionary = later_rent["save"].duplicate(true)
	later_due["day"] = int(later_due["day"]) + 3
	_assert_eq(Progression.should_collect_weekly_rent(later_due, CareerTiers.get_tier("kamar_kos")), true, "pending rent resumes collection after 3-day grace")
	var settled_later := Progression.pay_weekly_rent(later_rent["save"], true, 120000)
	_assert_eq(bool(settled_later["ok"]), true, "paying accumulated pending rent succeeds")
	_assert_eq(int(settled_later["save"]["balance_rp"]), 65000, "balance deducted by 135000 pending rent")
	_assert_eq(int(settled_later["save"]["pending_rent_rp"]), 0, "pending rent cleared after payment")

	# 19. Street Hub Navigation, Empty Private Kos, 0-Chore Exploit Guard & Mood Mechanics
	for t in CareerTiers.TIERS:
		var tid := String(t["id"])
		_assert_eq(NpcRoster.get_home_npcs(tid).size(), 0, "private room has 0 uninvited NPCs for " + tid)
		var scfg: Dictionary = NpcRoster.get_street_config(tid)
		_assert_true(ResourceLoader.exists(String(scfg.get("street_scene", ""))), "street scene exists for " + tid)
		var srect: Rect2 = scfg.get("walk_rect", Rect2())
		var sspawn: Vector3 = scfg.get("player_spawn", Vector3.ZERO)
		var phome: Vector3 = scfg.get("portal_home", Vector3.ZERO)
		var pwork: Vector3 = scfg.get("portal_work", Vector3.ZERO)
		_assert_true(srect.has_point(Vector2(sspawn.x, sspawn.z)), "street spawn inside walk_rect for " + tid)
		_assert_true(srect.has_point(Vector2(phome.x, phome.z)), "portal_home inside walk_rect for " + tid)
		_assert_true(srect.has_point(Vector2(pwork.x, pwork.z)), "portal_work inside walk_rect for " + tid)
		_assert_true(phome.distance_to(pwork) >= 2.0, "street portals separated >=2m for " + tid)
		var snpcs: Array = scfg.get("street_npcs", [])
		_assert_true(snpcs.size() >= 2, "street has >=2 neighbors for " + tid)
		for snpc in snpcs:
			var sp: Vector3 = snpc["pos"]
			_assert_true(srect.has_point(Vector2(sp.x, sp.z)), "street npc inside walk_rect: " + String(snpc["id"]))
			_assert_true(sp.distance_to(sspawn) >= 1.2, "street npc >=1.2m from spawn: " + String(snpc["id"]))
			_assert_true(sp.distance_to(phome) >= 1.0, "street npc >=1.0m from portal_home: " + String(snpc["id"]))
			_assert_true(sp.distance_to(pwork) >= 1.0, "street npc >=1.0m from portal_work: " + String(snpc["id"]))
			_assert_true(not ("Maid " in String(snpc.get("label_en", ""))), "no 'Maid' translation in EN: " + String(snpc["id"]))

	# 0-chore instant-exit exploit blocked (and fired 0-chore still penalizes!)
	var sv_exp := Progression.create_player_save()
	sv_exp["day"] = 3
	var sh_zero := ChoreEngine.create_shift("kamar_kos", MajikanProfiles.get_profile("ibu_kos_melati"), 100)
	var cs_zero := MajikanCall.create_state(MajikanProfiles.get_profile("ibu_kos_melati"))
	var res_zero := Progression.settle_shift(sv_exp, sh_zero, cs_zero)
	_assert_eq(bool(res_zero["ok"]), true, "0-chore abort settles cleanly")
	_assert_eq(bool(res_zero.get("aborted", false)), true, "0-chore non-fired marked aborted")
	_assert_eq(int(res_zero["payout_rp"]), 0, "0-chore exploit awards Rp 0")
	_assert_eq(int(res_zero["xp_gained"]), 0, "0-chore exploit awards 0 XP")
	_assert_eq(int(res_zero["save"]["day"]), 3, "0-chore abort does not advance day")
	_assert_eq(int(res_zero["save"]["completed_shifts"]), 0, "0-chore abort does not increment completed_shifts")

	var cs_zero_fired := cs_zero.duplicate(true)
	cs_zero_fired["fired"] = true
	var res_zf := Progression.settle_shift(sv_exp, sh_zero, cs_zero_fired)
	_assert_eq(bool(res_zf.get("aborted", true)), false, "0-chore fired is NOT treated as free abort")
	_assert_eq(int(res_zf["save"]["fired_count"]), 1, "0-chore fired increments fired_count")
	_assert_eq(int(res_zf["save"]["day"]), 4, "0-chore fired advances day")

	# Partial shift proration (1 of 3 chores)
	var sh_part := ChoreEngine.create_shift("kamar_kos", MajikanProfiles.get_profile("ibu_kos_melati"), 100)
	sh_part = ChoreEngine.complete_chore(sh_part, String(sh_part["assigned_ids"][0]), 0.85, 1)["shift"]
	var res_part := Progression.settle_shift(sv_exp, sh_part, cs_zero)
	var expected_prorated := int(sh_part["earned_rp"]) + int(round(35000.0 / 3.0))
	_assert_eq(int(res_part["payout_rp"]), expected_prorated, "partial 1/3 shift prorates contract pay")

	# Mood speed, +15% morale payout bonus, Upgrade mood_bonus, and per-shift distraction cap
	_assert_true(ChoreEngine.effective_duration("sweep_floor", 1, 85) < ChoreEngine.effective_duration("sweep_floor", 1, 60), "high mood >=80 speeds up chore")
	_assert_true(ChoreEngine.effective_duration("sweep_floor", 1, 20) > ChoreEngine.effective_duration("sweep_floor", 1, 60), "low mood <=25 slows down chore")
	var sv_up := sv_exp.duplicate(true)
	sv_up["unlocked_kos_upgrades"] = ["rak_sepatu", "ac_hemat"]
	_assert_eq(Progression.get_mood_bonus(sv_up), 16, "get_mood_bonus sums upgrade mood bonuses")
	var cs_high_mood := cs_zero.duplicate(true)
	cs_high_mood["mood"] = 85
	var res_morale := Progression.settle_shift(sv_exp, sh_settle, cs_high_mood)
	var res_base_mood := Progression.settle_shift(sv_exp, sh_settle, cs_zero)
	_assert_true(int(res_morale["payout_rp"]) > int(res_base_mood["payout_rp"]), "high mood >=80 grants morale bonus payout")

	var cs_cap := MajikanCall.create_state(MajikanProfiles.get_profile("ibu_kos_melati"))
	cs_cap = MajikanCall.apply_distraction(cs_cap, "playing_game")
	cs_cap = MajikanCall.apply_distraction(cs_cap, "calling_boyfriend")
	var mood_at_cap := int(cs_cap["mood"])
	cs_cap = MajikanCall.apply_distraction(cs_cap, "calling_boyfriend")
	_assert_eq(int(cs_cap["mood"]), mood_at_cap, "3rd distraction in same shift capped")
	_assert_eq(int(cs_cap.get("distractions_used", 0)), 2, "distractions_used capped at 2")

	var bad_mood_save := SaveStore.deserialize('{"mood": 999, "chatted_dates": {"ibu_sari": "day_2", "bad": 123}}')
	_assert_eq(int(bad_mood_save["mood"]), 100, "mood clamped <= 100")
	_assert_eq(String(bad_mood_save["chatted_dates"].get("ibu_sari", "")), "day_2", "valid chatted_dates preserved")
	_assert_eq(bad_mood_save["chatted_dates"].has("bad"), false, "non-string chatted_dates stripped")

	# 20. All 4 Gaps: Atmosphere + 3D Kos Upgrades, Street Traffic, Portraits + Map, Settings + Daily Log
	_assert_eq(ArtAtmosphere.get_phase("shift", 1, 10.0), "pagi", "phase pagi at 10s")
	_assert_eq(ArtAtmosphere.get_phase("shift", 1, 60.0), "siang", "phase siang at 60s")
	_assert_eq(ArtAtmosphere.get_phase("shift", 1, 125.0), "sore", "phase sore at 125s")
	_assert_eq(ArtAtmosphere.get_phase("shift", 1, 180.0), "malam", "phase malam at 180s")
	_assert_eq(ArtAtmosphere.get_weather(3, true), "hujan", "day 3 rainy when weather_fx enabled")
	_assert_eq(ArtAtmosphere.get_weather(3, false), "cerah", "weather forced cerah when weather_fx disabled")

	var kos_ps: PackedScene = load("res://assets/models/kos_room.glb")
	_assert_true(kos_ps != null, "kos_room.glb loads for upgrade visual check")
	if kos_ps != null:
		var kos_inst := kos_ps.instantiate()
		root.add_child(kos_inst)
		ArtAtmosphere.apply_kos_upgrades_visual(kos_inst, [])
		var ac_node := kos_inst.find_child("IndoorAC", true, false) as Node3D
		var fan_node := kos_inst.find_child("FanBlade_0", true, false) as Node3D
		var rc_node := kos_inst.find_child("RiceCookerStand", true, false) as Node3D
		_assert_true(ac_node != null and not ac_node.visible, "IndoorAC hidden before purchase")
		_assert_true(fan_node != null and not fan_node.visible, "FanBlade_0 hidden before purchase")
		_assert_true(rc_node != null and not rc_node.visible, "RiceCookerStand hidden before purchase")
		ArtAtmosphere.apply_kos_upgrades_visual(kos_inst, ["ac_hemat", "kipas_angin", "magic_com_pro", "rak_sepatu", "kasur_empuk"])
		_assert_true(ac_node.visible, "IndoorAC visible after ac_hemat purchase")
		_assert_true(fan_node.visible, "FanBlade_0 visible after kipas_angin purchase")
		_assert_true(rc_node.visible, "RiceCookerStand visible after magic_com_pro purchase")
		_assert_true(kos_inst.find_child("RakSepatu", true, false) != null, "RakSepatu spawned after rak_sepatu purchase")
		root.remove_child(kos_inst)
		kos_inst.free()

	_assert_eq(ArtStreetTraffic.get_traffic_config("kamar_kos").size(), 0, "kampung_gang spawns 0 vehicles")
	var t_p36: Array = ArtStreetTraffic.get_traffic_config("perumahan_36")
	_assert_true(t_p36.size() >= 2, "perumahan_36 spawns cruising traffic")
	for tv in t_p36:
		_assert_true(ArtStreetTraffic.is_lane_safe(float(tv["z"])), "vehicle lane safely outside sidewalk: " + String(tv["id"]))
		_assert_true(ResourceLoader.exists(String(tv["model_path"])), "vehicle model exists: " + String(tv["model_path"]))
	var t_step := t_p36.duplicate(true)
	var x0 := float(t_step[0]["x"])
	ArtStreetTraffic.step_vehicles(t_step, 1.0)
	_assert_true(float(t_step[0]["x"]) != x0, "step_vehicles moves vehicle x")

	var p_a := ArtPortraits.get_portrait("ibu_melati", "strict")
	var p_b := ArtPortraits.get_portrait("ibu_melati", "strict")
	_assert_true(p_a != null and p_a.get_width() >= 48 and p_a.get_height() == p_a.get_width(), "portrait is square ImageTexture (>=48px)")
	_assert_true(p_a == p_b, "portrait cached in static dictionary")
	var sv_map := Progression.create_player_save()
	sv_map["xp"] = 250
	sv_map["active_tier_id"] = "kampung"
	var map_nodes := ArtPortraits.get_map_destinations(sv_map, "home")
	_assert_true(map_nodes.size() >= 8, "map returns places + 5 district tiers")
	_assert_eq(bool(map_nodes[0]["active"]), true, "kos_room marked active in home mode")

	var sv_log := Progression.create_player_save()
	for i_log in range(15):
		sv_log = ArtSettings.append_daily_log(sv_log, {"day": i_log + 1, "kind": "shift", "title_id": "Shift #%d" % (i_log + 1), "title_en": "Shift #%d" % (i_log + 1), "delta_rp": 50000})
	_assert_eq(ArtSettings.get_daily_log(sv_log).size(), ArtSettings.MAX_DAILY_LOG, "daily_log capped at 12 entries")
	sv_log["gfx_quality"] = "low"
	sv_log["weather_fx"] = false
	var sv_rt := SaveStore.deserialize(SaveStore.serialize(sv_log))
	_assert_eq(String(sv_rt["gfx_quality"]), "low", "SaveStore preserves gfx_quality")
	_assert_eq(bool(sv_rt["weather_fx"]), false, "SaveStore preserves weather_fx")
	_assert_eq(ArtSettings.get_daily_log(sv_rt).size(), ArtSettings.MAX_DAILY_LOG, "SaveStore preserves daily_log")

	# 21. Remaining Polish Gaps: Wishlist, Story Chapters, Day-1 Tutorial, Street Patrols + Umbrella, BGM/Rain Loops
	var sv_w := Progression.create_player_save()
	sv_w["balance_rp"] = 500000
	var bw_ok := ArtWishlistStory.buy_wishlist_item(sv_w, "kirim_kampung")
	_assert_eq(bool(bw_ok["ok"]), true, "buy wishlist item succeeds")
	_assert_eq(int(bw_ok["save"]["balance_rp"]), 350000, "wishlist deducts balance")
	_assert_eq(int(bw_ok["save"]["xp"]), 60, "wishlist awards xp bonus")
	var bw_dup := ArtWishlistStory.buy_wishlist_item(bw_ok["save"], "kirim_kampung")
	_assert_eq(bool(bw_dup["ok"]), false, "duplicate wishlist purchase blocked")
	_assert_eq(int(bw_dup["save"]["xp"]), 60, "duplicate wishlist purchase grants 0 extra xp")
	_assert_true(Progression.get_mood_bonus(bw_ok["save"]) >= 5, "wishlist mood_bonus folds into Progression.get_mood_bonus")

	for t_ch in CareerTiers.TIERS:
		var ch_tid := String(t_ch["id"])
		var ch := ArtWishlistStory.get_unseen_chapter(sv_w, ch_tid)
		_assert_true(not ch.is_empty(), "story chapter exists for tier " + ch_tid)
	var sv_seen := ArtWishlistStory.mark_chapter_seen(sv_w, "ch_kamar_kos")
	_assert_true(ArtWishlistStory.get_unseen_chapter(sv_seen, "kamar_kos").is_empty(), "seen chapter not repeated")
	_assert_eq(ArtWishlistStory.get_newly_unlocked_chapter_tier(70, 90, sv_w), "kampung", "detects newly unlocked kampung chapter on XP cross")
	_assert_eq(ArtWishlistStory.get_newly_unlocked_chapter_tier(90, 120, sv_w), "", "returns empty when no new tier unlocked")
	var sv_seen_kp := ArtWishlistStory.mark_chapter_seen(sv_w, "ch_kampung")
	_assert_eq(ArtWishlistStory.get_newly_unlocked_chapter_tier(70, 90, sv_seen_kp), "", "returns empty when newly unlocked chapter already seen")
	_assert_true(ArtWishlistStory.get_tutorial_hint(0, "id") != "", "tutorial step 0 hint present")
	var sv_tut := ArtWishlistStory.advance_tutorial(sv_w, 2)
	_assert_eq(int(sv_tut["tutorial_step"]), 2, "tutorial advances cleanly")

	# SaveStore backward compatibility for legacy saves (completed_shifts > 0, no tutorial_step)
	var sv_legacy := SaveStore.deserialize('{"completed_shifts": 3, "unlocked_wishlist": ["kirim_kampung", "kirim_kampung", "fake_item"], "seen_chapters": ["ch_kamar_kos", "bogus"], "bgm_enabled": false}')
	_assert_eq(int(sv_legacy["tutorial_step"]), 4, "legacy save with completed_shifts skips Day-1 tutorial")
	_assert_eq((sv_legacy["unlocked_wishlist"] as Array).size(), 1, "SaveStore deduplicates & validates unlocked_wishlist")
	_assert_eq((sv_legacy["seen_chapters"] as Array).size(), 1, "SaveStore validates seen_chapters")
	_assert_eq(bool(sv_legacy["bgm_enabled"]), false, "SaveStore preserves bgm_enabled")

	# Street patrols stay inside walk_rect, clear of portals, and pause near player
	var sc_p36 := NpcRoster.get_street_config("perumahan_36")
	var rt_npcs := ArtStreetPatrols.create_runtime_npcs(sc_p36["street_npcs"])
	var wrect_p36: Rect2 = sc_p36["walk_rect"]
	for _step_i in range(25):
		ArtStreetPatrols.step_patrols(rt_npcs, sc_p36, Vector3(-10.0, 0.0, -10.0), 0.25)
	var moved_any := false
	for rnpc in rt_npcs:
		if bool(rnpc["patrol"]):
			moved_any = true
			var rpos: Vector3 = rnpc["pos"]
			_assert_true(wrect_p36.has_point(Vector2(rpos.x, rpos.z)), "patrol stays inside walk_rect: " + String(rnpc["id"]))
			_assert_true(absf(rpos.x - float(sc_p36["portal_home"].x)) >= 0.80, "patrol avoids portal_home: " + String(rnpc["id"]))
			_assert_true(absf(rpos.x - float(sc_p36["portal_work"].x)) >= 0.80, "patrol avoids portal_work: " + String(rnpc["id"]))
	_assert_true(moved_any, "street has >=1 patrolling citizen")

	var test_player := PlayerControllerScene.new()
	var umb := ArtStreetPatrols.sync_player_umbrella(test_player, true)
	_assert_true(umb != null and umb.visible, "umbrella attached and visible when raining")
	ArtStreetPatrols.sync_player_umbrella(test_player, false)
	_assert_eq(umb.visible, false, "umbrella hidden indoors / clear weather")
	test_player.free()

	var bgm_wav := AudioSynth.make_cozy_bgm_loop()
	var rain_wav := AudioSynth.make_rain_loop()
	_assert_eq(bgm_wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, "BGM uses LOOP_FORWARD")
	_assert_true(bgm_wav.loop_end > 44100, "BGM loop_end set to frame count (>2s)")
	_assert_eq(rain_wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Rain ambient uses LOOP_FORWARD")
	_assert_true(rain_wav.loop_end > 22050, "Rain loop_end set to frame count (>1s)")

	# 22. Warung-Life Parity Sprint: Mood Start, Level Tip Bonus, NPC 1:1 IDs, Chore Tools & Tap Boost, Tier 1 Room, Dynamic Portraits, 16s BGM & Tactile SFX
	var sv_m := Progression.create_player_save()
	sv_m["balance_rp"] = 500000
	sv_m["mood"] = 72
	sv_m = Progression.buy_kos_upgrade(sv_m, "kasur_empuk")["save"] # +8 mood
	sv_m = Progression.buy_kos_upgrade(sv_m, "kipas_angin")["save"] # +8 mood
	var start_mood := Progression.get_shift_starting_mood(sv_m)
	_assert_true(start_mood >= 80, "shift starting mood incorporates save mood + upgrade bonuses (>=80)")
	var cs_m := MajikanCall.create_state(MajikanProfiles.get_profile("ibu_kos_melati"), start_mood)
	_assert_eq(int(cs_m["mood"]), start_mood, "MajikanCall.create_state uses passed initial_mood instead of hardcoded 50")

	_assert_true(Progression.get_level_tip_bonus(400) > Progression.get_level_tip_bonus(0), "higher player level increases contract tip multiplier")
	_assert_eq(int(CareerTiers.get_tier("perumahan_45")["min_level"]), Progression.level_from_xp(int(CareerTiers.get_tier("perumahan_45")["min_xp"])), "perumahan_45 min_level matches level_from_xp")
	_assert_eq(int(CareerTiers.get_tier("cluster_elite")["min_level"]), Progression.level_from_xp(int(CareerTiers.get_tier("cluster_elite")["min_xp"])), "cluster_elite min_level matches level_from_xp")

	for tier_id in ["kamar_kos", "kampung", "perumahan_36", "perumahan_45", "cluster_elite"]:
		var sc_t := NpcRoster.get_street_config(tier_id)
		for sn in sc_t.get("street_npcs", []):
			var sn_id := String(sn["id"])
			var found_nb := false
			for nb in Neighborhood.NEIGHBORS:
				if String(nb["id"]) == sn_id:
					found_nb = true
					break
			_assert_true(found_nb, "street NPC id exists in Neighborhood.NEIGHBORS: " + sn_id)
	var shift_react := NpcRoster.get_shift_npc_reaction("ibu_melati", "id")
	_assert_true(String(shift_react.get("text", "")) != "", "shift NPC has interactive greeting reaction")

	_assert_eq(String(ChoreEngine.CHORE_TOOLS.get("sweep_floor", "")), "broom", "sweep_floor maps to broom tool prop")
	_assert_true(ChoreEngine.MAX_TAP_BOOSTS_PER_CHORE >= 2 and ChoreEngine.MAX_TAP_BOOSTS_PER_CHORE <= 4, "tap boost per-chore cap prevents instant exploit")
	_assert_eq(String(MajikanProfiles.get_profile("ibu_kos_melati")["work_interior_scene"]), "res://assets/models/kos_neighbor_room.glb", "Tier 1 shift uses distinct kos_neighbor_room.glb")

	var tp2 := PlayerControllerScene.new()
	var tool_node := ArtStreetPatrols.sync_chore_tool(tp2, "broom")
	_assert_true(tool_node != null and tool_node.visible, "chore tool prop attached & visible when cleaning")
	ArtStreetPatrols.sync_chore_tool(tp2, "")
	_assert_eq(tool_node.visible, false, "chore tool prop hidden when idle")
	tp2.free()

	var p_tex := ArtPortraits.get_player_portrait("#C98E66", "#2E7D6B", "hijab", "happy")
	_assert_true(p_tex != null and p_tex.get_width() >= 48, "dynamic player portrait renders (>=48px)")

	var bgm16 := AudioSynth.make_cozy_bgm_loop()
	_assert_true(bgm16.loop_end >= 22050 * 14, "cozy BGM extended to >=14s A/B phrase")
	_assert_true(AudioSynth.make_ui_click().data.size() > 0, "ui click SFX synthesized")
	_assert_true(AudioSynth.make_door_chime().data.size() > 0, "door chime SFX synthesized")
	_assert_true(AudioSynth.make_chore_tick().data.size() > 0, "chore tick SFX synthesized")
	_assert_true(AudioSynth.make_footstep_tick().data.size() > 0, "footstep tick SFX synthesized")

	# 23. Growth, Story Epilogue, Career Ranks & Level-Up Unlocks
	var xpp0 := Progression.get_xp_progress(0)
	_assert_eq(int(xpp0["level"]), 1, "xp 0 is level 1")
	_assert_eq(int(xpp0["xp_in_level"]), 0, "xp 0 in-level is 0")
	_assert_eq(int(xpp0["xp_needed"]), 40, "lv1->lv2 needs 40 xp")
	var xpp50 := Progression.get_xp_progress(50)
	_assert_eq(int(xpp50["level"]), 2, "xp 50 is level 2")
	_assert_eq(int(xpp50["xp_in_level"]), 10, "xp 50 has 10 xp into level 2")
	_assert_eq(int(xpp50["xp_needed"]), 120, "lv2->lv3 needs 120 xp (40..160)")

	_assert_true(int(Progression.KOS_UPGRADES["kipas_angin"]["mood_bonus"]) > 0, "kipas_angin gives positive mood_bonus")
	_assert_eq(Economy.get_career_rank(600, "id"), "ART Profesional", "rank 600")
	_assert_eq(Economy.get_career_rank(1400, "id"), "Housekeeper Teladan", "rank 1400")

	var unlocks := Progression.get_xp_unlocks(70, 90, "id")
	_assert_true(unlocks.size() >= 1, "crossing 80 XP returns unlock summary lines")

	var sv_ep := Progression.create_player_save()
	sv_ep["xp"] = 1400
	_assert_eq(ArtWishlistStory.is_epilogue_unlocked(sv_ep), false, "epilogue locked before all 4 wishlist items")
	sv_ep["unlocked_wishlist"] = ArtWishlistStory.WISHLIST_ITEMS.keys()
	_assert_eq(ArtWishlistStory.is_epilogue_unlocked(sv_ep), true, "epilogue unlocks with cluster_elite + 4 wishlist items")
	var ep := ArtWishlistStory.get_unseen_epilogue(sv_ep)
	_assert_eq(String(ep.get("id", "")), "ch_epilogue", "unseen epilogue returned")
	var sv_ep_seen := ArtWishlistStory.mark_chapter_seen(sv_ep, "ch_epilogue")
	_assert_true(ArtWishlistStory.get_unseen_epilogue(sv_ep_seen).is_empty(), "seen epilogue not repeated")
	var sv_ep_rt := SaveStore.deserialize(SaveStore.serialize(sv_ep_seen))
	_assert_true("ch_epilogue" in (sv_ep_rt["seen_chapters"] as Array), "SaveStore preserves ch_epilogue in seen_chapters")
	_assert_eq(ArtWishlistStory.get_storybook_entries(sv_ep_seen, "id").size(), 6, "storybook lists 5 chapters + epilogue")

	# 24. 1-Month Retention: 7-Day Streak, Clock-Skew Safety, Daily Missions, Shift Events, Badges & Modest Meal Sink
	var sv_r := Progression.create_player_save()
	var sync1 := ArtRetention.sync_daily_login(sv_r, "2026-11-26")
	sv_r = sync1["save"]
	_assert_eq(int(sv_r["login_streak"]), 1, "first login sets streak to 1")
	_assert_eq(bool(sync1["can_claim_streak"]), true, "first login allows streak claim")
	var cl1 := ArtRetention.claim_streak_reward(sv_r, "2026-11-26")
	_assert_eq(bool(cl1["ok"]), true, "day 1 streak reward claimed")
	_assert_true(int(cl1["save"]["balance_rp"]) > 0, "day 1 streak adds Rp")
	var cl_dup := ArtRetention.claim_streak_reward(cl1["save"], "2026-11-26")
	_assert_eq(bool(cl_dup["ok"]), false, "same-day duplicate streak claim blocked")

	var sync2 := ArtRetention.sync_daily_login(cl1["save"], "2026-11-27")
	_assert_eq(int(sync2["save"]["login_streak"]), 2, "consecutive day increments streak to 2")
	var sync_skew := ArtRetention.sync_daily_login(sync2["save"], "2026-11-25")
	_assert_eq(int(sync_skew["save"]["login_streak"]), 2, "backward clock skew preserves streak instead of resetting")
	_assert_eq(bool(sync_skew["can_claim_streak"]), false, "backward clock skew blocks re-claiming earlier streak")
	var cl_skew := ArtRetention.claim_streak_reward(cl1["save"], "2026-11-25")
	_assert_eq(bool(cl_skew["ok"]), false, "backward clock skew cannot re-claim streak reward")
	var sync_gap := ArtRetention.sync_daily_login(sync2["save"], "2026-11-30")
	_assert_eq(int(sync_gap["save"]["login_streak"]), 1, "multi-day gap resets streak to 1")

	var sv_m2 := ArtRetention.record_mission_progress(sync1["save"], "neighbors", 3, "2026-11-26")
	var missions_today := ArtRetention.get_active_missions(sv_m2, "2026-11-26", "id")
	_assert_eq(missions_today.size(), 3, "3 rotating daily missions generated")
	var sv_m_old := ArtRetention.record_mission_progress(sv_m2, "neighbors", 1, "2026-11-28")
	_assert_eq(String(sv_m_old["daily_missions"]["date"]), "2026-11-28", "mismatched mission date auto-resets")

	var ev_any := ArtRetention.get_shift_event(2, "kampung", "id")
	_assert_true(String(ev_any.get("id", "")) != "", "shift event returned for day/tier")
	_assert_true(float(ev_any.get("pay_mult", 0.0)) > 0.5, "shift event pay_mult valid")

	var sv_bg := Progression.create_player_save()
	sv_bg["completed_shifts"] = 1
	sv_bg["shift_boost_count"] = 5
	sv_bg["xp"] = 1400
	sv_bg["unlocked_wishlist"] = ArtWishlistStory.WISHLIST_ITEMS.keys()
	var bg_res := ArtRetention.evaluate_badges(sv_bg)
	_assert_true((bg_res["newly_unlocked"] as Array).size() >= 3, "badges unlock on milestones")
	_assert_true(int(bg_res["save"]["xp"]) > 1400, "new badges grant +25 XP bonus once")
	var bg_dup := ArtRetention.evaluate_badges(bg_res["save"])
	_assert_eq((bg_dup["newly_unlocked"] as Array).size(), 0, "badges never double-award")

	var sv_ret_rt := SaveStore.deserialize('{"login_streak": 99, "unlocked_badges": ["first_shift", "first_shift", "bogus"], "shift_boost_count": -4}')
	_assert_eq(int(sv_ret_rt["login_streak"]), 7, "SaveStore clamps login_streak 0..7")
	_assert_eq((sv_ret_rt["unlocked_badges"] as Array).size(), 1, "SaveStore deduplicates & validates unlocked_badges")
	_assert_eq(int(sv_ret_rt["shift_boost_count"]), 0, "SaveStore clamps shift_boost_count >= 0")

	var sv_meal := Progression.create_player_save()
	sv_meal["day"] = 3
	sv_meal["balance_rp"] = 20000
	var sh_meal := ChoreEngine.create_shift("kamar_kos", MajikanProfiles.get_profile("ibu_kos_melati"), 100)
	sh_meal = ChoreEngine.complete_chore(sh_meal, "make_bed", 0.85, 1)["shift"]
	var cs_meal := MajikanCall.create_state(MajikanProfiles.get_profile("ibu_kos_melati"))
	var res_meal := Progression.settle_shift(sv_meal, sh_meal, cs_meal)
	_assert_eq(int(res_meal["meal_cost_rp"]), 8000, "day >= 3 non-live-in deducts Rp 8,000 meal sink cleanly")
	_assert_eq(int(res_meal["save"]["balance_rp"]), 20000 + int(res_meal["payout_rp"]) - 8000, "meal sink deducted from balance after payout_rp")

	# 25. Vibrant Mobile Color Grading
	var cg_sun := DirectionalLight3D.new()
	var cg_bounce := DirectionalLight3D.new()
	var cg_env := Environment.new()
	var cg_sky_mat := ProceduralSkyMaterial.new()
	var cg_sky := Sky.new()
	cg_sky.sky_material = cg_sky_mat
	cg_env.sky = cg_sky
	ArtAtmosphere.apply_lighting(cg_sun, cg_bounce, cg_env, "siang", "hujan")
	_assert_true(cg_env.adjustment_saturation <= 1.16, "rainy saturation slightly tempered")
	ArtAtmosphere.apply_lighting(cg_sun, cg_bounce, cg_env, "siang", "cerah")
	_assert_true(cg_env.adjustment_enabled, "color adjustment enabled on Environment")
	_assert_true(cg_env.adjustment_saturation >= 1.20, "sunny siang resets & boosts saturation >= 1.20")
	_assert_true(cg_env.ambient_light_energy >= 0.34 and cg_env.ambient_light_energy <= 0.48, "ambient energy stays warm & balanced (0.34..0.48)")
	_assert_true(cg_bounce.light_energy >= 0.28 and cg_bounce.light_energy <= 0.45, "bounce light warm & lifts shadows (0.28..0.45)")
	_assert_true(cg_sky_mat.sky_top_color.b > 0.85, "sunny sky top color vibrant tropical blue")
	cg_sun.free()
	cg_bounce.free()

	# 26. Indonesian Life Rhythm: Clock, Sleep Recharge, Prayer Times, Ramadhan & THR
	_assert_eq(ArtLifeRhythm.format_clock(450), "07:30", "clock formats 450 min as 07:30")
	_assert_eq(ArtLifeRhythm.get_phase_from_minutes(450), "pagi", "07:30 is pagi")
	_assert_eq(ArtLifeRhythm.get_phase_from_minutes(720), "siang", "12:00 is siang")
	_assert_eq(ArtLifeRhythm.get_phase_from_minutes(930), "sore", "15:30 is sore")
	_assert_eq(ArtLifeRhythm.get_phase_from_minutes(1140), "malam", "19:00 is malam")
	_assert_eq(ArtLifeRhythm.get_season(9), "biasa", "day 9 is biasa")
	_assert_eq(ArtLifeRhythm.get_season(10), "ramadhan", "day 10 is ramadhan")
	_assert_eq(ArtLifeRhythm.get_season(16), "lebaran", "day 16 is lebaran")

	var sh_low_e := ChoreEngine.create_shift("kamar_kos", MajikanProfiles.get_profile("ibu_kos_melati"), 100, 42)
	_assert_eq(int(sh_low_e["energy"]), 42, "4-arg create_shift uses persistent initial_energy")
	var sv_sl := Progression.create_player_save()
	sv_sl["energy"] = 30
	sv_sl["mood"] = 50
	sv_sl["day"] = 1
	var sh_sl := ChoreEngine.create_shift("kamar_kos", MajikanProfiles.get_profile("ibu_kos_melati"), 100, 30)
	sh_sl = ChoreEngine.complete_chore(sh_sl, "make_bed", 0.85, 1)["shift"]
	var res_sl := Progression.settle_shift(sv_sl, sh_sl, MajikanCall.create_state(MajikanProfiles.get_profile("ibu_kos_melati")))
	_assert_true(int(res_sl["save"]["energy"]) < 30, "settle_shift persists drained energy")
	_assert_eq(bool(res_sl["save"]["worked_since_sleep"]), true, "settle_shift marks worked_since_sleep")
	var sl_after_work := ArtLifeRhythm.sleep_in_bed(res_sl["save"], [])
	_assert_eq(int(sl_after_work["save"]["energy"]), 100, "sleep_in_bed recharges energy to 100")
	_assert_eq(int(sl_after_work["save"]["day"]), 2, "sleep after shift does not double-increment day")
	_assert_eq(bool(sl_after_work["save"]["worked_since_sleep"]), false, "sleep clears worked_since_sleep")
	var sl_rest_only := ArtLifeRhythm.sleep_in_bed(sl_after_work["save"], [])
	_assert_eq(int(sl_rest_only["save"]["day"]), 3, "rest-only sleep advances day by 1")

	var sv_ram := Progression.create_player_save()
	sv_ram["day"] = 10
	sv_ram["balance_rp"] = 30000
	var sh_ram := ChoreEngine.create_shift("kamar_kos", MajikanProfiles.get_profile("ibu_kos_melati"), 100)
	sh_ram = ChoreEngine.complete_chore(sh_ram, "make_bed", 0.85, 1)["shift"]
	var res_ram := Progression.settle_shift(sv_ram, sh_ram, MajikanCall.create_state(MajikanProfiles.get_profile("ibu_kos_melati")))
	_assert_eq(int(res_ram["meal_cost_rp"]), 0, "Ramadhan daytime waives lunch meal sink")

	var sv_pr := Progression.create_player_save()
	sv_pr["day"] = 10
	sv_pr["energy"] = 50
	sv_pr["mood"] = 60
	sv_pr["game_minutes"] = 1080
	var pr1 := ArtLifeRhythm.perform_prayer(sv_pr, "maghrib", 10)
	_assert_eq(bool(pr1["ok"]), true, "first maghrib prayer succeeds")
	_assert_eq(int(pr1["save"]["mood"]), 87, "ramadhan maghrib prayer + buka puasa boosts mood (+12 + 15)")
	_assert_eq(int(pr1["save"]["energy"]), 70, "ramadhan maghrib grants +20 takjil energy once")
	var pr_dup := ArtLifeRhythm.perform_prayer(pr1["save"], "maghrib", 10)
	_assert_eq(bool(pr_dup["ok"]), false, "same prayer cannot be farmed twice same day")
	var tak_dup := ArtLifeRhythm.claim_takjil(pr1["save"], 10)
	_assert_eq(bool(tak_dup["ok"]), false, "cannot double-dip takjil after ramadhan maghrib")

	var sv_thr := Progression.create_player_save()
	sv_thr["day"] = 16
	sv_thr["balance_rp"] = 10000
	var thr1 := ArtLifeRhythm.claim_thr_if_eligible(sv_thr)
	_assert_eq(bool(thr1["ok"]), true, "Day 16 Lebaran grants THR bonus")
	_assert_eq(int(thr1["bonus_rp"]), 150000, "kamar_kos THR is Rp 150,000")
	var thr_dup := ArtLifeRhythm.claim_thr_if_eligible(thr1["save"])
	_assert_eq(bool(thr_dup["ok"]), false, "THR cannot be claimed twice in same cycle")

	var sv_lr_rt := SaveStore.deserialize('{"thr_claimed_cycle": -1, "game_minutes": 9999, "energy": -5}')
	_assert_eq(int(sv_lr_rt["thr_claimed_cycle"]), -1, "SaveStore preserves signed thr_claimed_cycle == -1")
	_assert_eq(int(sv_lr_rt["game_minutes"]), 1439, "SaveStore clamps game_minutes 0..1439")
	_assert_eq(int(sv_lr_rt["energy"]), 0, "SaveStore clamps energy >= 0")

	# 27. Warung-Life Warm OmniLight3D Pools
	var rl_day: Array = ArtAtmosphere.get_room_lights_config("siang")
	var rl_night: Array = ArtAtmosphere.get_room_lights_config("malam")
	_assert_eq(rl_day.size(), 2, "room has 2 warm OmniLight3D pools")
	_assert_true(float(rl_night[0]["energy"]) > float(rl_day[0]["energy"]), "room lamp warms up at night")
	var sl_day: Array = ArtAtmosphere.get_street_lights_config("siang")
	var sl_night: Array = ArtAtmosphere.get_street_lights_config("malam")
	_assert_true(sl_night.size() <= 3 and sl_night.size() >= 2, "street light pool count <= 3 for mobile perf")
	_assert_true(float(sl_night[0]["energy"]) > float(sl_day[0]["energy"]), "streetlamp glow ramps up at night")

	# 28. Smooth HD Visuals: Character Rim Polish + Idempotent Contact Shadow
	var sv_char := Node3D.new()
	var sv_mi := MeshInstance3D.new()
	var sv_box := BoxMesh.new()
	var sv_mat := StandardMaterial3D.new()
	sv_mat.albedo_color = Color(0.2, 0.7, 0.4)
	sv_box.material = sv_mat
	sv_mi.mesh = sv_box
	sv_char.add_child(sv_mi)
	ArtSceneVisuals.apply_character_polish(sv_char)
	var polished_mat := sv_mi.get_active_material(0) as StandardMaterial3D
	_assert_true(polished_mat != null and polished_mat.rim_enabled, "apply_character_polish enables subtle rim light")
	_assert_true(polished_mat != null and polished_mat.rim <= 0.08 and polished_mat.roughness >= 0.72, "character polish keeps rim subtle (<=0.08) and matte roughness (>=0.72)")
	ArtSceneVisuals.attach_contact_shadow(sv_char, 0.38)
	ArtSceneVisuals.attach_contact_shadow(sv_char, 0.38)
	var cs_count := 0
	for ch in sv_char.get_children():
		if ch.name == "_ContactShadow":
			cs_count += 1
	_assert_eq(cs_count, 1, "attach_contact_shadow is idempotent (exactly 1 _ContactShadow)")
	var cs_node := sv_char.find_child("_ContactShadow", false, false) as MeshInstance3D
	_assert_true(cs_node != null and cs_node.position.y >= 0.025, "contact shadow sits at y >= 0.025 above rugs")
	_assert_eq(cs_node.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "contact shadow does not cast directional shadow")
	sv_char.free()

	# 29. Unique NPC Cast (no duplicate model_path, no Player char_art reuse) + Lightmap UV2 binding
	var expected_chars := [
		"res://assets/models/char_art.glb",
		"res://assets/models/char_art_hijab.glb",
		"res://assets/models/char_art_pro.glb",
		"res://assets/models/char_art_elite.glb",
		"res://assets/models/char_ibu.glb",
		"res://assets/models/char_kakak.glb",
		"res://assets/models/char_budi.glb",
		"res://assets/models/char_dewi.glb",
		"res://assets/models/char_pak_rt.glb",
		"res://assets/models/char_ojek.glb",
		"res://assets/models/char_kurir.glb",
		"res://assets/models/char_pelajar.glb",
		"res://assets/models/char_hendra.glb",
		"res://assets/models/char_rina.glb",
		"res://assets/models/char_agus.glb",
	]
	for cp in expected_chars:
		_assert_true(ResourceLoader.exists(cp), "character model exists: " + cp)
	for tier_k in ["kos", "kampung", "perumahan_36", "perumahan_45", "cluster_elite"]:
		var st_npcs: Array = ArtNpcRoster.get_street_config(tier_k).get("street_npcs", [])
		var seen_st := {}
		for n in st_npcs:
			var mp := String(n.get("model_path", ""))
			_assert_true(mp != "res://assets/models/char_art.glb", tier_k + " street NPC must not reuse player green daster: " + mp)
			_assert_true(not seen_st.has(mp), tier_k + " street NPC model_path must be unique: " + mp)
			seen_st[mp] = true
		var sh_npcs: Array = ArtNpcRoster.get_shift_npcs(tier_k)
		var seen_sh := {}
		for n in sh_npcs:
			var mp := String(n.get("model_path", ""))
			_assert_true(mp != "res://assets/models/char_art.glb", tier_k + " shift NPC must not reuse player green daster: " + mp)
			_assert_true(not seen_sh.has(mp), tier_k + " shift NPC model_path must be unique: " + mp)
			seen_sh[mp] = true
	var lm_root := Node3D.new()
	var lm_no_uv2 := MeshInstance3D.new()
	var lm_box := BoxMesh.new()
	lm_box.material = StandardMaterial3D.new()
	lm_no_uv2.mesh = lm_box
	lm_root.add_child(lm_no_uv2)
	var lm_with_uv2 := MeshInstance3D.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
	arr[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, StandardMaterial3D.new())
	lm_with_uv2.mesh = am
	lm_root.add_child(lm_with_uv2)
	var lm_img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	lm_img.fill(Color(0.8, 0.78, 0.75, 1.0))
	var lm_tex := ImageTexture.create_from_image(lm_img)
	ArtSceneVisuals.apply_lightmap(lm_root, lm_tex)
	var m_no := lm_no_uv2.get_active_material(0) as StandardMaterial3D
	var m_yes := lm_with_uv2.get_active_material(0) as StandardMaterial3D
	_assert_true(m_no != null and not m_no.detail_enabled, "apply_lightmap skips meshes without UV2")
	_assert_true(m_yes != null and m_yes.detail_enabled, "apply_lightmap enables detail on meshes with UV2")
	_assert_eq(m_yes.detail_uv_layer, BaseMaterial3D.DETAIL_UV_2, "apply_lightmap binds DETAIL_UV_2")
	_assert_eq(m_yes.detail_blend_mode, BaseMaterial3D.BLEND_MODE_MUL, "apply_lightmap uses BLEND_MODE_MUL")
	lm_root.free()

	# 30. Real Human MakeHuman Cast + High-Contrast GI + Clean World (v2 Overhaul)
	_assert_true(ResourceLoader.exists("res://assets/lightmaps/kampung_gang_lightmap.png"), "kampung_gang_lightmap.png exists in non-excluded lightmaps dir")
	_assert_true(ResourceLoader.exists("res://assets/lightmaps/kos_room_lightmap.png"), "kos_room_lightmap.png exists in non-excluded lightmaps dir")
	var ep_txt := FileAccess.get_file_as_string("res://export_presets.cfg")
	_assert_true(not ("assets/lightmaps" in ep_txt), "export_presets.cfg does not exclude assets/lightmaps/")
	var gang_ps := load("res://assets/models/kampung_gang.glb") as PackedScene
	if gang_ps != null:
		var gang_inst := gang_ps.instantiate()
		var uv2_count := 0
		var st_stack := [gang_inst]
		while st_stack.size() > 0:
			var sn = st_stack.pop_back()
			if sn is MeshInstance3D and sn.mesh is ArrayMesh:
				for s in range(sn.mesh.get_surface_count()):
					if (sn.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_TEX_UV2) != 0:
						uv2_count += 1
			for c in sn.get_children():
				st_stack.append(c)
		_assert_true(uv2_count >= 10, "kampung_gang.glb exports UV2 TEXCOORD_1 on architectural meshes (got %d)" % uv2_count)
		gang_inst.free()
	var kos_lm_img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/lightmaps/kos_room_lightmap.png"))
	if kos_lm_img != null:
		var min_l := 1.0
		var max_l := 0.0
		for py in range(0, kos_lm_img.get_height(), 8):
			for px in range(0, kos_lm_img.get_width(), 8):
				var col := kos_lm_img.get_pixel(px, py)
				var lum := col.get_luminance()
				if lum < min_l:
					min_l = lum
				if lum > max_l:
					max_l = lum
		_assert_true(min_l <= 0.44 and (max_l - min_l) >= 0.45, "kos_room_lightmap has rich GI contrast (min=%.2f max=%.2f)" % [min_l, max_l])
	var art_ps := load("res://assets/models/char_art.glb") as PackedScene
	if art_ps != null:
		var art_inst := art_ps.instantiate()
		_assert_true(art_inst.find_child("Mannequin_F", true, false) == null, "char_art replaced old Mannequin_F dummy")
		var ap_art := art_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_assert_true(ap_art != null, "char_art has AnimationPlayer")
		if ap_art != null:
			var anim_str := ",".join(ap_art.get_animation_list()).to_lower()
			_assert_true("idle" in anim_str and "walk" in anim_str, "char_art has idle and walk clips")
			_assert_true(("fixing" in anim_str or "clean" in anim_str) and ("celebrat" in anim_str or "jump" in anim_str), "char_art has clean and celebrate clips")
		art_inst.free()
	var hs_test := preload("res://src/scenes/chore_hotspot.gd").new()
	hs_test.setup("sweep", "Sapu", "Sweep", Vector3.ZERO)
	var hs_ring := hs_test.get_child(0) as MeshInstance3D
	_assert_true(hs_ring != null and hs_ring.mesh is CylinderMesh, "chore_hotspot uses flat subtle CylinderMesh pad instead of neon TorusMesh")
	hs_test.free()

	# 31. Full-Game GI Lightmaps (all 10 stages) + App Icon + iOS CI
	var gi_stages := [
		"kos_room",
		"kampung_gang",
		"kampung_street",
		"cluster_elite_street",
		"kos_neighbor_room",
		"room_kampung_house",
		"room_majikan_living",
		"room_elite_living",
		"kamar_art_small",
		"kamar_art_large",
	]
	for st_name in gi_stages:
		var lm_p := "res://assets/lightmaps/%s_lightmap.png" % st_name
		_assert_true(ResourceLoader.exists(lm_p), "lightmap exists for stage: " + st_name)
		var st_ps := load("res://assets/models/%s.glb" % st_name) as PackedScene
		_assert_true(st_ps != null, "stage glb loads: " + st_name)
		if st_ps != null:
			var st_inst := st_ps.instantiate()
			var st_uv2 := 0
			var st_q := [st_inst]
			while st_q.size() > 0:
				var nd = st_q.pop_back()
				if nd is MeshInstance3D and nd.mesh is ArrayMesh:
					for s in range(nd.mesh.get_surface_count()):
						if (nd.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_TEX_UV2) != 0:
							st_uv2 += 1
				for ch in nd.get_children():
					st_q.append(ch)
			_assert_true(st_uv2 >= 5, "%s exports UV2 TEXCOORD_1 (>=5 surfaces, got %d)" % [st_name, st_uv2])
			st_inst.free()
		var abs_lm := ProjectSettings.globalize_path(lm_p)
		if FileAccess.file_exists(abs_lm):
			var lmi := Image.load_from_file(abs_lm)
			if lmi != null:
				var mn := 1.0
				var mx := 0.0
				for py in range(0, lmi.get_height(), 16):
					for px in range(0, lmi.get_width(), 16):
						var lv := lmi.get_pixel(px, py).get_luminance()
						mn = minf(mn, lv)
						mx = maxf(mx, lv)
				_assert_true(mn >= 0.25 and (mx - mn) >= 0.28, "%s lightmap contrast valid (min=%.2f max=%.2f)" % [st_name, mn, mx])

	_assert_true(String(ProjectSettings.get_setting("application/config/icon", "")) == "res://assets/icon.png", "project.godot sets application/config/icon")
	_assert_true(ResourceLoader.exists("res://assets/icon.png"), "res://assets/icon.png exists for Android/iOS/PWA")
	_assert_true("platform=\"iOS\"" in ep_txt, "export_presets.cfg includes iOS export preset")
	_assert_true(FileAccess.file_exists(ProjectSettings.globalize_path("res://../.github/workflows/ios-build.yml")), "iOS macOS GitHub workflow exists")

	# 32. Production HD Visual Core (AgX, RID-Cached Unified Pass, Layer-0 Sharpen, Atmosphere Sync)
	_assert_true(ResourceLoader.exists("res://shaders/hd_detail.gdshader"), "hd_detail.gdshader exists")
	_assert_true(ResourceLoader.exists("res://shaders/hd_sharpen.gdshader"), "hd_sharpen.gdshader exists")
	var hd_detail_sh := load("res://shaders/hd_detail.gdshader") as Shader
	var hd_sharp_sh := load("res://shaders/hd_sharpen.gdshader") as Shader
	_assert_true(hd_detail_sh != null and hd_sharp_sh != null, "HD production shaders load")

	var cache_test := {}
	var shared_mat := StandardMaterial3D.new()
	shared_mat.resource_name = "FloorTile"
	var m1 := MeshInstance3D.new()
	var m2 := MeshInstance3D.new()
	var arr_lm := []
	arr_lm.resize(Mesh.ARRAY_MAX)
	arr_lm[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD])
	arr_lm[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
	arr_lm[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
	arr_lm[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
	var am_lm := ArrayMesh.new()
	am_lm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr_lm)
	am_lm.surface_set_material(0, shared_mat)
	m1.name = "FloorSlab"
	m1.mesh = am_lm
	m2.name = "FloorTrim"
	m2.mesh = am_lm
	var test_root := Node3D.new()
	test_root.add_child(m1)
	test_root.add_child(m2)
	var ol_mat := ArtSceneVisuals.ensure_detail_outline_material()
	_assert_true(ol_mat != null, "ensure_detail_outline_material returns ShaderMaterial")
	var lm_u_img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	lm_u_img.fill(Color(0.8, 0.78, 0.75, 1.0))
	var lm_u_tex := ImageTexture.create_from_image(lm_u_img)
	ArtSceneVisuals.apply_unified_material_pass(test_root, true, false, ol_mat, cache_test, lm_u_tex, true)
	var ov1 := m1.get_surface_override_material(0) as StandardMaterial3D
	var ov2 := m2.get_surface_override_material(0) as StandardMaterial3D
	_assert_true(ov1 != null and ov1 == ov2, "RID material cache shares override across matching surfaces")
	_assert_true(absf(ov1.roughness - 0.56) < 0.01 and ov1.metallic_specular <= 0.26, "floor tile gets satin 0.56 roughness without harsh glare hotspot")
	_assert_true(ov1.detail_enabled and ov1.detail_albedo == lm_u_tex, "unified pass folds UV2 lightmap cleanly")
	_assert_true(ov1.vertex_color_use_as_albedo, "unified pass folds COLOR_0 AO cleanly")
	test_root.free()

	var mg_ps := load("res://scenes/main_game.tscn") as PackedScene
	_assert_true(mg_ps != null, "main_game.tscn loads")
	if mg_ps != null:
		var mg_inst := mg_ps.instantiate()
		var wenv := mg_inst.find_child("WorldEnvironment", true, false) as WorldEnvironment
		var sunl := mg_inst.find_child("SunLight", true, false) as DirectionalLight3D
		var sp_layer := mg_inst.find_child("SharpenPost", true, false) as CanvasLayer
		var hud_layer := mg_inst.find_child("HUD", true, false) as CanvasLayer
		_assert_true(wenv != null and wenv.environment.tonemap_mode == Environment.TONE_MAPPER_AGX, "main_game uses AgX tonemapper")
		_assert_true(wenv != null and wenv.environment.glow_bloom <= 0.08, "main_game keeps bloom subtle (<= 0.08)")
		_assert_true(sunl != null and sunl.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL, "main_game uses tight orthogonal shadow map")
		_assert_true(sp_layer != null and hud_layer != null and sp_layer.layer == 0 and sp_layer.layer < hud_layer.layer, "SharpenPost sits on layer 0 below HUD")
		mg_inst.free()

	_assert_true("MagicComBody" in ArtAtmosphere.RICE_COOKER_NODES, "Atmosphere RICE_COOKER_NODES covers Formula 2 MagicComBody")
	_assert_true("FanHubBadge" in ArtAtmosphere.FAN_NODES, "Atmosphere FAN_NODES covers Formula 2 FanHubBadge")

	# 33. Formula 1 Cast Rollout (15 Characters: Casual Walk Posture, Sculpted Hair, Zero Sphere Caps, Vert Budget)
	var hero_chars := ["char_art", "char_art_hijab", "char_art_pro", "char_art_elite"]
	var npc_chars := ["char_ibu", "char_kakak", "char_budi", "char_dewi", "char_pak_rt", "char_ojek", "char_kurir", "char_pelajar", "char_hendra", "char_rina", "char_agus"]
	for cname in hero_chars + npc_chars:
		var c_ps := load("res://assets/models/%s.glb" % cname) as PackedScene
		_assert_true(c_ps != null, "character loads: " + cname)
		if c_ps != null:
			var ci := c_ps.instantiate()
			var split_verts := 0
			var has_sphere_cap := false
			var cq := [ci]
			while cq.size() > 0:
				var cnode = cq.pop_back()
				if cnode is MeshInstance3D:
					var cmi := cnode as MeshInstance3D
					var nm := cmi.name.to_lower()
					if "haircap" in nm or "ponytailcap" in nm or "cepolbun" in nm:
						has_sphere_cap = true
					if cmi.mesh != null:
						for s in range(cmi.mesh.get_surface_count()):
							split_verts += cmi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size()
				for ch in cnode.get_children():
					cq.append(ch)
			var cap_limit := 14500 if (cname in hero_chars) else 10500
			_assert_true(split_verts <= cap_limit, "%s split verts (%d) <= %d" % [cname, split_verts, cap_limit])
			if cname in ["char_art", "char_art_pro", "char_art_elite", "char_dewi", "char_pelajar"]:
				_assert_true(not has_sphere_cap, "%s replaces sphere HairCap with sculpted hair" % cname)
			ci.free()

	var walk_ps := load("res://assets/models/char_art.glb") as PackedScene
	if walk_ps != null:
		var wi := walk_ps.instantiate()
		root.add_child(wi)
		var wap := wi.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var wskel := wi.find_child("Skeleton3D", true, false) as Skeleton3D
		_assert_true(wap != null and wskel != null, "char_art has AnimationPlayer + Skeleton3D")
		if wap != null and wskel != null:
			var w_clip := ""
			for aname in wap.get_animation_list():
				if aname.to_lower() == "walk" or aname.to_lower().begins_with("walk_"):
					w_clip = aname
					break
			_assert_true(w_clip != "", "char_art has Walk clip")
			if w_clip != "":
				wap.play(w_clip)
				wap.seek(0.25, true)
				wap.advance(0.0)
				var b_sp := wskel.find_bone("spine_01")
				var b_nk := wskel.find_bone("neck_01")
				var b_la := wskel.find_bone("lowerarm_l")
				var b_ra := wskel.find_bone("lowerarm_r")
				_assert_true(b_sp >= 0 and b_nk >= 0 and b_la >= 0 and b_ra >= 0, "char_art skeleton has spine/neck/lowerarm bones")
				if b_sp >= 0 and b_nk >= 0 and b_la >= 0 and b_ra >= 0:
					var sp_deg := rad_to_deg(wskel.get_bone_pose_rotation(b_sp).get_angle())
					var nk_deg := rad_to_deg(wskel.get_bone_pose_rotation(b_nk).get_angle())
					var la_deg := rad_to_deg(wskel.get_bone_pose_rotation(b_la).get_angle())
					var ra_deg := rad_to_deg(wskel.get_bone_pose_rotation(b_ra).get_angle())
					_assert_true(sp_deg < 10.0 and nk_deg < 10.0, "char_art Walk upright spine/neck (<10 deg, got %.1f/%.1f)" % [sp_deg, nk_deg])
					_assert_true(la_deg < 40.0 and ra_deg < 40.0, "char_art Walk relaxed elbows (<40 deg, got %.1f/%.1f)" % [la_deg, ra_deg])
		root.remove_child(wi)
		wi.free()

	# 34. Reactive Dialogue, Story Milestones & Chore Juice
	var g_rain_id: String = Neighborhood.get_reactive_greeting("bang_ojek", "kamar_kos", "pagi", "hujan", "id")
	var g_rain_en: String = Neighborhood.get_reactive_greeting("bang_ojek", "kamar_kos", "pagi", "hujan", "en")
	var g_sun_id: String = Neighborhood.get_reactive_greeting("bang_ojek", "kamar_kos", "pagi", "cerah", "id")
	_assert_true(g_rain_id != "" and g_rain_id != g_sun_id and ("hujan" in g_rain_id.to_lower()), "Bang Ojek reacts to rain in Indonesian")
	_assert_true(g_rain_en != "" and ("rain" in g_rain_en.to_lower()) and not ("hujan" in g_rain_en.to_lower()), "Bang Ojek reacts to rain in English without ID leak")

	var g_elite_id: String = Neighborhood.get_reactive_greeting("pak_rt", "cluster_elite", "siang", "cerah", "id")
	var g_kos_id: String = Neighborhood.get_reactive_greeting("pak_rt", "kamar_kos", "siang", "cerah", "id")
	_assert_true(g_elite_id != g_kos_id and ("elite" in g_elite_id.to_lower()), "Pak RT reacts to Cluster Elite career growth")

	var g_night_id: String = Neighborhood.get_reactive_greeting("mbak_dewi", "kamar_kos", "malam", "cerah", "id")
	var g_day_id: String = Neighborhood.get_reactive_greeting("mbak_dewi", "kamar_kos", "pagi", "cerah", "id")
	_assert_true(g_night_id != g_day_id, "Mbak Dewi reacts to malam/night phase")

	for t_dict in CareerTiers.TIERS:
		var tid := String(t_dict["id"])
		var q_id: String = ArtWishlistStory.get_tier_milestone_quote(tid, "id")
		var q_en: String = ArtWishlistStory.get_tier_milestone_quote(tid, "en")
		_assert_true(q_id.length() > 15 and q_en.length() > 15 and q_id != q_en, "Milestone quote localized for " + tid)

	var mg_txt := FileAccess.get_file_as_string("res://src/scenes/main_game.gd")
	_assert_true("get_reactive_greeting" in mg_txt, "main_game uses ArtNeighborhood.get_reactive_greeting")
	_assert_true("_cam_punch" in mg_txt, "main_game includes chore completion micro-camera punch")
	var elite_npcs: Array = NpcRoster.get_shift_npcs("cluster_elite")
	for enpc in elite_npcs:
		if String(enpc.get("id", "")) == "kakak_nadine":
			var npos: Vector3 = enpc.get("pos", Vector3.ZERO)
			_assert_true(npos.x < 0.0, "Kakak Nadine spawns clear of cluster_elite marble kitchen island")

	# 35. Round-1 Core: Multi-Slot Save, Remittance Deadline, Cutscenes, Guides, Supply Cart, Kasbon & Spotlights
	_assert_eq(SaveStore.SLOT_COUNT, 3, "SaveStore exposes 3 save slots")
	_assert_eq(SaveStore.get_slot_path(1), SaveStore.DEFAULT_PATH, "Slot 1 mirrors DEFAULT_PATH for backward compatibility")
	_assert_eq(SaveStore.get_slot_path(99), SaveStore.get_slot_path(3), "Out-of-range slot clamps to slot 3")
	var mig_sv := SaveStore.sanitize({"completed_shifts": 2})
	_assert_true(bool(mig_sv.get("guide_seen", false)), "Returning players with completed_shifts > 0 skip guide_seen")
	var slot_sv := Progression.create_player_save()
	slot_sv["player_name"] = "Mbak Uji"
	slot_sv["balance_rp"] = 95000
	_assert_true(SaveStore.save_to_slot(slot_sv, 2), "save_to_slot(2) succeeds")
	var loaded_s2 := SaveStore.load_from_slot(2)
	_assert_eq(String(loaded_s2.get("player_name", "")), "Mbak Uji", "load_from_slot(2) restores slot data")
	_assert_true(SaveStore.list_save_slots("id").size() == 3, "list_save_slots returns 3 slot summaries")
	SaveStore.delete_slot(2)

	# Remittance goal & exploit guards
	var rem_sv := Progression.create_player_save()
	rem_sv["balance_rp"] = 200000
	var r_neg := ArtWishlistStory.send_remittance(rem_sv, -50000)
	_assert_true(not bool(r_neg["ok"]), "send_remittance rejects negative amount")
	var r_over := ArtWishlistStory.send_remittance(rem_sv, 250000)
	_assert_true(not bool(r_over["ok"]), "send_remittance rejects > balance_rp")
	var r_part := ArtWishlistStory.send_remittance(rem_sv, 50000)
	_assert_true(bool(r_part["ok"]), "send_remittance accepts partial 50k transfer")
	rem_sv = r_part["save"]
	_assert_eq(int(rem_sv["balance_rp"]), 150000, "partial remittance deducts balance")
	_assert_eq(int(rem_sv["remittance_sent_rp"]), 50000, "partial remittance increments sent_rp")
	var r_done := ArtWishlistStory.send_remittance(rem_sv, 100000)
	_assert_true(bool(r_done["ok"]) and bool(r_done["goal_completed"]), "completing 150k triggers goal_completed")
	rem_sv = r_done["save"]
	_assert_true("kirim_kampung" in rem_sv["unlocked_wishlist"], "150k remittance unlocks kirim_kampung once")
	var xp_after_rem := int(rem_sv["xp"])
	var r_repeat := ArtWishlistStory.send_remittance(rem_sv, 10000)
	_assert_true(not bool(r_repeat["ok"]) and int(rem_sv["xp"]) == xp_after_rem, "repeat remittance after goal completed cannot farm XP")
	var rem_stat_id := ArtWishlistStory.get_remittance_goal_status(rem_sv, "id")
	_assert_true(bool(rem_stat_id["completed"]) and int(rem_stat_id["deadline_day"]) == 10, "remittance status tracks deadline_day=10")

	# Intro cutscene beats & Panduan 1/2 guides (clean ID/EN)
	var beats_id := ArtWishlistStory.get_intro_cutscene_beats("Sari", "id")
	var beats_en := ArtWishlistStory.get_intro_cutscene_beats("Sari", "en")
	_assert_eq(beats_id.size(), 3, "Intro cutscene has 3 Indonesian beats")
	_assert_eq(beats_en.size(), 3, "Intro cutscene has 3 English beats")
	_assert_true(bool(beats_id[0].get("phone", false)) and String(beats_id[0].get("speaker_id", "")) == "ibu_kampung", "Beat 0 frames incoming phone call from Ibu di Kampung")
	_assert_true(String(beats_id[0]["text"]) != String(beats_en[0]["text"]), "Intro beats localized cleanly")
	var guides_id := ArtWishlistStory.get_onboarding_guides(Progression.create_player_save(), "id")
	var guides_en := ArtWishlistStory.get_onboarding_guides(Progression.create_player_save(), "en")
	_assert_eq(guides_id.size(), 2, "Onboarding exposes 2 visual guide cards")
	_assert_true(String(guides_id[0]["title"]) != String(guides_en[0]["title"]), "Guide titles localized cleanly")

	# Preview balance, supply cart + courier timer + sleep completion, kasbon debt cap, spotlight steps
	var prev_sv := Progression.create_player_save()
	prev_sv["balance_rp"] = 100000
	var pv := Progression.preview_balance_after(prev_sv, 45000)
	_assert_true(bool(pv["can_afford"]) and int(pv["balance_after"]) == 55000, "preview_balance_after computes exact post-purchase balance")

	var bad_cart := Progression.checkout_supply_cart(prev_sv, {"kopi_tubruk": -2})
	_assert_true(not bool(bad_cart["ok"]), "checkout_supply_cart rejects negative qty exploit")
	var ok_cart := Progression.checkout_supply_cart(prev_sv, {"kopi_tubruk": 1})
	_assert_true(bool(ok_cart["ok"]), "checkout_supply_cart succeeds on valid item")
	prev_sv = ok_cart["save"]
	var oid := String(ok_cart["order_id"])
	_assert_true(int(prev_sv["balance_rp"]) < 100000 and (prev_sv["courier_orders"] as Array).size() == 1, "checkout deducts Rp and queues courier order")
	var early_claim := Progression.claim_courier_delivery(prev_sv, oid)
	_assert_true(not bool(early_claim["ok"]), "cannot claim courier delivery before timer finishes")
	prev_sv = Progression.tick_courier_orders(prev_sv, 20.0)
	var ready_claim := Progression.claim_courier_delivery(prev_sv, oid)
	_assert_true(bool(ready_claim["ok"]) and (ready_claim["save"]["courier_orders"] as Array).is_empty(), "courier claim succeeds once timer=0 and removes order atomically")
	var dbl_claim := Progression.claim_courier_delivery(ready_claim["save"], oid)
	_assert_true(not bool(dbl_claim["ok"]), "double-claim courier delivery rejected")

	# Courier timer auto-completes on sleep
	var sleep_cart: Dictionary = Progression.checkout_supply_cart(ready_claim["save"], {"kopi_tubruk": 1})["save"]
	var slept: Dictionary = ArtLifeRhythm.sleep_in_bed(sleep_cart, [])["save"]
	var slept_orders: Array = slept.get("courier_orders", [])
	_assert_true(slept_orders.size() == 1 and float(slept_orders[0]["remaining_s"]) <= 0.0, "sleep_in_bed finishes pending courier deliveries")

	# Kasbon cap & repayment
	var kb_sv := Progression.create_player_save()
	var kb_neg := Progression.record_kasbon(kb_sv, "Warung Bu Tini", -5000)
	_assert_true(not bool(kb_neg["ok"]), "record_kasbon rejects negative amount")
	var kb_over := Progression.record_kasbon(kb_sv, "Warung Bu Tini", 150000)
	_assert_true(not bool(kb_over["ok"]), "record_kasbon enforces MAX_KASBON_DEBT_RP cap")
	var kb_ok := Progression.record_kasbon(kb_sv, "Warung Bu Tini", 25000)
	_assert_true(bool(kb_ok["ok"]) and int(kb_ok["save"]["balance_rp"]) == 25000, "record_kasbon credits wallet and logs debt")
	var kb_pay := Progression.pay_kasbon(kb_ok["save"], String(kb_ok["debt_id"]))
	_assert_true(bool(kb_pay["ok"]) and int(kb_pay["save"]["balance_rp"]) == 0, "pay_kasbon settles debt cleanly")

	var spots_id := Progression.get_spotlight_tutorial_steps("id")
	var spots_en := Progression.get_spotlight_tutorial_steps("en")
	_assert_eq(spots_id.size(), 4, "4 interactive spotlight steps defined")
	_assert_true(String(spots_id[0]["text"]) != String(spots_en[0]["text"]), "Spotlight steps localized cleanly")

	# 36. High-Res 3D Cycles Bust Portraits & Painterly UI Icons
	for pid in ["player", "ibu_melati", "mbak_dewi", "pak_budi", "ibu_sari", "ibu_citra", "pak_hendra", "pak_rt", "bang_ojek", "kurir_paket", "anak_sekolah", "pak_agus", "kakak_nadine", "kakak_maya", "ibu_tini", "mbak_rina", "adik_bima", "ibu_kampung"]:
		var pt := ArtPortraits.get_portrait(pid, "happy")
		_assert_true(pt != null and pt.get_width() >= 256 and pt.get_height() >= 256, "3D bust portrait >=256px for " + pid)
	var ph_hijab := ArtPortraits.get_player_portrait("#C68B59", "#4E7D63", "hijab", "happy")
	_assert_true(ph_hijab != null and ph_hijab.get_width() >= 256, "Player hijab portrait >=256px")
	for ic in ["icon_phone", "icon_door", "icon_broom", "icon_career", "icon_wardrobe", "icon_upgrade", "app_bank", "app_shop", "app_chat", "app_debt", "app_dreams", "app_story", "app_missions", "app_map", "app_guide", "logo_art_simulator", "star_filled", "star_empty", "icon_hand_pointer", "icon_courier_box"]:
		var u_tex := ArtPortraits.get_ui_icon(ic)
		_assert_true(u_tex != null and u_tex.get_width() >= 32, "UI icon loads cleanly: " + ic)

	# 37. 3D Street Landmarks, Zebra Crossing, Island/Kitchen Clutter & Street Diversity
	var ks_py := FileAccess.get_file_as_string("res://blender/build_kampung_street.py")
	_assert_true("MushollaDome" in ks_py and "MushollaGate" in ks_py, "kampung_street includes Indonesian Musholla landmark")
	_assert_true("ZebraStripe_" in ks_py, "kampung_street includes crisp white zebra crossing")
	var el_py := FileAccess.get_file_as_string("res://blender/build_elite_assets.py")
	_assert_true("IslandTray" in el_py and "IslandTeapot" in el_py and "SpiceJar_" in el_py, "room_elite_living populates kitchen island & counter clutter")
	var mj_py := FileAccess.get_file_as_string("res://blender/build_majikan_interior.py")
	_assert_true("LPG3kg" in mj_py and "WallCalendar" in mj_py, "room_majikan_living includes LPG 3kg canister and wall calendar")
	var kos_st: Array = NpcRoster.get_street_config("kamar_kos").get("street_npcs", [])
	var has_kid := false
	for kn in kos_st:
		if String(kn.get("id", "")) == "anak_sekolah":
			has_kid = true
	_assert_true(has_kid, "kamar_kos street includes anak_sekolah student for sidewalk diversity")

	# 38. Phase 4 UI Overhaul: Title Screen, Illustrated Dock, Dialogue Bar, Spotlight & Smartphone OS
	var mg_src := FileAccess.get_file_as_string("res://src/scenes/main_game.gd")
	_assert_true("_build_title_overlay" in mg_src and "--capture-title=" in mg_src, "main_game has Title Screen overlay + --capture-title flag")
	_assert_true("_make_dock_icon_btn" in mg_src and "icon_broom" in mg_src and "icon_upgrade" in mg_src, "main_game uses illustrated icon dock buttons")
	_assert_true("_dialogue_bar" in mg_src and "get_intro_cutscene_beats" in mg_src, "main_game renders bottom narrative dialogue bar + phone cutscene")
	_assert_true("_open_guide_modal" in mg_src and "get_onboarding_guides" in mg_src, "main_game renders Guide 1/2 Bank Desaku onboarding card")
	_assert_true("_spotlight_wrap" in mg_src and "icon_hand_pointer" in mg_src, "main_game renders interactive spotlight + hand pointer")
	_assert_true("_phone_os_wrap" in mg_src and "preview_balance_after" in mg_src and "send_remittance" in mg_src, "main_game implements Smartphone OS with Bank Desaku, Supply Shop & balance confirmation")
	_assert_true("_courier_toast" in mg_src and "tick_courier_orders" in mg_src, "main_game renders live bottom-left courier delivery timer toast")
	var mg_script := load("res://src/scenes/main_game.gd")
	_assert_true(mg_script != null, "main_game.gd parses cleanly without errors")
	var rem_miss := Progression.create_player_save()
	rem_miss["day"] = 11
	var rem_dl := ArtWishlistStory.check_remittance_deadline(rem_miss)
	_assert_true(bool(rem_dl["penalty_applied"]) and int(rem_dl["save"]["remittance_deadline_day"]) == 16, "check_remittance_deadline applies mood penalty once and extends grace deadline")

	# 39. Round 2 World-Class Parity: Responsive Joystick/Phone, Warm Ground, Matte Characters & Export Hygiene
	_assert_true(not ArtAtmosphere.should_show_virtual_joystick(Vector2(1280, 720), false, false), "desktop 1280x720 hides virtual joystick")
	_assert_true(not ArtAtmosphere.should_show_virtual_joystick(Vector2(1280, 720), true, false), "touch-laptop at 1280x720 does not show virtual joystick")
	_assert_true(ArtAtmosphere.should_show_virtual_joystick(Vector2(780, 437), true, true), "mobile 780x437 shows virtual joystick")
	_assert_eq(Progression.get_phone_layout_mode(Vector2(780, 437)), "landscape", "780x437 uses landscape Smartphone OS layout")
	_assert_eq(Progression.get_phone_layout_mode(Vector2(1280, 720)), "portrait", "1280x720 uses portrait Smartphone OS layout")

	var char_root := Node3D.new()
	var char_mesh := MeshInstance3D.new()
	char_mesh.name = "BodySkin"
	char_mesh.mesh = BoxMesh.new()
	var cmat := StandardMaterial3D.new()
	cmat.resource_name = "SkinMat"
	cmat.roughness = 0.40
	char_mesh.mesh.surface_set_material(0, cmat)
	char_root.add_child(char_mesh)
	var c_cache := {}
	ArtSceneVisuals.apply_unified_material_pass(char_root, false, false, ol_mat, c_cache)
	var cov := char_mesh.get_surface_override_material(0) as StandardMaterial3D
	_assert_true(cov != null and cov.next_pass == null, "characters do not get harsh cel-outline next_pass")
	_assert_true(cov != null and cov.roughness >= 0.70 and cov.metallic_specular <= 0.28, "character skin gets soft matte roughness without plastic glare")
	char_root.free()

	var tscn_txt := FileAccess.get_file_as_string("res://scenes/main_game.tscn")
	_assert_true("ground_bottom_color = Color(0.11, 0.10, 0.12" in tscn_txt, "main_game.tscn ground_bottom_color uses warm dark studio charcoal instead of green void")
	_assert_true("shadow_opacity = 0.68" in tscn_txt, "SunLight uses softer cozy shadow_opacity = 0.68")

	var ep_txt2 := FileAccess.get_file_as_string("res://export_presets.cfg")
	_assert_true("assets/portraits/_raw/*" in ep_txt2, "export_presets.cfg excludes intermediate _raw portrait renders")

	_assert_true("should_show_virtual_joystick" in mg_src and "get_phone_layout_mode" in mg_src, "main_game wires responsive joystick and Smartphone OS layout")
	_assert_true("_hp_bottom_left" in mg_src and "apply_unified_material_pass(player, false, false" in mg_src, "main_game places HP bottom-left and disables harsh character outline")

	# 40. Mobile Touch Prompts (Zero [E] on Touch), Tappable World Prompt, Friendly Color Labels & Modal Wrapping
	_assert_true(not ArtAtmosphere.should_show_keyboard_hints(Vector2(780, 437), true, true), "mobile 780x437 hides keyboard [E] hints")
	_assert_true(not ArtAtmosphere.should_show_keyboard_hints(Vector2(900, 600), true, false), "narrow touch screen hides keyboard [E] hints")
	_assert_true(ArtAtmosphere.should_show_keyboard_hints(Vector2(1280, 720), false, false), "desktop 1280x720 shows keyboard [E] hints")
	_assert_eq(ArtAtmosphere.format_action_prompt("Keluar Kamar", "id", true), "[E] Keluar Kamar", "desktop prompt keeps [E] shortcut")
	_assert_eq(ArtAtmosphere.format_action_prompt("Keluar Kamar", "id", false), "Ketuk: Keluar Kamar", "mobile ID prompt says Ketuk without [E]")
	_assert_eq(ArtAtmosphere.format_action_prompt("Step Outside", "en", false), "Tap: Step Outside", "mobile EN prompt says Tap without [E]")
	_assert_true(not ("[E]" in ArtAtmosphere.format_tasks_hint("id", false)), "mobile ID tasks hint has zero [E]")
	_assert_true(not ("[E]" in ArtAtmosphere.format_tasks_hint("en", false)), "mobile EN tasks hint has zero [E]")
	_assert_true("[E]" in ArtAtmosphere.format_tasks_hint("id", true), "desktop tasks hint shows [E]")
	_assert_true(not ("[E]" in ArtWishlistStory.get_tutorial_hint(2, "id", false)), "mobile tutorial step 2 ID omits [E]")
	_assert_true(not ("[E]" in ArtWishlistStory.get_tutorial_hint(2, "en", false)), "mobile tutorial step 2 EN omits [E]")
	_assert_eq(Progression.get_color_label("#4E7D63", "id"), "Hijau Batik", "wardrobe color #4E7D63 maps to Hijau Batik (no raw hex)")
	_assert_eq(Progression.get_color_label("#4E7D63", "en"), "Batik Sage", "wardrobe color #4E7D63 maps to Batik Sage in EN")
	_assert_true("format_action_prompt" in mg_src and "_world_prompt: Button" in mg_src, "main_game makes _world_prompt a tappable Button using format_action_prompt")
	_assert_true("_modal_card" in mg_src and "_modal_scroll" in mg_src and "AUTOWRAP_WORD_SMART" in mg_src, "main_game sizes modal responsively and wraps buttons")

	# 41. Round 4 Asset & Modal/Phone OS Polish: Currency Formatting, Canvas Sizing, Save Delete & Clean Icons
	var r4_save := Progression.create_player_save()
	r4_save["balance_rp"] = 250000
	var r4_guides := ArtWishlistStory.get_onboarding_guides(r4_save, "id")
	_assert_eq(String(r4_guides[0]["card_balance"]), "Rp 250.000", "Guide 1 formats balance with space & thousand dots")
	_assert_true("Rp 0" in String(r4_guides[0]["goal_progress"]) and "Rp 150.000" in String(r4_guides[0]["goal_progress"]), "Guide 1 progress formats Rp 0 of Rp 150.000")
	_assert_true(not ("->" in String(r4_guides[0]["body"])), "Guide 1 avoids raw ASCII -> arrow")
	var r4_guides_en := ArtWishlistStory.get_onboarding_guides(r4_save, "en")
	_assert_true(not ("->" in String(r4_guides_en[0]["body"])), "Guide 1 EN avoids raw ASCII -> arrow")
	_assert_true("_btn_modal_close.text = _t(\"Tutup\", \"Close\")" in mg_src, "main_game uses Tutup/Close instead of Mantap! on modal close button")
	_assert_true("skip_autowrap" in mg_src and "Vector2(96, 44)" in mg_src, "save_slots delete button reserves >=96px width and skips autowrap")
	_assert_true("canvas_sz := get_viewport().get_visible_rect().size" in mg_src, "main_game sizes modals & Phone OS in canvas_items coordinate space")
	_assert_true(not ("Rp25.000" in mg_src), "phone_debt uses formatted currency spacing instead of hardcoded Rp25.000")
	_assert_true(not ("(+Mood)" in mg_src.split("\"Telp Keluarga")[0].substr(max(0, mg_src.find("\"chat\"")))), "phone_chat ID copy uses (+Semangat) without mixed English (+Mood)")
	_assert_true("font_disabled_color" in mg_src and "_fit_modal_scroll_height" in mg_src, "main_game sets high-contrast font_disabled_color and content-fit modal scroll height")
	_assert_true("\"Sholat / Doa (+12 Semangat)\"" in mg_src, "settings prayer button uses Indonesian +12 Semangat without mixed Mood")

	# 42. Round 5 World, 3D Character Material, Sky Horizon, Street Spacing, Umbrella & HUD/Dialogue/Spotlight Polish
	var ws_src := FileAccess.get_file_as_string("res://src/core/wishlist_story.gd")
	_assert_true(not ("Rp150.000" in ws_src), "wishlist_story formats Rp 150.000 with space (no Rp150.000)")

	var r5_env := Environment.new()
	var r5_sky_mat := ProceduralSkyMaterial.new()
	var r5_sky := Sky.new()
	r5_sky.sky_material = r5_sky_mat
	r5_env.sky = r5_sky
	var atmo_inst = ArtAtmosphere.new()
	atmo_inst.call("apply_lighting", null, null, r5_env, "siang", "cerah", "street")
	_assert_true(r5_sky_mat.ground_bottom_color.g > 0.28 and r5_sky_mat.ground_horizon_color.b > 0.40, "street daytime sky sets lush non-black ground/horizon instead of black void")

	var NpcRosterScript = load("res://src/core/npc_roster.gd")
	var kg_cfg: Dictionary = NpcRosterScript.get_street_config("kampung")
	var kg_npcs: Array = kg_cfg.get("street_npcs", [])
	var min_npc_dist := 99.0
	for i in range(kg_npcs.size()):
		for j in range(i + 1, kg_npcs.size()):
			var p1: Vector3 = kg_npcs[i]["pos"]
			var p2: Vector3 = kg_npcs[j]["pos"]
			var d_xz := Vector2(p1.x - p2.x, p1.z - p2.z).length()
			if d_xz < min_npc_dist:
				min_npc_dist = d_xz
	_assert_true(min_npc_dist >= 1.75, "kampung street NPCs spaced >= 1.75m apart to avoid nameplate collisions")

	var sp_src := FileAccess.get_file_as_string("res://src/core/street_patrols.gd")
	_assert_true("Vector3(0.26" in sp_src or "Vector3(-0.26" in sp_src, "rain umbrella offsets handle beside shoulder rather than piercing torso")

	var r5_char := Node3D.new()
	var r5_mi := MeshInstance3D.new()
	var r5_sphere := SphereMesh.new()
	var r5_mat := StandardMaterial3D.new()
	r5_mat.resource_name = "HairBlack"
	r5_mat.roughness = 0.25
	r5_mat.metallic_specular = 0.85
	r5_sphere.material = r5_mat
	r5_mi.mesh = r5_sphere
	r5_char.add_child(r5_mi)
	ArtSceneVisuals.apply_unified_material_pass(r5_char, false, false, null, {})
	var r5_cov: StandardMaterial3D = r5_mi.get_surface_override_material(0) as StandardMaterial3D
	_assert_true(r5_cov != null and r5_cov.roughness >= 0.72 and r5_cov.metallic_specular <= 0.22, "character hair/hat/shoe material pass clamps plastic glare (roughness>=0.72, spec<=0.22)")
	r5_char.free()

	var PortraitsCls = load("res://src/core/portraits.gd")
	_assert_true(PortraitsCls.get_ui_icon("app_chat") != null, "app_chat UI icon loads cleanly for street Ngobrol dock button")
	_assert_true("Atmosphere.apply_lighting(sun_light, bounce_light, env, _cur_phase, _cur_weather, _world_mode)" in mg_src, "main_game passes _world_mode into Atmosphere.apply_lighting")
	_assert_true("Portraits.get_ui_icon(\"app_chat\")" in mg_src, "main_game swaps street action dock icon to app_chat")
	_assert_true("call_deferred(\"_position_spotlight_widgets\")" in mg_src and not ("_spotlight_hand.offset_top =" in mg_src), "main_game defers spotlight positioning and animates _spotlight_hand.position.y without offset_top stretch")
	_assert_true("(_spotlight_wrap != null and _spotlight_wrap.visible)" in mg_src.split("var hide_labels :=")[1].split("\n")[0], "world Label3D hides while spotlight tutorial is visible and restores automatically")
	_assert_true("_call_banner != null and _call_banner.visible" in mg_src.split("func _show_toast")[1].split("func ")[0], "_show_toast suppresses non-urgent overlap when call banner is active")
	_assert_true("spk_row.add_child(_dlg_phone_badge)" in mg_src, "dialogue TELP badge renders inline beside speaker name instead of over portrait")

	# 43. Round 6 Asset Optimization, Draw-Call Batching & Full UI/UX Placement Best Practices
	var m_safe: Dictionary = ArtAtmosphere.compute_hud_safe_margins(Rect2(42, 24, 1196, 672), Vector2(1280, 720), Vector2(1280, 720))
	_assert_true(int(m_safe.get("left", 0)) == 42 and int(m_safe.get("top", 0)) == 24 and int(m_safe.get("right", 0)) == 42 and int(m_safe.get("bottom", 0)) == 24, "compute_hud_safe_margins computes all 4 inset edges clamped [0,48]")

	var tc_b: Dictionary = ArtAtmosphere.compute_top_center_bounds(1280.0, 296.0, 356.0, 14.0, 16.0)
	_assert_true(float(tc_b.get("offset_left", 0.0)) >= 316.0 and float(tc_b.get("offset_right", 0.0)) <= -376.0, "compute_top_center_bounds keeps CallBanner/Toast clear of top-left and top-right HUD badges")

	var wp_clamped: Vector2 = ArtAtmosphere.clamp_world_prompt_pos(Vector2(100.0, 20.0), Vector2(180.0, 44.0), Vector2(1280.0, 720.0), {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0})
	_assert_true(wp_clamped.y >= 116.0, "clamp_world_prompt_pos keeps world action pill clear below top-left HUD card")

	_assert_true(not ArtSaveStore.should_show_slot_delete({"exists": true, "onboarding_done": false}), "empty slot with exists=true but onboarding_done=false never shows Delete button")
	_assert_true(ArtSaveStore.should_show_slot_delete({"exists": true, "onboarding_done": true}), "completed save slot shows Delete button")

	# Asset optimization: kos_room preserves ALL HD upgrade/animated nodes + UV2 lightmaps + surface draw-call budgets
	var r6_kos_ps := load("res://assets/models/kos_room.glb") as PackedScene
	var r6_kos_inst := r6_kos_ps.instantiate()
	var kos_missing: Array = []
	var expected_kos_nodes := [
		"IndoorAC", "IndoorACVent",
		"FanBase", "FanPole", "FanMotorCowl", "FanGuardRingFront", "FanGuardRingBack",
		"FanSpoke_0", "FanSpoke_1", "FanSpoke_2", "FanSpoke_3", "FanHubBadge",
		"FanBtn_0", "FanBtn_1", "FanBtn_2", "FanBlade_0", "FanBlade_1", "FanBlade_2",
		"RiceCookerStand", "MagicComBody", "MagicComLid", "MagicComVent", "MagicComLED",
		"cover", "pillow",
	]
	for req_name in expected_kos_nodes:
		if r6_kos_inst.find_child(req_name, true, false) == null:
			kos_missing.append(req_name)
	_assert_true(kos_missing.is_empty(), "kos_room.glb preserves all runtime upgrade/animated nodes after static batching: %s" % str(kos_missing))
	r6_kos_inst.free()

	var surf_budgets := {
		"res://assets/models/kampung_street.glb": 80,
		"res://assets/models/kos_room.glb": 90,
		"res://assets/models/kampung_gang.glb": 65,
		"res://assets/models/room_majikan_living.glb": 85,
	}
	for gpath in surf_budgets.keys():
		var gps := load(String(gpath)) as PackedScene
		var ginst := gps.instantiate()
		var sc_sum := 0
		var has_uv2 := false
		var stack: Array = [ginst]
		while not stack.is_empty():
			var cur: Node = stack.pop_back()
			if cur is MeshInstance3D and (cur as MeshInstance3D).mesh != null:
				var m: Mesh = (cur as MeshInstance3D).mesh
				sc_sum += m.get_surface_count()
				for si in range(m.get_surface_count()):
					if (m.surface_get_format(si) & Mesh.ARRAY_FORMAT_TEX_UV2) != 0:
						has_uv2 = true
			for ch in cur.get_children():
				stack.append(ch)
		ginst.free()
		_assert_true(sc_sum <= int(surf_budgets[gpath]), "%s surface draw calls (%d) within budget <= %d" % [String(gpath).get_file(), sc_sum, int(surf_budgets[gpath])])
		_assert_true(has_uv2, "%s preserves ARRAY_FORMAT_TEX_UV2 for lightmap rendering" % String(gpath).get_file())

	var turf_imp := FileAccess.get_file_as_string("res://assets/models/kampung_street_kampung_turf_v22_ph_alb_hd.jpg.import")
	var batu_nrm_imp := FileAccess.get_file_as_string("res://assets/models/kampung_street_batu_alam_v11_nrm.jpg.import")
	_assert_true("compress/mode=2" in turf_imp, "stage ground texture uses VRAM compression (compress/mode=2)")
	_assert_true("compress/mode=2" in batu_nrm_imp and "compress/normal_map=1" in batu_nrm_imp, "stage normal map uses VRAM compression + normal_map=1")

	_assert_true("_modal_list.remove_child(c)" in mg_src, "_clear_modal removes children synchronously before queue_free so modal height fits tightly")
	_assert_true(not ("focus_behavior_recursive" in mg_src) and ("_set_hud_focus_enabled" in mg_src), "main_game uses Godot 4.x recursive focus_mode trapping (no focus_behavior_recursive)")
	_assert_true("icon_door" in mg_src.split("if _in_shift:")[1].split("else:")[0], "Shift end/cancel dock button uses distinct icon_door instead of duplicate icon_broom")
	_assert_true("\"log\"" in mg_src.split("if _phone_os_app == \"home\":")[1].split("elif _phone_os_app")[0], "Phone OS home grid has symmetric 10 apps (including Catatan Harian)")
	_assert_true("\"font_focus_color\"" in mg_src, "_style_btn overrides font_focus_color so focused gold CTAs keep dark-ink contrast")
	_assert_true(load("res://src/scenes/main_game.gd") != null, "main_game.gd compiles cleanly with zero parse errors")

	# 44. Round 7 Exploit Closure, Story Continuity, 3D Skin Tint, BoneAttachment3D Tool, Audio & Responsive Viewports
	var r7_kb := Progression.create_player_save()
	r7_kb["day"] = 1
	var r7_b1 := Progression.record_kasbon(r7_kb, "Warung Bu Tini", 25000)
	var r7_p1 := Progression.pay_kasbon(r7_b1["save"], String(r7_b1["debt_id"]))
	_assert_eq(int(r7_p1["save"]["xp"]), 8, "first kasbon repayment on day 1 grants +8 XP")
	var r7_b2 := Progression.record_kasbon(r7_p1["save"], "Warung Bu Tini", 25000)
	var r7_p2 := Progression.pay_kasbon(r7_b2["save"], String(r7_b2["debt_id"]))
	_assert_eq(int(r7_p2["save"]["xp"]), 8, "repeat kasbon repayment same day yields +0 XP (blocks infinite Day-1 XP exploit)")
	r7_p2["save"]["day"] = 2
	var r7_b3 := Progression.record_kasbon(r7_p2["save"], "Warung Bu Tini", 25000)
	var r7_p3 := Progression.pay_kasbon(r7_b3["save"], String(r7_b3["debt_id"]))
	_assert_eq(int(r7_p3["save"]["xp"]), 16, "kasbon repayment on a new day grants +8 XP again")

	var r7_thr_sv := Progression.create_player_save()
	r7_thr_sv["day"] = 1
	r7_thr_sv["balance_rp"] = 0
	for _sl_i in range(16):
		var r7_sl := ArtLifeRhythm.sleep_in_bed(r7_thr_sv, [])
		r7_thr_sv = r7_sl["save"]
		if int(r7_thr_sv["day"]) >= 16:
			break
	_assert_eq(int(r7_thr_sv["balance_rp"]), 0, "0-work rest-only sleep cycle grants 0 Rp THR (blocks sleep THR farm)")

	var r7_up_sv := Progression.create_player_save()
	r7_up_sv["unlocked_kos_upgrades"] = ["kipas_angin", "kasur_empuk", "magic_com_pro", "ac_hemat"]
	r7_up_sv["energy"] = 20
	var r7_up_sl := ArtLifeRhythm.sleep_in_bed(r7_up_sv, [])
	_assert_eq(int(r7_up_sl["save"]["energy"]), 162, "sleep_in_bed restores full unlocked_kos_upgrades max energy (162)")
	r7_up_sv["day"] = 10
	r7_up_sv["energy"] = 150
	var r7_up_tak := ArtLifeRhythm.claim_takjil(r7_up_sv, 10)
	_assert_eq(int(r7_up_tak["save"]["energy"]), 162, "claim_takjil respects full unlocked_kos_upgrades max energy (162)")

	var r7_rt := SaveStore.deserialize('{"active_profile_id":"pak_hendra_kampung","kasbon_xp_day":4,"cycle_shifts_worked":3,"rest_only_streak":2}')
	_assert_eq(String(r7_rt["active_profile_id"]), "pak_agus_kampung", "SaveStore migrates legacy pak_hendra_kampung to pak_agus_kampung")
	_assert_eq(int(r7_rt.get("kasbon_xp_day", -1)), 4, "SaveStore preserves kasbon_xp_day")
	_assert_eq(int(r7_rt.get("cycle_shifts_worked", -1)), 3, "SaveStore preserves cycle_shifts_worked")
	_assert_eq(int(r7_rt.get("rest_only_streak", -1)), 2, "SaveStore preserves rest_only_streak")

	var r7_kp_profs := MajikanProfiles.get_profiles_for_tier("kampung")
	_assert_true(r7_kp_profs.size() > 0 and String(r7_kp_profs[0]["id"]) == "pak_agus_kampung" and "Agus" in String(r7_kp_profs[0]["name"]), "Kampung employer matches Chapter 2 Pak Agus continuity")
	_assert_eq(String(MajikanProfiles.get_profile("pak_hendra_kampung").get("id", "")), "pak_agus_kampung", "legacy pak_hendra_kampung lookup resolves to pak_agus_kampung")

	var r7_bima_found := false
	for npc_d in NpcRoster.get_street_config("kamar_kos").get("street_npcs", []):
		if String(npc_d.get("id", "")) == "adik_bima":
			r7_bima_found = true
	for npc_d in NpcRoster.get_shift_npcs("kampung"):
		if String(npc_d.get("id", "")) == "adik_bima":
			r7_bima_found = true
	_assert_true(r7_bima_found, "adik_bima is placed in kampung world roster (not orphaned)")
	_assert_true(not String(NpcRoster.get_shift_npc_reaction("adik_bima", "id").get("text", "")).is_empty(), "adik_bima has shift reaction dialogue")
	var r7_honorific_ok := true
	for t_id in ["kamar_kos", "kampung", "perumahan_36", "perumahan_45", "cluster_elite"]:
		for n_d in NpcRoster.get_shift_npcs(t_id):
			var le := String(n_d.get("label_en", ""))
			if le.begins_with("Mrs. ") or le.begins_with("Mr. "):
				r7_honorific_ok = false
	_assert_true(r7_honorific_ok, "EN NPC labels use consistent Ibu/Pak honorifics across shift & street")

	var PlayerCtrlCls = load("res://src/scenes/player_controller.gd")
	var r7_pc: Node3D = PlayerCtrlCls.new()
	r7_pc.load_outfit("starter_kasual", "res://assets/models/char_art.glb", "#4E7D63", "#8F5733")
	var r7_skin_col := Color.WHITE
	var r7_pc_stack: Array = [r7_pc]
	while not r7_pc_stack.is_empty():
		var cur_n: Node = r7_pc_stack.pop_back()
		if cur_n is MeshInstance3D and (cur_n as MeshInstance3D).mesh != null:
			var mi_pc := cur_n as MeshInstance3D
			for si in range(mi_pc.mesh.get_surface_count()):
				var r7_am: Material = mi_pc.get_active_material(si)
				if r7_am is StandardMaterial3D and "human.body" in (r7_am as StandardMaterial3D).resource_name.to_lower():
					r7_skin_col = (r7_am as StandardMaterial3D).albedo_color
		for ch in cur_n.get_children():
			r7_pc_stack.append(ch)
	_assert_true(not r7_skin_col.is_equal_approx(Color.WHITE), "PlayerController._apply_skin_tint modulates textured Human.body material")
	var r7_tool1 := ArtStreetPatrols.sync_chore_tool(r7_pc, "broom")
	var r7_tool2 := ArtStreetPatrols.sync_chore_tool(r7_pc, "sponge")
	_assert_true(r7_tool1 != null and r7_tool1 == r7_tool2 and r7_tool1.get_parent() is BoneAttachment3D and String((r7_tool1.get_parent() as BoneAttachment3D).bone_name) == "hand_r", "ChoreToolProp attaches to hand_r BoneAttachment3D without duplicating")
	r7_pc.free()

	var AudioSynthCls = load("res://src/core/audio_synth.gd")
	var r7_pray_wav = AudioSynthCls.make_prayer_chime()
	var r7_sleep_wav = AudioSynthCls.make_sleep_lullaby()
	_assert_true(r7_pray_wav is AudioStreamWAV and (r7_pray_wav as AudioStreamWAV).data.size() > 1000, "AudioSynth.make_prayer_chime returns valid PCM")
	_assert_true(r7_sleep_wav is AudioStreamWAV and (r7_sleep_wav as AudioStreamWAV).data.size() > 1000, "AudioSynth.make_sleep_lullaby returns valid PCM")

	var rent_fn := mg_src.split("func _open_rent_modal")[1].split("\nfunc ")[0]
	_assert_true(rent_fn.find("_btn_modal_close.visible = false") < rent_fn.find("_show_modal()"), "_open_rent_modal hides close button BEFORE _show_modal so players cannot skip weekly rent")
	_assert_true(not ("VERSI 1.5" in mg_src) and not ("VERSION 1.5" in mg_src), "What's New modal matches Version 1.6 (no stale 1.5 string)")
	_assert_true(not ("(Rp 0)" in mg_src) and not ("Rp 120,000" in mg_src), "main_game uses free/no-pay wording and Indonesian dot-thousand Rp formatting")
	_assert_true("icon_career" in mg_src.split("\"log\"")[1].split("]")[0], "Phone OS Catatan Harian uses distinct icon_career icon instead of duplicate app_debt/app_guide")
	_assert_true("anchor_left = 0.5" in mg_src.split("func _build_dialogue_bar")[1].split("\nfunc ")[0], "_dialogue_bar uses bottom-center anchors capped for ultrawide viewports")

	var call_tick_empty: Dictionary = MajikanCall.start_call({}, "Gate")
	for _t in 10:
		call_tick_empty = MajikanCall.tick_call(call_tick_empty, 2.0)
	_assert_true(call_tick_empty.has("trust") and int(call_tick_empty["warnings"]) == 1, "MajikanCall.tick_call never crashes on empty/default state")
	_assert_true("if _in_shift and bool(_call_state.get(\"active_call\", false)):" in mg_src, "main_game guards MajikanCall loop with _in_shift so calls never fire on Title/Home")

	# 45. Round 8 Phone Log, Adik Bima Clearance, Rent Cap, Fired Forfeit, Skill Perks, Sweet-Spot, Post-Epilogue Investments & Articulated Vehicles
	_assert_true("elif _phone_os_app == \"log\":" in mg_src, "Phone OS renders Catatan Harian (log) entries cleanly instead of blank screen")
	_assert_true("_toast_timer = 0.0" in mg_src.split("func _enter_home_mode")[1].split("\nfunc ")[0], "_enter_home_mode clears leftover shift toast")
	_assert_true("_title_wrap.visible = false" in mg_src.split("func _open_onboarding")[1].split("\nfunc ")[0], "_open_onboarding hides _title_wrap")

	var r8_bima_pos := Vector3.ZERO
	for sn in NpcRoster.get_shift_npcs("kampung"):
		if String(sn.get("id", "")) == "adik_bima":
			r8_bima_pos = sn["pos"]
	_assert_true(Vector2(r8_bima_pos.x, r8_bima_pos.z).distance_to(Vector2(-1.15, -0.18)) >= 1.20, "Adik Bima stands well clear (>=1.2m) of Kampung DiningTable")

	var r8_rent_cap := rent_sv.duplicate(true)
	for _rc in range(5):
		r8_rent_cap = Progression.pay_weekly_rent(r8_rent_cap, false, 120000)["save"]
	_assert_true(int(r8_rent_cap["pending_rent_rp"]) <= 150000, "weekly rent late surcharge is capped at Rp 150.000 (no infinite debt trap)")

	var r8_perk_sv := Progression.create_player_save()
	r8_perk_sv["day"] = 5
	r8_perk_sv["balance_rp"] = 50000
	r8_perk_sv["skill_xp"] = {"sweeping": 80, "tidiness": 80, "cooking": 80, "laundry": 80}
	_assert_eq(Progression.get_max_boosts_for_save(r8_perk_sv), 4, "sweeping Lv 3 perk grants 4 tap boosts per chore")
	_assert_true(Progression.get_boost_seconds_for_save(r8_perk_sv) >= 0.85, "tidiness Lv 3 perk increases tap boost to >=0.85s")
	_assert_true(Progression.get_tip_bonus_multiplier(r8_perk_sv) >= 1.10, "laundry Lv 3 perk grants >= +10% tip bonus")
	var r8_sh_cook := ChoreEngine.create_shift("kamar_kos", MajikanProfiles.get_profile("ibu_kos_melati"), 100)
	r8_sh_cook = ChoreEngine.complete_chore(r8_sh_cook, "make_bed", 1.0, 1)["shift"]
	var r8_cook_res := Progression.settle_shift(r8_perk_sv, r8_sh_cook, MajikanCall.create_state(MajikanProfiles.get_profile("ibu_kos_melati")))
	_assert_eq(int(r8_cook_res["meal_cost_rp"]), 0, "cooking Lv 3 perk waives Rp 8.000 daily meal deduction")

	var r8_sweet := ChoreEngine.evaluate_tap_boost("cook_rice", 0.58)
	_assert_true(bool(r8_sweet.get("perfect", false)) and int(r8_sweet.get("bonus_rp", 0)) >= 2500 and float(r8_sweet.get("mult", 1.0)) >= 1.75, "cook_rice tap inside 45-75% sweet-spot grants 1.8x boost + Rp 2.500 bonus")

	var r8_ep_sv := Progression.create_player_save()
	r8_ep_sv["xp"] = 1600
	r8_ep_sv["balance_rp"] = 8000000
	r8_ep_sv["unlocked_wishlist"] = ["kirim_kampung", "hp_baru", "tabung_kontrakan", "motor_matic"]
	_assert_true(ArtWishlistStory.is_epilogue_unlocked(r8_ep_sv), "4 core wishlist items unlock epilogue cleanly")
	var r8_inv := ArtWishlistStory.buy_investment(r8_ep_sv, "invest_warung")
	_assert_true(bool(r8_inv["ok"]) and ArtWishlistStory.get_passive_daily_income(r8_inv["save"]) >= 25000, "post-epilogue invest_warung grants >= Rp 25.000 passive daily income")
	var r8_inv_sl := ArtLifeRhythm.sleep_in_bed(r8_inv["save"], [])
	_assert_true(int(r8_inv_sl.get("passive_income_rp", 0)) >= 25000, "sleep_in_bed pays post-epilogue passive investment income")
	var r8_inv_rt := SaveStore.deserialize(SaveStore.serialize(r8_inv["save"]))
	_assert_true("invest_warung" in r8_inv_rt.get("unlocked_investments", []), "SaveStore preserves unlocked_investments")

	var r8_ang := (load("res://assets/models/veh_angkot.glb") as PackedScene).instantiate()
	var r8_wheels := 0
	var r8_q: Array = [r8_ang]
	while not r8_q.is_empty():
		var wn: Node = r8_q.pop_front()
		if "Wheel_" in wn.name:
			r8_wheels += 1
		for wc in wn.get_children():
			r8_q.append(wc)
	r8_ang.free()
	_assert_true(r8_wheels >= 4, "veh_angkot.glb exposes 4 articulated Wheel_* child nodes for wheel spin")

	var r8_veh_arr := [{"x": 0.0, "z": 4.75, "dir": 1, "speed": 3.0, "kind": "angkot", "wheel_angle": 0.0}]
	ArtStreetTraffic.step_vehicles(r8_veh_arr, 0.5, Vector3(1.5, 0.0, 4.2))
	_assert_true(float(r8_veh_arr[0].get("wheel_angle", 0.0)) > 0.0, "step_vehicles updates wheel_angle and yields cleanly when player nears road")

	var r8_st_node := Node3D.new()
	ArtAtmosphere.sync_stage_lights(r8_st_node, "street", "malam")
	var r8_lamp1 := r8_st_node.find_child("StreetLampC", true, false) as OmniLight3D
	ArtAtmosphere.sync_stage_lights(r8_st_node, "street", "pagi")
	var r8_lamp2 := r8_st_node.find_child("StreetLampC", true, false) as OmniLight3D
	_assert_true(r8_lamp1 != null and r8_lamp1 == r8_lamp2, "sync_stage_lights reuses OmniLight3D nodes instead of freeing/recreating")
	r8_st_node.free()

	# 46. Global Hit Phase 1: Room Cleanliness %, Spatial Mess Chunks, ASMR Foley, Jemuran Rain Rescue & Household Clues
	var ce_inst := ChoreEngine.new()
	_assert_true(ce_inst.has_method("compute_room_cleanliness"), "ChoreEngine exposes compute_room_cleanliness")
	if ce_inst.has_method("compute_room_cleanliness"):
		var cl_sh := ChoreEngine.create_shift("kamar_kos", MajikanProfiles.get_profile("ibu_kos_melati"), 100)
		_assert_eq(int(ce_inst.call("compute_room_cleanliness", cl_sh, "", 0.0)), 0, "fresh shift starts at 0% room cleanliness")
		_assert_true(int(ce_inst.call("compute_room_cleanliness", cl_sh, "make_bed", 0.5)) > 10, "active chore interpolates room cleanliness smoothly")
		cl_sh = ChoreEngine.complete_chore(cl_sh, "make_bed", 1.0, 1)["shift"]
		cl_sh = ChoreEngine.complete_chore(cl_sh, "sweep_floor", 1.0, 1)["shift"]
		cl_sh = ChoreEngine.complete_chore(cl_sh, "water_plants", 1.0, 1)["shift"]
		_assert_eq(int(ce_inst.call("compute_room_cleanliness", cl_sh, "", 0.0)), 100, "all chores done reaches 100% sparkling clean")

	var hs_r9 := ChoreHotspotScene.new()
	hs_r9.setup("wash_dishes", "Cuci Piring", "Wash Dishes", Vector3(1.0, 0.0, 1.0))
	_assert_true(hs_r9.has_method("set_progress") and hs_r9.get_child_count() >= 3, "ChoreHotspot spawns spatial 3D mess chunks + exposes set_progress")
	if hs_r9.has_method("set_progress"):
		hs_r9.call("set_progress", 0.80)
	hs_r9.free()

	var au_inst := AudioSynth.new()
	for foley_fn in ["make_dish_splash", "make_wok_sizzle", "make_cloth_snap", "make_thunder_rumble"]:
		_assert_true(au_inst.has_method(foley_fn), "AudioSynth provides ASMR foley: " + foley_fn)
		if au_inst.has_method(foley_fn):
			var wav: AudioStreamWAV = au_inst.call(foley_fn)
			_assert_true(wav != null and wav.data.size() > 100, foley_fn + " builds valid AudioStreamWAV")

	_assert_true(ResourceLoader.exists("res://src/core/jemuran_event.gd"), "jemuran_event.gd module exists")
	if ResourceLoader.exists("res://src/core/jemuran_event.gd"):
		var JE := load("res://src/core/jemuran_event.gd")
		_assert_true(not bool(JE.call("should_trigger", "kamar_kos", 25.0, false, 1, 3)), "Jemuran event never triggers in indoor kamar_kos")
		_assert_true(bool(JE.call("should_trigger", "kampung", 18.0, false, 1, 4)), "Jemuran event triggers in kampung mid-shift")
		var jst: Dictionary = JE.call("create_state", Vector3(-1.85, 0.0, 0.0))
		var j_res: Dictionary = JE.call("rescue", jst)
		_assert_true(bool(j_res["ok"]) and int(j_res["bonus_rp"]) == 15000, "Rescuing Jemuran grants +Rp 15.000")
		var j_dbl: Dictionary = JE.call("rescue", j_res["state"])
		_assert_true(not bool(j_dbl["ok"]), "Double-rescue rejected")
		var j_exp: Dictionary = JE.call("tick_state", JE.call("create_state", Vector3.ZERO), 20.0)
		_assert_true(bool(j_exp.get("failed", false)) and not bool(j_exp.get("active", true)), "Expired Jemuran sets failed=true")

	_assert_true(ResourceLoader.exists("res://src/core/household_clues.gd"), "household_clues.gd module exists")
	if ResourceLoader.exists("res://src/core/household_clues.gd"):
		var HC := load("res://src/core/household_clues.gd")
		var clue_sv := Progression.create_player_save()
		_assert_true(clue_sv.has("unlocked_clues"), "Save initializes unlocked_clues")
		for tid in ["kamar_kos", "kampung", "perumahan_36", "perumahan_45", "cluster_elite"]:
			var picked: Dictionary = HC.call("pick_clue_for_shift", tid, [], 1)
			_assert_true(not picked.is_empty(), "Every career tier has discoverable Household Clues: " + tid)
		var c1: Dictionary = HC.call("pick_clue_for_shift", "kampung", [], 1)
		var cid1 := String(c1.get("id", ""))
		var cr1: Dictionary = HC.call("collect_clue", clue_sv, cid1)
		_assert_true(bool(cr1["ok"]) and cid1 in cr1["save"].get("unlocked_clues", []), "collect_clue unlocks clue and awards XP")
		var cr_dup: Dictionary = HC.call("collect_clue", cr1["save"], cid1)
		_assert_true(not bool(cr_dup["ok"]), "Duplicate clue collect blocked")
		var hc_rt := SaveStore.deserialize(SaveStore.serialize(cr1["save"]))
		_assert_true(cid1 in hc_rt.get("unlocked_clues", []), "SaveStore preserves unlocked_clues across round-trip")

	print("GODOT TDD RESULT: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
