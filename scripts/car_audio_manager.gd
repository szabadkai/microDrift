extends Node

## Layered Engine Audio System
## Three-layer synth: Thrum (low body), Whine (mechanical), Grit (combustion texture)
## Based on precise Hz/filter/waveform targets for realistic, non-fatiguing engine audio

@export_group("Car Reference")
@export var car: VehicleBody3D

@export_group("Layer A: Thrum (Low Engine Body)")
@export var thrum_freq_idle: float = 80.0      # Hz at idle
@export var thrum_freq_max: float = 150.0      # Hz at max speed (lower = deeper)
@export var thrum_lowpass_idle: float = 600.0  # LP cutoff at idle
@export var thrum_lowpass_max: float = 2200.0  # LP cutoff at max
@export var thrum_vol_idle_db: float = -14.0   # Volume at idle
@export var thrum_vol_max_db: float = -4.0     # Volume at max
@export var thrum_harmonic_mix: float = 0.3    # 2nd harmonic strength

@export_group("Layer B: Whine (Mechanical/Gear)")
@export var whine_freq_idle: float = 400.0     # Hz at idle
@export var whine_freq_max: float = 600.0      # Hz at max speed (lower = less shrill)
@export var whine_bandpass_q: float = 2.5      # Band-pass Q factor
@export var whine_vol_idle_db: float = -24.0   # Volume at idle
@export var whine_vol_max_db: float = -8.0     # Volume at max

@export_group("Layer C: Combustion Grit")
@export var grit_bandpass_low: float = 200.0   # Band-pass low edge
@export var grit_bandpass_high: float = 600.0  # Band-pass high edge
@export var grit_mod_freq: float = 30.0        # AM modulation frequency (20-40 Hz)
@export var grit_vol_db: float = -28.0         # Very low volume

@export_group("Response Tuning")
@export var smoothing_factor: float = 0.04     # Speed interpolation per frame (slower)
@export var pitch_smoothing: float = 0.06      # Pitch changes per frame (slower)
@export var speed_curve: float = 0.6           # Exponent for speed mapping (<1 = slower rise)

# Audio nodes - one player per layer
var thrum_player: AudioStreamPlayer
var whine_player: AudioStreamPlayer
var grit_player: AudioStreamPlayer

# Generator references
var thrum_generator: AudioStreamGenerator
var whine_generator: AudioStreamGenerator
var grit_generator: AudioStreamGenerator

# Phase tracking for each oscillator
var thrum_phase: float = 0.0
var thrum_harmonic_phase: float = 0.0
var whine_phase: float = 0.0
var grit_phase: float = 0.0
var grit_mod_phase: float = 0.0

# State
var speed01: float = 0.0           # Current smoothed speed (0-1)
var target_speed01: float = 0.0    # Target speed (0-1)
var throttle: float = 0.0          # Current throttle input (0-1)
var current_thrum_freq: float = 80.0
var current_whine_freq: float = 400.0

const MIX_RATE: float = 22050.0

func _ready() -> void:
  if not car:
    car = get_parent() as VehicleBody3D
  if not car:
    printerr("CarAudioManager: No car found!")
    return
  
  _setup_audio_layers()

func _setup_audio_layers() -> void:
  # Layer A: Thrum
  thrum_player = AudioStreamPlayer.new()
  thrum_player.bus = "SFX"
  thrum_player.volume_db = thrum_vol_idle_db
  add_child(thrum_player)
  
  thrum_generator = AudioStreamGenerator.new()
  thrum_generator.mix_rate = MIX_RATE
  thrum_generator.buffer_length = 0.1
  thrum_player.stream = thrum_generator
  thrum_player.play()
  
  # Layer B: Whine - DISABLED (too shrill)
  # whine_player = AudioStreamPlayer.new()
  # whine_player.bus = "SFX"
  # whine_player.volume_db = whine_vol_idle_db
  # add_child(whine_player)
  # 
  # whine_generator = AudioStreamGenerator.new()
  # whine_generator.mix_rate = MIX_RATE
  # whine_generator.buffer_length = 0.1
  # whine_player.stream = whine_generator
  # whine_player.play()
  
  # Layer C: Grit
  grit_player = AudioStreamPlayer.new()
  grit_player.bus = "SFX"
  grit_player.volume_db = grit_vol_db
  add_child(grit_player)
  
  grit_generator = AudioStreamGenerator.new()
  grit_generator.mix_rate = MIX_RATE
  grit_generator.buffer_length = 0.1
  grit_player.stream = grit_generator
  grit_player.play()

