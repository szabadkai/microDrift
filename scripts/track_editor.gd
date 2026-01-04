@tool
extends Node3D

## Track Editor - Place Marker3D nodes as children to define track control points
## The track will smoothly interpolate between these markers

@export var path_node: Path3D
@export var csg_polygon: CSGPolygon3D
@export_group("Generation Settings")
@export var smoothness: float = 0.5  ## How smooth the curves are (0-1)
@export var auto_close_loop: bool = true  ## Automatically connect last point to first
@export_range(1.0, 10.0) var subdivisions: int = 4  ## Points to generate between each marker

## Regenerate track when parameters change
@export var regenerate: bool = false:
  set(value):
    if value and Engine.is_editor_hint():
      generate_track()
      regenerate = false

func _ready() -> void:
  if not Engine.is_editor_hint():
    _setup_keyboard_inputs()
    
    # Start race music
    MusicManager.play_track(MusicManager.MusicTrack.RANDOM)
  
  generate_track()

func _input(event: InputEvent) -> void:
  if event is InputEventKey and event.pressed:
    if event.keycode == KEY_R and event.meta_pressed:
      get_tree().reload_current_scene()

func generate_track() -> void:
  if not path_node:
    printerr("TrackEditor: No Path3D assigned!")
    return
  
  # Collect all Marker3D children as control points
  var markers: Array[Node3D] = []
  for child in get_children():
    if child is Marker3D:
      markers.append(child)
  
  if markers.size() < 2:
    printerr("TrackEditor: Need at least 2 Marker3D nodes as children!")
    return
  
  # Sort markers by name to ensure consistent order
  markers.sort_custom(func(a, b): return a.name < b.name)
  
  var curve = Curve3D.new()
  curve.bake_interval = 0.5
  
  # Generate smooth curve through all markers
  for i in range(markers.size()):
    var marker = markers[i]
    var pos = marker.global_position - global_position  # Convert to local space
    
    # Calculate tangent handles for smooth curves
    var prev_pos = markers[(i - 1 + markers.size()) % markers.size()].global_position - global_position
    var next_pos = markers[(i + 1) % markers.size()].global_position - global_position
    
    # Tangent points toward next marker and away from previous
    var in_tangent = (pos - prev_pos).normalized()
    var out_tangent = (next_pos - pos).normalized()
    
    # Average for smooth transition
    var tangent = (in_tangent + out_tangent).normalized()
    
    # Scale tangents based on distance to neighbors
    var in_dist = pos.distance_to(prev_pos) * smoothness
    var out_dist = next_pos.distance_to(pos) * smoothness
    
    var in_handle = -tangent * in_dist * 0.5
    var out_handle = tangent * out_dist * 0.5
    
    curve.add_point(pos, in_handle, out_handle)
    
    # Add subdivisions between this marker and the next
    if i < markers.size() - 1 or auto_close_loop:
      var next_idx = (i + 1) % markers.size()
      var next_marker = markers[next_idx]
      
      for sub in range(1, subdivisions):
        var t = float(sub) / float(subdivisions)
        # Simple linear interpolation between markers
        var sub_pos = pos.lerp(next_marker.global_position - global_position, t)
        
        # Calculate tangent for subdivision
        var sub_tangent = (next_marker.global_position - global_position - pos).normalized()
        var sub_dist = pos.distance_to(next_marker.global_position - global_position) * smoothness * 0.3
        
        curve.add_point(sub_pos, -sub_tangent * sub_dist, sub_tangent * sub_dist)
  
  # Close the loop if enabled
  if auto_close_loop and markers.size() > 2:
    var first_pos = curve.get_point_position(0)
    var first_in = curve.get_point_in(0)
    var first_out = curve.get_point_out(0)
    curve.add_point(first_pos, first_in, first_out)
  
  path_node.curve = curve
  
  # Update CSG
  if csg_polygon:
    csg_polygon.path_node = path_node.get_path()
    csg_polygon.path_local = true
  
  # Position car at first marker
  if not Engine.is_editor_hint():
    var player_car = get_node_or_null("PlayerCar")
    if player_car and markers.size() > 0:
      var start_pos = markers[0].global_position
      start_pos.y += 1.5  # Raise above track surface
      
      var forward_dir = Vector3.FORWARD
      if markers.size() > 1:
        forward_dir = (markers[1].global_position - markers[0].global_position).normalized()
      
      # Face backward (as requested earlier)
      var basis = Basis.looking_at(-forward_dir, Vector3.UP)
      player_car.global_transform = Transform3D(basis, start_pos)
  
  print("Track Generated from %d markers (%d total points)" % [markers.size(), curve.point_count])

func _setup_keyboard_inputs() -> void:
  # Setup P1 inputs (WASD + Space)
  _add_key_mapping("p1_accelerate", KEY_W)
  _add_key_mapping("p1_brake", KEY_S)
  _add_key_mapping("p1_steer_left", KEY_A)
  _add_key_mapping("p1_steer_right", KEY_D)
  _add_key_mapping("p1_handbrake", KEY_SPACE)
  _add_key_mapping("p1_use_item", KEY_E)

func _add_key_mapping(action_name: String, key_code:int) -> void:
  if not InputMap.has_action(action_name):
    InputMap.add_action(action_name)
  
  # Check if key already assigned
  var events = InputMap.action_get_events(action_name)
  for event in events:
    if event is InputEventKey and event.keycode == key_code:
      return
  
  var key = InputEventKey.new()
  key.keycode = key_code
  InputMap.action_add_event(action_name, key)
