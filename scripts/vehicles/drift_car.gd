extends VehicleBody3D
class_name DriftCar

## Core vehicle controller with momentum-based drift physics
## Implements drift-to-boost charging system with blue/orange spark tiers

# Player configuration
@export var player_index: int = 1

# Physics tuning - Arcade style
@export_group("Speed")
@export var max_speed: float = 30.0  # m/s - higher top speed
@export var engine_power: float = 3000.0  # balanced acceleration
@export var brake_power: float = 1500.0  # responsive braking
@export var reverse_power: float = 1500.0  # snappy reverse

@export_group("Steering")
@export var max_steer_angle: float = 0.6  # radians - tighter turns
@export var steer_speed: float = 3.0  # slower rise for precise control
@export var steer_return_speed: float = 10.0  # fast return to center
@export var high_speed_steer_damp: float = 0.6  # Reduce steering by 60% at max speed

@export_group("Drift")
@export var base_friction: float = 3.5  # high grip for arcade feel
@export var drift_friction: float = 1.2  # still slides when drifting
@export var drift_charge_rate: float = 1.0  # slower charge (drift is secondary)
@export var max_drift_charge: float = 2.0  # lower max
@export var min_boost_charge: float = 0.5  # minimum charge for any boost
@export var blue_boost_threshold: float = 1.0  # easier to get small boost
@export var orange_boost_threshold: float = 1.8  # max boost
@export var blue_boost_impulse: float = 2.0  # subtle boost
@export var orange_boost_impulse: float = 4.0  # noticeable but not crazy

@export_group("Downforce")
@export_group("Downforce")
@export var downforce_factor: float = 400.0  # stronger downforce for stability

# Node references
@onready var front_left_wheel: VehicleWheel3D = $FrontLeftWheel
@onready var front_right_wheel: VehicleWheel3D = $FrontRightWheel
@onready var rear_left_wheel: VehicleWheel3D = $RearLeftWheel
@onready var rear_right_wheel: VehicleWheel3D = $RearRightWheel

# State
var current_steer: float = 0.0
var drift_charge: float = 0.0
var is_drifting: bool = false
var current_speed: float = 0.0
var held_powerup: String = ""

# Boost state
enum BoostTier { NONE, BLUE, ORANGE }
var active_boost: BoostTier = BoostTier.NONE
var boost_timer: float = 0.0

# Input action names (built dynamically from player_index)
var input_accelerate: String
var input_brake: String
var input_steer_left: String
var input_steer_right: String
var input_handbrake: String
var input_use_item: String

# Signals
signal drift_started
signal drift_ended(charge: float, tier: BoostTier)
signal boost_activated(tier: BoostTier)
signal powerup_collected(powerup_name: String)
signal powerup_used(powerup_name: String)


func _ready() -> void:
  # Build input action names based on player index
  var prefix = "p%d_" % player_index
  input_accelerate = prefix + "accelerate"
  input_brake = prefix + "brake"
  input_steer_left = prefix + "steer_left"
  input_steer_right = prefix + "steer_right"
  input_handbrake = prefix + "handbrake"
  input_use_item = prefix + "use_item"
  
  # Initialize wheel friction
  _set_all_wheel_friction(base_friction)


func _physics_process(delta: float) -> void:
  current_speed = linear_velocity.length()
  
  _handle_input(delta)
  _apply_downforce()
  _update_boost(delta)


func _handle_input(delta: float) -> void:
  # Throttle and brake
  var throttle = Input.get_action_strength(input_accelerate)
  var brake_input = Input.get_action_strength(input_brake)
  var handbrake = Input.is_action_pressed(input_handbrake)
  
  # Steering input
  var steer_input = Input.get_action_strength(input_steer_left) - Input.get_action_strength(input_steer_right)
  
  # Reduce steering angle at high speeds to prevent spinouts
  var speed_damp = 1.0 - (clamp(current_speed / max_speed, 0.0, 1.0) * high_speed_steer_damp)
  var target_steer = steer_input * max_steer_angle * speed_damp
  
  var active_steer_speed = steer_speed
  if steer_input == 0.0:
    active_steer_speed = steer_return_speed
    
  current_steer = lerp(current_steer, target_steer, active_steer_speed * delta)
  steering = current_steer
  
  # Apply engine force (negated because our visual front is -Z)
  # Determine if we're moving forward or backward relative to car facing
  var forward_dir = -global_transform.basis.z
  var moving_forward = linear_velocity.dot(forward_dir) > 0.5
  var moving_backward = linear_velocity.dot(forward_dir) < -0.5
  var nearly_stopped = current_speed < 1.0
  
  if throttle > 0.0:
    # Accelerate forward
    engine_force = -throttle * engine_power
    brake = 0.0
  elif brake_input > 0.0:
    if moving_forward and not nearly_stopped:
      # Moving forward - apply brakes
      brake = brake_input * brake_power
      engine_force = 0.0
    else:
      # Stopped or moving backward - reverse
      engine_force = brake_input * reverse_power
      brake = 0.0
  else:
    engine_force = 0.0
    brake = 0.0
  
  # Drift handling
  _handle_drift(delta, handbrake)
  
  # Powerup use
  if Input.is_action_just_pressed(input_use_item) and held_powerup != "":
    _use_powerup()