func _physics_process(_delta: float) -> void:
  if not car:
    return
  
  _update_speed()
  _update_audio_parameters()
  _fill_thrum_buffer()
  # _fill_whine_buffer()  # Disabled
  _fill_grit_buffer()

func _update_speed() -> void:
  var max_speed = car.max_speed if "max_speed" in car else 50.0
  var current_speed = car.linear_velocity.length()
  
  # Get throttle input
  if "input_accelerate" in car:
    throttle = Input.get_action_strength(car.input_accelerate)
  else:
    throttle = 0.0
  
  # Calculate base speed01 with curve
  var linear_speed = clamp(current_speed / max_speed, 0.0, 1.0)
  var speed_based = pow(linear_speed, speed_curve)
  
  # Blend speed with throttle - throttle has strong influence
  # When throttle is 0, engine sound drops significantly
  # When throttle is 1, sound follows speed
  var throttle_influence = 0.6  # How much throttle affects sound vs pure speed
  var throttle_floor = 0.15     # Minimum RPM when coasting (idle-ish)
  
  # Target is blend of speed-based and throttle-modified
  var throttle_modified = speed_based * (throttle_floor + throttle * (1.0 - throttle_floor))
  target_speed01 = lerp(speed_based, throttle_modified, throttle_influence)
  
  # Smooth interpolation - faster when decelerating (letting off throttle)
  var current_smoothing = smoothing_factor
  if target_speed01 < speed01:
    current_smoothing = smoothing_factor * 2.5  # Drop faster
  
  speed01 = lerp(speed01, target_speed01, current_smoothing)

func _update_audio_parameters() -> void:
  # Layer A: Thrum frequencies and volume
  var target_thrum_freq = lerp(thrum_freq_idle, thrum_freq_max, speed01)
  current_thrum_freq = lerp(current_thrum_freq, target_thrum_freq, pitch_smoothing)
  
  var thrum_vol = lerp(thrum_vol_idle_db, thrum_vol_max_db, speed01)
  thrum_player.volume_db = thrum_vol
  
  # Layer B: Whine - DISABLED
  # var target_whine_freq = lerp(whine_freq_idle, whine_freq_max, speed01)
  # current_whine_freq = lerp(current_whine_freq, target_whine_freq, pitch_smoothing)
  # var whine_vol = lerp(whine_vol_idle_db, whine_vol_max_db, speed01)
  # whine_player.volume_db = whine_vol
  
  # Layer C: Grit volume stays constant (very low)

func _fill_thrum_buffer() -> void:
  var playback = thrum_player.get_stream_playback() as AudioStreamGeneratorPlayback
  if not playback:
    return
  
  var frames = playback.get_frames_available()
  if frames == 0:
    return
  
  var increment = current_thrum_freq / MIX_RATE
  var harmonic_increment = (current_thrum_freq * 2.0) / MIX_RATE  # 2nd harmonic
  
  # Low-pass simulation via filter coefficient (simple 1-pole)
  var cutoff = lerp(thrum_lowpass_idle, thrum_lowpass_max, speed01)
  var rc = 1.0 / (TAU * cutoff)
  var dt = 1.0 / MIX_RATE
  var alpha = dt / (rc + dt)
  
  if not has_meta("thrum_filter_state"):
    set_meta("thrum_filter_state", 0.0)
  var filter_state = get_meta("thrum_filter_state")
  
  for i in range(frames):
    # Saw wave with mild saturation for fundamental
    var saw = (fmod(thrum_phase, 1.0) * 2.0 - 1.0)
    # Soft saturation
    saw = tanh(saw * 1.2)
    
    # Triangle wave for 2nd harmonic
    var tri_phase = fmod(thrum_harmonic_phase, 1.0)
    var triangle = 1.0 - 4.0 * abs(tri_phase - 0.5)
    
    # Mix fundamental + 2nd harmonic
    var raw = saw * 0.6 + triangle * thrum_harmonic_mix
    
    # Simple low-pass filter
    filter_state = filter_state + alpha * (raw - filter_state)
    var sample = filter_state * 0.5
    
    playback.push_frame(Vector2(sample, sample))
    
    thrum_phase = fmod(thrum_phase + increment, 1.0)
    thrum_harmonic_phase = fmod(thrum_harmonic_phase + harmonic_increment, 1.0)
  
  set_meta("thrum_filter_state", filter_state)

