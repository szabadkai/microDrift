extends Camera3D
class_name FollowCamera

## Dead-zone camera that tracks the car when it moves outside the center area

@export_node_path("Node3D") var target_path: NodePath
@export var height: float = 35.0  # Camera height above the ground (higher = smaller cars)
@export var follow_speed: float = 4.0  # How quickly camera catches up when tracking
@export var dead_zone_ratio: float = 0.5  # Center 50% is the dead zone (0.0-1.0)
@export var camera_angle: Vector3 = Vector3(-75, 0, 0)  # Static camera angle (pitch, yaw, roll)

var target: Node3D
var camera_focus: Vector3  # The point on the ground the camera is centered on


func _ready() -> void:
  # Resolve the target node from the path
  if target_path:
    target = get_node(target_path) as Node3D
  
  if target:
    # Start centered on the target
    camera_focus = target.global_position
    camera_focus.y = 0  # Keep focus on ground level
    _update_camera_transform()


func _physics_process(delta: float) -> void:
  if not target:
    return
  
  # Get target position on the ground plane
  var target_pos = target.global_position
  target_pos.y = 0  # Project to ground level
  
  # Calculate offset from camera focus to target
  var offset_from_center = target_pos - camera_focus
  
  # Calculate the visible area bounds based on camera height and angle
  # This is an approximation based on the camera's view
  var view_distance = height / tan(deg_to_rad(-camera_angle.x))
  var half_width = view_distance * 0.8  # Approximate visible width
  var half_depth = view_distance * 0.6  # Approximate visible depth
  
  # Dead zone bounds (center 50% of view)
  var dead_zone_half_width = half_width * dead_zone_ratio
  var dead_zone_half_depth = half_depth * dead_zone_ratio
  
  # Calculate how much the target is outside the dead zone
  var push_x = 0.0
  var push_z = 0.0
  
  if offset_from_center.x > dead_zone_half_width:
    push_x = offset_from_center.x - dead_zone_half_width
  elif offset_from_center.x < -dead_zone_half_width:
    push_x = offset_from_center.x + dead_zone_half_width
  
  if offset_from_center.z > dead_zone_half_depth:
    push_z = offset_from_center.z - dead_zone_half_depth
  elif offset_from_center.z < -dead_zone_half_depth:
    push_z = offset_from_center.z + dead_zone_half_depth
  
  # Only move camera if target is outside dead zone
  if push_x != 0.0 or push_z != 0.0:
    var target_focus = camera_focus + Vector3(push_x, 0, push_z)
    camera_focus = camera_focus.lerp(target_focus, follow_speed * delta)
  
  _update_camera_transform()


func _update_camera_transform() -> void:
  # Position camera above the focus point, offset back based on angle
  var angle_rad = deg_to_rad(camera_angle.x)
  var back_offset = height / tan(-angle_rad) if angle_rad != 0 else 0
  
  global_position = camera_focus + Vector3(0, height, back_offset)
  
  # Apply static rotation
  rotation_degrees = camera_angle
