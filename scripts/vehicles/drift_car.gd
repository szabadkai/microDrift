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
@export var max_speed: float = 32.0  ## Maximum velocity in m/s
@export var engine_power: float = 250.0  ## Forward acceleration force
@export var brake_power: float = 100.0  ## Brake force
@export var reverse_power: float = 120.0  ## Reverse acceleration

# ════════════════════════════════════════════════════════════════════════════
# STEERING TUNING
# ════════════════════════════════════════════════════════════════════════════

@export_group("Steering")
@export var max_steer_angle: float = 0.25  ## Max wheel angle (radians) - reduced for realistic turning
@export var steer_speed: float = 4.0  ## Rate of steering input rise
@export var steer_return_speed: float = 12.0  ## Rate of steering return to center
## In DRIFTING, steering controls angular velocity instead of wheel angle
@export var drift_angular_speed: float = 4.0  ## Rotation rate while drifting (rad/s)

# ════════════════════════════════════════════════════════════════════════════
# DRIFT TUNING - THE CORE EXPLICIT DRIFT SETTINGS
# ════════════════════════════════════════════════════════════════════════════

@export_group("Drift")
## Minimum speed to enter drift state
@export var min_drift_speed: float = 5.0
## Minimum speed to maintain drift state (drops out if below)
@export var min_drift_exit_speed: float = 3.0
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
# NATURAL SLIP SETTINGS - Grip loss at high speed cornering
# ════════════════════════════════════════════════════════════════════════════

@export_group("Natural Slip")
## Speed threshold where natural slip can start occurring (m/s)
@export var slip_speed_threshold: float = 15.0
## How aggressively grip is lost when above threshold (higher = easier to slip)
@export var slip_sensitivity: float = 1.5
## Minimum lateral friction during natural slip (prevents total spinout)
@export var slip_min_friction: float = 2.0

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
## How quickly brakes ramp up (higher = smoother)
@export var brake_smoothing: float = 8.0
## Brake input threshold for wheel lock-up (0.7 = 70% brake locks wheels)
@export var brake_lock_threshold: float = 0.7
## How much grip is reduced during brake lock (0.3 = 30% of normal grip)
@export var brake_lock_grip: float = 0.3

# ════════════════════════════════════════════════════════════════════════════
# OFF-ROAD SLOWDOWN - Encourages staying on track
# ════════════════════════════════════════════════════════════════════════════

@export_group("Off-Road")
## Collision layer for road surfaces (GridMap roads should use this layer)
@export_flags_3d_physics var road_collision_layer: int = 2
## Drag force applied when off-road (higher = more slowdown)
@export var offroad_drag: float = 8.0
## Acceleration multiplier when off-road (0.3 = 30% power)
@export var offroad_acceleration: float = 0.3
## Maximum speed when off-road (as fraction of max_speed)
@export var offroad_max_speed_factor: float = 0.4

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
var smoothed_brake: float = 0.0  ## Smoothed brake value to prevent jerky stops
var is_brake_locked: bool = false  ## True when wheels are locked during hard braking
var is_on_road: bool = true  ## True when driving on road surface

## Visual yaw offset for mesh (exaggerated drift angle)
var visual_yaw_offset: float = 0.0

# DEBUG: Timer to limit debug spam
var _debug_timer: float = 0.0

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
  
  # DEBUG: Check if input actions exist
  print("=== DriftCar Input Debug ===")
  print("Player index: ", player_index)
  print("Looking for action: ", input_accelerate, " - exists: ", InputMap.has_action(input_accelerate))
  print("Looking for action: ", input_brake, " - exists: ", InputMap.has_action(input_brake))
  print("Looking for action: ", input_steer_left, " - exists: ", InputMap.has_action(input_steer_left))
  print("Looking for action: ", input_steer_right, " - exists: ", InputMap.has_action(input_steer_right))
  print("Looking for action: ", input_handbrake, " - exists: ", InputMap.has_action(input_handbrake))


