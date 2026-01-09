extends Node

## Improved Engine Audio System
## Multi-layer synth with realistic combustion pulses
## Features: Airborne rev-up, throttle-responsive, deep bass rumble

@export_group("Car Reference")
@export var car: VehicleBody3D

@export_group("Engine Character")
## Number of cylinders (4, 6, 8) - affects firing frequency
@export var cylinders: int = 4
## Base idle RPM (affects idle sound)
@export var idle_rpm: float = 800.0
## Max RPM
@export var max_rpm: float = 6000.0
## How much RPM increases when airborne (free-revving)
@export var airborne_rpm_boost: float = 2000.0

@export_group("Layer A: Sub-Bass (Engine Rumble)")
@export var bass_freq_idle: float = 45.0        # Low bass at idle
@export var bass_freq_max: float = 70.0         # Bass rises with RPM
@export var bass_vol_idle_db: float = -20.0     # Much quieter - subtle rumble
@export var bass_vol_max_db: float = -14.0      # Still present but not dominant

@export_group("Layer B: Main Engine (Combustion Pulse)")
@export var main_freq_idle: float = 80.0        # Base frequency at idle
@export var main_freq_max: float = 200.0        # Frequency at max RPM
@export var main_lowpass_idle: float = 400.0    # Darker at idle
@export var main_lowpass_max: float = 1200.0    # Opens up at high RPM
@export var main_vol_idle_db: float = -12.0
@export var main_vol_max_db: float = -2.0

@export_group("Layer C: Combustion Texture")
@export var texture_vol_db: float = -18.0       # Background crackle
@export var texture_bandpass_center: float = 400.0

@export_group("Response Tuning")
@export var rpm_smoothing: float = 0.08          # How fast RPM changes
@export var rpm_smoothing_down: float = 0.15     # Faster drop when lifting throttle
@export var volume_smoothing: float = 0.1

# Audio nodes
var bass_player: AudioStreamPlayer
var main_player: AudioStreamPlayer
var texture_player: AudioStreamPlayer

# Generators
var bass_generator: AudioStreamGenerator
var main_generator: AudioStreamGenerator
var texture_generator: AudioStreamGenerator

# Phase tracking
var bass_phase: float = 0.0
var main_phase: float = 0.0
var main_phase_2: float = 0.0  # 2nd harmonic
var main_phase_3: float = 0.0  # 3rd harmonic
var texture_phase: float = 0.0
var pulse_phase: float = 0.0   # For combustion pulse timing

# State
var current_rpm: float = 800.0
var target_rpm: float = 800.0
var rpm_normalized: float = 0.0  # 0-1 for easy interpolation
var throttle: float = 0.0
var is_airborne: bool = false
var current_bass_vol: float = -10.0
var current_main_vol: float = -12.0

const MIX_RATE: float = 22050.0

func _ready() -> void:
  if not car:
    car = get_parent() as VehicleBody3D
  if not car:
    printerr("CarAudioManager: No car found!")
    return
  
  _setup_audio_layers()

func _setup_audio_layers() -> void:
  # Layer A: Sub-Bass
  bass_player = AudioStreamPlayer.new()
  bass_player.bus = "SFX"
  bass_player.volume_db = bass_vol_idle_db
  add_child(bass_player)
  
  bass_generator = AudioStreamGenerator.new()
  bass_generator.mix_rate = MIX_RATE
  bass_generator.buffer_length = 0.1
  bass_player.stream = bass_generator
  bass_player.play()
  
  # Layer B: Main Engine
  main_player = AudioStreamPlayer.new()
  main_player.bus = "SFX"
  main_player.volume_db = main_vol_idle_db
  add_child(main_player)
  
  main_generator = AudioStreamGenerator.new()
  main_generator.mix_rate = MIX_RATE
  main_generator.buffer_length = 0.1
  main_player.stream = main_generator
  main_player.play()
  
  # Layer C: Combustion Texture
  texture_player = AudioStreamPlayer.new()
  texture_player.bus = "SFX"
  texture_player.volume_db = texture_vol_db
  add_child(texture_player)
  
  texture_generator = AudioStreamGenerator.new()
  texture_generator.mix_rate = MIX_RATE
  texture_generator.buffer_length = 0.1
  texture_player.stream = texture_generator
  texture_player.play()

func _physics_process(_delta: float) -> void:
  if not car:
    return
  
  _update_rpm()
  _update_volumes()
  _fill_bass_buffer()
  _fill_main_buffer()
  _fill_texture_buffer()

