extends Node
## Autoload "Sfx": tiny procedural sound bank so the prototype needs no audio assets.
## Swap these for real samples later; keep the play(name, pitch) interface.

const RATE := 22050
const POOL := 8
## Notes (semitones above C5) for the rising snap combo.
const COMBO_STEPS: Array[int] = [0, 2, 4, 7, 9, 12, 14, 16]

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = Settings.SFX_BUS
		add_child(p)
		_players.append(p)
	_streams["click"] = _synth([[740.0, 0.0], [1110.0, 0.0]], 0.09, 40.0, 0.4)
	_streams["hover"] = _synth([[1320.0, 0.0]], 0.04, 80.0, 0.12)
	_streams["pick"] = _synth([[520.0, 0.0]], 0.07, 45.0, 0.35)
	_streams["tick"] = _synth([[1040.0, 0.0]], 0.04, 90.0, 0.25)
	_streams["snap"] = _synth([[523.25, 0.0], [1046.5, 0.0], [1568.0, 0.03]], 0.28, 14.0, 0.6)
	_streams["wrong"] = _synth([[150.0, 0.0], [110.0, 0.05]], 0.2, 20.0, 0.6)
	_streams["row"] = _synth([[784.0, 0.0], [988.0, 0.09], [1175.0, 0.18]], 0.6, 8.0, 0.55)
	_streams["win"] = _synth([[523.25, 0.0], [659.25, 0.12], [784.0, 0.24], [1046.5, 0.36], [1318.5, 0.52], [1568.0, 0.68]], 1.8, 3.5, 0.6)


func play(sound: String, pitch := 1.0) -> void:
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.play()


func combo_pitch(combo: int) -> float:
	return pow(2.0, COMBO_STEPS[mini(combo, COMBO_STEPS.size() - 1)] / 12.0)


## notes: Array of [frequency_hz, start_seconds]; each is a decaying sine + octave.
func _synth(notes: Array, length: float, decay: float, volume: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for note in notes:
		var f: float = note[0]
		var i0 := int(float(note[1]) * RATE)
		for i in range(i0, n):
			var t := float(i - i0) / RATE
			var env := minf(t / 0.004, 1.0) * exp(-t * decay)
			buf[i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * env
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i] / peak * volume, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