func _physics_process(delta: float) -> void:
  current_speed = linear_velocity.length()
  
  # Check what surface we're on
  _update_surface_detection()
  
  # DEBUG: Log inputs for first 3 seconds
  _debug_timer += delta
  if _debug_timer < 3.0 and fmod(_debug_timer, 0.5) < delta:
    var accel = Input.get_action_strength(input_accelerate)
    var brake_in = Input.get_action_strength(input_brake)
    var steer_l = Input.get_action_strength(input_steer_left)
    var steer_r = Input.get_action_strength(input_steer_right)
    print("INPUT: accel=", accel, " brake=", brake_in, " steerL=", steer_l, " steerR=", steer_r, " speed=", current_speed)
  
  # State machine update
  match current_state:
    VehicleState.NORMAL:
      _process_normal_state(delta)
      # Spawn tire marks if brakes are locked
      if is_brake_locked:
        _spawn_tire_marks()
    VehicleState.DRIFTING:
      _process_drifting_state(delta)
      _spawn_tire_marks()  # Spawn marks while drifting
    VehicleState.BOOSTING:
      _process_boosting_state(delta)
  
  # Always apply downforce and lateral control
  _apply_downforce()
  _apply_lateral_friction(delta)
  _apply_offroad_drag(delta)
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
  
  # Check if drift button released or speed too low
  var handbrake = Input.is_action_pressed(input_handbrake)
  if not handbrake or current_speed < min_drift_exit_speed:
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
  
  # Reset tire marks so this drift session starts completely fresh
  _reset_tire_marks()
  
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
  ## When brakes locked: Reduced grip for sliding
  ## At high speed + hard steering: Natural slip occurs
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
      # In NORMAL state, start with full grip
      friction = lateral_friction_normal
      
      # Check if brakes are locked
      if is_brake_locked:
        friction = lateral_friction_normal * brake_lock_grip
      else:
        # NATURAL SLIP: Reduce grip at high speed when steering hard
        # This creates realistic "breaking loose" when cornering aggressively
        if current_speed > slip_speed_threshold:
          var steer_input = Input.get_action_strength(input_steer_left) - Input.get_action_strength(input_steer_right)
          var steer_intensity = abs(steer_input)
          
          # How far above slip threshold are we? (0 at threshold, 1 at max_speed)
          var speed_excess = (current_speed - slip_speed_threshold) / (max_speed - slip_speed_threshold)
          speed_excess = clamp(speed_excess, 0.0, 1.0)
          
          # Slip factor: high when both speed and steering are high
          var slip_factor = speed_excess * steer_intensity * slip_sensitivity
          slip_factor = clamp(slip_factor, 0.0, 1.0)
          
          # Reduce friction based on slip factor
          # Interpolate between full friction and minimum slip friction
          friction = lerp(lateral_friction_normal, slip_min_friction, slip_factor)
  
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
  var forward_speed = linear_velocity.dot(forward_dir)
  var moving_forward = forward_speed > 0.5
  var nearly_stopped = current_speed < 1.0
  
  # Determine effective max speed (boosted during BOOSTING state, reduced off-road)
  var effective_max_speed = max_speed
  if current_state == VehicleState.BOOSTING:
    effective_max_speed = max_speed * boost_max_speed_bonus
  elif not is_on_road:
    effective_max_speed = max_speed * offroad_max_speed_factor
  
  # Apply off-road power reduction
  var surface_power_factor = _get_offroad_power_factor()
  var final_power = power_factor * surface_power_factor
  
  # Reset VehicleBody3D brake - we'll handle braking with direct forces
  brake = 0.0
  
  # Apply engine force
  if throttle > 0.0:
    # Only accelerate if below max speed
    if current_speed < effective_max_speed:
      engine_force = -throttle * engine_power * final_power
    else:
      engine_force = 0.0
  elif brake_input > 0.0:
    if moving_forward and not nearly_stopped:
      # Braking while moving forward
      # Use direct force at center of mass instead of wheel brakes to avoid pitching
      engine_force = 0.0
      
      # Check if brake is hard enough to lock wheels
      var was_brake_locked = is_brake_locked
      is_brake_locked = brake_input >= brake_lock_threshold and current_speed > 5.0
      
      # Reset tire marks when brake lock starts (new skid)
      if is_brake_locked and not was_brake_locked:
        _reset_tire_marks()
      
      # Smooth the brake force
      var target_brake_force = brake_input * brake_power * mass
      smoothed_brake = lerp(smoothed_brake, target_brake_force, brake_smoothing * delta)
      
      # Apply braking force opposite to velocity direction (at center of mass = no pitch)
      var brake_force = -linear_velocity.normalized() * smoothed_brake
      apply_central_force(brake_force)
    else:
      # Reverse
      engine_force = brake_input * reverse_power
      smoothed_brake = 0.0
      if is_brake_locked:
        _reset_tire_marks()
      is_brake_locked = false
  else:
    engine_force = 0.0
    smoothed_brake = 0.0
    if is_brake_locked:
      _reset_tire_marks()
    is_brake_locked = false


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
# TIRE MARKS
# ════════════════════════════════════════════════════════════════════════════

var _tire_mark_timer: float = 0.0
var _last_left_pos: Vector3 = Vector3.ZERO
var _last_right_pos: Vector3 = Vector3.ZERO
var _tire_mark_active: bool = false
const TIRE_MARK_INTERVAL: float = 0.025

func _spawn_tire_marks() -> void:
  _tire_mark_timer += get_physics_process_delta_time()
  if _tire_mark_timer < TIRE_MARK_INTERVAL:
    return
  _tire_mark_timer = 0.0
  
  var left_pos = rear_left_wheel.global_position if rear_left_wheel else global_position
  var right_pos = rear_right_wheel.global_position if rear_right_wheel else global_position
  
  # Raycast down to find ground surface for each wheel
  var left_ground = _get_ground_position(left_pos)
  var right_ground = _get_ground_position(right_pos)
  
  # Only draw if we have previous positions and are moving
  if _tire_mark_active and current_speed > 2.0:
    if left_ground != Vector3.ZERO and _last_left_pos != Vector3.ZERO:
      _create_tire_mark_segment(_last_left_pos, left_ground)
    if right_ground != Vector3.ZERO and _last_right_pos != Vector3.ZERO:
      _create_tire_mark_segment(_last_right_pos, right_ground)
  
  _last_left_pos = left_ground
  _last_right_pos = right_ground
  _tire_mark_active = true


