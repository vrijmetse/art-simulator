class_name ArtSceneVisuals
extends RefCounted

static var _contact_tex: ImageTexture = null
static var _default_outline_mat: ShaderMaterial = null

static func ensure_detail_outline_material() -> ShaderMaterial:
	if _default_outline_mat == null:
		var sh := load("res://shaders/hd_detail.gdshader") as Shader
		if sh != null:
			_default_outline_mat = ShaderMaterial.new()
			_default_outline_mat.shader = sh
			_default_outline_mat.set_shader_parameter("outline_color", Color(0.24, 0.16, 0.11, 1.0))
			_default_outline_mat.set_shader_parameter("outline_width", 0.0018)
	return _default_outline_mat

static func apply_unified_material_pass(
	node: Node,
	is_room: bool,
	force_outline: bool,
	outline_mat: ShaderMaterial,
	mat_cache: Dictionary,
	lightmap_tex: Texture2D = null,
	apply_ao: bool = false
) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.name == "_ContactShadow":
			return
		var n_low := mi.name.to_lower()
		var is_flat_arch := ("wall" in n_low or "dinding" in n_low or "floor" in n_low or "lantai" in n_low or "ceiling" in n_low or "atap" in n_low or "desk" in n_low or "meja" in n_low or "wardrobe" in n_low or "lemari" in n_low or "bed_frame" in n_low or "skirt" in n_low or "wainscot" in n_low or "kerupukglass" in n_low or "fanspoke" in n_low or "galonwaterfill" in n_low or "galonaquabottle" in n_low)
		var is_smooth_prop := ("pillow" in n_low or "bantal" in n_low or "guling" in n_low or "quilt" in n_low or "lamp" in n_low or "lampu" in n_low or "mug" in n_low or "cup" in n_low or "chair" in n_low or "kursi" in n_low or "plant" in n_low or "pot" in n_low or "bag" in n_low or "tas" in n_low or "fan" in n_low or "kipas" in n_low or "galon" in n_low or "magiccom" in n_low or "bottle" in n_low or "laundry" in n_low)
		var wants_outline := force_outline or (is_smooth_prop and not is_flat_arch)
		if mi.mesh != null:
			var is_arr := mi.mesh is ArrayMesh
			for s in range(mi.mesh.get_surface_count()):
				var fmt: int = (mi.mesh as ArrayMesh).surface_get_format(s) if is_arr else 0
				var has_ao: bool = apply_ao and is_arr and ((fmt & Mesh.ARRAY_FORMAT_COLOR) != 0)
				var has_uv2: bool = (lightmap_tex != null) and is_arr and ((fmt & Mesh.ARRAY_FORMAT_TEX_UV2) != 0)
				var mat: Material = mi.get_active_material(s)
				if mat is StandardMaterial3D:
					var role_tag := "std"
					if is_room:
						if "floor" in n_low or "lantai" in n_low:
							role_tag = "floor"
						elif "mirror" in n_low or "cermin" in n_low:
							role_tag = "mirror"
						elif "galonwaterfill" in n_low:
							role_tag = "galon_water"
						elif "galonaquabottle" in n_low:
							role_tag = "galon_pet"
						elif "kerupukglass" in n_low:
							role_tag = "kerupuk_glass"
						elif "wood" in n_low or "kayu" in n_low or "desk" in n_low or "meja" in n_low or "wardrobe" in n_low or "lemari" in n_low:
							role_tag = "wood_obj"
					var cache_key := "%d_%s_%s_%s_%s" % [mat.get_rid().get_id(), str(wants_outline), str(has_ao), str(has_uv2), role_tag]
					if mat_cache.has(cache_key):
						mi.set_surface_override_material(s, mat_cache[cache_key])
						continue
					var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					var m_low := sm.resource_name.to_lower()
					var is_emissive := sm.emission_enabled and sm.emission_energy_multiplier > 0.5
					if has_ao and not is_emissive:
						sm.vertex_color_use_as_albedo = true
						sm.vertex_color_is_srgb = false
					if has_uv2 and not is_emissive:
						sm.detail_enabled = true
						sm.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
						sm.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
						sm.detail_albedo = lightmap_tex
					if is_room:
						if role_tag == "floor" or "tile" in m_low or "floor" in m_low:
							sm.roughness = 0.56
							sm.metallic = 0.0
							sm.metallic_specular = 0.24
						elif role_tag == "mirror" or "mirror" in m_low:
							sm.albedo_color = Color(0.58, 0.74, 0.88, 1.0)
							sm.roughness = 0.08
							sm.metallic = 0.35
						elif role_tag == "galon_water":
							sm.roughness = 0.10
							sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
							sm.albedo_color = Color(0.12, 0.56, 0.88, 0.56)
						elif role_tag == "galon_pet":
							sm.roughness = 0.06
							sm.metallic = 0.06
							sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
							sm.albedo_color = Color(0.68, 0.88, 1.0, 0.28)
						elif role_tag == "kerupuk_glass" or "kerupukglass" in m_low:
							sm.roughness = 0.08
							sm.metallic = 0.04
							sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
							sm.albedo_color = Color(0.92, 0.96, 1.0, 0.22)
						elif role_tag == "wood_obj" or "wood" in m_low or "kayu" in m_low or "walnut" in m_low or "teak" in m_low:
							sm.albedo_color = sm.albedo_color.darkened(0.08)
							sm.roughness = clampf(sm.roughness * 0.82, 0.22, 0.55)
						if not is_flat_arch and sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
							sm.rim_enabled = true
							sm.rim = 0.18
					else:
						sm.rim_enabled = true
						sm.rim = 0.05
						sm.rim_tint = 0.35
						var is_vehicle := ("sedan" in n_low or "van" in n_low or "angkot" in n_low or "motor" in n_low or "wheel" in n_low or "tire" in m_low or "headlight" in m_low or "taillight" in m_low or "carpaint" in m_low or "carglass" in m_low)
						if is_vehicle or sm.metallic >= 0.25 or is_emissive:
							pass
						else:
							sm.metallic = 0.0
							if "skin" in m_low:
								sm.roughness = maxf(sm.roughness, 0.76)
								sm.metallic_specular = 0.18
							elif not ("eye" in m_low or "iris" in m_low or "glass" in m_low or "buckle" in m_low):
								sm.roughness = maxf(sm.roughness, 0.78)
								sm.metallic_specular = minf(sm.metallic_specular, 0.16)
					if sm.normal_enabled:
						sm.normal_scale = 1.35
					if wants_outline and outline_mat != null and sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
						sm.next_pass = outline_mat
					elif not is_room and not force_outline:
						sm.next_pass = null
					mat_cache[cache_key] = sm
					mi.set_surface_override_material(s, sm)
	for child in node.get_children():
		apply_unified_material_pass(child, is_room, force_outline, outline_mat, mat_cache, lightmap_tex, apply_ao)

