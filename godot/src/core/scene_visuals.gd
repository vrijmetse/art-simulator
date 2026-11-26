class_name ArtSceneVisuals
extends RefCounted

static var _contact_tex: ImageTexture = null

static func apply_baked_ao(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var fmt: int = mi.mesh.surface_get_format(s)
				if (fmt & Mesh.ARRAY_FORMAT_COLOR) == 0:
					continue
				var mat: Material = mi.get_active_material(s)
				if mat is StandardMaterial3D:
					var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					if sm.emission_enabled and sm.emission_energy_multiplier > 0.5:
						continue
					sm.vertex_color_use_as_albedo = true
					sm.vertex_color_is_srgb = false
					mi.set_surface_override_material(s, sm)
	for child in node.get_children():
		apply_baked_ao(child)

static func apply_character_polish(node: Node) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.name == "_ContactShadow":
			return
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.get_active_material(s)
				if mat is StandardMaterial3D:
					var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					sm.rim_enabled = true
					sm.rim = 0.24
					sm.rim_tint = 0.55
					if "skin" in sm.resource_name.to_lower() and sm.roughness > 0.72:
						sm.roughness = 0.68
					mi.set_surface_override_material(s, sm)
	for child in node.get_children():
		apply_character_polish(child)

static func _get_contact_shadow_tex() -> ImageTexture:
	if _contact_tex == null:
		var sz := 64
		var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
		var half := float(sz - 1) * 0.5
		for y in range(sz):
			for x in range(sz):
				var dx := (float(x) - half) / half
				var dy := (float(y) - half) / half
				var r := sqrt(dx * dx + dy * dy)
				var a := 0.0
				if r < 1.0:
					var t := 1.0 - r
					a = t * t * 0.44
				img.set_pixel(x, y, Color(0.03, 0.04, 0.08, a))
		_contact_tex = ImageTexture.create_from_image(img)
	return _contact_tex

static func attach_contact_shadow(target: Node3D, radius: float = 0.36) -> void:
	if target == null:
		return
	var existing := target.find_child("_ContactShadow", false, false)
	if existing != null:
		return
	var mi := MeshInstance3D.new()
	mi.name = "_ContactShadow"
	var pm := PlaneMesh.new()
	var d := maxf(0.25, radius * 2.0)
	pm.size = Vector2(d, d)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _get_contact_shadow_tex()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pm.material = mat
	mi.mesh = pm
	mi.position = Vector3(0.0, 0.028, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target.add_child(mi)
