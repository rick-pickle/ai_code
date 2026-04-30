extends Node

const DEFAULT_BUS := "Master"

const AMBIENCE_PATHS := {
	"rain": "res://assets/audio/ambience/rain_loop.wav",
}

const SFX_PATHS := {
	"dialogue_advance": "res://assets/audio/sfx/dialogue_advance.wav",
	"open_seal": "res://assets/audio/sfx/open_seal.wav",
	"archive_seal": "res://assets/audio/sfx/archive_seal.wav",
	"return_to_sender": "res://assets/audio/sfx/return_to_sender.wav",
	"send_letter": "res://assets/audio/sfx/send_letter.wav",
	"see_through": "res://assets/audio/sfx/see_through.wav",
	"lamplight": "res://assets/audio/sfx/lamplight.wav",
	"boss_appear": "res://assets/audio/sfx/boss_appear.wav",
	"victory": "res://assets/audio/sfx/victory.wav",
	"defeat": "res://assets/audio/sfx/defeat.wav",
}

var _ambience_player: AudioStreamPlayer
var _stream_cache: Dictionary = {}
var _playback_enabled := true


func _ready() -> void:
	_playback_enabled = not _is_headless()
	if not _playback_enabled:
		print("AUDIO_STAGE ready headless=true playback_enabled=false created_player=false")
		return

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	_ambience_player.bus = DEFAULT_BUS
	_ambience_player.volume_db = -18.0
	add_child(_ambience_player)
	print("AUDIO_STAGE ready headless=false playback_enabled=true created_player=true")
	play_ambience("rain")


func _exit_tree() -> void:
	stop_all()


func play_ambience(sound_id: String, volume_db: float = -18.0) -> void:
	if not _playback_enabled:
		return
	var stream := _load_stream(AMBIENCE_PATHS.get(sound_id, ""))
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_ambience_player.stream = stream
	_ambience_player.volume_db = volume_db
	if not _ambience_player.playing:
		_ambience_player.play()


func stop_ambience() -> void:
	if _ambience_player != null:
		_ambience_player.stop()
		_ambience_player.stream = null


func stop_all() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			var player := child as AudioStreamPlayer
			player.stop()
			player.stream = null
	_stream_cache.clear()


func play_sfx(sound_id: String, volume_db: float = -8.0, pitch_scale: float = 1.0) -> void:
	if not _playback_enabled:
		return
	var stream := _load_stream(SFX_PATHS.get(sound_id, ""))
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.name = "Sfx_%s" % sound_id
	player.bus = DEFAULT_BUS
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_skill(skill_id: String) -> void:
	if SFX_PATHS.has(skill_id):
		play_sfx(skill_id)


func _load_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if _stream_cache.has(path):
		return _stream_cache[path] as AudioStream

	if path.get_extension().to_lower() == "wav":
		var wav_stream := _load_pcm16_wav(path)
		if wav_stream != null:
			_stream_cache[path] = wav_stream
			return wav_stream

	if not ResourceLoader.exists(path):
		push_warning("Missing audio stream: %s" % path)
		return null
	var loaded: Resource = load(path)
	if loaded is AudioStream:
		_stream_cache[path] = loaded
		return loaded as AudioStream
	push_warning("Invalid audio stream: %s" % path)
	return null


func _is_headless() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"


func _load_pcm16_wav(path: String) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		push_warning("Missing WAV file: %s" % path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Cannot open WAV file: %s" % path)
		return null

	if file.get_buffer(4).get_string_from_ascii() != "RIFF":
		push_warning("Invalid WAV RIFF header: %s" % path)
		return null
	file.seek(8)
	if file.get_buffer(4).get_string_from_ascii() != "WAVE":
		push_warning("Invalid WAV WAVE header: %s" % path)
		return null

	var channels := 0
	var sample_rate := 0
	var bits_per_sample := 0
	var data := PackedByteArray()

	while file.get_position() + 8 <= file.get_length():
		var chunk_id := file.get_buffer(4).get_string_from_ascii()
		var chunk_size := file.get_32()
		var chunk_start := file.get_position()
		if chunk_id == "fmt ":
			var audio_format := file.get_16()
			channels = file.get_16()
			sample_rate = file.get_32()
			file.seek(chunk_start + 14)
			bits_per_sample = file.get_16()
			if audio_format != 1:
				push_warning("Unsupported WAV format: %s" % path)
				return null
		elif chunk_id == "data":
			data = file.get_buffer(chunk_size)
		file.seek(chunk_start + chunk_size + (chunk_size % 2))

	if channels <= 0 or sample_rate <= 0 or bits_per_sample != 16 or data.is_empty():
		push_warning("Unsupported WAV data: %s" % path)
		return null

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = channels == 2
	stream.data = data
	return stream