func _handle_drift(delta: float, handbrake: bool) -> void:
  var velocity_based_friction = clamp(current_speed / max_speed, 0.2, 1.0)
  
  if handbrake and current_speed > 2.0:
    # Enter/continue drift
    if not is_drifting:
      is_drifting = true
      drift_started.emit()
    
    # Reduce rear wheel friction for slide
    var drift_slip = drift_friction * velocity_based_friction
    rear_left_wheel.wheel_friction_slip = drift_slip
    rear_right_wheel.wheel_friction_slip = drift_slip
    
    # Charge up boost meter
    drift_charge = min(drift_charge + drift_charge_rate * delta, max_drift_charge)
    
  elif is_drifting:
    # Released drift - apply boost if charged enough
    is_drifting = false
    
    var tier = _get_boost_tier(drift_charge)
    drift_ended.emit(drift_charge, tier)
    
    if tier != BoostTier.NONE:
      _apply_boost(tier)
    
    # Reset
    drift_charge = 0.0
    _set_rear_wheel_friction(base_friction)
  else:
    # Normal driving - restore friction
    _set_rear_wheel_friction(base_friction)


func _get_boost_tier(charge: float) -> BoostTier:
  if charge >= orange_boost_threshold:
    return BoostTier.ORANGE
  elif charge >= blue_boost_threshold:
    return BoostTier.BLUE
  elif charge >= min_boost_charge:
    return BoostTier.BLUE  # Minimum viable boost
  return BoostTier.NONE


func _apply_boost(tier: BoostTier) -> void:
  active_boost = tier
  boost_timer = 0.3  # Short boost duration
  
  var impulse_strength: float
  match tier:
    BoostTier.BLUE:
      impulse_strength = blue_boost_impulse
    BoostTier.ORANGE:
      impulse_strength = orange_boost_impulse
    _:
      return
  
    # Apply forward impulse (our visual front is -Z due to model rotation)
  var forward_dir = -global_transform.basis.z
  apply_central_impulse(forward_dir * impulse_strength * mass)
  boost_activated.emit(tier)


func _update_boost(delta: float) -> void:
  if active_boost != BoostTier.NONE:
    boost_timer -= delta
    if boost_timer <= 0.0:
      active_boost = BoostTier.NONE


func _apply_downforce() -> void:
  # Apply artificial gravity based on speed to keep car grounded
  var downforce = downforce_factor * (current_speed / max_speed)
  apply_central_force(Vector3.DOWN * downforce)


func _set_all_wheel_friction(friction: float) -> void:
  if front_left_wheel:
    front_left_wheel.wheel_friction_slip = friction
  if front_right_wheel:
    front_right_wheel.wheel_friction_slip = friction
  _set_rear_wheel_friction(friction)


func _set_rear_wheel_friction(friction: float) -> void:
  if rear_left_wheel:
    rear_left_wheel.wheel_friction_slip = friction
  if rear_right_wheel:
    rear_right_wheel.wheel_friction_slip = friction


func _use_powerup() -> void:
  powerup_used.emit(held_powerup)
  held_powerup = ""


func collect_powerup(powerup_name: String) -> void:
  held_powerup = powerup_name
  powerup_collected.emit(powerup_name)


## Apply spin effect (e.g., from elastic band hit)
func apply_spin(degrees: float) -> void:
  var torque_impulse = Vector3.UP * deg_to_rad(degrees) * mass * 10.0
  apply_torque_impulse(torque_impulse)


## Get normalized drift charge (0.0 - 1.0)
func get_drift_charge_normalized() -> float:
  return drift_charge / max_drift_charge


## Get current boost tier for visual effects
func get_current_boost_tier() -> BoostTier:
  return active_boost
