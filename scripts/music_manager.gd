extends Node

## Music Manager - Singleton for handling background music
## Manages track selection, looping, and volume control

enum MusicTrack {
	NONE,
	ACTION_1,
	ACTION_2,
	ACTION_3,
	ACTION_4,
	ACTION_5,
	RANDOM  # Randomly select from action tracks
}

var music_player: AudioStreamPlayer
var current_track: MusicTrack = MusicTrack.NONE
var music_volume: float = 0.7  # 0.0 to 1.0

# Track paths
var track_paths = {
	MusicTrack.ACTION_1: "res://music/bgm_action_1.mp3",
	MusicTrack.ACTION_2: "res://music/bgm_action_2.mp3",
	MusicTrack.ACTION_3: "res://music/bgm_action_3.mp3",
	MusicTrack.ACTION_4: "res://music/bgm_action_4.mp3",
	MusicTrack.ACTION_5: "res://music/bgm_action_5.mp3",
}

func _ready() -> void:
	# Create audio player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"  # We'll create this bus
	add_child(music_player)
	music_player.finished.connect(_on_track_finished)
	
	print("MusicManager initialized")

func play_track(track: MusicTrack) -> void:
	if track == MusicTrack.NONE:
		stop_music()
		return
	
	# Handle random selection
	if track == MusicTrack.RANDOM:
		var action_tracks = [
			MusicTrack.ACTION_1,
			MusicTrack.ACTION_2,
			MusicTrack.ACTION_3,
			MusicTrack.ACTION_4,
			MusicTrack.ACTION_5
		]
		track = action_tracks[randi() % action_tracks.size()]
	
	# Don't restart if already playing this track
	if current_track == track and music_player.playing:
		return
	
	current_track = track
	
	# Load and play
	var track_path = track_paths.get(track)
	if track_path:
		var stream = load(track_path)
		if stream:
			music_player.stream = stream
			music_player.volume_db = linear_to_db(music_volume)
			music_player.play()
			print("Playing track: %s" % track_path)
		else:
			printerr("Failed to load music: %s" % track_path)
	else:
		printerr("Unknown track: %d" % track)

func stop_music() -> void:
	music_player.stop()
	current_track = MusicTrack.NONE

func pause_music() -> void:
	music_player.stream_paused = true

func resume_music() -> void:
	music_player.stream_paused = false

func set_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)

func fade_out(duration: float = 1.0) -> void:
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, duration)
	tween.tween_callback(stop_music)

func fade_in(duration: float = 1.0) -> void:
	music_player.volume_db = -80.0
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), duration)

func _on_track_finished() -> void:
	# Loop the current track
	if current_track != MusicTrack.NONE:
		music_player.play()
