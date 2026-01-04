@tool
extends Node

const ASSET_PATH = "res://racing-kit/"
const MESHLIB_OUTPUT_PATH = "res://racing_kit_meshlib.tres"
const INDIVIDUAL_ASSETS_PATH = "res://scenes/assets/road/"
const BASE_ROAD_MODEL = "roadStraight.gltf"

var calculated_cell_size = 2.0

func _ready():
  if not Engine.is_editor_hint():
    generate_mesh_library()
    await get_tree().create_timer(1.0).timeout
    get_tree().quit()

func generate_mesh_library():
  print("--- Starting MeshLibrary Generation (Direct) ---")
  
  # Create export directory if it doesn't exist
  if not DirAccess.dir_exists_absolute(INDIVIDUAL_ASSETS_PATH):
    DirAccess.make_dir_recursive_absolute(INDIVIDUAL_ASSETS_PATH)
  
  # 1. Calculate the minimum grid cell size from the base road
  var base_scene = load(ASSET_PATH + BASE_ROAD_MODEL)
  if base_scene is PackedScene:
    var base_instance = base_scene.instantiate()
    var base_mesh_instance = _find_mesh_instance(base_instance)
    if base_mesh_instance and base_mesh_instance.mesh:
      var aabb = base_mesh_instance.mesh.get_aabb()
      calculated_cell_size = min(aabb.size.x, aabb.size.z)
      print("Calculated Cell Size: %.2f (from %s)" % [calculated_cell_size, BASE_ROAD_MODEL])
    base_instance.queue_free()
  
  var mesh_lib = MeshLibrary.new()
  var dir = DirAccess.open(ASSET_PATH)
  
  if not dir:
    printerr("ERROR: Could not open asset path: ", ASSET_PATH)
    return

  dir.list_dir_begin()
  var file_name = dir.get_next()
  var item_id = 0
  
  while file_name != "":
    if file_name.ends_with(".gltf") and file_name.to_lower().contains("road"):
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
          
          # Center the mesh on XZ plane
          var offset = Vector3(-(aabb.position.x + aabb.size.x / 2.0), 0, -(aabb.position.z + aabb.size.z / 2.0))
          var xform = Transform3D().translated(offset)
          mesh_lib.set_item_mesh_transform(item_id, xform)
          
          # Add collision shape
          var col_shape = original_mesh.create_trimesh_shape()
          if col_shape:
            mesh_lib.set_item_shapes(item_id, [col_shape])
          
          # Also save individual asset scene
          var item_scene_root = Node3D.new()
          item_scene_root.name = file_name.get_basename()
          
          var new_mesh_instance = MeshInstance3D.new()
          new_mesh_instance.name = "Mesh"
          new_mesh_instance.mesh = original_mesh
          new_mesh_instance.transform.origin = offset
          item_scene_root.add_child(new_mesh_instance)
          new_mesh_instance.owner = item_scene_root
          
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
          
          var grid_cells = Vector2(aabb.size.x / calculated_cell_size, aabb.size.z / calculated_cell_size)
          print("Processed %s (Occupies: %.1fx%.1f cells)" % [file_name, grid_cells.x, grid_cells.y])
          item_id += 1
        
        instance.queue_free()
    
    file_name = dir.get_next()
  
  if item_id > 0:
    var error = ResourceSaver.save(mesh_lib, MESHLIB_OUTPUT_PATH)
    if error == OK:
      print("--- SUCCESS ---")
      print("MeshLibrary: %s" % MESHLIB_OUTPUT_PATH)
      print("Individual Assets: %s" % INDIVIDUAL_ASSETS_PATH)
      print("Total items: %d" % item_id)
      print("RECOMMENDED GridMap cell_size: Vector3(%.2f, 0.5, %.2f)" % [calculated_cell_size, calculated_cell_size])
    else:
      printerr("ERROR saving MeshLibrary: ", error)
  else:
    print("--- NO ITEMS FOUND ---")

func _find_mesh_instance(node: Node) -> MeshInstance3D:
  if node is MeshInstance3D:
    return node
  for child in node.get_children():
    var result = _find_mesh_instance(child)
    if result: return result
  return null
