extends VehicleBody3D
class_name DriftCar

## Explicit Drift Vehicle Controller
## Implements state machine: NORMAL → DRIFTING → BOOSTING
## Drift is EXPLICIT (manual lateral velocity control), not emergent (wheel physics)

# ════════════════════════════════════════════════════════════════════════════
# STATE MACHINE
# ════════════════════════════════════════════════════════════════════════════

enum VehicleState { NORMAL, DRIFTING, BOOSTING }
var current_state: VehicleState = VehicleState.NORMAL

# ════════════════════════════════════════════════════════════════════════════
# PLAYER CONFIGURATION
# ════════════════════════════════════════════════════════════════════════════

@export var player_index: int = 1

# ════════════════════════════════════════════════════════════════════════════
# SPEED TUNING
# ════════════════════════════════════════════════════════════════════════════

@export_group("Speed")
@export var max_speed: float = 22.0  ## Maximum velocity in m/s
@export var engine_power: float = 250.0  ## Forward acceleration force
@export var brake_power: float = 500.0  ## Brake force
@export var reverse_power: float = 120.0  ## Reverse acceleration

# ════════════════════════════════════════════════════════════════════════════
# STEERING TUNING
# ════════════════════════════════════════════════════════════════════════════

@export_group("Steering")
@export var max_steer_angle: float = 0.35  ## Max wheel angle (radians) - low to force drifting
@export var steer_speed: float = 4.0  ## Rate of steering input rise
@export var steer_return_speed: float = 12.0  ## Rate of steering return to center
## In DRIFTING, steering controls angular velocity instead of wheel angle
@export var drift_angular_speed: float = 4.0  ## Rotation rate while drifting (rad/s)

# ════════════════════════════════════════════════════════════════════════════
# DRIFT TUNING - THE CORE EXPLICIT DRIFT SETTINGS
# ════════════════════════════════════════════════════════════════════════════

@export_group("Drift")
## Minimum speed to enter drift state
@export var min_drift_speed: float = 3.0
## Lateral friction in NORMAL state (high = grippy, car follows velocity)
@export var lateral_friction_normal: float = 12.0
## Lateral friction in DRIFTING state (low = slidey, car drifts sideways)
@export var lateral_friction_drifting: float = 0.3
## Forward acceleration multiplier during drift (reduced for balance)
@export var drift_acceleration_factor: float = 0.5
## Minimum drift angle (degrees) to accumulate charge
@export var drift_angle_threshold: float = 15.0
## Charge accumulated per second at ideal drift conditions
@export var charge_rate: float = 1.2
## Maximum drift charge
@export var max_charge: float = 2.0
## Minimum charge required to trigger any boost
@export var min_boost_charge: float = 0.3

# ════════════════════════════════════════════════════════════════════════════
# BOOST TUNING
# ════════════════════════════════════════════════════════════════════════════

@export_group("Boost")
## Impulse strength per unit of charge
@export var boost_impulse_strength: float = 15.0
## Duration of BOOSTING state (seconds)
@export var boost_duration: float = 0.4
## Max speed multiplier during boost
@export var boost_max_speed_bonus: float = 1.3
## Steering reduction during boost (0.5 = 50% steering authority)
@export var boost_steer_reduction: float = 0.6
## Visual FOV kick (can be read by camera)
@export var boost_fov_kick: float = 10.0

# ════════════════════════════════════════════════════════════════════════════
# STABILITY
# ════════════════════════════════════════════════════════════════════════════

@export_group("Stability")
## Artificial downforce to keep car grounded
@export var downforce_factor: float = 500.0

# ════════════════════════════════════════════════════════════════════════════
# BOOST TIERS (FOR VISUAL FEEDBACK)
# ════════════════════════════════════════════════════════════════════════════

enum BoostTier { NONE, BLUE, ORANGE }
@export_group("Boost Tiers")
@export var blue_boost_threshold: float = 0.8  ## Charge needed for blue sparks
@export var orange_boost_threshold: float = 1.6  ## Charge needed for orange sparks

