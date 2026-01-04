extends CanvasLayer

func _ready() -> void:
  $Panel/VBoxContainer/BackButton.pressed.connect(_on_back_pressed)
  hide()

func set_winner(player_name: String) -> void:
  $Panel/VBoxContainer/WinnerLabel.text = player_name + " WINS!"
  show()
  $Panel/VBoxContainer/BackButton.grab_focus()

func _on_back_pressed() -> void:
  # Return to main menu
  get_tree().paused = false
  get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
