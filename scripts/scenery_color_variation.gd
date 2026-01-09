extends Node
class_name SceneryColorVariation

## Applies color variation to tree foliage in GridMaps at runtime

@export var target_gridmap_path: NodePath
@export var foliage_shader: Shader

# Base colors for foliage variation
const FOLIAGE_COLORS = [
	Color(0.45, 0.65, 0.35),  # Light green
	Color(0.35, 0.55, 0.25),  # Medium green
	Color(0.30, 0.50, 0.20),  # Darker green
	Color(0.40, 0.60, 0.30),  # Yellow-green
	Color(0.35, 0.58, 0.28),  # Fresh green
]

var _applied_materials: Dictionary = {}


func _ready() -> void:
	# Wait a frame for GridMap to be fully loaded
	await get_tree().process_frame
	_apply_variation()


func _apply_variation() -> void:
	if target_gridmap_path.is_empty():
		return
	
	var gridmap = get_node_or_null(target_gridmap_path) as GridMap
	if not gridmap:
		push_warning("SceneryColorVariation: Could not find GridMap at path")
		return
	
	var mesh_library = gridmap.mesh_library
	if not mesh_library:
		return
	
	# Find tree items and apply color variation
	for item_id in mesh_library.get_item_list():
		var item_name = mesh_library.get_item_name(item_id)
		if "tree" in item_name.to_lower():
			_apply_foliage_variation_to_item(mesh_library, item_id)


func _apply_foliage_variation_to_item(mesh_library: MeshLibrary, item_id: int) -> void:
	var mesh = mesh_library.get_item_mesh(item_id)
	if not mesh:
		return
	
	# Get random color for this tree type
	var color_index = item_id % FOLIAGE_COLORS.size()
	var base_color = FOLIAGE_COLORS[color_index]
	
	# Apply variation to each surface
	for surface_idx in range(mesh.get_surface_count()):
		var material = mesh.surface_get_material(surface_idx)
		if material and material is StandardMaterial3D:
			var mat_name = material.resource_name if material.resource_name else ""
			# Only modify grass/foliage materials, not bark
			if "grass" in mat_name.to_lower() or "leaf" in mat_name.to_lower() or "foliage" in mat_name.to_lower():
				var new_material = material.duplicate() as StandardMaterial3D
				# Add slight random variation
				var variation = randf_range(-0.08, 0.08)
				new_material.albedo_color = Color(
					clamp(base_color.r + variation, 0.2, 0.6),
					clamp(base_color.g + variation * 0.5, 0.4, 0.8),
					clamp(base_color.b + variation, 0.15, 0.45)
				)
				mesh.surface_set_material(surface_idx, new_material)
				print("[SceneryVariation] Applied color variation to: ", mesh_library.get_item_name(item_id))