# ════════════════════════════════════════════════════════════════════════════
# NODE REFERENCES
# ════════════════════════════════════════════════════════════════════════════

@onready var front_left_wheel: VehicleWheel3D = $FrontLeftWheel
@onready var front_right_wheel: VehicleWheel3D = $FrontRightWheel
@onready var rear_left_wheel: VehicleWheel3D = $RearLeftWheel
@onready var rear_right_wheel: VehicleWheel3D = $RearRightWheel
@onready var car_model: Node3D = $CarModel

# ════════════════════════════════════════════════════════════════════════════
# RUNTIME STATE
# ════════════════════════════════════════════════════════════════════════════

var current_steer: float = 0.0  ## Smoothed steering input
var drift_charge: float = 0.0  ## Current charge level
var current_speed: float = 0.0  ## Cached speed magnitude
var boost_timer: float = 0.0  ## Remaining boost time
var drift_angle: float = 0.0  ## Current angle between forward and velocity
var active_boost_tier: BoostTier = BoostTier.NONE
var held_powerup: String = ""

## Visual yaw offset for mesh (exaggerated drift angle)
var visual_yaw_offset: float = 0.0

# Input action names
var input_accelerate: String
var input_brake: String
var input_steer_left: String
var input_steer_right: String
var input_handbrake: String
var input_use_item: String

# ════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ════════════════════════════════════════════════════════════════════════════

signal drift_started
signal drift_ended(charge: float, tier: BoostTier)
signal boost_activated(tier: BoostTier)
signal state_changed(new_state: VehicleState)
signal powerup_collected(powerup_name: String)
signal powerup_used(powerup_name: String)


# ════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
  # Build player-specific input action names
  var prefix = "p%d_" % player_index
  input_accelerate = prefix + "accelerate"
  input_brake = prefix + "brake"
  input_steer_left = prefix + "steer_left"
  input_steer_right = prefix + "steer_right"
  input_handbrake = prefix + "handbrake"
  input_use_item = prefix + "use_item"


func _physics_process(delta: float) -> void:
  current_speed = linear_velocity.length()
  
  # State machine update
  match current_state:
    VehicleState.NORMAL:
      _process_normal_state(delta)
    VehicleState.DRIFTING:
      _process_drifting_state(delta)
    VehicleState.BOOSTING:
      _process_boosting_state(delta)
  
  # Always apply downforce and lateral control
  _apply_downforce()
  _apply_lateral_friction(delta)
  _update_visual_yaw(delta)
  
  # Powerup use (available in any state)
  if Input.is_action_just_pressed(input_use_item) and held_powerup != "":
    _use_powerup()


# ════════════════════════════════════════════════════════════════════════════
# STATE: NORMAL
# ════════════════════════════════════════════════════════════════════════════

func _process_normal_state(delta: float) -> void:
  # Standard steering via wheel angle
  _handle_steering(delta, 1.0)
  _apply_steering_to_wheels()
  
  # Standard throttle/brake
  _handle_throttle(delta, 1.0)
  
  # Check transition to DRIFTING
  var handbrake = Input.is_action_pressed(input_handbrake)
  # DEBUG: Uncomment to see drift entry conditions
  if handbrake:
    print("Handbrake pressed! Speed: ", current_speed, " / min: ", min_drift_speed, " - State: ", current_state)
  if handbrake and current_speed > min_drift_speed:
    _enter_drifting_state()


# ════════════════════════════════════════════════════════════════════════════
# STATE: DRIFTING
# ════════════════════════════════════════════════════════════════════════════