static func apply_baked_ao(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh is ArrayMesh:
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

static func apply_lightmap(node: Node, lightmap_tex: Texture2D) -> void:
	if node == null or lightmap_tex == null:
		return
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh is ArrayMesh:
			for s in range(mi.mesh.get_surface_count()):
				var fmt: int = mi.mesh.surface_get_format(s)
				if (fmt & Mesh.ARRAY_FORMAT_TEX_UV2) == 0:
					continue
				var mat: Material = mi.get_active_material(s)
				if mat is StandardMaterial3D:
					var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					if sm.emission_enabled and sm.emission_energy_multiplier > 0.5:
						continue
					sm.detail_enabled = true
					sm.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
					sm.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
					sm.detail_albedo = lightmap_tex
					mi.set_surface_override_material(s, sm)
	for child in node.get_children():
		apply_lightmap(child, lightmap_tex)

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
					sm.rim = 0.05
					sm.rim_tint = 0.35
					var rname := sm.resource_name.to_lower()
					if "skin" in rname:
						sm.roughness = maxf(sm.roughness, 0.76)
						sm.metallic_specular = 0.18
					elif not ("eye" in rname or "iris" in rname or "glass" in rname or "buckle" in rname):
						sm.roughness = maxf(sm.roughness, 0.78)
						sm.metallic_specular = minf(sm.metallic_specular, 0.16)
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
