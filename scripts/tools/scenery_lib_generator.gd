@tool
extends Node

## Generates a MeshLibrary for scenery assets (trees, barriers, tents, etc.)
## Run this scene to generate the library

const ASSET_PATH = "res://racing-kit/"
const MESHLIB_OUTPUT_PATH = "res://scenery_meshlib.tres"
const INDIVIDUAL_ASSETS_PATH = "res://scenes/assets/scenery/"

# Assets to EXCLUDE from scenery (main driveable road pieces)
# We exclude generic "road" but then explicitly include decorative road elements
const EXCLUDE_PATTERNS = []

# Assets to specifically INCLUDE
# Includes decorative road elements: Border (striped curbs), Sand (run-off), Wall (barriers)
const INCLUDE_PATTERNS = [
	"tree", "grass", "tent", "barrier", "pylon", "flag", "rail", 
	"fence", "light", "billboard", "grandStand", "pits", "overhead",
	"ramp", "banner", "camera", "radar",
	# Decorative road elements - striped curbs, sand traps, walls
	"Border", "Sand", "Wall"
]

# These road patterns should still be excluded (they're driveable surfaces)
const ROAD_EXCLUDE_PATTERNS = [
	"roadStraight", "roadCornerLarge.", "roadCornerLarger.", "roadCornerSmall.",
	"roadCurved", "roadEnd", "roadStart", "roadSplit", "roadPit", "roadRamp",
	"roadBump", "roadHalf", "roadCrossing", "roadSide", "roadSkew"
]

func _ready():
	if not Engine.is_editor_hint():
		generate_mesh_library()
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()

func _should_include_asset(file_name: String) -> bool:
	var lower_name = file_name.to_lower()
	var base_name = file_name.get_basename()
	
	# First check if it matches any include pattern
	var matches_include = false
	for pattern in INCLUDE_PATTERNS:
		if lower_name.contains(pattern.to_lower()):
			matches_include = true
			break
	
	if not matches_include:
		return false
	
	# Check general exclude patterns
	for pattern in EXCLUDE_PATTERNS:
		if lower_name.contains(pattern.to_lower()):
			return false
	
	# For road items, only include decorative elements (Border, Sand, Wall)
	# Exclude main driveable surfaces
	if lower_name.contains("road"):
		# Must contain one of the decorative keywords
		var is_decorative = (
			base_name.contains("Border") or 
			base_name.contains("Sand") or 
			base_name.contains("Wall")
		)
		if not is_decorative:
			return false
	
	return true

