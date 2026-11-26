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
const AudioSynth := preload("res://src/core/audio_synth.gd")

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
	_assert_eq(st_fired["payout_rp"], int(sh_fired["earned_rp"]), "fired shift forfeits base contract pay")
	_assert_eq(st_fired["xp_gained"], int(floor(float(sh_fired["xp_earned"]) * 0.5)), "fired shift halves XP")

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

	print("GODOT TDD RESULT: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
