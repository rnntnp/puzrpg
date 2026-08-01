class_name Battle
extends Node2D

@onready var left_fighter: Fighter = $UI/LeftFighter
@onready var right_fighter: Fighter = $UI/RightFighter
@onready var left_bar: ProgressBar = $UI/LeftHealthBar
@onready var right_bar: ProgressBar = $UI/RightHealthBar
@onready var left_hp_label: Label = $UI/LeftHealthLabel
@onready var right_hp_label: Label = $UI/RightHealthLabel
@onready var left_stats: Label = $UI/LeftStats
@onready var right_stats: Label = $UI/RightStats
@onready var status_label: Label = $UI/StatusLabel
@onready var start_button: Button = $UI/StartButton

var battle_running := false


func _ready() -> void:
	left_fighter.health_changed.connect(_on_left_health_changed)
	right_fighter.health_changed.connect(_on_right_health_changed)
	left_fighter.defeated.connect(_on_fighter_defeated)
	right_fighter.defeated.connect(_on_fighter_defeated)
	start_button.pressed.connect(_on_start_button_pressed)
	_reset_battle()


func _process(delta: float) -> void:
	if not battle_running:
		return
	if left_fighter.advance_cooldown(delta):
		left_fighter.attack(right_fighter)
	if battle_running and right_fighter.advance_cooldown(delta):
		right_fighter.attack(left_fighter)


func _reset_battle() -> void:
	battle_running = false
	left_fighter.reset()
	right_fighter.reset()
	status_label.text = "준비"
	status_label.modulate = Color("#ffd166")
	start_button.text = "전투 시작"
	start_button.disabled = false
	_update_stats()


func _update_stats() -> void:
	left_stats.text = "%s\n공격력 %d\n쿨타임 %.1f초" % [left_fighter.display_name, left_fighter.attack_power, left_fighter.attack_cooldown]
	right_stats.text = "%s\n공격력 %d\n쿨타임 %.1f초" % [right_fighter.display_name, right_fighter.attack_power, right_fighter.attack_cooldown]


func _on_start_button_pressed() -> void:
	if not left_fighter.is_alive() or not right_fighter.is_alive():
		_reset_battle()
		return
	battle_running = true
	left_fighter.cooldown_remaining = left_fighter.attack_cooldown
	right_fighter.cooldown_remaining = right_fighter.attack_cooldown
	status_label.text = "전투 중"
	status_label.modulate = Color.WHITE
	start_button.disabled = true
	start_button.text = "전투 중..."


func _on_left_health_changed(health: int, maximum: int) -> void:
	left_bar.max_value = maximum
	left_bar.value = health
	left_hp_label.text = "%s  %d / %d" % [left_fighter.display_name, health, maximum]


func _on_right_health_changed(health: int, maximum: int) -> void:
	right_bar.max_value = maximum
	right_bar.value = health
	right_hp_label.text = "%d / %d  %s" % [health, maximum, right_fighter.display_name]


func _on_fighter_defeated(_fighter: Fighter) -> void:
	battle_running = false
	if not left_fighter.is_alive() and not right_fighter.is_alive():
		status_label.text = "무승부!"
	elif not right_fighter.is_alive():
		status_label.text = "%s 승리!" % left_fighter.display_name
	else:
		status_label.text = "%s 승리!" % right_fighter.display_name
	status_label.modulate = Color("#ffd166")
	start_button.disabled = false
	start_button.text = "다시 하기"
