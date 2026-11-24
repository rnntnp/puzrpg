extends RefCounted
## Preserve the concave shell silhouette; never take its convex hull.
static var cache: Dictionary = {}

static func shell_chain(ball: MergeBall, count: int, include_outline_expansion: bool = false) -> PackedVector2Array:
	var shell := ball.visual_container.find_child("ShellOutline", true, false) as Sprite2D
	if shell == null or shell.texture == null: return PackedVector2Array()
	var key := "%s:%s" % [shell.texture.get_rid().get_id(), count]
	if not cache.has(key):
		var image := shell.texture.get_image()
		if image.is_compressed(): image.decompress()
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(image, 0.5)
		var polygons := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 1.0)
		var largest := PackedVector2Array()
		var largest_area := 0.0
		for polygon in polygons:
			var area := 0.0
			for i in polygon.size(): area += polygon[i].cross(polygon[(i+1)%polygon.size()])
			if absf(area)>largest_area:
				largest_area=absf(area)
				largest=polygon
		cache[key] = simplify(largest, count, true)
	var local: PackedVector2Array = cache[key].duplicate()
	var to_body := ball.global_transform.affine_inverse()*shell.global_transform
	var expansion:=Vector2.ONE
	if include_outline_expansion and shell.material is ShaderMaterial:
		var expand_texels: float=shell.material.get_shader_parameter("outline_expand_texels")
		expansion+=Vector2.ONE*expand_texels*2.0/shell.texture.get_size()
	for i in local.size(): local[i] = to_body*((local[i]+shell.get_rect().position)*expansion)
	if Geometry2D.is_polygon_clockwise(local): local.reverse()
	return local

static func simplify(polygon: PackedVector2Array, count: int, preserve_bounds: bool = false) -> PackedVector2Array:
	if preserve_bounds and count>=4 and polygon.size()>count:
		return fit_contour(polygon,count)
	var result := polygon.duplicate()
	# Remove the least significant corner, keeping sharp tips and deep valleys.
	while result.size()>count:
		var least := INF
		var index := 0
		var anchors: Array[int]=[]
		if preserve_bounds and count>=4:
			for axis in 4:
				var extreme:=0
				for i in result.size():
					if (axis==0 and result[i].x<result[extreme].x) or (axis==1 and result[i].x>result[extreme].x) or (axis==2 and result[i].y<result[extreme].y) or (axis==3 and result[i].y>result[extreme].y):extreme=i
				anchors.append(extreme)
		for i in result.size():
			if i in anchors:continue
			var a := result[(i-1+result.size())%result.size()]
			var b := result[i]
			var c := result[(i+1)%result.size()]
			var importance := absf((b-a).cross(c-b))
			if importance<least:
				least=importance
				index=i
		result.remove_at(index)
	while result.size()>=3 and result.size()<count:
		var longest := 0.0
		var index := 0
		for i in result.size():
			var length := result[i].distance_squared_to(result[(i+1)%result.size()])
			if length>longest:
				longest=length
				index=i
		result.insert(index+1,result[index].lerp(result[(index+1)%result.size()],0.5))
	return result

static func fit_contour(polygon: PackedVector2Array, count: int) -> PackedVector2Array:
	# Retain the four extrema, then split the edge with the largest contour
	# error. Least-area deletion can leave a long, visibly inset chord.
	var selected: Array[int]=[]
	for axis in 4:
		var extreme:=0
		for i in polygon.size():
			if (axis==0 and polygon[i].x<polygon[extreme].x) or (axis==1 and polygon[i].x>polygon[extreme].x) or (axis==2 and polygon[i].y<polygon[extreme].y) or (axis==3 and polygon[i].y>polygon[extreme].y):extreme=i
		if not extreme in selected:selected.append(extreme)
	while selected.size()<count:
		selected.sort()
		var worst:=-1.0
		var candidate:=-1
		for edge in selected.size():
			var start:=selected[edge]
			var finish:=selected[(edge+1)%selected.size()]
			var index:=(start+1)%polygon.size()
			while index!=finish:
				var closest:=Geometry2D.get_closest_point_to_segment(polygon[index],polygon[start],polygon[finish])
				var error:=polygon[index].distance_squared_to(closest)
				if error>worst:worst=error;candidate=index
				index=(index+1)%polygon.size()
		if candidate<0:break
		selected.append(candidate)
	selected.sort()
	var result:=PackedVector2Array()
	for index in selected:result.append(polygon[index])
	return result
