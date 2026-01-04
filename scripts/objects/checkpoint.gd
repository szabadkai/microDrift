extends Area3D
class_name Checkpoint

## Checkpoint system for lap counting
## Index 0 is the Start/Finish line

@export var index: int = 0
@export var is_start_finish: bool = false

signal checkpoint_passed(car: Node3D, index: int)

func _ready() -> void:
  body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
  # Check if the body is a car (DriftCar class)
  # We use duck typing or class checking
  if body.has_method("get_drift_charge_normalized") or body is VehicleBody3D:
    checkpoint_passed.emit(body, index)
