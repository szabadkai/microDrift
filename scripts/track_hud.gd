extends CanvasLayer

## Reusable HUD that automatically finds and displays stats for the first DriftCar

var player_car: DriftCar
var speed_label: Label
var drift_label: Label
var boost_label: Label

func _ready() -> void:
  # Find labels
  speed_label = get_node_or_null("SpeedLabel")
  drift_label = get_node_or_null("DriftLabel")
  boost_label = get_node_or_null("BoostLabel")
  
  # Auto-detect player car
  _find_player_car()

func _find_player_car() -> void:
  # Search entire scene tree for a DriftCar
  var root = get_tree().root
  for child in root.get_children():
    var car = _find_drift_car_recursive(child)
    if car:
      player_car = car
      print("HUD found car: %s" % player_car.name)
      return
  
  if not player_car:
    printerr("TrackHUD: No DriftCar found in scene!")

func _find_drift_car_recursive(node: Node) -> DriftCar:
  if node is DriftCar:
    return node
  
  for child in node.get_children():
    var result = _find_drift_car_recursive(child)
    if result:
      return result
  
  return null

func _process(_delta: float) -> void:
  if not player_car:
    return
  
  # Speed display
  if speed_label:
    var speed_mps = player_car.current_speed
    var speed_kmh = speed_mps * 3.6
    speed_label.text = "Speed: %.1f km/h" % speed_kmh
  
  # Drift charge display
  if drift_label:
    var charge_percent = player_car.get_drift_charge_normalized() * 100.0
    drift_label.text = "Drift: %.0f%%" % charge_percent
    
    # Color based on charge tier
    if charge_percent >= 83:
      drift_label.add_theme_color_override("font_color", Color.ORANGE)
    elif charge_percent >= 50:
      drift_label.add_theme_color_override("font_color", Color.CYAN)
    else:
      drift_label.add_theme_color_override("font_color", Color.WHITE)
  
  # Boost state
  if boost_label:
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