func _update_rpm() -> void:
  var max_speed = car.max_speed if "max_speed" in car else 50.0
  var current_speed = car.linear_velocity.length()
  
  # Get throttle input
  if "input_accelerate" in car:
    throttle = Input.get_action_strength(car.input_accelerate)
  else:
    throttle = 0.0
  
  # Check if airborne (all wheels off ground)
  _check_airborne()
  
  # Base RPM from speed (simulating gear ratios with simple curve)
  var speed_ratio = clamp(current_speed / max_speed, 0.0, 1.0)
  
  # Simulate gear changes - RPM cycles up and down through gears
  # This creates the characteristic rise-and-fall of engine sound
  var num_gears = 4.0
  var gear_position = fmod(speed_ratio * num_gears, 1.0)
  
  # Each gear goes from ~35% to 100% of RPM range, then drops to 35% for next gear
  var gear_rpm_min = 0.35
  var gear_rpm_range = gear_position * (1.0 - gear_rpm_min) + gear_rpm_min
  
  # Overall progression still trends upward with speed
  var overall_progression = sqrt(speed_ratio) * 0.4  # sqrt for faster initial response
  var speed_based_rpm = idle_rpm + (max_rpm - idle_rpm) * (gear_rpm_range * 0.6 + overall_progression)
  
  # Throttle strongly influences RPM - lifting off causes RPM to drop
  var throttle_influence = 0.5
  var base_target = lerp(idle_rpm, speed_based_rpm, throttle * throttle_influence + (1.0 - throttle_influence))
  
  # When stopped with throttle, rev up!
  if current_speed < 2.0 and throttle > 0.0:
    base_target = lerp(idle_rpm, max_rpm * 0.7, throttle)
  
  # AIRBORNE: Engine revs UP when wheels are free (no load)
  if is_airborne:
    # When airborne, if throttle is pressed, RPM spikes up quickly
    if throttle > 0.1:
      base_target = min(base_target + airborne_rpm_boost * throttle, max_rpm)
    else:
      # If no throttle while airborne, RPM also rises but less (momentum)
      base_target = min(base_target + airborne_rpm_boost * 0.3, max_rpm * 0.85)
  
  target_rpm = base_target
  
  # Smooth RPM changes - faster when revving down (lifting throttle)
  var smoothing = rpm_smoothing
  if target_rpm < current_rpm:
    smoothing = rpm_smoothing_down
  
  current_rpm = lerp(current_rpm, target_rpm, smoothing)
  current_rpm = clamp(current_rpm, idle_rpm, max_rpm)
  
  # Normalize for easy use
  rpm_normalized = (current_rpm - idle_rpm) / (max_rpm - idle_rpm)

func _check_airborne() -> void:
  ## Check if all wheels are off the ground
  if not car:
    is_airborne = false
    return
  
  # Try to access wheels from the car
  var wheels_grounded = 0
  var total_wheels = 0
  
  # Check VehicleWheel3D children
  for child in car.get_children():
    if child is VehicleWheel3D:
      total_wheels += 1
      if child.is_in_contact():
        wheels_grounded += 1
  
  # Airborne if no wheels touching ground
  if total_wheels > 0:
    is_airborne = wheels_grounded == 0
  else:
    is_airborne = false

func _update_volumes() -> void:
  # Bass volume
  var target_bass = lerp(bass_vol_idle_db, bass_vol_max_db, rpm_normalized)
  current_bass_vol = lerp(current_bass_vol, target_bass, volume_smoothing)
  bass_player.volume_db = current_bass_vol
  
  # Main volume - also influenced by throttle
  var target_main = lerp(main_vol_idle_db, main_vol_max_db, rpm_normalized)
  # Reduce volume slightly when coasting
  if throttle < 0.1:
    target_main -= 3.0
  current_main_vol = lerp(current_main_vol, target_main, volume_smoothing)
  main_player.volume_db = current_main_vol

func _fill_bass_buffer() -> void:
  var playback = bass_player.get_stream_playback() as AudioStreamGeneratorPlayback
  if not playback:
    return
  
  var frames = playback.get_frames_available()
  if frames == 0:
    return
  
  # Bass frequency tied to RPM
  var freq = lerp(bass_freq_idle, bass_freq_max, rpm_normalized)
  var increment = freq / MIX_RATE
  
  # Filter state for smoothing
  if not has_meta("bass_filter"):
    set_meta("bass_filter", 0.0)
  var filter_state = get_meta("bass_filter")
  
  # Very low lowpass for sub-bass
  var cutoff = 120.0  # Keep it very low
  var alpha = cutoff / (cutoff + MIX_RATE / TAU)
  
  for i in range(frames):
    # Sine wave with subtle harmonics for sub-bass
    var sine = sin(bass_phase * TAU)
    var harmonic = sin(bass_phase * TAU * 2.0) * 0.2
    
    var raw = (sine + harmonic) * 0.35  # Subtle rumble, not overpowering
    
    # Low pass filter
    filter_state = filter_state + alpha * (raw - filter_state)
    
    playback.push_frame(Vector2(filter_state, filter_state))
    bass_phase = fmod(bass_phase + increment, 1.0)
  
  set_meta("bass_filter", filter_state)

