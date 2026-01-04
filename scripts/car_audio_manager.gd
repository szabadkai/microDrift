extends Node

## Advanced Car Audio Manager
## Realistic engine sound simulation with proper RPM modeling, gear shifting, and audio processing
## Optimized for non-fatiguing listening with proper frequency management

@export_group("Car Reference")
@export var car: VehicleBody3D

@export_group("Gear Configuration")
@export var num_gears: int = 4  # 4 equal ranges
@export var shift_up_rpm: float = 0.92  # Shift up at 92% - hold gears longer
@export var shift_down_rpm: float = 0.35  # Shift down at 35% - less downshifting
@export var rpm_drop_on_shift: float = 0.4  # Bigger RPM drop for more dramatic shifts

@export_group("Audio Tuning")
@export var min_pitch: float = 0.4  # Lower idle pitch for deeper sound
@export var max_pitch: float = 1.4  # Lower max pitch - less high frequency
@export var base_volume_db: float = -12.0  # Base engine volume
@export var pitch_slew_time: float = 0.15  # 150ms exponential decay
@export var volume_slew_time: float = 0.15
@export var max_audio_rpm: float = 0.7  # Cap RPM for audio only

@export_group("Frequency Management")
@export var lowpass_cutoff_idle: float = 800.0  # Hz at idle - lower for deeper sound
@export var lowpass_cutoff_full: float = 2400.0  # Hz at full throttle - reduced high-end
@export var lowpass_resonance: float = 1.2

# Audio nodes
var engine_player: AudioStreamPlayer
var lowpass_effect: AudioEffectLowPassFilter
var effect_bus_idx: int = -1

# State variables
var current_rpm: float = 0.0  # Normalized 0.0-1.0
var current_gear: int = 1
var target_pitch: float = 0.4
var current_pitch: float = 0.4
var target_volume_db: float = -12.0
var current_volume_db: float = -12.0

# Input cache
var throttle_position: float = 0.0
var current_speed: float = 0.0
var is_braking: bool = false

# Slew rate limiters
var max_pitch_change_per_frame: float = 0.007  # ±0.7 semitones at 60fps

func _ready() -> void:
  if not car:
    car = get_parent() as VehicleBody3D
  if not car:
    printerr("CarAudioManager: No car found!")
    return
  
  _setup_audio_pipeline()
  
  if car.has_signal("drift_started"):
    car.drift_started.connect(_on_drift_started)
  if car.has_signal("drift_ended"):
    car.drift_ended.connect(_on_drift_ended)

func _setup_audio_pipeline() -> void:
  engine_player = AudioStreamPlayer.new()
  engine_player.bus = "SFX"
  engine_player.volume_db = base_volume_db
  add_child(engine_player)
  
  effect_bus_idx = AudioServer.get_bus_index("SFX")
  if effect_bus_idx >= 0:
    var has_lowpass = false
    for i in range(AudioServer.get_bus_effect_count(effect_bus_idx)):
      if AudioServer.get_bus_effect(effect_bus_idx, i) is AudioEffectLowPassFilter:
        lowpass_effect = AudioServer.get_bus_effect(effect_bus_idx, i)
        has_lowpass = true
        break
    
    if not has_lowpass:
      lowpass_effect = AudioEffectLowPassFilter.new()
      lowpass_effect.cutoff_hz = lowpass_cutoff_idle
      lowpass_effect.resonance = lowpass_resonance
      AudioServer.add_bus_effect(effect_bus_idx, lowpass_effect)
  
  var generator = AudioStreamGenerator.new()
  generator.mix_rate = 22050.0
  generator.buffer_length = 0.1
  engine_player.stream = generator
  engine_player.play()

func _physics_process(delta: float) -> void:
  if not car:
    return
  
  _update_inputs()
  _simulate_rpm(delta)
  _handle_gear_shifts()
  _calculate_audio_targets()
  _apply_audio_smoothing(delta)
  
  if engine_player.stream is AudioStreamGenerator:
    _fill_audio_buffer()

func _update_inputs() -> void:
  throttle_position = 0.0
  is_braking = false
  
  if "input_accelerate" in car:
    throttle_position = Input.get_action_strength(car.input_accelerate)
  
  if "input_brake" in car:
    is_braking = Input.get_action_strength(car.input_brake) > 0.1
  
  current_speed = car.linear_velocity.length()

func _simulate_rpm(_delta: float) -> void:
  var max_speed = car.max_speed if "max_speed" in car else 50.0
  var speed_ratio = clamp(current_speed / max_speed, 0.0, 1.0)
  
  # If stopped, idle RPM
  if current_speed < 0.5:
    current_gear = 1
    current_rpm = 0.05 + throttle_position * 0.15
    return
  
  # Each gear covers 25% of speed range (4 gears)
  # Calculate RPM to climb from ~0.2 to ~1.0 within each gear's 25% speed range
  var gear_start = float(current_gear - 1) * 0.25
  var gear_end = float(current_gear) * 0.25
  
  if speed_ratio >= gear_start and speed_ratio < gear_end:
    # Within current gear - linear RPM climb
    var progress_in_gear = (speed_ratio - gear_start) / 0.25
    current_rpm = 0.2 + (progress_in_gear * 0.75)  # 0.2 to 0.95
  elif speed_ratio >= gear_end:
    # Should upshift
    current_rpm = 0.95
  else:
    # Should downshift
    current_rpm = 0.25
  
  # Allow throttle to raise RPM when revving
  if throttle_position > 0.5:
    current_rpm = min(current_rpm + throttle_position * 0.1, 1.0)

