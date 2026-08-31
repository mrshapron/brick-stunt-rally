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
var _turn: AudioStreamWAV
var _levelstart: AudioStreamWAV
var _click: AudioStreamWAV

var _pool: Array[AudioStreamPlayer] = []
var _last_smash_ms: int = 0
var _last_turn_ms: int = 0
var muted: bool = false

# GTA-style radio: a list of stations you can flip through. Each entry is
# {name, stream}; a null stream means "Radio Off".
var _stations: Array = []
var _station_idx: int = 1
var _radio_layer: CanvasLayer
var _radio_label: Label
var _radio_toast_t: float = 0.0


func _ready() -> void:
	# Keep audio alive while the game is paused so menu clicks still sound.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_engine = AudioStreamPlayer.new()
	_engine.stream = _make_engine()
	_engine.volume_db = -26.0
	add_child(_engine)

	# Radio: several looped stations to choose from while you play.
	_music = AudioStreamPlayer.new()
	_music.volume_db = -16.0
	add_child(_music)
	_build_stations()
	_apply_station()
	_build_radio_ui()

	# Softer, rounder one-shots (sine-based, gentle envelopes, low noise).
	_flip = _make_sequence([523.0, 784.0], 0.12)
	_smash = _make_smash()
	_checkpoint = _make_sequence([660.0, 990.0], 0.1)
	_finish = _make_sequence([523.0, 659.0, 784.0, 1046.0], 0.15)
	_shoot = _make_soft_pew(720.0, 360.0, 0.14)
	_explosion = _make_explosion()
	_hit = _make_soft_pew(440.0, 330.0, 0.09)
	_turn = _make_swish(0.22)
	_levelstart = _make_levelstart()
	_click = _make_click()

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


func radio_name() -> String:
	if _stations.is_empty():
		return ""
	return str(_stations[_station_idx].get("name", ""))


func radio_next() -> String:
	if _stations.is_empty():
		return ""
	_station_idx = (_station_idx + 1) % _stations.size()
	_apply_station()
	_show_radio_toast(radio_name())
	return radio_name()


func radio_prev() -> String:
	if _stations.is_empty():
		return ""
	_station_idx = (_station_idx - 1 + _stations.size()) % _stations.size()
	_apply_station()
	_show_radio_toast(radio_name())
	return radio_name()


func _apply_station() -> void:
	if _stations.is_empty():
		return
	var stream = _stations[_station_idx].get("stream")
	if stream == null:
		_music.stop()
	else:
		_music.stream = stream
		_music.play()


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action("radio") and event.is_action_pressed("radio"):
		radio_next()


func _process(delta: float) -> void:
	if _engine.playing:
		var w := clampf(delta * 6.0, 0.0, 1.0)
		_engine.pitch_scale = lerpf(_engine.pitch_scale, _engine_target_pitch, w)
		_engine.volume_db = lerpf(_engine.volume_db, _engine_target_vol, w)

	if _radio_toast_t > 0.0 and _radio_label:
		_radio_toast_t -= delta
		_radio_label.modulate.a = clampf(_radio_toast_t / 0.6, 0.0, 1.0)


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


func play_turn() -> void:
	# Soft tire scrub when the car sharply changes heading. Rate-limited and
	# quiet so it adds feel without getting noisy.
	var now := Time.get_ticks_msec()
	if now - _last_turn_ms < 240:
		return
	_last_turn_ms = now
	_play(_turn, randf_range(-2.0, 2.0), -20.0)


func play_level_start() -> void:
	_play(_levelstart, 0.0, -11.0)


func play_click() -> void:
	_play(_click, randf_range(-1.0, 1.0), -16.0)


func _play(stream: AudioStreamWAV, pitch_variation: float, vol: float = -13.0) -> void:
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = 1.0 + pitch_variation * 0.05
			p.volume_db = vol
			p.play()
			return


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = MIX
	st.stereo = false
	st.data = data
	return st


func _build_radio_ui() -> void:
	# A small "now playing" toast that fades after switching stations.
	_radio_layer = CanvasLayer.new()
	_radio_layer.layer = 64
	add_child(_radio_layer)
	_radio_label = Label.new()
	_radio_label.anchor_left = 0.5
	_radio_label.anchor_right = 0.5
	_radio_label.offset_top = 26.0
	_radio_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_radio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_radio_label.add_theme_font_size_override("font_size", 30)
	_radio_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_radio_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_radio_label.add_theme_constant_override("outline_size", 10)
	_radio_label.modulate.a = 0.0
	_radio_layer.add_child(_radio_label)


