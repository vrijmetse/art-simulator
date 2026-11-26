class_name ArtAudioSynth
extends RefCounted

const SAMPLE_RATE := 22050

static func _build_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := clampi(int(round(clampf(samples[i], -1.0, 1.0) * 32767.0)), -32768, 32767)
		pcm[i * 2] = v & 0xFF
		pcm[i * 2 + 1] = (v >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = pcm
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

static func _apply_loop_fade(buf: PackedFloat32Array, fade_samples: int) -> void:
	var n := mini(fade_samples, buf.size() / 4)
	if n <= 0:
		return
	for i in range(n):
		var w := 0.5 * (1.0 - cos(PI * float(i) / float(n)))
		buf[i] *= w
		buf[buf.size() - 1 - i] *= w

static func _append_tone(buf: PackedFloat32Array, start_idx: int, freq: float, dur_s: float, amp: float) -> void:
	var n := int(dur_s * SAMPLE_RATE)
	for i in range(n):
		var idx := start_idx + i
		if idx >= buf.size():
			break
		var t := float(i) / float(SAMPLE_RATE)
		var env := minf(1.0, t / 0.01) * exp(-t * 7.5)
		buf[idx] += sin(TAU * freq * t) * amp * env

static func make_coin_chime() -> AudioStreamWAV:
	var total := int(0.42 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	_append_tone(buf, 0, 523.25, 0.16, 0.35)
	_append_tone(buf, int(0.08 * SAMPLE_RATE), 659.25, 0.18, 0.35)
	_append_tone(buf, int(0.16 * SAMPLE_RATE), 783.99, 0.24, 0.38)
	return _build_wav(buf)

static func make_phone_ring() -> AudioStreamWAV:
	var total := int(0.55 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	for pulse in range(2):
		var off := int(float(pulse) * 0.25 * SAMPLE_RATE)
		var n := int(0.18 * SAMPLE_RATE)
		for i in range(n):
			var idx := off + i
			if idx >= total:
				break
			var t := float(i) / float(SAMPLE_RATE)
			var env := minf(1.0, t / 0.015) * minf(1.0, (0.18 - t) / 0.02)
			buf[idx] = (sin(TAU * 440.0 * t) + sin(TAU * 480.0 * t)) * 0.25 * env
	return _build_wav(buf)

static func make_broom_sweep() -> AudioStreamWAV:
	var total := int(0.28 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var seed_val := 12345
	var lp := 0.0
	for i in range(total):
		seed_val = (seed_val * 1103515245 + 12345) & 0x7FFFFFFF
		var noise := (float(seed_val % 2000) / 1000.0) - 1.0
		lp = lp * 0.80 + noise * 0.20
		var t := float(i) / float(total)
		var env := sin(PI * t)
		buf[i] = lp * 0.30 * env
	return _build_wav(buf)

static func make_level_up_fanfare() -> AudioStreamWAV:
	var total := int(0.65 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var notes := [523.25, 659.25, 783.99, 1046.50]
	for i in range(notes.size()):
		_append_tone(buf, int(float(i) * 0.11 * SAMPLE_RATE), notes[i], 0.30, 0.35)
	return _build_wav(buf)

static func make_warning_buzz() -> AudioStreamWAV:
	var total := int(0.32 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	_append_tone(buf, 0, 196.0, 0.14, 0.40)
	_append_tone(buf, int(0.15 * SAMPLE_RATE), 164.8, 0.16, 0.42)
	return _build_wav(buf)

static func _append_kalimba(buf: PackedFloat32Array, start_idx: int, freq: float, dur_s: float, amp: float) -> void:
	var n := int(dur_s * SAMPLE_RATE)
	for i in range(n):
		var idx := start_idx + i
		if idx >= buf.size():
			break
		var t := float(i) / float(SAMPLE_RATE)
		var env := minf(1.0, t / 0.008) * exp(-t * 4.2)
		var overtone_env := exp(-t * 14.0)
		var sample := sin(TAU * freq * t) + 0.25 * sin(TAU * freq * 2.0 * t) * overtone_env + 0.08 * sin(TAU * freq * 3.0 * t) * overtone_env
		buf[idx] += sample * amp * env

static func make_cozy_bgm_loop() -> AudioStreamWAV:
	var total := 16 * SAMPLE_RATE
	var buf := PackedFloat32Array()
	buf.resize(total)

	# Warm Indonesian pentatonic (Slendro/Pelog-inspired C major pentatonic)
	# 16-second A/B phrase (64 steps at 0.25s/step)
	var melody := [
		# Phrase A (0-8s)
		523.25, 0.0, 392.00, 440.00, 523.25, 0.0, 659.25, 587.33,
		523.25, 440.00, 392.00, 0.0, 329.63, 392.00, 440.00, 0.0,
		587.33, 0.0, 523.25, 440.00, 392.00, 0.0, 329.63, 293.66,
		261.63, 329.63, 392.00, 0.0, 440.00, 392.00, 329.63, 0.0,
		# Phrase B (8-16s)
		659.25, 0.0, 587.33, 523.25, 440.00, 0.0, 523.25, 587.33,
		659.25, 523.25, 440.00, 0.0, 392.00, 440.00, 523.25, 0.0,
		587.33, 523.25, 440.00, 392.00, 329.63, 0.0, 392.00, 440.00,
		392.00, 329.63, 293.66, 0.0, 261.63, 329.63, 392.00, 0.0,
	]
	var bass := [
		130.81, 196.00, 164.81, 196.00,
		146.83, 220.00, 196.00, 130.81,
		164.81, 220.00, 196.00, 146.83,
		130.81, 164.81, 196.00, 130.81,
	]

	var step_s := 0.25
	for i in range(melody.size()):
		var freq: float = melody[i]
		if freq > 0.0:
			_append_kalimba(buf, int(float(i) * step_s * SAMPLE_RATE), freq, 0.65, 0.16)

	for b in range(bass.size()):
		_append_kalimba(buf, int(float(b) * 1.0 * SAMPLE_RATE), bass[b], 1.15, 0.12)

	_apply_loop_fade(buf, int(0.05 * SAMPLE_RATE))
	return _build_wav(buf, true)

static func make_rain_loop() -> AudioStreamWAV:
	var total := 3 * SAMPLE_RATE
	var buf := PackedFloat32Array()
	buf.resize(total)

	var seed_val := 98765
	var lp1 := 0.0
	var lp2 := 0.0
	for i in range(total):
		seed_val = (seed_val * 1103515245 + 12345) & 0x7FFFFFFF
		var noise := (float(seed_val % 2000) / 1000.0) - 1.0
		lp1 = lp1 * 0.85 + noise * 0.15
		lp2 = lp2 * 0.88 + lp1 * 0.12
		var t := float(i) / float(total)
		var swell := 0.85 + 0.15 * sin(TAU * t)
		buf[i] = lp2 * 0.22 * swell

	_apply_loop_fade(buf, int(0.06 * SAMPLE_RATE))
	return _build_wav(buf, true)


static func make_ui_click() -> AudioStreamWAV:
	var total := int(0.06 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	_append_tone(buf, 0, 880.0, 0.045, 0.25)
	return _build_wav(buf)


static func make_door_chime() -> AudioStreamWAV:
	var total := int(0.36 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	_append_kalimba(buf, 0, 659.25, 0.20, 0.30)
	_append_kalimba(buf, int(0.11 * SAMPLE_RATE), 783.99, 0.24, 0.32)
	return _build_wav(buf)


static func make_chore_tick() -> AudioStreamWAV:
	var total := int(0.08 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	_append_tone(buf, 0, 587.33, 0.06, 0.22)
	return _build_wav(buf)


static func make_footstep_tick() -> AudioStreamWAV:
	var total := int(0.07 * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var seed_val := 54321
	var lp := 0.0
	for i in range(total):
		seed_val = (seed_val * 1103515245 + 12345) & 0x7FFFFFFF
		var noise := (float(seed_val % 2000) / 1000.0) - 1.0
		lp = lp * 0.85 + noise * 0.15
		var t := float(i) / float(total)
		var env := exp(-t * 10.0)
		buf[i] = lp * 0.25 * env
	return _build_wav(buf)
