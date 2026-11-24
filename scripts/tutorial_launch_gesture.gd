extends Node2D
## Demonstrate aiming from the real launcher origin, with variable reach.
var clock:=0.0

func _process(delta: float) -> void:
	clock+=delta
	queue_redraw()

func _draw() -> void:
	var angle:=sin(clock*1.4)*0.6
	var direction:=Vector2.UP.rotated(angle)
	var tip:=direction*(140.0+sin(clock*1.9)*35.0)
	var outline:=Color(0.02,0.06,0.12,0.9)
	var white:=Color(1.0,0.96,0.65,0.9)
	draw_arc(Vector2.ZERO,16.0,0.0,TAU,40,white,2.0,true)
	draw_line(Vector2.ZERO,tip,outline,7.0,true)
	draw_line(Vector2.ZERO,tip,white,3.0,true)
	for sign_value in [-1.0,1.0]:
		var wing:=tip-direction.rotated(sign_value*0.6)*19.0
		draw_line(tip,wing,outline,7.0,true)
		draw_line(tip,wing,white,3.0,true)
	draw_circle(tip,11.0,Color(1.0,1.0,1.0,0.7))
	draw_arc(tip,18.0,0.0,TAU,32,white,2.0,true)
