class_name ArtPortraits
extends RefCounted

const CareerTiers := preload("res://src/core/career_tiers.gd")

static var _portrait_cache: Dictionary = {}
static var _ui_icon_cache: Dictionary = {}

const CHARACTER_STYLES := {
	"player": {
		"bg": Color("#2A4B5C"),
		"skin": Color("#D8A47F"),
		"hair": Color("#1E1B18"),
		"shirt": Color("#2E7D6B"),
		"accent": Color("#E0B86B"),
		"headwear": "hair_short",
		"glasses": false,
		"mustache": false,
	},
	"ibu_melati": {
		"bg": Color("#4A3042"),
		"skin": Color("#DFB08C"),
		"hair": Color("#8C3B5A"),
		"shirt": Color("#B85C7A"),
		"accent": Color("#F0D6B8"),
		"headwear": "hijab",
		"glasses": false,
		"mustache": false,
	},
	"mbak_dewi": {
		"bg": Color("#384E3C"),
		"skin": Color("#D39C74"),
		"hair": Color("#241C18"),
		"shirt": Color("#C97A4B"),
		"accent": Color("#F2E3C9"),
		"headwear": "hair_bun",
		"glasses": false,
		"mustache": false,
	},
	"pak_budi": {
		"bg": Color("#3D352B"),
		"skin": Color("#C98E66"),
		"hair": Color("#1A1A1A"),
		"shirt": Color("#6E472B"),
		"accent": Color("#D9A84E"),
		"headwear": "peci",
		"glasses": false,
		"mustache": true,
	},
	"ibu_sari": {
		"bg": Color("#28463B"),
		"skin": Color("#DCAA85"),
		"hair": Color("#2F7A67"),
		"shirt": Color("#459680"),
		"accent": Color("#E8C468"),
		"headwear": "hijab",
		"glasses": false,
		"mustache": false,
	},
	"ibu_citra": {
		"bg": Color("#413452"),
		"skin": Color("#E3B796"),
		"hair": Color("#2B201C"),
		"shirt": Color("#6C528A"),
		"accent": Color("#E6C98A"),
		"headwear": "hair_bob",
		"glasses": false,
		"mustache": false,
	},
	"pak_hendra": {
		"bg": Color("#2C3B4E"),
		"skin": Color("#D49E78"),
		"hair": Color("#262629"),
		"shirt": Color("#3C5675"),
		"accent": Color("#D4AF5A"),
		"headwear": "hair_short",
		"glasses": true,
		"mustache": false,
	},
	"pak_rt": {
		"bg": Color("#423829"),
		"skin": Color("#C88D64"),
		"hair": Color("#1C1C1E"),
		"shirt": Color("#7A4E2D"),
		"accent": Color("#E0B252"),
		"headwear": "peci",
		"glasses": true,
		"mustache": true,
	},
	"bang_ojek": {
		"bg": Color("#244A34"),
		"skin": Color("#C68B62"),
		"hair": Color("#2E8B57"),
		"shirt": Color("#2B7A4B"),
		"accent": Color("#F2C94C"),
		"headwear": "helmet",
		"glasses": false,
		"mustache": false,
	},
	"kurir_paket": {
		"bg": Color("#4A3524"),
		"skin": Color("#CE936A"),
		"hair": Color("#D96B27"),
		"shirt": Color("#D96B27"),
		"accent": Color("#2B4C7E"),
		"headwear": "cap",
		"glasses": false,
		"mustache": false,
	},
	"anak_sekolah": {
		"bg": Color("#2E445A"),
		"skin": Color("#D7A078"),
		"hair": Color("#1D1917"),
		"shirt": Color("#ECEFF2"),
		"accent": Color("#B83232"),
		"headwear": "hair_short",
		"glasses": false,
		"mustache": false,
	},
	"pak_agus": {
		"bg": Color("#334149"),
		"skin": Color("#C9926E"),
		"hair": Color("#262626"),
		"shirt": Color("#5C6B73"),
		"accent": Color("#D4AF5A"),
		"headwear": "peci",
		"glasses": false,
		"mustache": true,
	},
	"kakak_nadine": {
		"bg": Color("#4B2E3B"),
		"skin": Color("#E6B89C"),
		"hair": Color("#2B1F1D"),
		"shirt": Color("#D97B93"),
		"accent": Color("#F5E1CE"),
		"headwear": "hair_bob",
		"glasses": false,
		"mustache": false,
	},
	"kakak_maya": {
		"bg": Color("#2B4157"),
		"skin": Color("#E2B292"),
		"hair": Color("#241C1A"),
		"shirt": Color("#5B8FB9"),
		"accent": Color("#F0D6B8"),
		"headwear": "hair_bun",
		"glasses": false,
		"mustache": false,
	},
	"ibu_tini": {
		"bg": Color("#3D4B34"),
		"skin": Color("#D49E78"),
		"hair": Color("#3B6E4C"),
		"shirt": Color("#6B8E4E"),
		"accent": Color("#E8C468"),
		"headwear": "hijab",
		"glasses": false,
		"mustache": false,
	},
	"mbak_rina": {
		"bg": Color("#2A4B5C"),
		"skin": Color("#D8A47F"),
		"hair": Color("#1E1B18"),
		"shirt": Color("#3A8C7A"),
		"accent": Color("#E0B86B"),
		"headwear": "hair_bun",
		"glasses": false,
		"mustache": false,
	},
	"adik_bima": {
		"bg": Color("#2E445A"),
		"skin": Color("#E6B89C"),
		"hair": Color("#2B2D42"),
		"shirt": Color("#4EA8DE"),
		"accent": Color("#F2C94C"),
		"headwear": "hair_short",
		"glasses": false,
		"mustache": false,
	},
}

