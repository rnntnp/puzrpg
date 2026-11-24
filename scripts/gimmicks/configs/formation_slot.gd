extends Resource

@export var character: CharacterData
@export_range(1, 100000, 1) var health := 100
@export_enum("Front", "Rear") var column := 0
@export var position := Vector2(480, 350)
@export_range(0, 100, 1) var attack := 4
@export_range(0.1, 3.0, 0.01) var size_multiplier := 1.0
@export var sizing_reference: CharacterData
