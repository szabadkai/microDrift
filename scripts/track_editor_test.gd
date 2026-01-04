extends Node3D
## Simple scene controller for track editor test
## Handles scene reset with Shift+R

func _ready() -> void:
  _setup_keyboard_inputs()

func _input(event: InputEvent) -> void:
  if event is InputEventKey and event.pressed:
    # Shift+R to reset scene
    if event.keycode == KEY_R and event.shift_pressed:
      get_tree().reload_current_scene()

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