func _fill_main_buffer() -> void:
  var playback = main_player.get_stream_playback() as AudioStreamGeneratorPlayback
  if not playback:
    return
  
  var frames = playback.get_frames_available()
  if frames == 0:
    return
  
  # Main engine frequency
  var freq = lerp(main_freq_idle, main_freq_max, rpm_normalized)
  var increment = freq / MIX_RATE
  var increment_2 = (freq * 2.0) / MIX_RATE  # Octave
  var increment_3 = (freq * 1.5) / MIX_RATE  # Fifth
  
  # Combustion pulse frequency (firing rate)
  # For a 4-stroke: pulses per second = (RPM / 60) * (cylinders / 2)
  var pulses_per_second = (current_rpm / 60.0) * (cylinders / 2.0)
  var pulse_increment = pulses_per_second / MIX_RATE
  
  # Lowpass filter - opens with RPM
  var cutoff = lerp(main_lowpass_idle, main_lowpass_max, rpm_normalized)
  var rc = 1.0 / (TAU * cutoff)
  var dt = 1.0 / MIX_RATE
  var alpha = dt / (rc + dt)
  
  if not has_meta("main_filter"):
    set_meta("main_filter", 0.0)
  var filter_state = get_meta("main_filter")
  
  for i in range(frames):
    # Combustion pulse envelope - creates the "burbling" character
    # Each cylinder fires creating a pressure pulse
    var pulse_pos = fmod(pulse_phase, 1.0)
    # Sharp attack, quick decay envelope for each firing
    var pulse_envelope = 0.3 + 0.7 * exp(-pulse_pos * 8.0)
    
    # Main tone - mix of waveforms for richness
    # Using shaped waveform that sounds more like combustion
    var phase_val = fmod(main_phase, 1.0)
    
    # Asymmetric wave - compression/exhaust simulation
    var compression = 0.0
    if phase_val < 0.3:
      # Quick sharp rise (compression/ignition)
      compression = sin(phase_val / 0.3 * PI * 0.5)
    else:
      # Longer decay (exhaust)
      compression = cos((phase_val - 0.3) / 0.7 * PI * 0.5)
    
    # Add harmonics for body
    var h2 = sin(main_phase_2 * TAU) * 0.25
    var h3 = sin(main_phase_3 * TAU) * 0.15
    
    # Combine with pulse envelope
    var raw = (compression * 0.7 + h2 + h3) * pulse_envelope
    
    # Add slight grit/noise at higher RPM
    if rpm_normalized > 0.3:
      var noise = (randf() - 0.5) * 0.1 * (rpm_normalized - 0.3)
      raw += noise
    
    # Soft saturation for warmth
    raw = tanh(raw * 1.3) * 0.8
    
    # Lowpass filter
    filter_state = filter_state + alpha * (raw - filter_state)
    
    playback.push_frame(Vector2(filter_state, filter_state))
    
    main_phase = fmod(main_phase + increment, 1.0)
    main_phase_2 = fmod(main_phase_2 + increment_2, 1.0)
    main_phase_3 = fmod(main_phase_3 + increment_3, 1.0)
    pulse_phase = fmod(pulse_phase + pulse_increment, 1.0)
  
  set_meta("main_filter", filter_state)

func _fill_texture_buffer() -> void:
  var playback = texture_player.get_stream_playback() as AudioStreamGeneratorPlayback
  if not playback:
    return
  
  var frames = playback.get_frames_available()
  if frames == 0:
    return
  
  # Combustion texture - pulsating filtered noise
  var pulses_per_second = (current_rpm / 60.0) * (cylinders / 2.0)
  var pulse_increment = pulses_per_second / MIX_RATE
  
  # Band-pass for texture
  if not has_meta("texture_bp"):
    set_meta("texture_bp", {"y1": 0.0, "y2": 0.0, "x1": 0.0, "x2": 0.0})
  var bp = get_meta("texture_bp")
  
  var center = texture_bandpass_center + rpm_normalized * 200.0  # Rises with RPM
  var q = 1.5
  var omega = TAU * center / MIX_RATE
  var sin_omega = sin(omega)
  var cos_omega = cos(omega)
  var alpha_bp = sin_omega / (2.0 * q)
  
  var b0 = alpha_bp
  var b2 = -alpha_bp
  var a0 = 1.0 + alpha_bp
  var a1 = -2.0 * cos_omega
  var a2 = 1.0 - alpha_bp
  
  b0 /= a0
  b2 /= a0
  a1 /= a0
  a2 /= a0
  
  for i in range(frames):
    # Noise pulsed at firing rate
    var pulse_pos = fmod(texture_phase, 1.0)
    var pulse_env = exp(-pulse_pos * 6.0)  # Quick decay
    
    var noise = (randf() * 2.0 - 1.0) * pulse_env
    
    # Band-pass filter
    var filtered = b0 * noise + b2 * bp.x2 - a1 * bp.y1 - a2 * bp.y2
    bp.x2 = bp.x1
    bp.x1 = noise
    bp.y2 = bp.y1
    bp.y1 = filtered
    
    # Volume increases with RPM
    var vol = 0.3 + rpm_normalized * 0.4
    var sample = filtered * vol
    
    playback.push_frame(Vector2(sample, sample))
    texture_phase = fmod(texture_phase + pulse_increment, 1.0)
  
  set_meta("texture_bp", bp)
