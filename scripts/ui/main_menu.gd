extends Control

@export var background_model_path: NodePath
var background_model: Node3D

func _ready() -> void:
  if background_model_path:
    background_model = get_node(background_model_path)
  
  # Start menu music
  MusicManager.play_track(MusicManager.MusicTrack.RANDOM)
  
  # Connect buttons
  # Assuming standard naming convention from the plan; will be set in the scene
  var single_player_button = find_child("SinglePlayerButton")
  var multiplayer_button = find_child("MultiplayerButton")
  var quit_button = find_child("QuitButton")
  
  if single_player_button:
    single_player_button.pressed.connect(_on_single_player_pressed)
  if multiplayer_button:
    multiplayer_button.pressed.connect(_on_multiplayer_pressed)
  if quit_button:
    quit_button.pressed.connect(_on_quit_pressed)

func _process(delta: float) -> void:
  if background_model:
    background_model.rotate_y(0.5 * delta)

func _on_single_player_pressed() -> void:
  # Load the single player track
  get_tree().change_scene_to_file("res://scenes/test_track_single.tscn")

func _on_multiplayer_pressed() -> void:
  # Load the split screen track
  get_tree().change_scene_to_file("res://scenes/test_track_multi.tscn")

func _on_quit_pressed() -> void:
  get_tree().quit()
