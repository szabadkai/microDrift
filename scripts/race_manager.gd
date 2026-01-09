extends Node
class_name RaceManager

## Race Manager - Handles checkpoints, laps, and race completion
## Add this to your track scene and connect checkpoints to it

# ════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ════════════════════════════════════════════════════════════════════════════

@export_group("Race Settings")
## Total number of laps to complete the race
@export var total_laps: int = 3
## Total number of checkpoints in the track (including start/finish)
@export var checkpoint_count: int = 1
## Enable countdown before race starts
@export var enable_countdown: bool = true
## Countdown duration in seconds
@export var countdown_seconds: int = 3

@export_group("Debug")
@export var debug_logging: bool = true

# ════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ════════════════════════════════════════════════════════════════════════════

signal race_started
signal countdown_tick(seconds_remaining: int)
signal checkpoint_passed(car: Node3D, checkpoint_index: int, lap: int)
signal lap_completed(car: Node3D, lap: int, lap_time: float)
signal race_finished(car: Node3D, total_time: float, position: int)
signal all_cars_finished

# ════════════════════════════════════════════════════════════════════════════
# RACE STATE
# ════════════════════════════════════════════════════════════════════════════

enum RaceState { WAITING, COUNTDOWN, RACING, FINISHED }
var current_state: RaceState = RaceState.WAITING

# Per-car race data
# Dictionary[Node3D, CarRaceData]
var car_race_data: Dictionary = {}

# Finish order tracking
var finish_order: Array[Node3D] = []

# Time tracking
var race_start_time: float = 0.0
var countdown_timer: float = 0.0

# ════════════════════════════════════════════════════════════════════════════
# CAR RACE DATA CLASS
# ════════════════════════════════════════════════════════════════════════════

class CarRaceData:
	var current_lap: int = 0
	var last_checkpoint: int = -1
	var lap_start_time: float = 0.0
	var lap_times: Array[float] = []
	var best_lap_time: float = INF
	var total_time: float = 0.0
	var finished: bool = false
	var finish_position: int = 0

# ════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Auto-detect and connect checkpoints
	_find_and_connect_checkpoints()
	
	# Start countdown if enabled, otherwise start immediately
	if enable_countdown:
		call_deferred("start_countdown")
	else:
		call_deferred("start_race")


func _process(delta: float) -> void:
	match current_state:
		RaceState.COUNTDOWN:
			_process_countdown(delta)
		RaceState.RACING:
			pass  # Racing is handled by checkpoint signals

# ════════════════════════════════════════════════════════════════════════════
# CHECKPOINT SETUP
# ════════════════════════════════════════════════════════════════════════════

func _find_and_connect_checkpoints() -> void:
	var checkpoints = _find_all_checkpoints(get_parent())
	
	if checkpoints.is_empty():
		if debug_logging:
			print("[RaceManager] No checkpoints found - race will use lap counting only")
		checkpoint_count = 1  # Just start/finish
		return
	
	# Sort by index
	checkpoints.sort_custom(func(a, b): return a.index < b.index)
	
	checkpoint_count = checkpoints.size()
	
	for checkpoint in checkpoints:
		checkpoint.checkpoint_passed.connect(_on_checkpoint_passed)
		if debug_logging:
			print("[RaceManager] Connected checkpoint %d (start/finish: %s)" % [
				checkpoint.index, checkpoint.is_start_finish
			])


func _find_all_checkpoints(node: Node) -> Array[Checkpoint]:
	var result: Array[Checkpoint] = []
	
	if node is Checkpoint:
		result.append(node)
	
	for child in node.get_children():
		result.append_array(_find_all_checkpoints(child))
	
	return result

# ════════════════════════════════════════════════════════════════════════════
# RACE FLOW
# ════════════════════════════════════════════════════════════════════════════

func start_countdown() -> void:
	current_state = RaceState.COUNTDOWN
	countdown_timer = countdown_seconds
	
	# Freeze all cars during countdown
	_set_all_cars_frozen(true)
	
	if debug_logging:
		print("[RaceManager] Countdown started: %d seconds" % countdown_seconds)


func _process_countdown(delta: float) -> void:
	var previous_second = int(countdown_timer)
	countdown_timer -= delta
	var current_second = int(countdown_timer)
	
	# Emit signal when second changes
	if current_second != previous_second and current_second >= 0:
		countdown_tick.emit(current_second + 1)
		if debug_logging:
			print("[RaceManager] Countdown: %d" % (current_second + 1))
	
	# Countdown finished
	if countdown_timer <= 0:
		start_race()


