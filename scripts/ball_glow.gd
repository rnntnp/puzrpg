class_name BallGlow
extends Node2D

const GlowShader = preload("res://shaders/ball_glow_quad.gdshader")
static var shared_quad: QuadMesh
static var shared_material: ShaderMaterial
var surface: MeshInstance2D

var glow_radius := 0.0
var glow_color := Color.WHITE
var glow_strength := 0.0


func setup(radius: float, color: Color, strength: float) -> void:
	glow_radius = radius
	glow_color = color
	glow_strength = strength
	if surface==null:
		if shared_quad==null:
			shared_quad=QuadMesh.new()
			shared_quad.size=Vector2(2,2)
			shared_material=ShaderMaterial.new()
			shared_material.shader=GlowShader
		surface=MeshInstance2D.new()
		surface.mesh=shared_quad
		surface.material=shared_material
		add_child(surface)
	surface.scale=Vector2.ONE*maxf(0.0,radius)*1.7
	surface.modulate=Color(color,strength)
	surface.visible=radius>0.0 and strength>0.0