static func _load_tex_asset(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var res: Resource = ResourceLoader.load(res_path)
		if res is Texture2D:
			return res as Texture2D
	var abs_p := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_p):
		var img := Image.load_from_file(abs_p)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

static func get_ui_icon(icon_name: String) -> Texture2D:
	if _ui_icon_cache.has(icon_name):
		return _ui_icon_cache[icon_name]
	var tex := _load_tex_asset("res://assets/ui/%s.png" % icon_name)
	if tex != null:
		_ui_icon_cache[icon_name] = tex
		return tex
	var fb_img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	fb_img.fill(Color(0.95, 0.78, 0.26, 1.0))
	var fb := ImageTexture.create_from_image(fb_img)
	_ui_icon_cache[icon_name] = fb
	return fb

static func get_portrait(speaker_id: String, mood: String = "neutral") -> Texture2D:
	var norm_mood := mood
	if norm_mood != "neutral" and norm_mood != "happy" and norm_mood != "strict":
		norm_mood = "neutral"
	var cache_key := "%s_%s" % [speaker_id, norm_mood]
	if _portrait_cache.has(cache_key):
		return _portrait_cache[cache_key]

	var tex_hd := _load_tex_asset("res://assets/portraits/portrait_%s.png" % speaker_id)
	if tex_hd != null:
		_portrait_cache[cache_key] = tex_hd
		return tex_hd

	var style: Dictionary = CHARACTER_STYLES.get(speaker_id, CHARACTER_STYLES["player"])
	var tex := _render_portrait_from_style(style, norm_mood)
	_portrait_cache[cache_key] = tex
	return tex

static func get_player_portrait(skin_hex: String, shirt_hex: String, ob_style: String, mood: String = "neutral") -> Texture2D:
	var norm_mood := mood
	if norm_mood != "neutral" and norm_mood != "happy" and norm_mood != "strict":
		norm_mood = "neutral"
	var cache_key := "player_%s_%s_%s_%s" % [skin_hex, shirt_hex, ob_style, norm_mood]
	if _portrait_cache.has(cache_key):
		return _portrait_cache[cache_key]

	var variant := "player_hijab" if ob_style == "hijab" else "player_cepol"
	var tex_hd := _load_tex_asset("res://assets/portraits/portrait_%s.png" % variant)
	if tex_hd != null:
		_portrait_cache[cache_key] = tex_hd
		return tex_hd

	var base: Dictionary = CHARACTER_STYLES["player"].duplicate()
	base["skin"] = Color.from_string(skin_hex, base["skin"])
	base["shirt"] = Color.from_string(shirt_hex, base["shirt"])
	match ob_style:
		"hijab":
			base["headwear"] = "hijab"
		"cepol", "bun", "hair_bun":
			base["headwear"] = "hair_bun"
		"bob", "hair_bob":
			base["headwear"] = "hair_bob"
		_:
			base["headwear"] = "hair_short"

	var tex := _render_portrait_from_style(base, norm_mood)
	_portrait_cache[cache_key] = tex
	return tex