func start_race() -> void:
	current_state = RaceState.RACING
	race_start_time = Time.get_ticks_msec() / 1000.0
	
	# Unfreeze all cars
	_set_all_cars_frozen(false)
	
	# Initialize all registered cars
	for car in car_race_data.keys():
		var data = car_race_data[car] as CarRaceData
		data.current_lap = 0
		data.last_checkpoint = -1
		data.lap_start_time = race_start_time
		data.lap_times.clear()
		data.finished = false
	
	race_started.emit()
	
	if debug_logging:
		print("[RaceManager] RACE STARTED!")


func _set_all_cars_frozen(frozen: bool) -> void:
	for car in car_race_data.keys():
		if car is VehicleBody3D:
			car.set_physics_process(not frozen)
			if frozen:
				car.linear_velocity = Vector3.ZERO
				car.angular_velocity = Vector3.ZERO

# ════════════════════════════════════════════════════════════════════════════
# CHECKPOINT HANDLING
# ════════════════════════════════════════════════════════════════════════════

func _on_checkpoint_passed(car: Node3D, checkpoint_index: int) -> void:
	if current_state != RaceState.RACING:
		return
	
	# Register car if not already tracked
	if not car_race_data.has(car):
		register_car(car)
	
	var data = car_race_data[car] as CarRaceData
	
	if data.finished:
		return  # Already finished
	
	# Validate checkpoint order
	var expected_next = (data.last_checkpoint + 1) % checkpoint_count
	
	if checkpoint_index != expected_next:
		if debug_logging:
			print("[RaceManager] %s hit checkpoint %d but expected %d - ignored" % [
				car.name, checkpoint_index, expected_next
			])
		return
	
	# Valid checkpoint
	data.last_checkpoint = checkpoint_index
	
	if debug_logging:
		print("[RaceManager] %s passed checkpoint %d (lap %d)" % [
			car.name, checkpoint_index, data.current_lap + 1
		])
	
	checkpoint_passed.emit(car, checkpoint_index, data.current_lap + 1)
	
	# Check if this completes a lap (checkpoint 0 is start/finish)
	if checkpoint_index == 0 and data.last_checkpoint != -1:
		_complete_lap(car, data)


func _complete_lap(car: Node3D, data: CarRaceData) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var lap_time = current_time - data.lap_start_time
	
	data.lap_times.append(lap_time)
	data.current_lap += 1
	data.lap_start_time = current_time
	
	if lap_time < data.best_lap_time:
		data.best_lap_time = lap_time
	
	if debug_logging:
		print("[RaceManager] %s completed lap %d in %.2fs (best: %.2fs)" % [
			car.name, data.current_lap, lap_time, data.best_lap_time
		])
	
	lap_completed.emit(car, data.current_lap, lap_time)
	
	# Check if race is complete for this car
	if data.current_lap >= total_laps:
		_car_finished(car, data)


func _car_finished(car: Node3D, data: CarRaceData) -> void:
	data.finished = true
	data.total_time = Time.get_ticks_msec() / 1000.0 - race_start_time
	
	finish_order.append(car)
	data.finish_position = finish_order.size()
	
	if debug_logging:
		print("[RaceManager] %s FINISHED in position %d! Time: %.2fs" % [
			car.name, data.finish_position, data.total_time
		])
	
	race_finished.emit(car, data.total_time, data.finish_position)
	
	# Check if all cars have finished
	var all_finished = true
	for check_car in car_race_data.keys():
		if not (car_race_data[check_car] as CarRaceData).finished:
			all_finished = false
			break
	
	if all_finished:
		current_state = RaceState.FINISHED
		all_cars_finished.emit()
		if debug_logging:
			print("[RaceManager] ALL CARS FINISHED!")

# ════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ════════════════════════════════════════════════════════════════════════════

## Register a car to be tracked in the race
func register_car(car: Node3D) -> void:
	if not car_race_data.has(car):
		car_race_data[car] = CarRaceData.new()
		if debug_logging:
			print("[RaceManager] Registered car: %s" % car.name)


## Get current lap for a car (1-indexed for display)
func get_current_lap(car: Node3D) -> int:
	if car_race_data.has(car):
		return (car_race_data[car] as CarRaceData).current_lap + 1
	return 1


## Get race data for a car
func get_car_data(car: Node3D) -> CarRaceData:
	if car_race_data.has(car):
		return car_race_data[car]
	return null


## Get elapsed race time
func get_race_time() -> float:
	if current_state == RaceState.RACING:
		return Time.get_ticks_msec() / 1000.0 - race_start_time
	return 0.0


## Get current lap time for a car
func get_current_lap_time(car: Node3D) -> float:
	if car_race_data.has(car) and current_state == RaceState.RACING:
		var data = car_race_data[car] as CarRaceData
		return Time.get_ticks_msec() / 1000.0 - data.lap_start_time
	return 0.0


## Format time as MM:SS.ms
func format_time(seconds: float) -> String:
	var minutes = int(seconds) / 60
	var secs = fmod(seconds, 60.0)
	return "%d:%05.2f" % [minutes, secs]
