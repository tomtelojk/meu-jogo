class_name ForestAudio
extends Node

var enabled: bool = false
var wind: AudioStreamPlayer
var effect: AudioStreamPlayer

func _ready() -> void:
	wind = AudioStreamPlayer.new()
	wind.volume_db = -22.0
	add_child(wind)
	effect = AudioStreamPlayer.new()
	effect.volume_db = -16.0
	add_child(effect)

func toggle() -> bool:
	enabled = not enabled
	if enabled:
		if wind.stream == null:
			wind.stream = _wind_stream()
		wind.play()
	else:
		wind.stop()
		effect.stop()
	return enabled

func chime(victory: bool = false) -> void:
	if not enabled:
		return
	var notes: Array[float] = [392.0, 523.25, 659.25, 783.99, 1046.5] if victory else [523.25, 659.25, 783.99]
	var rate: int = 22050
	var duration := 2.0 if victory else 1.0
	var bytes := PackedByteArray()
	bytes.resize(int(rate * duration) * 2)
	for i in int(rate * duration):
		var t := float(i) / rate
		var value := 0.0
		for n in notes.size():
			var offset := t - n * 0.12
			if offset >= 0:
				value += sin(offset * notes[n] * TAU) * exp(-offset * 5.0) * minf(offset * 70, 1) * 0.2
		bytes.encode_s16(i * 2, int(clampf(value, -1, 1) * 32767))
	effect.stream = _wav(bytes, rate)
	effect.play()

func _wind_stream() -> AudioStreamWAV:
	var rate := 11025
	var bytes := PackedByteArray()
	bytes.resize(rate * 4 * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 713
	var last := 0.0
	for i in rate * 4:
		last = (last + rng.randf_range(-1, 1) * 0.018) / 1.018
		bytes.encode_s16(i * 2, int(clampf(last * 2, -1, 1) * 32767))
	var stream := _wav(bytes, rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = rate * 4
	return stream

func _wav(bytes: PackedByteArray, rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream
