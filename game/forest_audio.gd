class_name ForestAudio
extends Node

var enabled: bool = false
var wind: AudioStreamPlayer
var effect: AudioStreamPlayer
var voice:AudioStreamPlayer
var impacts:Dictionary={}
var voices:Dictionary={}

func _ready() -> void:
	wind = AudioStreamPlayer.new()
	wind.volume_db = -22.0
	add_child(wind)
	effect = AudioStreamPlayer.new()
	effect.volume_db = -16.0
	add_child(effect)
	voice=AudioStreamPlayer.new();voice.volume_db=-22.0;add_child(voice)

func toggle() -> bool:
	enabled = not enabled
	if enabled:
		if wind.stream == null:
			wind.stream = _wind_stream()
		wind.play()
	else:
		wind.stop()
		effect.stop()
		voice.stop()
	return enabled

func speak(data:AppearanceData,text:String)->void:
	if not enabled or data==null:return
	voice.stream=voice_stream(data,clampi(text.length()/35,3,7))
	voice.pitch_scale=data.voice_pitch;voice.play()

## Short RPG syllables, not recorded speech or text-to-speech. Each identity
## keeps its pitch, harmonic character, cadence and reproducible intonation.
func voice_stream(data:AppearanceData,syllables:int=5)->AudioStreamWAV:
	var key:="%d:%d:%d"%[data.seed,data.variant,syllables]
	if voices.has(key):return voices[key]
	var rate:=11025;var duration:=data.voice_cadence*syllables
	var bytes:=PackedByteArray();bytes.resize(ceili(duration*rate)*2)
	var rng:=RandomNumberGenerator.new();rng.seed=data.seed
	var tones:Array[float]=[]
	for i in syllables:tones.append(rng.randf_range(0.89,1.12))
	var base:=155.0+data.voice_timbre*37.0+posmod(data.seed,57)
	for i in bytes.size()/2:
		var time:=float(i)/rate
		var syllable:=mini(syllables-1,floori(time/data.voice_cadence))
		var local:=fmod(time,data.voice_cadence)/data.voice_cadence
		var phase:=time*base*tones[syllable]*TAU
		var tone:=sin(phase)*0.5+sin(phase*2.0+0.3)*0.18+sin(phase*(3+data.voice_timbre))*0.1
		if data.voice_timbre in [2,4]:tone+=rng.randf_range(-0.10,0.10)
		var envelope:=sin(minf(local/0.78,1.0)*PI)*0.35 if local<0.78 else 0.0
		bytes.encode_s16(i*2,roundi(tone*envelope*24000))
	voices[key]=_wav(bytes,rate)
	return voices[key]

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

func impact(wood:bool)->void:
	if not enabled:return
	if not impacts.has(wood):
		var rate:=11025;var bytes:=PackedByteArray();bytes.resize(2205*2)
		var rng:=RandomNumberGenerator.new();rng.seed=349 if wood else 901
		for i in 2205:
			var t:=float(i)/rate
			var tone:=sin(t*(140 if wood else 920)*TAU)*0.45+rng.randf_range(-0.5,0.5)
			bytes.encode_s16(i*2,int(tone*exp(-t*(24 if wood else 38))*22000))
		impacts[wood]=_wav(bytes,rate)
	effect.stream=impacts[wood];effect.play()

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
