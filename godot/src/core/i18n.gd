class_name ArtI18n

static func format_idr_digits(amount_rp: int) -> String:
	var n: int = abs(amount_rp)
	var s := str(n)
	var parts: PackedStringArray = []
	while s.length() > 3:
		parts.insert(0, s.substr(s.length() - 3, 3))
		s = s.substr(0, s.length() - 3)
	parts.insert(0, s)
	var joined := ".".join(parts)
	return ("-" + joined) if amount_rp < 0 else joined

static func format_balance(amount_rp: int, locale: String = "id") -> String:
	if locale == "en":
		var usd: int = int(round(float(amount_rp) / 15000.0))
		return "$%d" % usd
	return "Rp %s" % format_idr_digits(amount_rp)

static func format_price(amount_rp: int, locale: String = "id") -> String:
	if amount_rp == 0:
		return "Free" if locale == "en" else "Gratis"
	return format_balance(amount_rp, locale)
