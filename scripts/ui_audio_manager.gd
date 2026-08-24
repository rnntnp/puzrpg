extends Node

const BUTTON_CLICK_STREAM: AudioStream = preload("res://assets/audio/sfx/ui_click_003.ogg")

var _click_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_click_player = AudioStreamPlayer.new()
	_click_player.stream = BUTTON_CLICK_STREAM
	_click_player.volume_db = -4.0
	_click_player.max_polyphony = 8
	add_child(_click_player)
	get_tree().node_added.connect(_on_node_added)
	_connect_buttons_in(get_tree().root)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node as BaseButton)


func _connect_buttons_in(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node as BaseButton)
	for child in node.get_children():
		_connect_buttons_in(child)


func _connect_button(button: BaseButton) -> void:
	if not button.pressed.is_connected(_play_click):
		button.pressed.connect(_play_click)


func _play_click() -> void:
	_click_player.play()
