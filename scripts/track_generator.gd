extends Node3D

@export var path_node: Path3D
@export var csg_polygon: CSGPolygon3D
@export_group("Generation Settings")
@export var radius: float = 150.0
@export var num_points: int = 50
@export var randomness: float = 30.0
@export var seed_value: int = 0  # 0 for random

func _ready() -> void:
  if seed_value != 0:
    seed(seed_value)
  else:
    randomize()
  
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
    printerr("TrackGenerator: No PathNode assigned!")
    return
  
  var curve = Curve3D.new()
  curve.bake_interval = 2.0 # Smoothness resolution
  
  # Generate mostly straight track with gentle curves
  var track_length = radius * 2.0  # Total length of the straight section
  var spacing = track_length / float(num_points)
  
  for i in range(num_points):
    var progress = float(i) / float(num_points)
    
    # Main direction: mostly along Z-axis (straight)
    var z = progress * track_length - track_length / 2.0
    
    # Convex curve - consistent arc to one side (like a C-shape)
    # Using a quadratic function for smooth, gradual arc
    # Peaks in the middle, returns to 0 at ends
    var arc_factor = 4.0 * progress * (1.0 - progress)  # Parabola: 0 at start/end, 1 at middle
    var x = arc_factor * randomness * 1.2  # Smooth arc to the right
    
    # Keep track perfectly level
    var y = 0.0
    
    var pos = Vector3(x, y, z)
    
    # Calculate proper tangent for smooth curves
    # Derivative of the parabolic arc: 4(1 - 2*progress)
    var dx = 4.0 * (1.0 - 2.0 * progress) * randomness * 1.2 / float(num_points)
    var dz = track_length / float(num_points)  # Constant forward movement
    
    var tangent_dir = Vector3(dx, 0, dz).normalized()
    
    # Longer handles for smoother curves
    var control_len = spacing * 0.8
    var in_handle = -tangent_dir * control_len
    var out_handle = tangent_dir * control_len
    
    curve.add_point(pos, in_handle, out_handle)
  
  path_node.curve = curve
  
  # Force CSG update
  if csg_polygon:
    csg_polygon.path_node = path_node.get_path()
    csg_polygon.path_local = true
  
  # Move Player Car to start
  var player_car = get_node_or_null("PlayerCar")
  if player_car:
    var start_pos = curve.get_point_position(0)
    start_pos.y += 1.5  # Raise above track surface
    
    # Face backward along the track (reversed)
    var forward_dir = (curve.get_point_position(1) - start_pos).normalized()
    var basis = Basis.looking_at(-forward_dir, Vector3.UP)  # Negative for backward facing
    player_car.transform = Transform3D(basis, start_pos)
  
  print("Track Generated. Length: %.1f, Points: %d" % [track_length, num_points])

func _setup_keyboard_inputs() -> void:
  # Setup P1 inputs (WASD + Space)
  _add_key_mapping("p1_accelerate", KEY_W)
  _add_key_mapping("p1_brake", KEY_S)
  _add_key_mapping("p1_steer_left", KEY_A)
  _add_key_mapping("p1_steer_right", KEY_D)
  _add_key_mapping("p1_handbrake", KEY_SPACE)
  _add_key_mapping("p1_use_item", KEY_E)

func _add_key_mapping(action_name: String, key_code: int) -> void:
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
