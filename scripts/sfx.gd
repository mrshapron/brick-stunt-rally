extends Node
## Autoloaded sound system. All sounds are synthesized procedurally into
## AudioStreamWAV buffers at startup, so the game ships with zero audio assets.
## The engine is a seamless looped tone whose pitch tracks the car's speed;
## flips/smashes/checkpoints/finish are one-shots played from a small pool.

const MIX: int = 22050

var _engine: AudioStreamPlayer
var _engine_target_pitch: float = 0.6
var _engine_target_vol: float = -26.0
var _music: AudioStreamPlayer

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
	_engine.volume_db = -26.0
	add_child(_engine)

	# Gentle background music (soft pad chords + a light arpeggio), looped.
	_music = AudioStreamPlayer.new()
	_music.stream = _make_music()
	_music.volume_db = -17.0
	add_child(_music)
	_music.play()

	# Softer, rounder one-shots (sine-based, gentle envelopes, low noise).
	_flip = _make_sequence([523.0, 784.0], 0.12)
	_smash = _make_smash()
	_checkpoint = _make_sequence([660.0, 990.0], 0.1)
	_finish = _make_sequence([523.0, 659.0, 784.0, 1046.0], 0.15)
	_shoot = _make_soft_pew(720.0, 360.0, 0.14)
	_explosion = _make_explosion()
	_hit = _make_soft_pew(440.0, 330.0, 0.09)

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
	_engine_target_vol = lerpf(-26.0, -15.0, clampf(ratio * 1.3, 0.0, 1.0))


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
			p.volume_db = -13.0
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
	# A smooth, rounded hum: mostly sine + sub octave, only a hint of saw so it
	# has texture without the harsh buzz.
	var n := int(0.3 * MIX)
	var cycles := 21
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var ph := fposmod(float(i) / n * cycles, 1.0)
		var saw := ph * 2.0 - 1.0
		var sine := sin(ph * TAU)
		var sub := sin(ph * TAU * 0.5)
		var v := (saw * 0.12 + sine * 0.55 + sub * 0.33) * 0.42
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var st := _wav(data)
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	return st


func _make_soft_pew(f0: float, f1: float, dur: float) -> AudioStreamWAV:
	# A mellow, rounded blip: a pure sine glide with a soft attack/decay and a
	# touch of a higher harmonic for sparkle. No noise.
	var n := int(dur * MIX)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t * t)
		phase += TAU * f / MIX
		var env: float = clampf(t * 8.0, 0.0, 1.0) * pow(1.0 - t, 1.8)
		var v := (sin(phase) * 0.85 + sin(phase * 2.0) * 0.15) * env * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


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
	# A soft rounded "thock": a mellow woodblock tone with a gentle decay and
	# only a whisper of click - no harsh noise.
	var n := int(0.16 * MIX)
	var data := PackedByteArray()
	data.resize(n * 2)
	var f0 := 190.0
	for i in n:
		var t := float(i) / MIX
		var env: float = exp(-t * 24.0)
		var body := sin(TAU * f0 * t) * 0.7 + sin(TAU * f0 * 2.0 * t) * 0.2
		var click: float = exp(-t * 160.0) * sin(TAU * 520.0 * t) * 0.18
		var v := (body * env + click) * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _make_explosion() -> AudioStreamWAV:
	# A soft "whoomph": a low descending tone with a gentle filtered-noise
	# swell, smooth decay, kept mellow rather than harsh.
	var n := int(0.5 * MIX)
	var data := PackedByteArray()
	data.resize(n * 2)
	var nprev := 0.0
	for i in n:
		var t := float(i) / MIX
		var env: float = pow(1.0 - float(i) / n, 2.2)
		var rumble := sin(TAU * lerpf(110.0, 40.0, clampf(t / 0.5, 0.0, 1.0)) * t)
		# One-pole low-passed noise = soft "air" instead of a harsh hiss.
		var raw := randf() * 2.0 - 1.0
		nprev = lerpf(nprev, raw, 0.12)
		var v := (rumble * 0.6 + nprev * 0.4) * env * 0.55
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _make_music() -> AudioStreamWAV:
	# A calm looping backing track: soft sustained pad chords + a gentle
	# arpeggio over a I-V-vi-IV progression in C, with a light echo for warmth.
	var chords := [
		[261.63, 329.63, 392.0],
		[392.0, 493.88, 587.33],
		[220.0, 261.63, 329.63],
		[174.61, 220.0, 261.63],
	]
	var prog: Array = chords + chords
	var bar := 2.4
	var bar_n := int(bar * MIX)
	var n := bar_n * prog.size()
	var buf := PackedFloat32Array()
	buf.resize(n)

	for ci in prog.size():
		var chord: Array = prog[ci]
		var start := ci * bar_n
		for note in chord:
			_add_note(buf, start, bar_n, float(note), 0.11, true)
		_add_note(buf, start, bar_n, chord[0] * 0.5, 0.14, true)
		var steps := 6
		var sdur := bar / float(steps)
		for s in steps:
			var f: float = chord[s % chord.size()] * 2.0
			_add_note(buf, start + int(s * sdur * MIX), int(sdur * MIX * 0.9), f, 0.09, false)

	# Soft feedback echo for warmth.
	var delay := int(0.28 * MIX)
	for i in range(delay, n):
		buf[i] += buf[i - delay] * 0.28

	# Normalise to a safe headroom, then encode 16-bit.
	var peak := 0.0001
	for i in n:
		peak = maxf(peak, absf(buf[i]))
	var norm := 0.85 / peak
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i] * norm, -1.0, 1.0) * 32767.0))
	var st := _wav(data)
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	return st


func _add_note(buf: PackedFloat32Array, off: int, length: int, freq: float, amp: float, pad: bool) -> void:
	var n := buf.size()
	for i in length:
		var idx := off + i
		if idx >= n:
			break
		var t := float(i) / float(length)
		var env: float
		if pad:
			# Slow swell in and out (soft pad).
			env = clampf(t * 5.0, 0.0, 1.0) * clampf((1.0 - t) * 5.0, 0.0, 1.0)
		else:
			# Plucky: quick attack, gentle exponential decay.
			env = clampf(t * 24.0, 0.0, 1.0) * exp(-t * 4.5)
		var ph := TAU * freq * (float(i) / MIX)
		var s := sin(ph) * 0.82 + sin(ph * 2.0) * 0.18
		buf[idx] += s * env * amp


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