static func _render_portrait_from_style(style: Dictionary, norm_mood: String) -> ImageTexture:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	var bg: Color = style["bg"]
	var skin: Color = style["skin"]
	var hair: Color = style["hair"]
	var shirt: Color = style["shirt"]
	var accent: Color = style["accent"]
	var headwear: String = str(style["headwear"])

	# Background with subtle border
	img.fill(bg)
	_draw_rect(img, 0, 0, 48, 2, bg.lightened(0.18))
	_draw_rect(img, 0, 46, 48, 2, bg.darkened(0.22))

	# Shoulders / batik-accented shirt
	_draw_rect(img, 9, 34, 30, 14, shirt)
	_draw_rect(img, 14, 34, 20, 4, shirt.lightened(0.1))
	# Batik / collar accent dots
	_draw_rect(img, 18, 35, 12, 3, accent)
	_draw_pixel(img, 13, 40, accent)
	_draw_pixel(img, 34, 40, accent)
	_draw_pixel(img, 15, 44, accent)
	_draw_pixel(img, 32, 44, accent)

	# Neck
	_draw_rect(img, 20, 29, 8, 6, skin.darkened(0.1))

	# Hijab back drape if applicable
	if headwear == "hijab":
		_draw_rect(img, 12, 12, 24, 24, hair)
		_draw_rect(img, 10, 18, 28, 18, hair.darkened(0.08))

	# Head / Face
	_draw_rect(img, 15, 13, 18, 17, skin)
	_draw_rect(img, 17, 29, 14, 2, skin)

	# Headwear / Hair
	if headwear == "hair_short":
		_draw_rect(img, 14, 9, 20, 6, hair)
		_draw_rect(img, 14, 13, 2, 6, hair)
		_draw_rect(img, 32, 13, 2, 6, hair)
	elif headwear == "hair_bun":
		_draw_rect(img, 14, 9, 20, 6, hair)
		_draw_rect(img, 19, 5, 10, 5, hair.darkened(0.08))
		_draw_rect(img, 14, 13, 2, 7, hair)
		_draw_rect(img, 32, 13, 2, 7, hair)
	elif headwear == "hair_bob":
		_draw_rect(img, 13, 9, 22, 6, hair)
		_draw_rect(img, 12, 13, 3, 14, hair)
		_draw_rect(img, 33, 13, 3, 14, hair)
	elif headwear == "peci":
		_draw_rect(img, 15, 6, 18, 7, Color("#18181A"))
		_draw_rect(img, 16, 11, 16, 2, Color("#2E2E32"))
	elif headwear == "hijab":
		_draw_rect(img, 14, 9, 20, 5, hair.lightened(0.08))
		_draw_rect(img, 16, 30, 16, 4, hair)
	elif headwear == "helmet":
		_draw_rect(img, 13, 6, 22, 9, hair)
		_draw_rect(img, 15, 12, 18, 2, accent)
	elif headwear == "cap":
		_draw_rect(img, 14, 7, 20, 6, hair)
		_draw_rect(img, 14, 12, 23, 2, accent)

	# Eyes & Eyebrows by mood
	var eye_color := Color("#1E1A18")
	var brow_color := Color("#2B211C")
	if norm_mood == "happy":
		# Happy curved eyes
		_draw_rect(img, 18, 19, 3, 2, eye_color)
		_draw_rect(img, 27, 19, 3, 2, eye_color)
		_draw_rect(img, 18, 16, 3, 1, brow_color)
		_draw_rect(img, 27, 16, 3, 1, brow_color)
	elif norm_mood == "strict":
		# Angled strict brows + focused eyes
		_draw_rect(img, 18, 19, 2, 2, eye_color)
		_draw_rect(img, 28, 19, 2, 2, eye_color)
		_draw_pixel(img, 17, 16, brow_color)
		_draw_pixel(img, 18, 16, brow_color)
		_draw_pixel(img, 19, 17, brow_color)
		_draw_pixel(img, 28, 17, brow_color)
		_draw_pixel(img, 29, 16, brow_color)
		_draw_pixel(img, 30, 16, brow_color)
	else:
		# Neutral eyes
		_draw_rect(img, 18, 19, 2, 2, eye_color)
		_draw_rect(img, 28, 19, 2, 2, eye_color)
		_draw_rect(img, 18, 17, 3, 1, brow_color)
		_draw_rect(img, 27, 17, 3, 1, brow_color)

	# Glasses
	if bool(style.get("glasses", false)):
		var frame := Color("#2B303A")
		_draw_rect(img, 16, 18, 6, 4, frame)
		_draw_rect(img, 17, 19, 4, 2, skin)
		_draw_rect(img, 18, 19, 2, 2, eye_color)
		_draw_rect(img, 26, 18, 6, 4, frame)
		_draw_rect(img, 27, 19, 4, 2, skin)
		_draw_rect(img, 28, 19, 2, 2, eye_color)
		_draw_rect(img, 22, 19, 4, 1, frame)

	# Mustache
	if bool(style.get("mustache", false)):
		_draw_rect(img, 20, 23, 8, 2, Color("#241C18"))

	# Mouth by mood
	var mouth_color := Color("#8A4338")
	if norm_mood == "happy":
		_draw_pixel(img, 20, 25, mouth_color)
		_draw_rect(img, 21, 26, 6, 1, mouth_color)
		_draw_pixel(img, 27, 25, mouth_color)
	elif norm_mood == "strict":
		_draw_rect(img, 21, 26, 6, 1, mouth_color.darkened(0.2))
	else:
		_draw_rect(img, 21, 25, 6, 1, mouth_color)

	var tex := ImageTexture.create_from_image(img)
	return tex