func _process_drifting_state(delta: float) -> void:
  # In DRIFTING: steering controls angular velocity, not wheel angle
  var steer_input = Input.get_action_strength(input_steer_left) - Input.get_action_strength(input_steer_right)
  
  # Apply angular velocity for rotation
  # This makes the car rotate without necessarily changing velocity direction
  var target_angular = steer_input * drift_angular_speed
  angular_velocity.y = lerp(angular_velocity.y, target_angular, 8.0 * delta)
  
  # Wheels still turn visually but with less effect
  _handle_steering(delta, 0.3)
  _apply_steering_to_wheels()
  
  # Reduced throttle during drift
  _handle_throttle(delta, drift_acceleration_factor)
  
  # Calculate drift angle for charge accumulation
  _update_drift_angle()
  _accumulate_charge(delta)
  
  # Check if drift button released
  var handbrake = Input.is_action_pressed(input_handbrake)
  if not handbrake:
    _exit_drifting_state()


func _update_drift_angle() -> void:
  ## Calculate angle between vehicle forward direction and velocity direction
  ## This is the core metric for "how sideways" we're going
  
  var forward_dir = -global_transform.basis.z  # Our forward is -Z
  var velocity_horizontal = Vector3(linear_velocity.x, 0, linear_velocity.z)
  
  if velocity_horizontal.length_squared() < 0.1:
    drift_angle = 0.0
    return
  
  velocity_horizontal = velocity_horizontal.normalized()
  forward_dir.y = 0
  forward_dir = forward_dir.normalized()
  
  # Signed angle in degrees
  drift_angle = rad_to_deg(forward_dir.signed_angle_to(velocity_horizontal, Vector3.UP))


func _accumulate_charge(delta: float) -> void:
  ## Only accumulate charge when drifting at a significant angle
  ## Charge scales with both angle and speed for rewarding aggressive drifts
  
  var angle_abs = abs(drift_angle)
  
  # Must exceed threshold to charge
  if angle_abs < drift_angle_threshold:
    return
  
  if current_speed < min_drift_speed:
    return
  
  # Angle factor: 0 at threshold, 1 at 45°, caps at ~90°
  var angle_factor = clamp((angle_abs - drift_angle_threshold) / (45.0 - drift_angle_threshold), 0.0, 1.5)
  
  # Speed factor: 0 at min_drift_speed, 1 at max_speed
  var speed_factor = clamp((current_speed - min_drift_speed) / (max_speed - min_drift_speed), 0.0, 1.0)
  
  # Accumulate charge
  drift_charge = min(drift_charge + delta * charge_rate * angle_factor * (0.5 + speed_factor * 0.5), max_charge)


# ════════════════════════════════════════════════════════════════════════════
# STATE: BOOSTING
# ════════════════════════════════════════════════════════════════════════════

func _process_boosting_state(delta: float) -> void:
  # During boost: reduced steering, ignore drift input
  _handle_steering(delta, boost_steer_reduction)
  _apply_steering_to_wheels()
  
  # Full throttle feels right during boost
  _handle_throttle(delta, 1.0)
  
  # Count down boost timer
  boost_timer -= delta
  if boost_timer <= 0.0:
    _exit_boosting_state()


# ════════════════════════════════════════════════════════════════════════════
# STATE TRANSITIONS
# ════════════════════════════════════════════════════════════════════════════

func _enter_drifting_state() -> void:
  print(">>> ENTERING DRIFT STATE <<<")
  current_state = VehicleState.DRIFTING
  drift_charge = 0.0
  
  # ARCADE: Reduce rear wheel friction for slides (but not too low)
  _set_rear_wheel_friction(0.4)
  
  # ARCADE: Apply initial rotation kick based on steering direction
  # This makes the car SNAP into a sideways drift angle immediately
  var steer_input = Input.get_action_strength(input_steer_left) - Input.get_action_strength(input_steer_right)
  if abs(steer_input) > 0.1:
    # Moderate kick - enough to initiate drift without spinning
    var kick_strength = 1.5 * sign(steer_input)
    angular_velocity.y = kick_strength
  
  drift_started.emit()
  state_changed.emit(VehicleState.DRIFTING)


