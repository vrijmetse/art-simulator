class_name ArtStreetTraffic
extends RefCounted

const LANE_Z_NEAR := 4.75
const LANE_Z_FAR := 6.10
const ELITE_Z_NEAR := 3.65
const ELITE_Z_FAR := 4.75
const MIN_SAFE_Z := 2.35
const X_MIN := -9.0
const X_MAX := 9.0

const LIVERIES := {
	"angkot": [Color("#1D84B5"), Color("#2A9D8F"), Color("#E76F51")],
	"motor": [Color("#C1121F"), Color("#1D3557"), Color("#2B2D42")],
}


static func is_lane_safe(z: float) -> bool:
	return z >= MIN_SAFE_Z


static func get_traffic_config(tier_id: String) -> Array:
	match tier_id:
		"perumahan_36", "perumahan_45":
			return [
				{
					"id": "angkot_1",
					"kind": "angkot",
					"model_path": "res://assets/models/veh_angkot.glb",
					"livery_color": LIVERIES["angkot"][0],
					"x": -6.0,
					"z": LANE_Z_NEAR,
					"dir": 1,
					"speed": 2.4,
				},
				{
					"id": "motor_1",
					"kind": "motor",
					"model_path": "res://assets/models/veh_motor.glb",
					"livery_color": LIVERIES["motor"][0],
					"x": 2.5,
					"z": LANE_Z_NEAR,
					"dir": 1,
					"speed": 3.1,
				},
				{
					"id": "motor_2",
					"kind": "motor",
					"model_path": "res://assets/models/veh_motor.glb",
					"livery_color": LIVERIES["motor"][1],
					"x": 5.5,
					"z": LANE_Z_FAR,
					"dir": -1,
					"speed": 3.4,
				},
			]
		"cluster_elite":
			return [
				{
					"id": "motor_elite_1",
					"kind": "motor",
					"model_path": "res://assets/models/veh_motor.glb",
					"livery_color": LIVERIES["motor"][2],
					"x": -4.5,
					"z": ELITE_Z_NEAR,
					"dir": 1,
					"speed": 3.2,
				},
				{
					"id": "angkot_elite_1",
					"kind": "angkot",
					"model_path": "res://assets/models/veh_angkot.glb",
					"livery_color": LIVERIES["angkot"][1],
					"x": 4.0,
					"z": ELITE_Z_FAR,
					"dir": -1,
					"speed": 2.6,
				},
				{
					"id": "motor_elite_2",
					"kind": "motor",
					"model_path": "res://assets/models/veh_motor.glb",
					"livery_color": LIVERIES["motor"][0],
					"x": -1.0,
					"z": ELITE_Z_FAR,
					"dir": -1,
					"speed": 3.5,
				},
			]
		_:
			# kampung_gang (kamar_kos / kampung) has no asphalt road
			return []


static func step_vehicles(vehicles: Array, delta: float, player_pos: Vector3 = Vector3(999.0, 0.0, 999.0)) -> void:
	for v in vehicles:
		if not (v is Dictionary):
			continue
		var dir: int = int(v.get("dir", 1))
		var base_speed: float = float(v.get("speed", 2.5))
		var vx: float = float(v.get("x", 0.0))
		var vz: float = float(v.get("z", 0.0))
		var speed: float = base_speed
		# Slow/yield cleanly if player approaches the vehicle ahead in the same lane zone
		if absf(player_pos.z - vz) < 1.35:
			var dx_ahead := (player_pos.x - vx) * float(dir)
			if dx_ahead > 0.0 and dx_ahead < 2.6:
				speed = 0.0 if dx_ahead < 1.35 else base_speed * 0.35
		vx += float(dir) * speed * delta
		if dir > 0 and vx > X_MAX:
			vx = X_MIN
		elif dir < 0 and vx < X_MIN:
			vx = X_MAX
		v["x"] = vx
		var wheel_r := 0.24 if String(v.get("kind", "angkot")) == "angkot" else 0.22
		v["wheel_angle"] = fmod(float(v.get("wheel_angle", 0.0)) + (speed * delta / wheel_r), TAU)


static func sync_vehicle_node(node: Node3D, v: Dictionary, is_night: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.position.x = float(v.get("x", 0.0))
	var w_ang := float(v.get("wheel_angle", 0.0))
	var stack: Array = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is Node3D and "Wheel_" in cur.name:
			(cur as Node3D).rotation.z = -w_ang
		if cur is MeshInstance3D and (cur as MeshInstance3D).mesh != null:
			var mi := cur as MeshInstance3D
			for s in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.get_active_material(s)
				if mat is StandardMaterial3D:
					var mn := mat.resource_name.to_lower()
					if "headlight" in mn or "taillight" in mn:
						var sm := mat.duplicate() as StandardMaterial3D
						sm.emission_enabled = is_night
						sm.emission_energy_multiplier = (1.8 if "headlight" in mn else 1.2) if is_night else 0.0
						mi.set_surface_override_material(s, sm)
		for ch in cur.get_children():
			stack.append(ch)
	var beam := node.get_node_or_null("_NightBeam") as OmniLight3D
	if is_night:
		if beam == null:
			beam = OmniLight3D.new()
			beam.name = "_NightBeam"
			beam.position = Vector3(1.55, 0.55, 0.0)
			beam.light_color = Color(1.0, 0.94, 0.78)
			beam.omni_range = 3.2
			beam.light_energy = 1.15
			beam.shadow_enabled = false
			node.add_child(beam)
		beam.visible = true
	elif beam != null:
		beam.visible = false


static func apply_livery(root: Node, livery_color: Color) -> void:
	if root == null:
		return
	var stack: Array = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			var mesh: Mesh = mi.mesh
			if mesh != null:
				for i in range(mesh.get_surface_count()):
					var mat: Material = mi.get_active_material(i)
					if mat is StandardMaterial3D and (mat.resource_name == "AngkotBody" or mat.resource_name == "MotorBody"):
						var dup := mat.duplicate() as StandardMaterial3D
						dup.albedo_color = livery_color
						mi.set_surface_override_material(i, dup)
		for child in cur.get_children():
			stack.append(child)
