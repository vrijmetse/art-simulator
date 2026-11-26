class_name ArtNeighborhood

const NEIGHBORS := [
	{
		"id": "ibu_sari",
		"name_id": "Ibu Sari",
		"role_id": "Istri / Pemilik Rumah",
		"greeting_id": "Alhamdulillah ruang tamu dan teras sudah bersih sekali. Ini uang makan siang buatmu ya!",
		"tip_rp": 5500,
		"start_x": -2.4,
		"lane_z": 1.35,
		"speed": 0.42,
		"skin": "#DFAC8E",
		"shirt": "#E07A5F",
		"hair": "#3D2C2E",
	},
	{
		"id": "adik_bima",
		"name_id": "Adik Bima",
		"role_id": "Anak Pemilik Rumah",
		"greeting_id": "Kakak ART! Makasih udah rapihin kamar belajarku. Ini koin jajan buat Kakak!",
		"tip_rp": 4500,
		"start_x": 0.1,
		"lane_z": 1.65,
		"speed": 0.52,
		"skin": "#E6B89C",
		"shirt": "#4EA8DE",
		"hair": "#2B2D42",
	},
	{
		"id": "pak_budi",
		"name_id": "Pak Budi",
		"role_id": "Suami / Kepala Keluarga",
		"greeting_id": "Rumah terasa nyaman setiap kami pulang kerja. Ini bonus kopi ya!",
		"tip_rp": 6000,
		"start_x": 2.6,
		"lane_z": 1.25,
		"speed": 0.46,
		"skin": "#D49E7D",
		"shirt": "#2A9D8F",
		"hair": "#2B2D42",
	},
]

static func create_patrols() -> Array:
	var out: Array = []
	for i in range(NEIGHBORS.size()):
		var spec: Dictionary = NEIGHBORS[i]
		var dir: int = 1 if (i % 2 == 0) else -1
		out.append({
			"spec": spec,
			"x": float(spec["start_x"]),
			"z": float(spec["lane_z"]),
			"dir": dir,
			"talking": false,
		})
	return out

static func claim_tip(state: Dictionary, npc_id: String, date_key: String) -> Dictionary:
	var found := {}
	for spec in NEIGHBORS:
		if spec["id"] == npc_id:
			found = spec
			break
	if found.is_empty():
		return {"claimed": false, "tip_rp": 0, "state": state}
	var chatted: Dictionary = state.get("chatted_dates", {})
	if chatted.get(npc_id, "") == date_key:
		return {"claimed": false, "tip_rp": 0, "state": state}
	var next := state.duplicate(true)
	var next_chatted: Dictionary = chatted.duplicate()
	next_chatted[npc_id] = date_key
	next["chatted_dates"] = next_chatted
	next["balance_rp"] = int(state.get("balance_rp", 0)) + int(found["tip_rp"])
	next["xp"] = int(state.get("xp", 0)) + 10
	return {"claimed": true, "tip_rp": int(found["tip_rp"]), "state": next}
