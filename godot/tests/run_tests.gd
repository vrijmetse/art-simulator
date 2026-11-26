extends SceneTree

const I18n := preload("res://src/core/i18n.gd")
const Economy := preload("res://src/core/economy.gd")
const Neighborhood := preload("res://src/core/neighborhood.gd")

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

	print("GODOT TDD RESULT: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
