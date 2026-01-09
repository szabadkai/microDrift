extends BaseTrack

## Track Editor Test Scene
## Uses BaseTrack for common functionality (pause menu, inputs, music)
## Add any track-specific behavior here

func _on_track_ready() -> void:
  # Any track-specific setup can go here
  print("Track Editor Test scene loaded")
