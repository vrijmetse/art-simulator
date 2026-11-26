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


static func step_vehicles(vehicles: Array, delta: float) -> void:
	for v in vehicles:
		if not (v is Dictionary):
			continue
		var dir: int = int(v.get("dir", 1))
		var speed: float = float(v.get("speed", 2.5))
		var x: float = float(v.get("x", 0.0)) + float(dir) * speed * delta
		if dir > 0 and x > X_MAX:
			x = X_MIN
		elif dir < 0 and x < X_MIN:
			x = X_MAX
		v["x"] = x


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
