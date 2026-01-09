extends BaseTrack

## Track Editor Test Scene
## Uses BaseTrack for common functionality (pause menu, inputs, music)
## Includes race management with checkpoints

var race_manager: RaceManager
var lap_label: Label
var time_label: Label
var countdown_label: Label
var surface_label: Label

func _on_track_ready() -> void:
  # Initialize optional node references
  race_manager = get_node_or_null("RaceManager")
  lap_label = get_node_or_null("DebugUI/LapLabel")
  time_label = get_node_or_null("DebugUI/TimeLabel")
  countdown_label = get_node_or_null("DebugUI/CountdownLabel")
  surface_label = get_node_or_null("DebugUI/SurfaceLabel")
  
  print("Track Editor Test scene loaded")
  
  # Register the player car with race manager
  if race_manager and player_car:
    race_manager.register_car(player_car)
    
    # Connect race signals
    race_manager.countdown_tick.connect(_on_countdown_tick)
    race_manager.race_started.connect(_on_race_started)
    race_manager.lap_completed.connect(_on_lap_completed)
    race_manager.race_finished.connect(_on_race_finished)
  
  # Hide countdown label initially
  if countdown_label:
    countdown_label.visible = false


func _on_track_process(_delta: float) -> void:
  # Update lap and time display
  if race_manager and player_car:
    if lap_label:
      var current_lap = race_manager.get_current_lap(player_car)
      lap_label.text = "Lap: %d/%d" % [min(current_lap, race_manager.total_laps), race_manager.total_laps]
    
    if time_label:
      time_label.text = "Time: %s" % race_manager.format_time(race_manager.get_race_time())
  
  # Show surface indicator
  if surface_label and player_car:
    if player_car.is_on_road_surface():
      surface_label.text = "Surface: Road"
      surface_label.add_theme_color_override("font_color", Color.GREEN)
    else:
      surface_label.text = "Surface: OFF-ROAD"
      surface_label.add_theme_color_override("font_color", Color.RED)


# ════════════════════════════════════════════════════════════════════════════
# RACE EVENT HANDLERS
# ════════════════════════════════════════════════════════════════════════════

func _on_countdown_tick(seconds_remaining: int) -> void:
  if countdown_label:
    countdown_label.visible = true
    countdown_label.text = str(seconds_remaining)
    
    # Animate the countdown
    var tween = create_tween()
    tween.tween_property(countdown_label, "scale", Vector2(1.5, 1.5), 0.0)
    tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.3)


func _on_race_started() -> void:
  if countdown_label:
    countdown_label.text = "GO!"
    countdown_label.add_theme_color_override("font_color", Color.GREEN)
    
    # Fade out
    var tween = create_tween()
    tween.tween_property(countdown_label, "modulate:a", 0.0, 1.0).set_delay(0.5)
    tween.tween_callback(func(): countdown_label.visible = false)


func _on_lap_completed(car: Node3D, lap: int, lap_time: float) -> void:
  if car == player_car:
    print("Lap %d completed in %s!" % [lap, race_manager.format_time(lap_time)])


func _on_race_finished(car: Node3D, total_time: float, position: int) -> void:
  if car == player_car:
    if countdown_label:
      countdown_label.visible = true
      countdown_label.modulate.a = 1.0
      countdown_label.text = "FINISHED!\n%s" % race_manager.format_time(total_time)
      countdown_label.add_theme_color_override("font_color", Color.GOLD)
