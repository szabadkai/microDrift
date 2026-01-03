extends Node3D

## Test track scene for vehicle tuning
## Updates debug UI with vehicle state

@onready var player_car: DriftCar = $Player1Car
@onready var speed_label: Label = $DebugUI/SpeedLabel
@onready var drift_label: Label = $DebugUI/DriftLabel
@onready var boost_label: Label = $DebugUI/BoostLabel


func _ready() -> void:
  # Connect to car signals for visual feedback
  player_car.drift_started.connect(_on_drift_started)
  player_car.drift_ended.connect(_on_drift_ended)
  player_car.boost_activated.connect(_on_boost_activated)


func _process(_delta: float) -> void:
  _update_debug_ui()


func _update_debug_ui() -> void:
  if not player_car:
    return
  
  # Speed display
  var speed_mps = player_car.current_speed
  var speed_kmh = speed_mps * 3.6
  speed_label.text = "Speed: %.1f km/h" % speed_kmh
  
  # Drift charge display
  var charge_percent = player_car.get_drift_charge_normalized() * 100.0
  drift_label.text = "Drift: %.0f%%" % charge_percent
  
  # Color the drift label based on charge tier
  if charge_percent >= 83:  # Orange threshold (2.5/3.0)
    drift_label.add_theme_color_override("font_color", Color.ORANGE)
  elif charge_percent >= 50:  # Blue threshold (1.5/3.0)
    drift_label.add_theme_color_override("font_color", Color.CYAN)
  else:
    drift_label.add_theme_color_override("font_color", Color.WHITE)
  
  # Boost state
  match player_car.get_current_boost_tier():
    DriftCar.BoostTier.ORANGE:
      boost_label.text = "BOOST: ORANGE!"
      boost_label.add_theme_color_override("font_color", Color.ORANGE)
    DriftCar.BoostTier.BLUE:
      boost_label.text = "BOOST: BLUE"
      boost_label.add_theme_color_override("font_color", Color.CYAN)
    _:
      boost_label.text = "Boost: Ready"
      boost_label.add_theme_color_override("font_color", Color.WHITE)


func _on_drift_started() -> void:
  print("[DEBUG] Drift started!")


func _on_drift_ended(charge: float, tier: DriftCar.BoostTier) -> void:
  print("[DEBUG] Drift ended - Charge: %.2f, Tier: %s" % [charge, DriftCar.BoostTier.keys()[tier]])


func _on_boost_activated(tier: DriftCar.BoostTier) -> void:
  print("[DEBUG] Boost activated: %s" % DriftCar.BoostTier.keys()[tier])
