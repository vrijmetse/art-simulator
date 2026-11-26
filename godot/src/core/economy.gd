class_name ArtEconomy

static func create_initial_state() -> Dictionary:
	return {
		"day": 1,
		"balance_rp": 0,
		"xp": 0,
		"locale": "id",
		"chatted_dates": {},
	}

static func award_contract(state: Dictionary, payout_rp: int, xp_gain: int) -> Dictionary:
	var next := state.duplicate(true)
	next["balance_rp"] = int(state.get("balance_rp", 0)) + max(0, payout_rp)
	next["xp"] = int(state.get("xp", 0)) + max(0, xp_gain)
	return next

static func get_career_rank(xp: int, locale: String = "id") -> String:
	if xp >= 300:
		return "Master Homekeeper" if locale == "en" else "ART Andalan"
	if xp >= 150:
		return "Senior Helper" if locale == "en" else "ART Cekatan"
	if xp >= 75:
		return "Skilled Helper" if locale == "en" else "ART Terampil"
	return "Junior Helper" if locale == "en" else "ART Pemula"