func _show_radio_toast(text: String) -> void:
	if _radio_label == null:
		return
	_radio_label.text = "RADIO  -  %s" % text
	_radio_toast_t = 2.0
	_radio_label.modulate.a = 1.0


func _build_stations() -> void:
	_stations = [
		{"name": "Chill Waves", "stream": _make_music()},
		{
			"name": "Synthwave",
			"stream": _make_track({
				"prog": [
					[220.0, 261.63, 329.63], [174.61, 220.0, 261.63],
					[261.63, 329.63, 392.0], [196.0, 246.94, 392.0],
				],
				"bar": 1.8, "wave": 2, "arp_amp": 0.10, "arp_oct": 2.0, "arp_steps": 8,
				"bass_amp": 0.17, "bass_oct": 0.5, "bass_pulse": 4, "pad_amp": 0.06,
				"kick": 4, "hat": 8, "echo": 0.22, "echo_time": 0.27,
			}),
		},
		{
			"name": "Chiptune",
			"stream": _make_track({
				"prog": [
					[261.63, 329.63, 392.0], [196.0, 246.94, 392.0],
					[220.0, 261.63, 329.63], [174.61, 220.0, 261.63],
				],
				"bar": 1.4, "wave": 1, "arp_amp": 0.11, "arp_oct": 2.0, "arp_steps": 8,
				"bass_amp": 0.10, "bass_oct": 0.5, "bass_pulse": 8, "pad_amp": 0.0,
				"kick": 4, "hat": 0, "echo": 0.12, "echo_time": 0.15,
			}),
		},
		{
			"name": "Lo-Fi Drive",
			"stream": _make_track({
				"prog": [
					[261.63, 329.63, 392.0, 493.88], [220.0, 261.63, 329.63, 392.0],
					[293.66, 349.23, 440.0, 523.25], [196.0, 246.94, 392.0, 466.16],
				],
				"bar": 2.6, "wave": 0, "arp_amp": 0.07, "arp_oct": 2.0, "arp_steps": 6,
				"bass_amp": 0.13, "bass_oct": 0.5, "bass_pulse": 2, "pad_amp": 0.10,
				"kick": 2, "hat": 4, "echo": 0.3, "echo_time": 0.33,
			}),
		},
		{"name": "Radio Off", "stream": null},
	]
	_station_idx = clampi(_station_idx, 0, _stations.size() - 1)


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


func _make_swish(dur: float) -> AudioStreamWAV:
	# A gentle "swoosh" for direction changes: airy low-passed noise with a soft
	# downward tone and a smooth in/out envelope, kept quiet and un-harsh.
	var n := int(dur * MIX)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / n
		var env := sin(PI * t)
		var raw := randf() * 2.0 - 1.0
		lp = lerpf(lp, raw, 0.25)
		lp2 = lerpf(lp2, lp, 0.25)
		var tone := sin(TAU * lerpf(520.0, 300.0, t) * float(i) / MIX) * 0.25
		var v := (lp2 * 0.8 + tone) * env * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _make_click() -> AudioStreamWAV:
	# A short mellow UI blip (two soft sine partials, quick decay).
	var n := int(0.055 * MIX)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / n
		var env: float = clampf(t * 20.0, 0.0, 1.0) * exp(-t * 16.0)
		var ph := float(i) / MIX
		var v := (sin(TAU * 880.0 * ph) * 0.7 + sin(TAU * 1320.0 * ph) * 0.3) * env * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _make_levelstart() -> AudioStreamWAV:
	# A cheerful little fanfare: a rising arpeggio resolving into a bright major
	# chord that swells out, with a touch of echo for warmth.
	var notes := [392.0, 523.25, 659.25, 783.99]
	var step_n := int(0.11 * MIX)
	var tail := int(0.55 * MIX)
	var n := step_n * notes.size() + tail
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in notes.size():
		_add_note(buf, i * step_n, step_n * 2, float(notes[i]), 0.13, false)
	var cstart := step_n * notes.size()
	for f in [523.25, 659.25, 783.99, 1046.5]:
		_add_note(buf, cstart, tail, float(f), 0.12, true)
	var delay := int(0.12 * MIX)
	for i in range(delay, n):
		buf[i] += buf[i - delay] * 0.25
	var peak := 0.0001
	for i in n:
		peak = maxf(peak, absf(buf[i]))
	var norm := 0.9 / peak
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i] * norm, -1.0, 1.0) * 32767.0))
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


