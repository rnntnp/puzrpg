extends RefCounted
## GJK closest witnesses for the convex shapes installed in stage 63.
## Read-only geometry: no physics queries, shape changes or gameplay forces.

static func measure(a: Shape2D, ta: Transform2D, b: Shape2D, tb: Transform2D, direction := Vector2.RIGHT) -> Dictionary:
	if direction.length_squared() < 0.000001: direction = Vector2.RIGHT
	var simplex: Array = [_vertex(a, ta, b, tb, direction)]
	var closest := _closest(simplex)
	for iteration in 48:
		var point: Vector2 = closest.point
		if point.length_squared() < 0.00000001: break
		var candidate := _vertex(a, ta, b, tb, -point)
		# Support-plane improvement bounds convergence of the distance search.
		if point.length_squared() - point.dot(candidate.w) <= maxf(0.00000001, point.length_squared() * 0.0000001): break
		var repeated := false
		for vertex in closest.simplex:
			if vertex.w.distance_squared_to(candidate.w) < 0.00000001: repeated = true
		if repeated: break
		simplex = closest.simplex.duplicate()
		simplex.append(candidate)
		closest = _closest(simplex)
	var pa := Vector2.ZERO
	var pb := Vector2.ZERO
	for i in closest.simplex.size():
		pa += closest.simplex[i].a * closest.weights[i]
		pb += closest.simplex[i].b * closest.weights[i]
	var delta := pb - pa
	return {"gap":delta.length(), "a":pa, "b":pb, "normal":delta.normalized() if delta.length_squared() > 0.00000001 else direction.normalized()}

static func _vertex(a: Shape2D, ta: Transform2D, b: Shape2D, tb: Transform2D, direction: Vector2) -> Dictionary:
	var pa := _support(a, ta, direction)
	var pb := _support(b, tb, -direction)
	return {"a":pa, "b":pb, "w":pa-pb}

static func _support(shape: Shape2D, transform: Transform2D, direction: Vector2) -> Vector2:
	# The transpose, rather than the inverse, also handles scaled transforms.
	var local := Vector2(transform.x.dot(direction), transform.y.dot(direction))
	var point := Vector2.ZERO
	if shape is CircleShape2D:
		point = local.normalized() * shape.radius
	elif shape is CapsuleShape2D:
		point = local.normalized() * shape.radius
		point.y += signf(local.y) * maxf(0.0, shape.height * 0.5 - shape.radius)
	elif shape is ConvexPolygonShape2D:
		var score := -INF
		for candidate in shape.points:
			if candidate.dot(local) > score:
				score = candidate.dot(local)
				point = candidate
	elif shape is RectangleShape2D:
		point = shape.size * 0.5 * local.sign()
	return transform * point

static func _closest(simplex: Array) -> Dictionary:
	if simplex.size() == 1:
		return {"simplex":simplex, "point":simplex[0].w, "weights":[1.0]}
	if simplex.size() == 3:
		var a: Vector2 = simplex[0].w
		var b: Vector2 = simplex[1].w
		var c: Vector2 = simplex[2].w
		var determinant := (b-a).cross(c-a)
		if absf(determinant) > 0.00000001:
			var wb := (-a).cross(c-a) / determinant
			var wc := (b-a).cross(-a) / determinant
			var wa := 1.0-wb-wc
			if wa >= 0.0 and wb >= 0.0 and wc >= 0.0:
				return {"simplex":simplex, "point":Vector2.ZERO, "weights":[wa,wb,wc]}
	var best := {"point":Vector2(INF, INF)}
	var best_distance := INF
	var edge_count := 1 if simplex.size() == 2 else 3
	for i in edge_count:
		var j := (i+1) % simplex.size()
		var a: Vector2 = simplex[i].w
		var edge: Vector2 = simplex[j].w-a
		var t := clampf(-a.dot(edge) / maxf(edge.length_squared(), 0.00000001), 0.0, 1.0)
		var point := a+edge*t
		if point.length_squared() >= best_distance: continue
		best_distance = point.length_squared()
		if t <= 0.0:
			best = {"simplex":[simplex[i]], "point":point, "weights":[1.0]}
		elif t >= 1.0:
			best = {"simplex":[simplex[j]], "point":point, "weights":[1.0]}
		else:
			best = {"simplex":[simplex[i],simplex[j]], "point":point, "weights":[1.0-t,t]}
	return best
