extends RefCounted
## Shared rest-pose sampling only; never changes collision shapes or runs physics.
static func build(ball: MergeBall, point_count: int = 6) -> Dictionary:
	var points := PackedVector2Array()
	var shapes: Array = []
	for node in ball.get_children():
		if not node is CollisionShape2D or node.disabled or node.shape == null: continue
		shapes.append({"node":node,"shape":node.shape,"transform":node.transform,"disabled":node.disabled})
		var p := PackedVector2Array()
		if node.shape is ConvexPolygonShape2D: p = node.shape.points
		elif node.shape is CircleShape2D:
			for i in 32: p.append(Vector2.from_angle(TAU*i/32.0)*node.shape.radius)
		elif node.shape is CapsuleShape2D:
			var stem: float = maxf(0,node.shape.height*0.5-node.shape.radius)
			for i in 17: p.append(Vector2.from_angle(PI+PI*i/16.0)*node.shape.radius+Vector2(0,-stem))
			for i in 17: p.append(Vector2.from_angle(PI*i/16.0)*node.shape.radius+Vector2(0,stem))
		elif node.shape is RectangleShape2D:
			var h: Vector2 = node.shape.size*0.5
			p = PackedVector2Array([Vector2(-h.x,-h.y),Vector2(h.x,-h.y),h,Vector2(-h.x,h.y)])
		for point in p: points.append(node.transform*point)
	var hull := Geometry2D.convex_hull(points)
	if hull.size()>1: hull.remove_at(hull.size()-1)
	var lengths := PackedFloat32Array([0.0])
	for i in hull.size(): lengths.append(lengths[-1]+hull[i].distance_to(hull[(i+1)%hull.size()]))
	var rest := PackedVector2Array()
	for i in point_count:
		var distance := lengths[-1]*i/point_count
		var edge := 0
		while edge+1<hull.size() and lengths[edge+1]<distance: edge+=1
		rest.append(hull[edge].lerp(hull[(edge+1)%hull.size()],(distance-lengths[edge])/maxf(lengths[edge+1]-lengths[edge],0.001)))
	return {"rest":rest,"shapes":shapes,"outline":hull}

