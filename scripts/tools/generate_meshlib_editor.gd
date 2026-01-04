@tool
extends EditorScript

const ASSET_PATH = "res://racing-Kit/"
const MESHLIB_OUTPUT_PATH = "res://racing_kit_meshlib.tres"
const BASE_ROAD_MODEL = "roadStraight.gltf"

func _run():
  print("--- Starting MeshLibrary Generation ---")
  
  # Calculate cell size
  var calculated_cell_size = 2.0
  var base_scene = load(ASSET_PATH + BASE_ROAD_MODEL)
  if base_scene is PackedScene:
    var base_instance = base_scene.instantiate()
    var base_mesh_instance = _find_mesh_instance(base_instance)
    if base_mesh_instance and base_mesh_instance.mesh:
      var aabb = base_mesh_instance.mesh.get_aabb()
      calculated_cell_size = min(aabb.size.x, aabb.size.z)
      print("Calculated Cell Size: %.2f" % calculated_cell_size)
    base_instance.queue_free()
  
  var mesh_lib = MeshLibrary.new()
  var dir = DirAccess.open(ASSET_PATH)
  
  if not dir:
    printerr("ERROR: Could not open: ", ASSET_PATH)
    return
  
  dir.list_dir_begin()
  var file_name = dir.get_next()
  var item_id = 0
  
  while file_name != "":
    if file_name.ends_with(".gltf") and file_name.to_lower().contains("road"):
      var scene = load(ASSET_PATH + file_name)
      
      if scene is PackedScene:
        var instance = scene.instantiate()
        var mesh_instance = _find_mesh_instance(instance)
        
        if mesh_instance and mesh_instance.mesh:
          var mesh = mesh_instance.mesh
          var aabb = mesh.get_aabb()
          
          mesh_lib.create_item(item_id)
          mesh_lib.set_item_name(item_id, file_name.get_basename())
          mesh_lib.set_item_mesh(item_id, mesh)
          
          # Center offset
          var offset = Vector3(-(aabb.position.x + aabb.size.x / 2.0), 0, -(aabb.position.z + aabb.size.z / 2.0))
          mesh_lib.set_item_mesh_transform(item_id, Transform3D().translated(offset))
          
          # Collision - array format is [shape, transform, shape2, transform2, ...]
          var shape = mesh.create_trimesh_shape()
          if shape:
            var shape_transform = Transform3D().translated(offset)
            mesh_lib.set_item_shapes(item_id, [shape, shape_transform])
          
          print("Added: %s" % file_name)
          item_id += 1
        
        instance.queue_free()
    
    file_name = dir.get_next()
  
  if item_id > 0:
    var error = ResourceSaver.save(mesh_lib, MESHLIB_OUTPUT_PATH)
    if error == OK:
      print("✓ SUCCESS: Saved %d items to %s" % [item_id, MESHLIB_OUTPUT_PATH])
      print("RECOMMENDED cell_size: Vector3(%.2f, 0.5, %.2f)" % [calculated_cell_size, calculated_cell_size])
    else:
      printerr("ERROR: Failed to save (code: %d)" % error)
  else:
    print("No items found!")

func _find_mesh_instance(node: Node) -> MeshInstance3D:
  if node is MeshInstance3D:
    return node
  for child in node.get_children():
    var result = _find_mesh_instance(child)
    if result: return result
  return null
