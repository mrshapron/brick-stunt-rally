extends Node
## Autoloaded sound system. All sounds are synthesized procedurally into
## AudioStreamWAV buffers at startup, so the game ships with zero audio assets.
## The engine is a seamless looped tone whose pitch tracks the car's speed;
## flips/smashes/checkpoints/finish are one-shots played from a small pool.

const MIX: int = 22050

var _engine: AudioStreamPlayer
var _engine_target_pitch: float = 0.6
var _engine_target_vol: float = -24.0

var _flip: AudioStreamWAV
var _smash: AudioStreamWAV
var _checkpoint: AudioStreamWAV
var _finish: AudioStreamWAV
var _shoot: AudioStreamWAV
var _explosion: AudioStreamWAV
var _hit: AudioStreamWAV

var _pool: Array[AudioStreamPlayer] = []
var _last_smash_ms: int = 0
var muted: bool = true


func _ready() -> void:
	_engine = AudioStreamPlayer.new()
	_engine.stream = _make_engine()
	_engine.volume_db = -24.0
	add_child(_engine)

	_flip = _make_chirp(420.0, 950.0, 0.28)
	_smash = _make_smash()
	_checkpoint = _make_sequence([660.0, 990.0], 0.09)
	_finish = _make_sequence([523.0, 659.0, 784.0, 1046.0], 0.14)
	_shoot = _make_chirp(1100.0, 320.0, 0.16)
	_explosion = _make_explosion()
	_hit = _make_chirp(700.0, 500.0, 0.06)

	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

	AudioServer.set_bus_mute(0, muted)


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	return muted


func is_muted() -> bool:
	return muted


func _process(delta: float) -> void:
	if _engine.playing:
		var w := clampf(delta * 6.0, 0.0, 1.0)
		_engine.pitch_scale = lerpf(_engine.pitch_scale, _engine_target_pitch, w)
		_engine.volume_db = lerpf(_engine.volume_db, _engine_target_vol, w)


func start_engine() -> void:
	_engine.pitch_scale = 0.6
	if not _engine.playing:
		_engine.play()


func stop_engine() -> void:
	_engine.stop()


func set_engine_speed(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.4)
	_engine_target_pitch = 0.6 + ratio * 1.6
	_engine_target_vol = lerpf(-24.0, -8.0, clampf(ratio * 1.3, 0.0, 1.0))


func play_flip() -> void:
	_play(_flip, 0.0)


func play_smash() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_smash_ms < 70:
		return
	_last_smash_ms = now
	_play(_smash, randf_range(-2.0, 2.0))


func play_checkpoint() -> void:
	_play(_checkpoint, 0.0)


func play_finish() -> void:
	_play(_finish, 0.0)


func play_shoot() -> void:
	_play(_shoot, randf_range(-3.0, 3.0))


func play_explosion() -> void:
	_play(_explosion, randf_range(-2.0, 2.0))


func play_hit() -> void:
	_play(_hit, randf_range(-3.0, 3.0))


func _play(stream: AudioStreamWAV, pitch_variation: float) -> void:
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = 1.0 + pitch_variation * 0.05
			p.volume_db = -6.0
			p.play()
			return


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = MIX
	st.stereo = false
	st.data = data
	return st


func _make_engine() -> AudioStreamWAV:
	var n := int(0.3 * MIX)
	var cycles := 21
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var ph := fposmod(float(i) / n * cycles, 1.0)
		var saw := ph * 2.0 - 1.0
		var sine := sin(ph * TAU)
		var sub := sin(ph * TAU * 0.5)
		var v := (saw * 0.5 + sine * 0.3 + sub * 0.2) * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var st := _wav(data)
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	return st


func _make_chirp(f0: float, f1: float, dur: float) -> AudioStreamWAV:
	var n := int(dur * MIX)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += TAU * f / MIX
		var env := sin(PI * t)
		var v := sin(phase) * env * 0.6
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _make_smash() -> AudioStreamWAV:
	# A short percussive "block clack": two woodblock-like partials with a fast
	# exponential decay, a sharp click transient, and just a touch of noise.
	var n := int(0.18 * MIX)
	var data := PackedByteArray()
	data.resize(n * 2)
	var f0 := 210.0
	for i in n:
		var t := float(i) / MIX
		var env: float = exp(-t * 28.0)
		var body := sin(TAU * f0 * t) * 0.6 + sin(TAU * f0 * 2.76 * t) * 0.3
		var click: float = exp(-t * 220.0) * sin(TAU * 900.0 * t) * 0.45
		var noise := (randf() * 2.0 - 1.0) * exp(-t * 130.0) * 0.18
		var v := (body * env + click + noise) * 0.7
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _make_explosion() -> AudioStreamWAV:
	# A meaty boom: noise burst over a low descending rumble, slow decay.
	var n := int(0.45 * MIX)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / MIX
		var env: float = pow(1.0 - float(i) / n, 1.6)
		var rumble := sin(TAU * lerpf(120.0, 45.0, clampf(t / 0.45, 0.0, 1.0)) * t)
		var noise := randf() * 2.0 - 1.0
		var v := (noise * 0.55 + rumble * 0.45) * env * 0.9
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _make_sequence(freqs: Array, each: float) -> AudioStreamWAV:
	var seg := int(each * MIX)
	var gap := int(0.02 * MIX)
	var total := (seg + gap) * freqs.size()
	var data := PackedByteArray()
	data.resize(total * 2)
	var idx := 0
	for f in freqs:
		for i in seg:
			var t := float(i) / seg
			var env := sin(PI * t)
			var v := sin(TAU * float(f) * float(i) / MIX) * env * 0.6
			data.encode_s16(idx * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
			idx += 1
		for i in gap:
			data.encode_s16(idx * 2, 0)
			idx += 1
	return _wav(data)
