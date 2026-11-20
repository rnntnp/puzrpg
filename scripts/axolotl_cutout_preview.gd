extends Node2D
## Reusable cutout rig for the independent preview and stage 63 player layer.

const ASSET_DIR := "res://assets/characters/axolotl_cutout/"
var _parts: Dictionary = {}
var _time := 0.0


func _ready() -> void:
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSET_DIR + "rig.json"))
	for part: Dictionary in rig["parts"]:
		var joint := Node2D.new()
		joint.name = part["name"]
		var pivot := Vector2(float(part["pivot"][0]), float(part["pivot"][1]))
		joint.position = pivot
		joint.set_meta("rest", pivot)
		joint.z_index = int(part["z"])
		_parts[part["name"]] = joint
		add_child(joint)
		var sprite := Sprite2D.new()
		sprite.texture = load(ASSET_DIR + "rig_parts/" + str(part["name"]) + ".png")
		sprite.centered = false
		sprite.position = Vector2(float(part["render_bounds"][0]), float(part["render_bounds"][1])) - pivot
		joint.add_child(sprite)
	# Gill joints inherit the head transform while retaining global draw order.
	for part: Dictionary in rig["parts"]:
		if part["parent"] == "head":
			var joint: Node2D = _parts[part["name"]]
			var head: Node2D = _parts["head"]
			joint.reparent(head)
			joint.position = Vector2(float(part["pivot"][0]), float(part["pivot"][1])) - head.position
			joint.set_meta("rest", joint.position)
			joint.z_index = int(part["z"]) - head.z_index


func _process(delta: float) -> void:
	_time = fmod(_time + delta, 3.2)
	var phase := _time / 3.2 * TAU
	var bob := -3.0 * (1.0 - cos(phase))
	for key: String in _parts:
		var joint: Node2D = _parts[key]
		var angle := 0.0
		if key == "head":
			angle = 1.1 * sin(phase)
		elif key.begins_with("gill_"):
			var delay := 0.0 if key.ends_with("top") else (0.35 if key.ends_with("mid") else 0.7)
			angle = 12.0 * sin(phase + 0.7 - delay) * (-1.0 if "_l_" in key else 1.0)
		elif key == "tail":
			angle = 2.1 * sin(phase - 0.6)
		elif key == "arm_front":
			angle = 0.9 * sin(phase + 0.3)
		elif key == "staff_arm":
			angle = 0.8 * sin(phase - 0.4)
		# Pillow's positive rotation is counterclockwise; Godot's is clockwise.
		joint.rotation_degrees = -angle
		joint.position = joint.get_meta("rest")
		if not key.begins_with("boot") and not key.begins_with("gill_"):
			joint.position.y += bob