func _exit_drifting_state() -> void:
  print(">>> EXITING DRIFT STATE <<< charge: ", drift_charge)
  var tier = _get_boost_tier(drift_charge)
  drift_ended.emit(drift_charge, tier)
  
  # Restore rear wheel friction
  _set_rear_wheel_friction(3.5)
  
  if drift_charge >= min_boost_charge:
    _enter_boosting_state(tier)
  else:
    current_state = VehicleState.NORMAL
    state_changed.emit(VehicleState.NORMAL)
  
  drift_charge = 0.0


func _enter_boosting_state(tier: BoostTier) -> void:
  current_state = VehicleState.BOOSTING
  active_boost_tier = tier
  boost_timer = boost_duration
  
  # Apply forward impulse (direction = vehicle forward, not velocity)
  var forward_dir = -global_transform.basis.z
  var charge_normalized = clamp(drift_charge / max_charge, 0.0, 1.0)
  var impulse = forward_dir * boost_impulse_strength * charge_normalized * mass
  apply_central_impulse(impulse)
  
  boost_activated.emit(tier)
  state_changed.emit(VehicleState.BOOSTING)


func _exit_boosting_state() -> void:
  current_state = VehicleState.NORMAL
  active_boost_tier = BoostTier.NONE
  state_changed.emit(VehicleState.NORMAL)


func _get_boost_tier(charge: float) -> BoostTier:
  if charge >= orange_boost_threshold:
    return BoostTier.ORANGE
  elif charge >= blue_boost_threshold:
    return BoostTier.BLUE
  elif charge >= min_boost_charge:
    return BoostTier.BLUE
  return BoostTier.NONE


# ════════════════════════════════════════════════════════════════════════════
# CORE PHYSICS: EXPLICIT LATERAL VELOCITY CONTROL
# ════════════════════════════════════════════════════════════════════════════

func _apply_lateral_friction(_delta: float) -> void:
  ## THE KEY MECHANIC: Manually control how much the car can slide sideways
  ## In NORMAL: Strong damping keeps car aligned with velocity
  ## In DRIFTING: Weak damping lets car slide sideways
  ## Using FORCE-BASED approach to work WITH physics engine
  
  var right_dir = global_transform.basis.x
  
  # Get lateral velocity component (how much we're sliding sideways)
  var lateral_speed = linear_velocity.dot(right_dir)
  
  # Skip if barely moving sideways
  if abs(lateral_speed) < 0.01:
    return
  
  # Choose friction based on state
  var friction: float
  match current_state:
    VehicleState.DRIFTING:
      friction = lateral_friction_drifting
    VehicleState.BOOSTING:
      friction = (lateral_friction_normal + lateral_friction_drifting) / 2.0
    _:
      friction = lateral_friction_normal
  
  # Apply a counter-force to reduce lateral velocity
  var damping_force = -right_dir * lateral_speed * friction * mass
  apply_central_force(damping_force)


# ════════════════════════════════════════════════════════════════════════════
# INPUT HANDLING
# ════════════════════════════════════════════════════════════════════════════

func _handle_steering(delta: float, authority: float) -> void:
  ## Process steering input with smoothing and authority modifier
  
  var steer_input = Input.get_action_strength(input_steer_left) - Input.get_action_strength(input_steer_right)
  
  # Reduce steering at high speeds for stability
  var speed_factor = clamp(current_speed / max_speed, 0.0, 1.0)
  var speed_reduction = 1.0 - (speed_factor * 0.4)  # 40% reduction at max speed
  
  var target_steer = steer_input * max_steer_angle * speed_reduction * authority
  
  # Smooth steering transitions
  var active_speed = steer_speed if steer_input != 0.0 else steer_return_speed
  current_steer = lerp(current_steer, target_steer, active_speed * delta)


func _apply_steering_to_wheels() -> void:
  ## Apply current steering angle to front wheels
  steering = current_steer


