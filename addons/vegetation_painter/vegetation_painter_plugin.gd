@tool
extends EditorPlugin

## Vegetation Painter Plugin
## Enables painting vegetation by clicking/dragging in the 3D viewport
## when a VegetationBrush node is selected

var _brush_node: Node3D
var _is_painting: bool = false
var _last_paint_pos: Vector3 = Vector3.ZERO
var _paint_interval: float = 0.3  # Minimum distance between paint strokes

func _enter_tree() -> void:
	print("VegetationPainter plugin loaded")

func _exit_tree() -> void:
	print("VegetationPainter plugin unloaded")

func _handles(object: Object) -> bool:
	# Handle VegetationBrush nodes
	return object is Node3D and object.get_script() and object.get_script().get_global_name() == "VegetationBrush"

func _edit(object: Object) -> void:
	_brush_node = object as Node3D

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if not _brush_node:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	
	# Handle mouse events
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_painting = true
				_paint_at_mouse(viewport_camera, mb.position)
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			else:
				_is_painting = false
				_last_paint_pos = Vector3.ZERO
	
	elif event is InputEventMouseMotion and _is_painting:
		var mm = event as InputEventMouseMotion
		_paint_at_mouse(viewport_camera, mm.position)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	return EditorPlugin.AFTER_GUI_INPUT_PASS

func _paint_at_mouse(camera: Camera3D, mouse_pos: Vector2) -> void:
	if not _brush_node or not _brush_node.has_method("_paint_at_position"):
		# Fallback: move brush and trigger paint
		var world_pos = _raycast_from_mouse(camera, mouse_pos)
		if world_pos != Vector3.ZERO:
			# Check distance from last paint
			if _last_paint_pos != Vector3.ZERO:
				var dist = world_pos.distance_to(_last_paint_pos)
				if dist < _paint_interval:
					return
			
			_brush_node.global_position = world_pos
			if _brush_node.has_method("_paint_vegetation"):
				_brush_node._paint_vegetation()
			_last_paint_pos = world_pos

func _raycast_from_mouse(camera: Camera3D, mouse_pos: Vector2) -> Vector3:
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	
	var space_state = _brush_node.get_world_3d().direct_space_state
	if not space_state:
		return Vector3.ZERO
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	# Use the brush's collision mask if available
	if _brush_node.get("paint_collision_mask"):
		query.collision_mask = _brush_node.paint_collision_mask
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	
	return Vector3.ZERO
