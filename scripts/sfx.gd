extends Node
## Efectos de sonido sintetizados en tiempo de ejecución (autoload "Sfx").
## No usa archivos de audio externos: genera ondas PCM de 16 bits estilo 8-bit.

const RATE := 22050
const POOL_SIZE := 8

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _noise := RandomNumberGenerator.new()


func _ready() -> void:
	_noise.seed = 4242
	_streams["shoot"] = _make("shoot", 0.09)
	_streams["explosion"] = _make("explosion", 0.45)
	_streams["bridge"] = _make("bridge", 0.9)
	_streams["fuel_low"] = _make("fuel_low", 0.12)
	_streams["refuel"] = _make("refuel", 0.14)
	_streams["enemy_shot"] = _make("enemy_shot", 0.12)
	_streams["click"] = _make("click", 0.05)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)


func play(sound: String, volume_db: float = 0.0) -> void:
	if not _streams.has(sound):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.play()


func _make(kind: String, duration: float) -> AudioStreamWAV:
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var phase2 := 0.0
	for i in n:
		var p := float(i) / float(n)
		var v := 0.0
		match kind:
			"shoot":
				phase += lerpf(1500.0, 420.0, p) / RATE
				v = _square(phase) * (1.0 - p) * 0.22
			"explosion":
				phase += lerpf(120.0, 40.0, p) / RATE
				v = (_noise.randf_range(-1.0, 1.0) * 0.7 + _square(phase) * 0.3) * pow(1.0 - p, 2.0) * 0.55
			"bridge":
				phase += lerpf(90.0, 30.0, p) / RATE
				v = (_noise.randf_range(-1.0, 1.0) * 0.6 + _square(phase) * 0.4) * pow(1.0 - p, 1.5) * 0.6
			"fuel_low":
				phase += 880.0 / RATE
				v = sin(TAU * phase) * 0.28 * (1.0 if p < 0.75 else (1.0 - p) / 0.25)
			"refuel":
				phase += lerpf(320.0, 960.0, p) / RATE
				phase2 += lerpf(480.0, 1440.0, p) / RATE
				v = (sin(TAU * phase) + 0.4 * sin(TAU * phase2)) * 0.16 * (1.0 - p * 0.5)
			"enemy_shot":
				phase += lerpf(600.0, 1100.0, p) / RATE
				v = _square(phase) * (1.0 - p) * 0.16
			"click":
				phase += 1200.0 / RATE
				v = _square(phase) * (1.0 - p) * 0.15
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


func _square(ph: float) -> float:
	return 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
