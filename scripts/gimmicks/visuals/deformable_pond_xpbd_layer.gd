extends "res://scripts/gimmicks/visuals/soft_pond_layer.gd"
## Real six-particle XPBD fallback where the optional Quark extension is absent.
const Faces = preload("res://scripts/gimmicks/visuals/deformable_pond_faces.gd")

func _register(ball: MergeBall) -> void:
	var face_layers := Faces.split(ball)
	super._register(ball)
	states[ball.get_instance_id()].face_layers = face_layers

func _publish(state: Dictionary) -> void:
	super._publish(state)
	Faces.update(state, tuning)

func restore_balls() -> void:
	var old_states: Array = states.values()
	super.restore_balls()
	Faces.restore(old_states)

func _exit_tree() -> void:
	restore_balls()
