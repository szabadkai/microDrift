@tool
extends Control
class_name SpeedDisplay

## Large digital speed display

@export var display_width: float = 120.0

var current_speed: float = 0.0

@onready var speed_label: Label = $SpeedLabel
@onready var unit_label: Label = $UnitLabel


func _ready() -> void:
	custom_minimum_size = Vector2(display_width, 80)


func set_speed(speed_kmh: float) -> void:
	current_speed = speed_kmh
	
	if speed_label:
		speed_label.text = str(int(speed_kmh))
	
	queue_redraw()


func _draw() -> void:
	# Background panel
	var bg_rect = Rect2(Vector2.ZERO, size)
	draw_rect(bg_rect, Color(0.1, 0.1, 0.15, 0.7), true)
	
	# Border with accent color based on speed
	var border_color = Color(0.4, 0.4, 0.5)
	if current_speed > 100:
		border_color = Color(0.2, 0.8, 1.0)  # Cyan at high speed
	if current_speed > 150:
		border_color = Color(1.0, 0.6, 0.2)  # Orange at very high speed
	
	draw_rect(bg_rect, border_color, false, 2.0)
