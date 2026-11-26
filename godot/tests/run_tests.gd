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
				var i_hip := skel.find_bone("thigh_l")
				var i_knee := skel.find_bone("calf_l")
				var i_foot := skel.find_bone("foot_l")
				var i_nk := skel.find_bone("neck_01")
				var i_hd := skel.find_bone("head_leaf")
				_assert_true(i_tip >= 0 and i_knee >= 0 and i_hd >= 0 and i_foot >= 0, "UAL1 human bones exist in " + cm_path)
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
					var total_h := p_hd.y
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
	_assert_eq(Progression.should_collect_weekly_rent(later_rent["save"], CareerTiers.get_tier("kamar_kos")), true, "pending rent keeps rent collection active")
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
	_assert_true(p_a != null and p_a.get_width() == 48 and p_a.get_height() == 48, "portrait is 48x48 ImageTexture")
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
	_assert_true(p_tex != null and p_tex.get_width() == 48, "dynamic player portrait renders 48x48")

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

	print("GODOT TDD RESULT: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
