extends Area3D

@export var speed: float = 40.0
@export var life_time: float = 3.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Auto destroy after 3 seconds
	await get_tree().create_timer(life_time).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	# Move forward relative to self
	global_position += -global_transform.basis.z * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("apply_spin"):
		body.apply_spin(180)
		print("Elastic band hit a car!")
		queue_free()
	elif body is StaticBody3D: # Hit a wall
		queue_free()
