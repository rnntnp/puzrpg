extends "res://scripts/gimmicks/visuals/soft_pond_meshes.gd"
## Isolate shader parameters from shared materials and non-ball objects.
func _install_material(source: CanvasItem) -> Dictionary:
	var original := source.material
	if original != null:
		source.material = original.duplicate()
	var record := super._install_material(source)
	record.original_material = original
	return record
