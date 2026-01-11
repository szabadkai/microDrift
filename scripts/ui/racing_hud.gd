extends CanvasLayer
class_name RacingHUD

## Modern Racing HUD with graphical RPM, Drift, and Speed displays
## Auto-detects DriftCar and CarAudioManager in the scene

# References
var player_car: DriftCar
var car_audio: Node  # CarAudioManager

# UI Element References - updated paths for corner layout
@onready var rpm_gauge: Control = $RPMGauge
@onready var drift_bar: Control = $DriftBar
@onready var speed_display: Control = $SpeedDisplay

# Cached values for smooth animations
var displayed_rpm: float = 800.0
var displayed_drift: float = 0.0
var displayed_speed: float = 0.0


func _ready() -> void:
	# Auto-detect player car after a short delay
	await get_tree().create_timer(0.1).timeout
	_find_player_car()


func _find_player_car() -> void:
	# Search entire scene tree for a DriftCar
	var root = get_tree().root
	for child in root.get_children():
		var car = _find_drift_car_recursive(child)
		if car:
			player_car = car
			# Find CarAudioManager as child of car
			for car_child in car.get_children():
				if "current_rpm" in car_child:  # Check for the property we need
					car_audio = car_child
					print("RacingHUD found audio manager: %s" % car_audio.name)
					break
			print("RacingHUD found car: %s (audio: %s)" % [player_car.name, car_audio != null])
			return
	
	if not player_car:
		printerr("RacingHUD: No DriftCar found in scene!")


func _find_drift_car_recursive(node: Node) -> DriftCar:
	if node is DriftCar:
		return node
	
	for child in node.get_children():
		var result = _find_drift_car_recursive(child)
		if result:
			return result
	
	return null


func _process(delta: float) -> void:
	if not player_car:
		_find_player_car()  # Keep trying to find car
		return
	
	_update_rpm_gauge(delta)
	_update_drift_bar(delta)
	_update_speed_display(delta)


func _update_rpm_gauge(delta: float) -> void:
	if not rpm_gauge:
		return
	
	# Get RPM from audio manager or estimate from speed
	var target_rpm: float = 800.0
	var max_rpm: float = 6000.0
	
	if car_audio and "current_rpm" in car_audio:
		target_rpm = car_audio.current_rpm
		max_rpm = car_audio.max_rpm if "max_rpm" in car_audio else 6000.0
	else:
		# Fallback: estimate RPM from speed
		var speed_ratio = clamp(player_car.current_speed / player_car.max_speed, 0.0, 1.0)
		target_rpm = 800.0 + speed_ratio * 5200.0
	
	# Smooth the display
	displayed_rpm = lerp(displayed_rpm, target_rpm, 10.0 * delta)
	
	# Update the gauge
	rpm_gauge.set_rpm(displayed_rpm, max_rpm)


func _update_drift_bar(delta: float) -> void:
	if not drift_bar:
		return
	
	var target_drift = player_car.get_drift_charge_normalized()
	var is_drifting = player_car.current_state == DriftCar.VehicleState.DRIFTING
	var is_boosting = player_car.current_state == DriftCar.VehicleState.BOOSTING
	
	# Smooth the display
	displayed_drift = lerp(displayed_drift, target_drift, 8.0 * delta)
	
	# Update the bar
	drift_bar.set_drift_charge(displayed_drift, is_drifting, is_boosting)


func _update_speed_display(delta: float) -> void:
	if not speed_display:
		return
	
	var speed_kmh = player_car.current_speed * 3.6
	
	# Smooth the display
	displayed_speed = lerp(displayed_speed, speed_kmh, 12.0 * delta)
	
	# Update the display
	speed_display.set_speed(displayed_speed)