func _handle_throttle(delta: float, power_factor: float) -> void:
  ## Process throttle and brake input
  
  var throttle = Input.get_action_strength(input_accelerate)
  var brake_input = Input.get_action_strength(input_brake)
  
  var forward_dir = -global_transform.basis.z
  var moving_forward = linear_velocity.dot(forward_dir) > 0.5
  var nearly_stopped = current_speed < 1.0
  
  # Determine effective max speed (boosted during BOOSTING state)
  var effective_max_speed = max_speed
  if current_state == VehicleState.BOOSTING:
    effective_max_speed = max_speed * boost_max_speed_bonus
  
  # Apply engine force
  if throttle > 0.0:
    # Only accelerate if below max speed
    if current_speed < effective_max_speed:
      engine_force = -throttle * engine_power * power_factor
    else:
      engine_force = 0.0
    brake = 0.0
  elif brake_input > 0.0:
    if moving_forward and not nearly_stopped:
      # Braking while moving forward
      brake = brake_input * brake_power
      engine_force = 0.0
    else:
      # Reverse
      engine_force = brake_input * reverse_power
      brake = 0.0
  else:
    engine_force = 0.0
    brake = 0.0


# ════════════════════════════════════════════════════════════════════════════
# STABILITY & VISUALS
# ════════════════════════════════════════════════════════════════════════════

func _apply_downforce() -> void:
  ## Artificial gravity to keep the car grounded at high speeds
  var speed_factor = clamp(current_speed / max_speed, 0.0, 1.0)
  apply_central_force(Vector3.DOWN * downforce_factor * speed_factor)


func _update_visual_yaw(delta: float) -> void:
  ## Optionally exaggerate the visual rotation of the car mesh
  ## This allows dramatic drift angles while keeping physics stable
  
  if car_model == null:
    return
  
  var target_offset: float = 0.0
  
  if current_state == VehicleState.DRIFTING:
    # Exaggerate the drift angle for visual drama
    target_offset = deg_to_rad(drift_angle) * 0.3  # 30% exaggeration
  
  visual_yaw_offset = lerp(visual_yaw_offset, target_offset, 8.0 * delta)
  
  # Apply to car model (note: model is already rotated 180° in scene)
  # We add a small yaw offset for visual flair
  # car_model.rotation.y = PI + visual_yaw_offset  # Disabled - could cause issues


# ════════════════════════════════════════════════════════════════════════════
# WHEEL FRICTION CONTROL
# ════════════════════════════════════════════════════════════════════════════

func _set_rear_wheel_friction(friction: float) -> void:
  if rear_left_wheel:
    rear_left_wheel.wheel_friction_slip = friction
  if rear_right_wheel:
    rear_right_wheel.wheel_friction_slip = friction


# ════════════════════════════════════════════════════════════════════════════
# POWERUP SYSTEM
# ════════════════════════════════════════════════════════════════════════════

func _use_powerup() -> void:
  powerup_used.emit(held_powerup)
  held_powerup = ""


func collect_powerup(powerup_name: String) -> void:
  held_powerup = powerup_name
  powerup_collected.emit(powerup_name)


# ════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ════════════════════════════════════════════════════════════════════════════

## Apply spin effect (e.g., from elastic band hit)
func apply_spin(degrees: float) -> void:
  var torque_impulse = Vector3.UP * deg_to_rad(degrees) * mass * 10.0
  apply_torque_impulse(torque_impulse)


## Get normalized drift charge (0.0 - 1.0)
func get_drift_charge_normalized() -> float:
  return drift_charge / max_charge


## Get current boost tier for visual effects
func get_current_boost_tier() -> BoostTier:
  return active_boost_tier


## Get current vehicle state
func get_current_state() -> VehicleState:
  return current_state


## Get current drift angle in degrees
func get_drift_angle() -> float:
  return drift_angle


## Check if currently boosting (for camera FOV effects)
func is_boosting() -> bool:
  return current_state == VehicleState.BOOSTING
