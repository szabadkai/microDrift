@tool
extends Node3D
class_name VegetationBrush

## Vegetation Brush Tool
## Add this to your scene, select it, and use the controls in the Inspector
## to paint random vegetation by clicking/dragging in the 3D viewport

@export_group("Brush Settings")
## Brush radius - vegetation spawns within this radius
@export var brush_radius: float = 2.0:
	set(v):
		brush_radius = v
		_update_preview()

## Number of items to place per paint stroke
@export var density: int = 3

## Minimum spacing between vegetation items
@export var min_spacing: float = 0.5

## Raycast from this height down to find ground
@export var raycast_height: float = 50.0

## Paint on these collision layers (default: layer 1)
@export_flags_3d_physics var paint_collision_mask: int = 1

@export_group("Vegetation Types")
## Include trees in brush
@export var include_trees: bool = true
## Include rocks in brush
@export var include_rocks: bool = true
## Include bushes in brush  
@export var include_bushes: bool = true
## Include grass in brush
@export var include_grass: bool = false

@export_group("Variation")
## Random scale range (min, max)
@export var scale_range: Vector2 = Vector2(0.8, 1.2)
## Random Y rotation
@export var random_rotation: bool = true

@export_group("Actions")
## Click to paint at current brush position
@export var paint_now: bool = false:
	set(v):
		if v and Engine.is_editor_hint():
			_paint_vegetation()

## Clear all vegetation children
@export var clear_all: bool = false:
	set(v):
		if v and Engine.is_editor_hint():
			_clear_vegetation()

# Internal state
var _preview_mesh: MeshInstance3D
var _nature_lib: MeshLibrary
var _recent_positions: Array[Vector3] = []

# Vegetation categories by item name patterns
const TREE_PATTERNS = ["Tree", "Pine", "Oak", "Birch", "Spruce", "Cypress"]
const ROCK_PATTERNS = ["Rock", "Boulder"]
const BUSH_PATTERNS = ["Bush"]
const GRASS_PATTERNS = ["Grass"]

func _ready() -> void:
	if Engine.is_editor_hint():
		_load_nature_library()
		_create_preview()

func _load_nature_library() -> void:
	_nature_lib = load("res://nature_meshlib.tres") as MeshLibrary
	if not _nature_lib:
		push_warning("VegetationBrush: Could not load nature_meshlib.tres")

func _create_preview() -> void:
	# Create a circle preview mesh to show brush area
	if _preview_mesh:
		_preview_mesh.queue_free()
	
	_preview_mesh = MeshInstance3D.new()
	var circle = CylinderMesh.new()
	circle.top_radius = brush_radius
	circle.bottom_radius = brush_radius
	circle.height = 0.05
	circle.radial_segments = 32
	_preview_mesh.mesh = circle
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 0.3, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_preview_mesh.material_override = mat
	
	add_child(_preview_mesh)
	_preview_mesh.position = Vector3.ZERO

func _update_preview() -> void:
	if _preview_mesh and _preview_mesh.mesh is CylinderMesh:
		var circle = _preview_mesh.mesh as CylinderMesh
		circle.top_radius = brush_radius
		circle.bottom_radius = brush_radius

func _get_available_items() -> Array[int]:
	## Returns item IDs from the nature library based on current filter settings
	var items: Array[int] = []
	
	if not _nature_lib:
		return items
	
	for id in _nature_lib.get_item_list():
		var item_name = _nature_lib.get_item_name(id)
		var include = false
		
		if include_trees:
			for pattern in TREE_PATTERNS:
				if item_name.contains(pattern):
					include = true
					break
		
		if include_rocks and not include:
			for pattern in ROCK_PATTERNS:
				if item_name.contains(pattern):
					include = true
					break
		
		if include_bushes and not include:
			for pattern in BUSH_PATTERNS:
				if item_name.contains(pattern):
					include = true
					break
		
		if include_grass and not include:
			for pattern in GRASS_PATTERNS:
				if item_name.contains(pattern):
					include = true
					break
		
		if include:
			items.append(id)
	
	return items

func _paint_vegetation() -> void:
	## Paint vegetation at current position
	if not _nature_lib:
		push_error("No nature library loaded!")
		return
	
	var items = _get_available_items()
	if items.is_empty():
		push_warning("No vegetation types selected!")
		return
	
	var world = get_world_3d()
	if not world:
		return
	
	var space_state = world.direct_space_state
	if not space_state:
		return
	
	# Place multiple items within brush radius
	for i in range(density):
		# Random position within brush radius
		var angle = randf() * TAU
		var dist = randf() * brush_radius
		var offset = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var spawn_pos = global_position + offset
		
		# Check spacing
		var too_close = false
		for pos in _recent_positions:
			if spawn_pos.distance_to(pos) < min_spacing:
				too_close = true
				break
		
		if too_close:
			continue
		
		# Raycast to find ground
		var ray_origin = spawn_pos + Vector3.UP * raycast_height
		var ray_end = spawn_pos + Vector3.DOWN * raycast_height
		
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.collision_mask = paint_collision_mask
		
		var result = space_state.intersect_ray(query)
		if result.is_empty():
			continue
		
		var ground_pos = result.position
		
		# Pick a random item
		var item_id = items[randi() % items.size()]
		var mesh = _nature_lib.get_item_mesh(item_id)
		var mesh_transform = _nature_lib.get_item_mesh_transform(item_id)
		
		if not mesh:
			continue
		
		# Create mesh instance
		var instance = MeshInstance3D.new()
		instance.mesh = mesh
		instance.name = _nature_lib.get_item_name(item_id) + "_" + str(randi())
		
		# Apply random scale
		var random_scale = randf_range(scale_range.x, scale_range.y)
		
		# Apply random rotation
		var random_rot = randf() * TAU if random_rotation else 0.0
		
		# Set transform
		instance.transform = mesh_transform
		instance.global_position = ground_pos
		instance.scale *= random_scale
		instance.rotation.y = random_rot
		
		# Add as child
		add_child(instance)
		instance.owner = get_tree().edited_scene_root
		
		_recent_positions.append(ground_pos)
		
		# Keep recent positions limited
		if _recent_positions.size() > 100:
			_recent_positions.pop_front()
	
	print("Painted vegetation at ", global_position)

func _clear_vegetation() -> void:
	## Remove all vegetation children (except preview)
	for child in get_children():
		if child != _preview_mesh:
			child.queue_free()
	_recent_positions.clear()
	print("Cleared all vegetation")

# Editor input handling for brush painting
func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint():
		return
	
	# Note: Direct input handling in editor tools is limited
	# The user should use the "Paint Now" button or move the node
	# and click the button for best results
