extends CanvasLayer

## Pause Menu - Triggered by ESC key during races
## Handles game pause/resume and settings

var is_paused: bool = false
var settings_panel: Panel
var main_panel: Panel

# Volume sliders
var music_slider: HSlider
var sfx_slider: HSlider

func _ready() -> void:
  # Hide by default
  hide()
  
  # Get references
  main_panel = $Panel
  settings_panel = $SettingsPanel
  
  # Connect buttons
  $Panel/VBoxContainer/ResumeButton.pressed.connect(_on_resume_pressed)
  $Panel/VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
  $Panel/VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)
  $Panel/VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
  
  # Settings
  music_slider = $SettingsPanel/VBoxContainer/MusicSlider
  sfx_slider = $SettingsPanel/VBoxContainer/SFXSlider
  
  music_slider.value_changed.connect(_on_music_volume_changed)
  sfx_slider.value_changed.connect(_on_sfx_volume_changed)
  
  $SettingsPanel/VBoxContainer/BackButton.pressed.connect(_on_settings_back_pressed)
  
  # Load saved volumes
  _load_volumes()

func _input(event: InputEvent) -> void:
  if event.is_action_pressed("ui_cancel"):  # ESC key
    if is_paused:
      _resume_game()
    else:
      _pause_game()

func _pause_game() -> void:
  is_paused = true
  get_tree().paused = true
  show()
  main_panel.show()
  settings_panel.hide()
  
  # Pause music
  if MusicManager:
    MusicManager.pause_music()

func _resume_game() -> void:
  is_paused = false
  get_tree().paused = false
  hide()
  
  # Resume music
  if MusicManager:
    MusicManager.resume_music()

func _on_resume_pressed() -> void:
  _resume_game()

func _on_settings_pressed() -> void:
  main_panel.hide()
  settings_panel.show()

func _on_settings_back_pressed() -> void:
  settings_panel.hide()
  main_panel.show()

func _on_main_menu_pressed() -> void:
  _resume_game()
  get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_quit_pressed() -> void:
  get_tree().quit()

func _on_music_volume_changed(value: float) -> void:
  if MusicManager:
    MusicManager.set_volume(value)
  # Save to config
  _save_volumes()

func _on_sfx_volume_changed(value: float) -> void:
  # Adjust SFX bus volume
  var sfx_bus_idx = AudioServer.get_bus_index("SFX")
  if sfx_bus_idx >= 0:
    AudioServer.set_bus_volume_db(sfx_bus_idx, linear_to_db(value))
  # Save to config
  _save_volumes()

func _load_volumes() -> void:
  # Load from config file if exists
  var config = ConfigFile.new()
  var err = config.load("user://settings.cfg")
  
  if err == OK:
    var music_vol = config.get_value("audio", "music_volume", 0.7)
    var sfx_vol = config.get_value("audio", "sfx_volume", 0.8)
    
    music_slider.value = music_vol
    sfx_slider.value = sfx_vol
    
    # Apply loaded values
    _on_music_volume_changed(music_vol)
    _on_sfx_volume_changed(sfx_vol)

func _save_volumes() -> void:
  var config = ConfigFile.new()
  config.set_value("audio", "music_volume", music_slider.value)
  config.set_value("audio", "sfx_volume", sfx_slider.value)
  config.save("user://settings.cfg")
