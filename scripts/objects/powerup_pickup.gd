extends Area3D

@onready var model: Node3D = $Model
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var respawn_timer: Timer = $RespawnTimer

const ROTATION_SPEED: float = 2.0

func _process(delta: float) -> void:
  if model.visible:
    model.rotate_y(ROTATION_SPEED * delta)

func _ready() -> void:
  body_entered.connect(_on_body_entered)
  respawn_timer.timeout.connect(_on_respawn_timeout)

func _on_body_entered(body: Node3D) -> void:
  if body.has_method("collect_powerup"):
    # Random powerup
    var powerup_names = ["BATTERY", "MARBLE", "ELASTIC"]
    var type = powerup_names[randi_range(0, 2)]
    body.collect_powerup(type)
    _set_active(false)
    respawn_timer.start()

func _on_respawn_timeout() -> void:
  _set_active(true)

func _set_active(active: bool) -> void:
  model.visible = active
  collision.set_deferred("disabled", !active)
