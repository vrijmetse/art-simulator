class_name ArtSceneVisuals
extends RefCounted

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