func _handle_gear_shifts() -> void:
  var max_speed = car.max_speed if "max_speed" in car else 50.0
  var speed_ratio = clamp(current_speed / max_speed, 0.0, 1.0)
  
  # Determine ideal gear (each gear = 25% of speed)
  var ideal_gear = int(speed_ratio * 4.0) + 1
  ideal_gear = clamp(ideal_gear, 1, 4)
  
  # Upshift when RPM is high and we need higher gear
  if current_rpm >= shift_up_rpm and current_gear < ideal_gear:
    current_gear += 1
    current_rpm = 0.25  # Drop to low RPM
    print("Upshift to gear %d" % current_gear)
  
  # Downshift when RPM is low
  elif current_rpm <= shift_down_rpm and current_gear > ideal_gear and current_gear > 1:
    current_gear -= 1
    current_rpm = 0.75  # Jump to higher RPM
    print("Downshift to gear %d" % current_gear)

func _calculate_audio_targets() -> void:
  # Cap the RPM used for audio to prevent piercing high frequencies
  var capped_rpm = clamp(current_rpm, 0.0, max_audio_rpm)
  var rpm_curve = pow(capped_rpm, 0.8)
  target_pitch = lerp(min_pitch, max_pitch, rpm_curve)
  
  var base_vol = base_volume_db
  var throttle_boost = throttle_position * 6.0
  var speed_factor = clamp(current_speed / 10.0, 0.3, 1.0)
  var brake_duck = 0.0
  
  if (is_braking or throttle_position < 0.1) and current_speed > 5.0:
    brake_duck = -3.0
  
  target_volume_db = base_vol + throttle_boost * speed_factor + brake_duck
  target_volume_db = min(target_volume_db, -8.0)
  
  if lowpass_effect:
    var throttle_for_filter = max(throttle_position, 0.3)
    var target_cutoff = lerp(lowpass_cutoff_idle, lowpass_cutoff_full, throttle_for_filter)
    
    if throttle_position < 0.7:
      target_cutoff = min(target_cutoff, 1800.0)
    
    lowpass_effect.cutoff_hz = lerp(lowpass_effect.cutoff_hz, target_cutoff, 0.1)

func _apply_audio_smoothing(delta: float) -> void:
  var pitch_diff = target_pitch - current_pitch
  pitch_diff = clamp(pitch_diff, -max_pitch_change_per_frame, max_pitch_change_per_frame)
  
  var pitch_decay = exp(-delta / pitch_slew_time)
  current_pitch = lerp(current_pitch, target_pitch, 1.0 - pitch_decay)
  engine_player.pitch_scale = current_pitch
  
  var volume_decay = exp(-delta / volume_slew_time)
  current_volume_db = lerp(current_volume_db, target_volume_db, 1.0 - volume_decay)
  engine_player.volume_db = current_volume_db

func _fill_audio_buffer() -> void:
  var playback = engine_player.get_stream_playback() as AudioStreamGeneratorPlayback
  if not playback:
    return
  
  var frames_available = playback.get_frames_available()
  if frames_available == 0:
    return
  
  var generator = engine_player.stream as AudioStreamGenerator
  var capped_rpm = clamp(current_rpm, 0.0, max_audio_rpm)
  var base_freq = 80.0 + (capped_rpm * 200.0)  # 80-280 Hz (deep)
  var increment = base_freq / generator.mix_rate
  
  if not has_meta("engine_phase"):
    set_meta("engine_phase", 0.0)
  
  var phase = get_meta("engine_phase")
  
  for i in range(frames_available):
    var fundamental = sin(phase * TAU) * 0.4
    var second = sin(phase * TAU * 2.0) * 0.2
    var third = sin(phase * TAU * 3.0) * 0.1
    var fourth = sin(phase * TAU * 4.0) * 0.05
    
    var rumble = (randf() * 2.0 - 1.0) * 0.06
    if throttle_position > 0.5:
      rumble *= 1.5
    
    var darkness_factor = 1.0 - clamp(current_rpm * 4.0, 0.0, 1.0)
    var dark_tone = sin(phase * TAU * 0.5) * 0.15 * darkness_factor
    
    var sample = fundamental + second + third + fourth + rumble + dark_tone
    sample = tanh(sample * 1.1) * 0.35
    
    playback.push_frame(Vector2(sample, sample))
    phase = fmod(phase + increment, 1.0)
  
  set_meta("engine_phase", phase)

func _on_drift_started() -> void:
  pass

func _on_drift_ended(_charge: float, _tier) -> void:
  pass