func generate_mesh_library():
	print("--- Starting Scenery MeshLibrary Generation ---")
	
	# Create export directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(INDIVIDUAL_ASSETS_PATH):
		DirAccess.make_dir_recursive_absolute(INDIVIDUAL_ASSETS_PATH)
	
	var mesh_lib = MeshLibrary.new()
	var dir = DirAccess.open(ASSET_PATH)
	
	if not dir:
		printerr("ERROR: Could not open asset path: ", ASSET_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var item_id = 0
	
	while file_name != "":
		# Only process .gltf files (prefer gltf over glb for consistency)
		if file_name.ends_with(".gltf"):
			if _should_include_asset(file_name):
				var full_path = ASSET_PATH + file_name
				var scene = load(full_path)
				
				if scene is PackedScene:
					var instance = scene.instantiate()
					var mesh_instance = _find_mesh_instance(instance)
					
					if mesh_instance and mesh_instance.mesh:
						var original_mesh = mesh_instance.mesh
						var aabb = original_mesh.get_aabb()
						
						# Create MeshLibrary item
						mesh_lib.create_item(item_id)
						mesh_lib.set_item_name(item_id, file_name.get_basename())
						mesh_lib.set_item_mesh(item_id, original_mesh)
						
						# Center the mesh on XZ plane, keep Y at ground level
						var offset = Vector3(
							-(aabb.position.x + aabb.size.x / 2.0),
							-aabb.position.y,  # Place bottom at grid level
							-(aabb.position.z + aabb.size.z / 2.0)
						)
						var xform = Transform3D().translated(offset)
						mesh_lib.set_item_mesh_transform(item_id, xform)
						
						# Add collision shape
						var col_shape = original_mesh.create_trimesh_shape()
						if col_shape:
							mesh_lib.set_item_shapes(item_id, [col_shape])
						
						# Also save individual asset scene
						_save_individual_scene(file_name, original_mesh, col_shape, offset)
						
						print("Added: %s (Size: %.1fx%.1fx%.1f)" % [
							file_name.get_basename(), 
							aabb.size.x, aabb.size.y, aabb.size.z
						])
						item_id += 1
					
					instance.queue_free()
		
		file_name = dir.get_next()
	
	# Also check for .glb files that don't have .gltf equivalents
	dir.list_dir_begin()
	file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".glb"):
			var gltf_equivalent = file_name.replace(".glb", ".gltf")
			# Only process if no .gltf version exists
			if not dir.file_exists(gltf_equivalent):
				if _should_include_asset(file_name):
					var full_path = ASSET_PATH + file_name
					var scene = load(full_path)
					
					if scene is PackedScene:
						var instance = scene.instantiate()
						var mesh_instance = _find_mesh_instance(instance)
						
						if mesh_instance and mesh_instance.mesh:
							var original_mesh = mesh_instance.mesh
							var aabb = original_mesh.get_aabb()
							
							mesh_lib.create_item(item_id)
							mesh_lib.set_item_name(item_id, file_name.get_basename())
							mesh_lib.set_item_mesh(item_id, original_mesh)
							
							var offset = Vector3(
								-(aabb.position.x + aabb.size.x / 2.0),
								-aabb.position.y,
								-(aabb.position.z + aabb.size.z / 2.0)
							)
							var xform = Transform3D().translated(offset)
							mesh_lib.set_item_mesh_transform(item_id, xform)
							
							var col_shape = original_mesh.create_trimesh_shape()
							if col_shape:
								mesh_lib.set_item_shapes(item_id, [col_shape])
							
							_save_individual_scene(file_name, original_mesh, col_shape, offset)
							
							print("Added (GLB): %s (Size: %.1fx%.1fx%.1f)" % [
								file_name.get_basename(), 
								aabb.size.x, aabb.size.y, aabb.size.z
							])
							item_id += 1
						
						instance.queue_free()
		
		file_name = dir.get_next()
	
	if item_id > 0:
		var error = ResourceSaver.save(mesh_lib, MESHLIB_OUTPUT_PATH)
		if error == OK:
			print("--- SUCCESS ---")
			print("Scenery MeshLibrary: %s" % MESHLIB_OUTPUT_PATH)
			print("Individual Assets: %s" % INDIVIDUAL_ASSETS_PATH)
			print("Total scenery items: %d" % item_id)
			print("TIP: Use a separate GridMap with this library for scenery overlay")
		else:
			printerr("ERROR saving MeshLibrary: ", error)
	else:
		print("--- NO ITEMS FOUND ---")

func _save_individual_scene(file_name: String, mesh: Mesh, col_shape: Shape3D, offset: Vector3) -> void:
	var item_scene_root = Node3D.new()
	item_scene_root.name = file_name.get_basename()
	
	var new_mesh_instance = MeshInstance3D.new()
	new_mesh_instance.name = "Mesh"
	new_mesh_instance.mesh = mesh
	new_mesh_instance.transform.origin = offset
	item_scene_root.add_child(new_mesh_instance)
	new_mesh_instance.owner = item_scene_root
	
	if col_shape:
		var static_body = StaticBody3D.new()
		static_body.name = "StaticBody3D"
		item_scene_root.add_child(static_body)
		static_body.owner = item_scene_root
		
		var collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		collision_shape.shape = col_shape
		collision_shape.transform.origin = offset
		static_body.add_child(collision_shape)
		collision_shape.owner = item_scene_root
	
	var individual_packed = PackedScene.new()
	individual_packed.pack(item_scene_root)
	var asset_save_path = INDIVIDUAL_ASSETS_PATH + file_name.get_basename() + ".tscn"
	ResourceSaver.save(individual_packed, asset_save_path)
	item_scene_root.queue_free()

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result: return result
	return null