func _get_ground_position(wheel_pos: Vector3) -> Vector3:
  ## Raycast down from wheel position to find the ground surface
  var space_state = get_world_3d().direct_space_state
  if not space_state:
    return Vector3.ZERO
  
  # Cast from slightly above wheel to below
  var ray_origin = wheel_pos + Vector3.UP * 0.5
  var ray_end = wheel_pos + Vector3.DOWN * 2.0
  
  var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
  query.exclude = [self]  # Don't hit the car itself
  query.collision_mask = 0xFFFFFFFF  # Hit everything
  
  var result = space_state.intersect_ray(query)
  
  if result:
    # Return position slightly above the hit point to avoid z-fighting
    return result.position + Vector3.UP * 0.005
  
  return Vector3.ZERO


func _create_tire_mark_segment(from_pos: Vector3, to_pos: Vector3) -> void:
  var direction = to_pos - from_pos
  var length = direction.length()
  if length < 0.01:
    return
  
  var mesh_instance = MeshInstance3D.new()
  var box = BoxMesh.new()
  box.size = Vector3(0.1, 0.01, length + 0.05)  # Slight overlap for continuity
  mesh_instance.mesh = box
  
  var mat = StandardMaterial3D.new()
  mat.albedo_color = Color(0.05, 0.05, 0.05, 0.9)
  mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  mesh_instance.material_override = mat
  
  # Position at midpoint - use actual Y from raycasted positions
  var mid = (from_pos + to_pos) / 2.0
  mesh_instance.global_position = mid
  
  # Orient along direction (horizontal rotation)
  mesh_instance.rotation.y = atan2(direction.x, direction.z)
  
  # Handle slopes - tilt the mark to match ground angle
  var horizontal_dir = Vector3(direction.x, 0, direction.z).normalized()
  if horizontal_dir.length_squared() > 0.01:
    var pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())
    mesh_instance.rotation.x = pitch
  
  get_tree().root.add_child(mesh_instance)
  
  # Fade and destroy
  var tween = create_tween()
  tween.tween_property(mat, "albedo_color:a", 0.0, 1.0).set_delay(3.0)
  tween.tween_callback(mesh_instance.queue_free)


func _reset_tire_marks() -> void:
  _tire_mark_active = false
  _last_left_pos = Vector3.ZERO
  _last_right_pos = Vector3.ZERO


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


## Check if currently on road surface
func is_on_road_surface() -> bool:
  return is_on_road


# ════════════════════════════════════════════════════════════════════════════
# SURFACE DETECTION & OFF-ROAD HANDLING
# ════════════════════════════════════════════════════════════════════════════

func _update_surface_detection() -> void:
  ## Raycast down to detect what surface we're driving on
  ## Road surfaces should be on collision layer 2
  
  var space_state = get_world_3d().direct_space_state
  if not space_state:
    is_on_road = true  # Default to on-road if we can't check
    return
  
  # Cast from center of car downward
  var ray_origin = global_position + Vector3.UP * 0.5
  var ray_end = global_position + Vector3.DOWN * 2.0
  
  var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
  query.exclude = [self]
  # Check for road layer specifically
  query.collision_mask = road_collision_layer
  
  var result = space_state.intersect_ray(query)
  
  # If we hit something on the road layer, we're on road
  is_on_road = result.size() > 0


func _apply_offroad_drag(_delta: float) -> void:
  ## Apply drag force when off-road to significantly slow the car
  ## This encourages players to stay on the track
  
  if is_on_road:
    return  # No extra drag on road
  
  if current_speed < 0.5:
    return  # Don't apply at very low speeds
  
  # Calculate off-road max speed
  var offroad_max = max_speed * offroad_max_speed_factor
  
  # If we're above the off-road max speed, apply strong braking
  if current_speed > offroad_max:
    var excess_speed_factor = (current_speed - offroad_max) / (max_speed - offroad_max)
    var drag_multiplier = 1.0 + excess_speed_factor * 2.0  # Extra drag when way over limit
    var drag_force = -linear_velocity.normalized() * offroad_drag * mass * drag_multiplier
    apply_central_force(drag_force)
  else:
    # Even below max, apply some drag to make it feel sluggish
    var drag_force = -linear_velocity.normalized() * offroad_drag * 0.5 * mass
    apply_central_force(drag_force)


func _get_offroad_power_factor() -> float:
  ## Returns acceleration multiplier based on surface
  ## Called by _handle_throttle to reduce power off-road
  if is_on_road:
    return 1.0
  return offroad_acceleration