static func get_map_destinations(save: Dictionary, world_mode: String) -> Array:
	var xp := int(save.get("xp", 0))
	var active_tier := CareerTiers.get_active_tier(xp)
	var active_tier_id := str(save.get("active_tier_id", active_tier.get("id", "kamar_kos")))

	var nodes: Array = [
		{
			"id": "kos_room",
			"kind": "place",
			"label_id": "Kamar Kos",
			"label_en": "Kos Room",
			"min_xp": 0,
			"unlocked": true,
			"active": world_mode == "home" or world_mode == "kos",
			"action": "kos",
		},
		{
			"id": "neighborhood_street",
			"kind": "place",
			"label_id": "Jalanan Lingkungan",
			"label_en": "Neighborhood Street",
			"min_xp": 0,
			"unlocked": true,
			"active": world_mode == "street",
			"action": "street",
		},
		{
			"id": "employer_house",
			"kind": "place",
			"label_id": "Rumah Majikan",
			"label_en": "Employer Shift House",
			"min_xp": 0,
			"unlocked": true,
			"active": world_mode == "shift",
			"action": "shift",
		},
	]

	for t in CareerTiers.get_all_tiers():
		var tier_id := str(t["id"])
		var min_xp := int(t["min_xp"])
		nodes.append({
			"id": "district_%s" % tier_id,
			"kind": "district",
			"tier_id": tier_id,
			"label_id": str(t["house_type"]),
			"label_en": str(t["house_type_en"]),
			"min_xp": min_xp,
			"unlocked": xp >= min_xp,
			"active": tier_id == active_tier_id,
			"action": "district",
		})

	return nodes

static func _draw_rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for py in range(maxi(0, y), mini(48, y + h)):
		for px in range(maxi(0, x), mini(48, x + w)):
			img.set_pixel(px, py, col)

static func _draw_pixel(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < 48 and y >= 0 and y < 48:
		img.set_pixel(x, y, col)
