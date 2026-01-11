@tool
extends Control
class_name RPMGauge

## Graphical RPM arc gauge with color gradient

@export var arc_radius: float = 120.0
@export var arc_width: float = 24.0
@export var arc_start_angle: float = 135.0  # Degrees, starting from right
@export var arc_end_angle: float = 45.0     # Degrees, ending at right

# Colors for the gradient
var color_low: Color = Color(0.2, 0.6, 1.0)    # Blue at idle
var color_mid: Color = Color(1.0, 1.0, 1.0)     # White in middle
var color_high: Color = Color(1.0, 0.3, 0.1)    # Red at redline

# Current state
var current_rpm: float = 800.0
var max_rpm: float = 6000.0
var rpm_normalized: float = 0.0

@onready var rpm_label: Label = $RPMLabel


func _ready() -> void:
	custom_minimum_size = Vector2(140, 90)


func set_rpm(rpm: float, max_rpm_value: float) -> void:
	current_rpm = rpm
	max_rpm = max_rpm_value
	rpm_normalized = clamp((rpm - 800.0) / (max_rpm - 800.0), 0.0, 1.0)
	
	if rpm_label:
		rpm_label.text = str(int(rpm))
	
	queue_redraw()


func _draw() -> void:
	var center = Vector2(size.x / 2, size.y - 10)
	
	# Background arc (dark)
	_draw_arc_segment(center, 0.0, 1.0, Color(0.15, 0.15, 0.2, 0.8))
	
	# Foreground arc (colored based on RPM)
	if rpm_normalized > 0.01:
		var color = _get_rpm_color(rpm_normalized)
		_draw_arc_segment(center, 0.0, rpm_normalized, color)
		
		# Glow effect at high RPM
		if rpm_normalized > 0.7:
			var glow_alpha = (rpm_normalized - 0.7) / 0.3 * 0.3
			_draw_arc_segment(center, 0.0, rpm_normalized, Color(color.r, color.g, color.b, glow_alpha), arc_width + 6)
	
	# Draw tick marks
	_draw_tick_marks(center)


func _draw_arc_segment(center: Vector2, start_t: float, end_t: float, color: Color, width: float = -1.0) -> void:
	if width < 0:
		width = arc_width
	
	var start_deg = arc_start_angle + (arc_end_angle - arc_start_angle + 360) * start_t
	var end_deg = arc_start_angle + (arc_end_angle - arc_start_angle + 360) * end_t
	
	# Normalize angles
	start_deg = fmod(start_deg, 360.0)
	end_deg = fmod(end_deg, 360.0)
	
	var points: PackedVector2Array = []
	var colors: PackedColorArray = []
	
	var segments = 32
	for i in range(segments + 1):
		var t = float(i) / segments
		var angle_deg = lerp(start_deg, end_deg, t)
		if end_deg < start_deg:
			angle_deg = lerp(start_deg, end_deg + 360, t)
			angle_deg = fmod(angle_deg, 360.0)
		
		var angle_rad = deg_to_rad(angle_deg)
		
		# Inner and outer points for thick arc
		var inner_point = center + Vector2(cos(angle_rad), sin(angle_rad)) * (arc_radius - width/2)
		var outer_point = center + Vector2(cos(angle_rad), sin(angle_rad)) * (arc_radius + width/2)
		
		# We'll draw as a polygon strip
		points.append(inner_point)
		points.append(outer_point)
		
		# Gradient color along the arc
		var seg_color = _get_rpm_color(start_t + (end_t - start_t) * t) if color == Color.WHITE else color
		colors.append(seg_color)
		colors.append(seg_color)
	
	# Draw as triangle strip
	for i in range(points.size() - 2):
		var tri_points = PackedVector2Array([points[i], points[i+1], points[i+2]])
		var tri_colors = PackedColorArray([colors[i], colors[i+1], colors[i+2]])
		draw_polygon(tri_points, tri_colors)


func _draw_tick_marks(center: Vector2) -> void:
	var tick_count = 6  # 0, 1, 2, 3, 4, 5, 6 (thousand RPM)
	
	for i in range(tick_count + 1):
		var t = float(i) / tick_count
		var angle_deg = arc_start_angle + (arc_end_angle - arc_start_angle + 360) * t
		if arc_end_angle < arc_start_angle:
			angle_deg = lerp(arc_start_angle, arc_end_angle + 360, t)
		angle_deg = fmod(angle_deg, 360.0)
		var angle_rad = deg_to_rad(angle_deg)
		
		var inner_r = arc_radius + arc_width/2 + 2
		var outer_r = arc_radius + arc_width/2 + 8
		
		var start_pos = center + Vector2(cos(angle_rad), sin(angle_rad)) * inner_r
		var end_pos = center + Vector2(cos(angle_rad), sin(angle_rad)) * outer_r
		
		var tick_color = Color(0.6, 0.6, 0.7) if i < tick_count else Color(1.0, 0.3, 0.3)
		draw_line(start_pos, end_pos, tick_color, 2.0)


func _get_rpm_color(t: float) -> Color:
	# Gradient: blue (0) -> white (0.5) -> red (1.0)
	if t < 0.5:
		return color_low.lerp(color_mid, t * 2.0)
	else:
		return color_mid.lerp(color_high, (t - 0.5) * 2.0)
