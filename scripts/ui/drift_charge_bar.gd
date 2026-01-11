@tool
extends Control
class_name DriftChargeBar

## Horizontal drift charge bar with tier colors and animations

@export var bar_width: float = 280.0
@export var bar_height: float = 32.0

# Tier colors
var color_base: Color = Color(0.2, 0.2, 0.25, 0.7)      # Empty bar
var color_tier1: Color = Color(0.9, 0.9, 1.0)          # White (0-50%)
var color_tier2: Color = Color(0.2, 0.9, 1.0)          # Cyan (50-80%)
var color_tier3: Color = Color(1.0, 0.6, 0.1)          # Orange (80-100%)

# State
var charge_normalized: float = 0.0
var is_drifting: bool = false
var is_boosting: bool = false
var pulse_time: float = 0.0

@onready var charge_label: Label = $ChargeLabel
@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	pass  # Use size from scene


func _process(delta: float) -> void:
	if is_drifting or is_boosting:
		pulse_time += delta * 8.0
		queue_redraw()


func set_drift_charge(charge: float, drifting: bool, boosting: bool) -> void:
	charge_normalized = clamp(charge, 0.0, 1.0)
	is_drifting = drifting
	is_boosting = boosting
	
	if charge_label:
		charge_label.text = "%d%%" % int(charge * 100)
	
	if status_label:
		if boosting:
			status_label.text = "BOOST!"
			status_label.add_theme_color_override("font_color", color_tier3)
		elif drifting:
			status_label.text = "DRIFTING"
			status_label.add_theme_color_override("font_color", _get_tier_color(charge))
		elif charge > 0.15:
			status_label.text = "READY"
			status_label.add_theme_color_override("font_color", color_tier2)
		else:
			status_label.text = ""
	
	queue_redraw()


func _draw() -> void:
	var bar_rect = Rect2(
		(size.x - bar_width) / 2,
		10,
		bar_width,
		bar_height
	)
	
	# Background bar
	draw_rect(bar_rect, color_base, true)
	
	# Charged portion
	if charge_normalized > 0.01:
		var fill_width = bar_width * charge_normalized
		var fill_rect = Rect2(bar_rect.position, Vector2(fill_width, bar_height))
		
		var fill_color = _get_tier_color(charge_normalized)
		
		# Pulse effect when drifting
		if is_drifting:
			var pulse = sin(pulse_time) * 0.15 + 0.85
			fill_color = fill_color * pulse
			fill_color.a = 1.0
		
		# Boost flash
		if is_boosting:
			var flash = sin(pulse_time * 2) * 0.3 + 0.7
			fill_color = fill_color.lerp(Color.WHITE, flash * 0.5)
		
		draw_rect(fill_rect, fill_color, true)
		
		# Glow at high charge
		if charge_normalized > 0.5:
			var glow_alpha = (charge_normalized - 0.5) * 0.4
			var glow_rect = Rect2(
				fill_rect.position - Vector2(2, 2),
				fill_rect.size + Vector2(4, 4)
			)
			draw_rect(glow_rect, Color(fill_color.r, fill_color.g, fill_color.b, glow_alpha), false, 2.0)
	
	# Border
	draw_rect(bar_rect, Color(0.5, 0.5, 0.6, 0.8), false, 2.0)
	
	# Tier markers
	_draw_tier_markers(bar_rect)


func _draw_tier_markers(bar_rect: Rect2) -> void:
	# Draw small ticks at 50% and 80%
	var markers = [0.5, 0.8]
	
	for m in markers:
		var x = bar_rect.position.x + bar_width * m
		var top = bar_rect.position.y - 3
		var bottom = bar_rect.position.y + bar_height + 3
		draw_line(Vector2(x, top), Vector2(x, bottom), Color(0.7, 0.7, 0.8, 0.6), 1.0)


func _get_tier_color(charge: float) -> Color:
	if charge >= 0.8:
		return color_tier3
	elif charge >= 0.5:
		return color_tier2
	else:
		return color_tier1