func _add_note(buf: PackedFloat32Array, off: int, length: int, freq: float, amp: float, pad: bool, wave: int = 0) -> void:
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
		var tt := float(i) / MIX
		var ph := TAU * freq * tt
		var s: float
		match wave:
			1:
				# Softened square (chiptune) - rounded with a sine to tame it.
				s = (1.0 if sin(ph) >= 0.0 else -1.0) * 0.45 + sin(ph) * 0.22
			2:
				# Softened saw (synth lead) - saw body with a sine underlay.
				var saw := fposmod(freq * tt, 1.0) * 2.0 - 1.0
				s = saw * 0.5 + sin(ph) * 0.18
			_:
				s = sin(ph) * 0.82 + sin(ph * 2.0) * 0.18
		buf[idx] += s * env * amp


func _add_kick(buf: PackedFloat32Array, off: int, amp: float) -> void:
	var n := buf.size()
	var dur := int(0.18 * MIX)
	for i in dur:
		var idx := off + i
		if idx < 0 or idx >= n:
			continue
		var t := float(i) / MIX
		var f := lerpf(120.0, 45.0, clampf(t / 0.12, 0.0, 1.0))
		var env := exp(-t * 22.0)
		buf[idx] += sin(TAU * f * t) * env * amp


func _add_hat(buf: PackedFloat32Array, off: int, amp: float) -> void:
	var n := buf.size()
	var dur := int(0.05 * MIX)
	var lp := 0.0
	for i in dur:
		var idx := off + i
		if idx < 0 or idx >= n:
			continue
		var t := float(i) / MIX
		var env := exp(-t * 90.0)
		var raw := randf() * 2.0 - 1.0
		lp = lerpf(lp, raw, 0.6)
		buf[idx] += lp * env * amp


func _make_track(cfg: Dictionary) -> AudioStreamWAV:
	# Parametric station builder: pad chords + bass + arpeggio + light drums over
	# a chord progression, normalised and looped. Variety comes from the cfg.
	var prog: Array = cfg["prog"]
	var bar: float = cfg.get("bar", 2.0)
	var bar_n := int(bar * MIX)
	var n := bar_n * prog.size()
	var buf := PackedFloat32Array()
	buf.resize(n)

	var wave := int(cfg.get("wave", 0))
	var arp_amp := float(cfg.get("arp_amp", 0.0))
	var arp_oct := float(cfg.get("arp_oct", 2.0))
	var arp_steps := int(cfg.get("arp_steps", 8))
	var bass_amp := float(cfg.get("bass_amp", 0.0))
	var bass_oct := float(cfg.get("bass_oct", 0.5))
	var bass_pulse := int(cfg.get("bass_pulse", 0))
	var pad_amp := float(cfg.get("pad_amp", 0.0))
	var kick := int(cfg.get("kick", 0))
	var hat := int(cfg.get("hat", 0))

	for ci in prog.size():
		var chord: Array = prog[ci]
		var start := ci * bar_n
		if pad_amp > 0.0:
			for note in chord:
				_add_note(buf, start, bar_n, float(note), pad_amp, true, 0)
		if bass_amp > 0.0:
			var root := float(chord[0]) * bass_oct
			if bass_pulse <= 0:
				_add_note(buf, start, bar_n, root, bass_amp, true, 0)
			else:
				var bdur := bar / float(bass_pulse)
				for b in bass_pulse:
					_add_note(buf, start + int(b * bdur * MIX), int(bdur * MIX * 0.9), root, bass_amp, false, 0)
		if arp_amp > 0.0:
			var sdur := bar / float(arp_steps)
			for s in arp_steps:
				var f: float = float(chord[s % chord.size()]) * arp_oct
				_add_note(buf, start + int(s * sdur * MIX), int(sdur * MIX * 0.9), f, arp_amp, false, wave)
		if kick > 0:
			var kdur := bar / float(kick)
			for b in kick:
				_add_kick(buf, start + int(b * kdur * MIX), 0.5)
		if hat > 0:
			var hdur := bar / float(hat)
			for b in hat:
				_add_hat(buf, start + int(b * hdur * MIX), 0.12)

	var echo := float(cfg.get("echo", 0.0))
	if echo > 0.0:
		var delay := int(float(cfg.get("echo_time", 0.25)) * MIX)
		for i in range(delay, n):
			buf[i] += buf[i - delay] * echo

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
