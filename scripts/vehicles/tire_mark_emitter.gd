extends Node3D
class_name TireMarkEmitter

## Emits tire marks when the car is drifting

@export var mark_lifetime: float = 4.0
@export var emit_interval: float = 0.03
@export var min_speed_for_marks: float = 2.0
@export var mark_color: Color = Color(0.1, 0.1, 0.1, 1.0)

var _timer: float = 0.0
var _car: DriftCar
var _last_pos: Vector3


func _ready() -> void:
	print("[TireMark] Initializing on: ", get_parent().name)
	# Find parent DriftCar
	var parent = get_parent()
	while parent and not parent is DriftCar:
		parent = parent.get_parent()
	_car = parent as DriftCar
	
	if _car:
		print("[TireMark] Found car: ", _car.name)
	else:
		print("[TireMark] ERROR: No DriftCar parent found!")
	
	_last_pos = global_position


func _physics_process(delta: float) -> void:
	if not _car:
		return
	
	var should_emit = _car.current_state == DriftCar.VehicleState.DRIFTING and _car.current_speed > min_speed_for_marks
	
	if should_emit:
		_timer += delta
		if _timer >= emit_interval:
			_timer = 0.0
			_spawn_mark()
	else:
		_timer = 0.0
	
	_last_pos = global_position


func _spawn_mark() -> void:
	var movement = global_position - _last_pos
	var length = max(movement.length(), 0.15)
	
	# Create mesh
	var mesh_instance = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.15, 0.02, length)
	mesh_instance.mesh = box
	
	# Create material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = mark_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = mat
	
	# Position
	mesh_instance.global_position = (_last_pos + global_position) / 2.0
	mesh_instance.global_position.y = 0.02  # Slightly above ground
	
	# Orient along movement
	if movement.length_squared() > 0.001:
		var dir = movement.normalized()
		mesh_instance.rotation.y = atan2(dir.x, dir.z)
	
	# Add to scene
	get_tree().root.add_child(mesh_instance)
	print("[TireMark] Spawned at: ", mesh_instance.global_position)
	
	# Fade and destroy
	var tween = create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, mark_lifetime * 0.4).set_delay(mark_lifetime * 0.6)
	tween.tween_callback(mesh_instance.queue_free)
