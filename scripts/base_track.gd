extends Node3D
class_name BaseTrack

## Base class for all track scenes
## Provides common functionality:
## - Pause menu (ESC)
## - Scene reset (Shift+R)
## - Player input setup
## - Music playback
## - Debug HUD updates

# ════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ════════════════════════════════════════════════════════════════════════════

## Number of players to set up keyboard inputs for
@export var player_count: int = 1

## Which music track to play (or RANDOM)
@export var music_track: MusicManager.MusicTrack = MusicManager.MusicTrack.RANDOM

## Enable debug HUD updates
@export var enable_debug_hud: bool = true

# ════════════════════════════════════════════════════════════════════════════
# NODE REFERENCES (Optional - set in editor or auto-detect)
# ════════════════════════════════════════════════════════════════════════════

var pause_menu: CanvasLayer
var player_car: DriftCar

# Debug UI labels (auto-detected from DebugUI/SpeedLabel etc.)
var speed_label: Label
var drift_label: Label
var boost_label: Label

# ════════════════════════════════════════════════════════════════════════════
# PRELOADED RESOURCES
# ════════════════════════════════════════════════════════════════════════════

const PAUSE_MENU_SCENE = preload("res://scenes/ui/pause_menu.tscn")

# ════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_setup_pause_menu()
	_setup_keyboard_inputs()
	_setup_debug_hud()
	_start_music()
	
	# Call child class setup
	_on_track_ready()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Shift+R to reset scene
		if event.keycode == KEY_R and event.shift_pressed:
			get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if enable_debug_hud:
		_update_debug_hud()
	
	# Call child class process
	_on_track_process(delta)

# ════════════════════════════════════════════════════════════════════════════
# VIRTUAL METHODS (Override in child classes)
# ════════════════════════════════════════════════════════════════════════════

## Called after base track setup is complete
func _on_track_ready() -> void:
	pass


## Called every frame after debug HUD update
func _on_track_process(_delta: float) -> void:
	pass

# ════════════════════════════════════════════════════════════════════════════
# PAUSE MENU
# ════════════════════════════════════════════════════════════════════════════

func _setup_pause_menu() -> void:
	# Instantiate and add pause menu
	pause_menu = PAUSE_MENU_SCENE.instantiate()
	add_child(pause_menu)

# ════════════════════════════════════════════════════════════════════════════
# KEYBOARD INPUTS
# ════════════════════════════════════════════════════════════════════════════

func _setup_keyboard_inputs() -> void:
	# Player 1: WASD + Space
	if player_count >= 1:
		_add_key_mapping("p1_accelerate", KEY_W)
		_add_key_mapping("p1_brake", KEY_S)
		_add_key_mapping("p1_steer_left", KEY_A)
		_add_key_mapping("p1_steer_right", KEY_D)
		_add_key_mapping("p1_handbrake", KEY_SPACE)
		_add_key_mapping("p1_use_item", KEY_E)
	
	# Player 2: Arrow keys + Right Ctrl
	if player_count >= 2:
		_add_key_mapping("p2_accelerate", KEY_UP)
		_add_key_mapping("p2_brake", KEY_DOWN)
		_add_key_mapping("p2_steer_left", KEY_LEFT)
		_add_key_mapping("p2_steer_right", KEY_RIGHT)
		_add_key_mapping("p2_handbrake", KEY_CTRL)
		_add_key_mapping("p2_use_item", KEY_SHIFT)
	
	# Player 3: IJKL + U
	if player_count >= 3:
		_add_key_mapping("p3_accelerate", KEY_I)
		_add_key_mapping("p3_brake", KEY_K)
		_add_key_mapping("p3_steer_left", KEY_J)
		_add_key_mapping("p3_steer_right", KEY_L)
		_add_key_mapping("p3_handbrake", KEY_U)
		_add_key_mapping("p3_use_item", KEY_O)
	
	# Player 4: Numpad 8456 + 7
	if player_count >= 4:
		_add_key_mapping("p4_accelerate", KEY_KP_8)
		_add_key_mapping("p4_brake", KEY_KP_5)
		_add_key_mapping("p4_steer_left", KEY_KP_4)
		_add_key_mapping("p4_steer_right", KEY_KP_6)
		_add_key_mapping("p4_handbrake", KEY_KP_7)
		_add_key_mapping("p4_use_item", KEY_KP_9)


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

# ════════════════════════════════════════════════════════════════════════════
# DEBUG HUD
# ════════════════════════════════════════════════════════════════════════════

func _setup_debug_hud() -> void:
	# Auto-detect player car
	player_car = _find_drift_car(self)
	
	if not player_car:
		push_warning("BaseTrack: No DriftCar found in scene - debug HUD will be disabled")
		enable_debug_hud = false
		return
	
	# Connect to car signals for debug logging
	player_car.drift_started.connect(_on_drift_started)
	player_car.drift_ended.connect(_on_drift_ended)
	player_car.boost_activated.connect(_on_boost_activated)
	
	# Try to find debug UI labels
	var debug_ui = get_node_or_null("DebugUI")
	if debug_ui:
		speed_label = debug_ui.get_node_or_null("SpeedLabel")
		drift_label = debug_ui.get_node_or_null("DriftLabel")
		boost_label = debug_ui.get_node_or_null("BoostLabel")


func _find_drift_car(node: Node) -> DriftCar:
	if node is DriftCar:
		return node
	for child in node.get_children():
		var result = _find_drift_car(child)
		if result:
			return result
	return null


func _update_debug_hud() -> void:
	if not player_car:
		return
	
	# Speed display
	if speed_label:
		var speed_mps = player_car.current_speed
		var speed_kmh = speed_mps * 3.6
		speed_label.text = "Speed: %.1f km/h" % speed_kmh
	
	# Drift charge display
	if drift_label:
		var charge_percent = player_car.get_drift_charge_normalized() * 100.0
		drift_label.text = "Drift: %.0f%%" % charge_percent
		
		# Color the drift label based on charge tier
		if charge_percent >= 83:  # Orange threshold
			drift_label.add_theme_color_override("font_color", Color.ORANGE)
		elif charge_percent >= 50:  # Blue threshold
			drift_label.add_theme_color_override("font_color", Color.CYAN)
		else:
			drift_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Boost state
	if boost_label:
		match player_car.get_current_boost_tier():
			DriftCar.BoostTier.ORANGE:
				boost_label.text = "BOOST: ORANGE!"
				boost_label.add_theme_color_override("font_color", Color.ORANGE)
			DriftCar.BoostTier.BLUE:
				boost_label.text = "BOOST: BLUE"
				boost_label.add_theme_color_override("font_color", Color.CYAN)
			_:
				boost_label.text = "Boost: Ready"
				boost_label.add_theme_color_override("font_color", Color.WHITE)

# ════════════════════════════════════════════════════════════════════════════
# MUSIC
# ════════════════════════════════════════════════════════════════════════════

func _start_music() -> void:
	if MusicManager:
		MusicManager.play_track(music_track)

# ════════════════════════════════════════════════════════════════════════════
# CAR SIGNAL HANDLERS (for debug logging)
# ════════════════════════════════════════════════════════════════════════════

func _on_drift_started() -> void:
	print("[DEBUG] Drift started!")


func _on_drift_ended(charge: float, tier: DriftCar.BoostTier) -> void:
	print("[DEBUG] Drift ended - Charge: %.2f, Tier: %s" % [charge, DriftCar.BoostTier.keys()[tier]])


func _on_boost_activated(tier: DriftCar.BoostTier) -> void:
	print("[DEBUG] Boost activated: %s" % DriftCar.BoostTier.keys()[tier])
