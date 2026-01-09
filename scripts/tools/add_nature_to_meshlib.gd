@tool
extends Node

## Creates a MeshLibrary from Free Forest Nature Pack assets
## Run this from the editor or headless to generate nature_meshlib.tres

const NATURE_PACK_PATH = "res://Free Forest Nature Pack/"
const MESHLIB_PATH = "res://nature_meshlib.tres"

# Scale factor to match racing kit scale (racing kit uses ~1 unit = 1 meter)
# Nature pack assets may need scaling to fit the micro scale
const SCALE_FACTOR = 0.3  # Adjust if assets look too big/small

# Asset paths to include (selective list for variety without bloat)
const NATURE_ASSETS = [
	# Trees - one of each type for variety
	"Trees/Pine/Flat_Tree_Pine_medium.glb",
	"Trees/Oak/Flat_Tree_Oak_medium.glb",
	"Trees/Birch/Flat_Tree_Birch_medium.glb",
	"Trees/Spruce/Flat_Tree_Spruce_medium.glb",
	"Trees/Cypress/Flat_Tree_Cypress_medium.glb",
	"Trees/Simple Trees/Flat_Tree_round_medium.glb",
	"Trees/Park Trees/Flat_Tree_Park_medium.glb",
	
	# Rocks
	"Rocks/Flat_Rock_01.glb",
	"Rocks/Flat_Rock_02.glb",
	"Rocks/Flat_Rock_05.glb",
	"Rocks/Flat_Boulder_01.glb",
	"Rocks/Flat_Boulder_02.glb",
	
	# Bushes
	"Bushes/Flat_Bush_small.glb",
	"Bushes/Flat_Bush_medium.glb",
	"Bushes/Flat_Bush_large.glb",
	"Bushes/Flat_Bush_with_Flowers.glb",
	
	# Grass
	"Grass/Flat_Grass_small.glb",
	"Grass/Flat_Grass_medium.glb",
	"Grass/Flat_Grass_Clumps_small.glb",
	
	# Mushrooms
	"Mushrooms/Flat_Mushroom_red.glb",
	"Mushrooms/Flat_Mushroom_yellow.glb",
	
	# Extras (logs, stumps)
	"Extras/Flat_Log.glb",
	"Extras/Flat_Stump.glb",
]

func _ready():
	if not Engine.is_editor_hint():
		add_nature_to_meshlib()
		await get_tree().create_timer(1.0).timeout
		get_tree().quit()

func add_nature_to_meshlib():
	print("=== Creating Nature Pack MeshLibrary ===")
	
	# Create a new mesh library
	var mesh_lib = MeshLibrary.new()
	var next_id = 0
	var added_count = 0
	
	for asset_path in NATURE_ASSETS:
		var full_path = NATURE_PACK_PATH + asset_path
		
		# Check if file exists
		if not ResourceLoader.exists(full_path):
			print("Skipping (not found): ", asset_path)
			continue
		
		var scene = load(full_path)
		if not scene is PackedScene:
			print("Skipping (not a scene): ", asset_path)
			continue
		
		var instance = scene.instantiate()
		var mesh_instance = _find_mesh_instance(instance)
		
		if mesh_instance and mesh_instance.mesh:
			var original_mesh = mesh_instance.mesh
			var aabb = original_mesh.get_aabb()
			
			# Extract name from filename
			var item_name = asset_path.get_file().get_basename()
			
			# Create MeshLibrary item
			mesh_lib.create_item(next_id)
			mesh_lib.set_item_name(next_id, item_name)
			mesh_lib.set_item_mesh(next_id, original_mesh)
			
			# Center and scale the mesh
			var scaled_aabb = aabb
			var center_offset = Vector3(
				-(aabb.position.x + aabb.size.x / 2.0),
				0,  # Keep Y at ground level
				-(aabb.position.z + aabb.size.z / 2.0)
			)
			
			# Apply scale and offset
			var xform = Transform3D()
			xform = xform.scaled(Vector3.ONE * SCALE_FACTOR)
			xform.origin = center_offset * SCALE_FACTOR
			mesh_lib.set_item_mesh_transform(next_id, xform)
			
			# Add collision shape
			var col_shape = original_mesh.create_trimesh_shape()
			if col_shape:
				# Note: Collision shapes also need to be transformed
				mesh_lib.set_item_shapes(next_id, [col_shape])
			
			print("Added: ", item_name, " (ID: ", next_id, ") - Size: ", aabb.size * SCALE_FACTOR)
			
			next_id += 1
			added_count += 1
		
		instance.queue_free()
	
	if added_count > 0:
		var error = ResourceSaver.save(mesh_lib, MESHLIB_PATH)
		if error == OK:
			print("=== SUCCESS ===")
			print("Created ", MESHLIB_PATH, " with ", added_count, " nature items")
			print("Scale factor: ", SCALE_FACTOR)
		else:
			printerr("ERROR saving MeshLibrary: ", error)
	else:
		print("=== NO ITEMS ADDED ===")
		print("No nature assets were found or loaded")

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result: 
			return result
	return null