func _fill_whine_buffer() -> void:
  var playback = whine_player.get_stream_playback() as AudioStreamGeneratorPlayback
  if not playback:
    return
  
  var frames = playback.get_frames_available()
  if frames == 0:
    return
  
  var increment = current_whine_freq / MIX_RATE
  
  # Band-pass filter state (2-pole resonant)
  if not has_meta("whine_bp_state"):
    set_meta("whine_bp_state", {"y1": 0.0, "y2": 0.0, "x1": 0.0, "x2": 0.0})
  var bp = get_meta("whine_bp_state")
  
  # Band-pass coefficients (simplified biquad)
  var center = current_whine_freq
  var omega = TAU * center / MIX_RATE
  var sin_omega = sin(omega)
  var cos_omega = cos(omega)
  var alpha_bp = sin_omega / (2.0 * whine_bandpass_q)
  
  var b0 = alpha_bp
  var b1 = 0.0
  var b2 = -alpha_bp
  var a0 = 1.0 + alpha_bp
  var a1 = -2.0 * cos_omega
  var a2 = 1.0 - alpha_bp
  
  # Normalize
  b0 /= a0
  b1 /= a0
  b2 /= a0
  a1 /= a0
  a2 /= a0
  
  for i in range(frames):
    # Soft sine/triangle hybrid
    var sine = sin(whine_phase * TAU)
    var tri_phase = fmod(whine_phase, 1.0)
    var triangle = 1.0 - 4.0 * abs(tri_phase - 0.5)
    
    # Blend - more sine for softer whine
    var raw = sine * 0.7 + triangle * 0.3
    
    # Apply band-pass filter
    var filtered = b0 * raw + b1 * bp.x1 + b2 * bp.x2 - a1 * bp.y1 - a2 * bp.y2
    
    # Update filter state
    bp.x2 = bp.x1
    bp.x1 = raw
    bp.y2 = bp.y1
    bp.y1 = filtered
    
    var sample = filtered * 0.4
    playback.push_frame(Vector2(sample, sample))
    
    whine_phase = fmod(whine_phase + increment, 1.0)
  
  set_meta("whine_bp_state", bp)

func _fill_grit_buffer() -> void:
  var playback = grit_player.get_stream_playback() as AudioStreamGeneratorPlayback
  if not playback:
    return
  
  var frames = playback.get_frames_available()
  if frames == 0:
    return
  
  var mod_increment = grit_mod_freq / MIX_RATE
  
  # Band-pass filter for noise (simple 2-pole)
  if not has_meta("grit_bp_state"):
    set_meta("grit_bp_state", {"y1": 0.0, "y2": 0.0, "x1": 0.0, "x2": 0.0})
  var bp = get_meta("grit_bp_state")
  
  # Center frequency for grit band-pass
  var center = (grit_bandpass_low + grit_bandpass_high) * 0.5  # ~400 Hz
  var bandwidth = grit_bandpass_high - grit_bandpass_low
  var q = center / bandwidth  # Q from bandwidth
  
  var omega = TAU * center / MIX_RATE
  var sin_omega = sin(omega)
  var cos_omega = cos(omega)
  var alpha_bp = sin_omega / (2.0 * q)
  
  var b0 = alpha_bp
  var b1 = 0.0
  var b2 = -alpha_bp
  var a0 = 1.0 + alpha_bp
  var a1 = -2.0 * cos_omega
  var a2 = 1.0 - alpha_bp
  
  b0 /= a0
  b1 /= a0
  b2 /= a0
  a1 /= a0
  a2 /= a0
  
  for i in range(frames):
    # White noise source
    var noise = randf() * 2.0 - 1.0
    
    # Apply band-pass filter
    var filtered = b0 * noise + b1 * bp.x1 + b2 * bp.x2 - a1 * bp.y1 - a2 * bp.y2
    bp.x2 = bp.x1
    bp.x1 = noise
    bp.y2 = bp.y1
    bp.y1 = filtered
    
    # Amplitude modulation at 20-40 Hz (engine pulses)
    var mod = 0.5 + 0.5 * sin(grit_mod_phase * TAU)
    
    var sample = filtered * mod * 0.3
    playback.push_frame(Vector2(sample, sample))
    
    grit_mod_phase = fmod(grit_mod_phase + mod_increment, 1.0)
  
  set_meta("grit_bp_state", bp)
