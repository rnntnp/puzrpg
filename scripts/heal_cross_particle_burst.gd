class_name HealCrossParticleBurst
extends Node2D

const PARTICLE_COUNT := 11
const EFFECT_DURATION := 0.9
const AUDIO_SAMPLE_RATE := 44100.0

var _particles: Array[Dictionary] = []
var _elapsed := 0.0


func play(at_global_position: Vector2) -> void:
	global_position = at_global_position
	z_index = 220
	for index in PARTICLE_COUNT:
		_particles.append({
			"position": Vector2(randf_range(-74.0, 74.0), randf_range(-12.0, 42.0)),
			"velocity": Vector2(randf_range(-13.0, 13.0), randf_range(-78.0, -48.0)),
			"size": randf_range(5.0, 9.0),
			"delay": randf_range(0.0, 0.28),
			"color": Color("#dfff73") if index % 2 == 0 else Color("#62b83e"),
		})
	_play_heal_chime()
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	for particle in _particles:
		if _elapsed < float(particle["delay"]):
			continue
		var velocity: Vector2 = particle["velocity"]
		particle["position"] = (particle["position"] as Vector2) + velocity * delta
		particle["velocity"] = velocity * 0.985
	queue_redraw()
	if _elapsed >= EFFECT_DURATION:
		queue_free()


func _draw() -> void:
	for particle in _particles:
		var particle_age := _elapsed - float(particle["delay"])
		if particle_age <= 0.0:
			continue
		var progress := clampf(particle_age / (EFFECT_DURATION - float(particle["delay"])), 0.0, 1.0)
		var pulse := 0.82 + sin(progress * PI) * 0.35
		var size := float(particle["size"]) * pulse
		var alpha := 1.0 - smoothstep(0.48, 1.0, progress)
		var color: Color = particle["color"]
		color.a = alpha
		var position: Vector2 = particle["position"]
		var arm := maxf(2.0, size * 0.34)
		draw_rect(Rect2(position - Vector2(arm, size), Vector2(arm * 2.0, size * 2.0)), color, true)
		draw_rect(Rect2(position - Vector2(size, arm), Vector2(size * 2.0, arm * 2.0)), color, true)


func _play_heal_chime() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = AUDIO_SAMPLE_RATE
	generator.buffer_length = 0.55
	var player := AudioStreamPlayer.new()
	player.stream = generator
	player.volume_db = -8.0
	add_child(player)
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frame_count := roundi(AUDIO_SAMPLE_RATE * 0.48)
	for frame_index in frame_count:
		var time := float(frame_index) / AUDIO_SAMPLE_RATE
		var sample := 0.0
		sample += _chime_note(time, 0.00, 659.25)
		sample += _chime_note(time, 0.10, 783.99)
		sample += _chime_note(time, 0.20, 987.77)
		sample = clampf(sample * 0.22, -0.8, 0.8)
		playback.push_frame(Vector2(sample, sample))


func _chime_note(time: float, delay: float, frequency: float) -> float:
	var note_time := time - delay
	if note_time < 0.0:
		return 0.0
	var envelope := exp(-note_time * 8.5) * minf(note_time / 0.012, 1.0)
	return (
		sin(TAU * frequency * note_time)
		+ sin(TAU * frequency * 2.0 * note_time) * 0.2
	) * envelope
