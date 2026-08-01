extends Node2D

@export_category("왼쪽 캐릭터")
@export var left_max_health: int = 100
@export var left_attack_power: int = 14

@export_category("오른쪽 캐릭터")
@export var right_max_health: int = 100
@export var right_attack_power: int = 11

@export_category("전투 설정")
@export_range(0.2, 10.0, 0.1) var attack_cooldown: float = 1.2

var left_health: int
var right_health: int
var battle_running := false
var left_cooldown := 0.0
var right_cooldown := 0.0

var left_fighter: Polygon2D
var right_fighter: Polygon2D
var left_bar: ProgressBar
var right_bar: ProgressBar
var left_hp_label: Label
var right_hp_label: Label
var status_label: Label
var start_button: Button

const BG := Color("#101827")
const PANEL := Color("#19253a")
const LEFT_COLOR := Color("#48a9ff")
const RIGHT_COLOR := Color("#ff6577")


func _ready() -> void:
	build_ui()
	reset_battle()


func _process(delta: float) -> void:
	if not battle_running:
		return

	left_cooldown -= delta
	right_cooldown -= delta

	if left_cooldown <= 0.0:
		left_cooldown += attack_cooldown
		attack(true)
	if battle_running and right_cooldown <= 0.0:
		right_cooldown += attack_cooldown
		attack(false)


func build_ui() -> void:
	RenderingServer.set_default_clear_color(BG)

	var canvas := CanvasLayer.new()
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	var title := make_label("AUTO BATTLE", 38, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 70)
	title.size = Vector2(720, 60)
	root.add_child(title)

	status_label = make_label("준비", 28, Color("#ffd166"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(0, 145)
	status_label.size = Vector2(720, 48)
	root.add_child(status_label)

	left_bar = make_health_bar(LEFT_COLOR)
	left_bar.position = Vector2(55, 240)
	root.add_child(left_bar)
	right_bar = make_health_bar(RIGHT_COLOR)
	right_bar.position = Vector2(385, 240)
	root.add_child(right_bar)

	left_hp_label = make_label("", 22, Color.WHITE)
	left_hp_label.position = Vector2(55, 196)
	left_hp_label.size = Vector2(280, 40)
	root.add_child(left_hp_label)
	right_hp_label = make_label("", 22, Color.WHITE)
	right_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_hp_label.position = Vector2(385, 196)
	right_hp_label.size = Vector2(280, 40)
	root.add_child(right_hp_label)

	left_fighter = make_fighter(LEFT_COLOR, false)
	left_fighter.position = Vector2(195, 570)
	root.add_child(left_fighter)
	right_fighter = make_fighter(RIGHT_COLOR, true)
	right_fighter.position = Vector2(525, 570)
	root.add_child(right_fighter)

	var versus := make_label("VS", 42, Color("#8090a8"))
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	versus.position = Vector2(310, 530)
	versus.size = Vector2(100, 60)
	root.add_child(versus)

	var left_stats := make_label("공격력 %d\n쿨타임 %.1f초" % [left_attack_power, attack_cooldown], 22, Color("#b9c8dc"))
	left_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_stats.position = Vector2(75, 730)
	left_stats.size = Vector2(240, 80)
	root.add_child(left_stats)
	var right_stats := make_label("공격력 %d\n쿨타임 %.1f초" % [right_attack_power, attack_cooldown], 22, Color("#b9c8dc"))
	right_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_stats.position = Vector2(405, 730)
	right_stats.size = Vector2(240, 80)
	root.add_child(right_stats)

	start_button = Button.new()
	start_button.text = "전투 시작"
	start_button.position = Vector2(130, 920)
	start_button.size = Vector2(460, 110)
	start_button.add_theme_font_size_override("font_size", 30)
	start_button.add_theme_color_override("font_color", Color.WHITE)
	start_button.add_theme_stylebox_override("normal", make_box(Color("#3478f6"), 24))
	start_button.add_theme_stylebox_override("hover", make_box(Color("#4388ff"), 24))
	start_button.add_theme_stylebox_override("pressed", make_box(Color("#255fc9"), 24))
	start_button.pressed.connect(on_start_pressed)
	root.add_child(start_button)


func make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func make_health_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.size = Vector2(280, 30)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", make_box(Color("#27364c"), 12))
	bar.add_theme_stylebox_override("fill", make_box(color, 12))
	return bar


func make_box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box


func make_fighter(color: Color, faces_left: bool) -> Polygon2D:
	var fighter := Polygon2D.new()
	fighter.polygon = PackedVector2Array([
		Vector2(-55, -75), Vector2(20, -75), Vector2(55, -35),
		Vector2(55, 70), Vector2(-55, 70)
	])
	if faces_left:
		fighter.scale.x = -1
	fighter.color = color
	return fighter


func reset_battle() -> void:
	battle_running = false
	left_health = left_max_health
	right_health = right_max_health
	left_cooldown = attack_cooldown
	right_cooldown = attack_cooldown
	status_label.text = "준비"
	status_label.modulate = Color("#ffd166")
	start_button.text = "전투 시작"
	start_button.disabled = false
	left_fighter.modulate = Color.WHITE
	right_fighter.modulate = Color.WHITE
	update_health_ui()


func on_start_pressed() -> void:
	if left_health <= 0 or right_health <= 0:
		reset_battle()
		return
	battle_running = true
	left_cooldown = attack_cooldown
	right_cooldown = attack_cooldown
	status_label.text = "전투 중"
	status_label.modulate = Color.WHITE
	start_button.disabled = true
	start_button.text = "전투 중..."


func attack(from_left: bool) -> void:
	var attacker := left_fighter if from_left else right_fighter
	var target := right_fighter if from_left else left_fighter
	var direction := 1.0 if from_left else -1.0

	if from_left:
		right_health = max(0, right_health - left_attack_power)
	else:
		left_health = max(0, left_health - right_attack_power)

	var attack_tween := create_tween()
	attack_tween.tween_property(attacker, "position:x", attacker.position.x + 45.0 * direction, 0.08)
	attack_tween.tween_property(attacker, "position:x", attacker.position.x, 0.12)

	var hit_tween := create_tween()
	hit_tween.tween_property(target, "modulate", Color("#ffdfdf"), 0.04)
	hit_tween.tween_property(target, "modulate", Color.WHITE, 0.16)
	update_health_ui()

	if left_health <= 0 or right_health <= 0:
		finish_battle()


func update_health_ui() -> void:
	left_bar.max_value = left_max_health
	left_bar.value = left_health
	right_bar.max_value = right_max_health
	right_bar.value = right_health
	left_hp_label.text = "BLUE  %d / %d" % [left_health, left_max_health]
	right_hp_label.text = "%d / %d  RED" % [right_health, right_max_health]


func finish_battle() -> void:
	battle_running = false
	if left_health <= 0 and right_health <= 0:
		status_label.text = "무승부!"
	elif right_health <= 0:
		status_label.text = "BLUE 승리!"
		right_fighter.modulate = Color("#556070")
	else:
		status_label.text = "RED 승리!"
		left_fighter.modulate = Color("#556070")
	status_label.modulate = Color("#ffd166")
	start_button.disabled = false
	start_button.text = "다시 하기"
