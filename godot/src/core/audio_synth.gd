class_name ArtAudioSynth
extends RefCounted

const SAMPLE_RATE := 22050

static func _build_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
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
	return wav

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
