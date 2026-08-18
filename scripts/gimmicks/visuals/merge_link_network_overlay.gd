class_name MergeLinkNetworkOverlay
extends Node2D

const RESULT_NEUTRAL := 0
const RESULT_SUCCESS := 1
const RESULT_FAILURE := -1

var board_bounds := Rect2()
var anchor_positions: Array[Vector2] = []
var anchor_labels: Array[String] = []
var anchor_connected: Array[bool] = []
var markers: Array[Dictionary] = []
var node_link_distance := 185.0
var anchor_reach_distance := 155.0
var turns_remaining := 0
var result_text := ""
var result_state := RESULT_NEUTRAL


func show_state(
	bounds: Rect2,
	anchors: Array[Vector2],
	labels: Array[String],
	connections: Array[bool],
	nodes: Array[Dictionary],
	link_distance: float,
	anchor_reach: float,
	turns: int,
	result: String,
	state: int
) -> void:
	board_bounds = bounds
	anchor_positions.assign(anchors)
	anchor_labels.assign(labels)
	anchor_connected.assign(connections)
	markers.assign(nodes)
	node_link_distance = maxf(1.0, link_distance)
	anchor_reach_distance = maxf(1.0, anchor_reach)
	turns_remaining = maxi(0, turns)
	result_text = result
	result_state = state
	queue_redraw()


func _draw() -> void:
	if not board_bounds.has_area():
		return
	_draw_link_ranges()
	_draw_links()
	_draw_anchors()
	_draw_markers()
	draw_string(
		ThemeDB.fallback_font,
		Vector2(board_bounds.position.x, board_bounds.position.y + 30.0),
		"MERGE LINK NETWORK · %d TURN" % turns_remaining,
		HORIZONTAL_ALIGNMENT_CENTER,
		board_bounds.size.x,
		20,
		Color("#d7f5ff")
	)
	if not result_text.is_empty():
		var feedback_color: Color = Color("#70ff9b") if result_state == RESULT_SUCCESS else Color("#ff6b6b")
		var feedback_rect := Rect2(
			Vector2(board_bounds.position.x + 58.0, board_bounds.get_center().y - 38.0),
			Vector2(board_bounds.size.x - 116.0, 76.0)
		)
		draw_rect(feedback_rect, Color(0.04, 0.08, 0.16, 0.9), true)
		draw_rect(feedback_rect, feedback_color, false, 3.0)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(board_bounds.position.x, board_bounds.get_center().y + 9.0),
			result_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			board_bounds.size.x,
			22,
			feedback_color
		)


func _draw_link_ranges() -> void:
	for anchor_position: Vector2 in anchor_positions:
		draw_circle(anchor_position, anchor_reach_distance, Color(1.0, 0.72, 0.25, 0.035))
		draw_arc(anchor_position, anchor_reach_distance, 0.0, TAU, 48, Color(1.0, 0.76, 0.35, 0.22), 1.5, true)
	for marker: Dictionary in markers:
		var marker_position: Vector2 = marker.get("position", Vector2.ZERO)
		draw_circle(marker_position, node_link_distance * 0.5, Color(0.25, 0.82, 1.0, 0.035))
		draw_arc(marker_position, node_link_distance * 0.5, 0.0, TAU, 40, Color(0.35, 0.86, 1.0, 0.2), 1.0, true)


func _draw_links() -> void:
	var link_color := Color("#70ff9b") if _all_anchors_connected() else Color("#63e6ff")
	for anchor_index in anchor_positions.size():
		for marker: Dictionary in markers:
			var marker_position: Vector2 = marker.get("position", Vector2.ZERO)
			if anchor_positions[anchor_index].distance_to(marker_position) <= anchor_reach_distance:
				draw_line(anchor_positions[anchor_index], marker_position, Color(link_color, 0.75), 4.0, true)
	for first_index in markers.size():
		var first_position: Vector2 = markers[first_index].get("position", Vector2.ZERO)
		for second_index in range(first_index + 1, markers.size()):
			var second_position: Vector2 = markers[second_index].get("position", Vector2.ZERO)
			if first_position.distance_to(second_position) <= node_link_distance:
				draw_line(first_position, second_position, Color(link_color, 0.65), 3.0, true)


func _draw_anchors() -> void:
	for index in anchor_positions.size():
		var is_connected: bool = index < anchor_connected.size() and anchor_connected[index]
		var anchor_color := Color("#70ff9b") if is_connected else Color("#ffd166")
		draw_circle(anchor_positions[index], 20.0, Color(anchor_color, 0.28))
		draw_arc(anchor_positions[index], 24.0, 0.0, TAU, 32, anchor_color, 5.0, true)
		var label: String = anchor_labels[index] if index < anchor_labels.size() else "ANCHOR"
		draw_string(
			ThemeDB.fallback_font,
			Vector2(anchor_positions[index].x - 62.0, anchor_positions[index].y - 33.0),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			124.0,
			15,
			anchor_color
		)


func _draw_markers() -> void:
	for marker: Dictionary in markers:
		var marker_position: Vector2 = marker.get("position", Vector2.ZERO)
		var lifetime: int = int(marker.get("turns", 0))
		draw_circle(marker_position, 14.0, Color(0.2, 0.8, 1.0, 0.42))
		draw_arc(marker_position, 18.0, 0.0, TAU, 24, Color("#63e6ff"), 3.0, true)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(marker_position.x - 16.0, marker_position.y + 6.0),
			str(lifetime),
			HORIZONTAL_ALIGNMENT_CENTER,
			32.0,
			14,
			Color.WHITE
		)


func _all_anchors_connected() -> bool:
	if anchor_connected.is_empty():
		return false
	for is_connected: bool in anchor_connected:
		if not is_connected:
			return false
	return true

