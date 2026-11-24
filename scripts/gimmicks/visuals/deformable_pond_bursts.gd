extends Node2D
## Shared quad instances. Spawn writes one block; the GPU animates all shapes.
const BurstShader = preload("res://shaders/deformable_pond_burst_instances.gdshader")
const SLOTS := 128
const STRIDE := 16 # 2D transform(8), color(4), custom data(4).
var game: MergeGame
var mesh_instance: MultiMeshInstance2D
var multimesh: MultiMesh
var burst_material: ShaderMaterial
var buffer := PackedFloat32Array()
var capacity := 64
var free_slots: Array[int] = []
var effects: Dictionary = {}
var clock := 0.0
var dirty := false
var spawned := 0
var uploads := 0
var active := true
var warm_frames := 2

func configure(board: MergeGame, settings: Resource) -> void:
	game=board
	capacity=settings.burst_initial_capacity
	z_index=18
	burst_material=ShaderMaterial.new()
	burst_material.shader=BurstShader
	var quad:=QuadMesh.new()
	quad.size=Vector2(2,2)
	multimesh=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_2D
	multimesh.use_colors=true
	multimesh.use_custom_data=true
	multimesh.mesh=quad
	multimesh.instance_count=capacity*SLOTS
	multimesh.visible_instance_count=0
	multimesh.custom_aabb=AABB(Vector3(-2048,-2048,-1),Vector3(4096,4096,2))
	buffer.resize(capacity*SLOTS*STRIDE)
	# Compile the shared GPU path during entry, before the first real merge.
	# Per-instance alpha is zero; the dummy is outside the visible board.
	_write(0,Vector2(-512,-512),0.0,Color(0,0,0,0),0.25,0.0,1.0)
	dirty=true
	for i in range(capacity-1,-1,-1):free_slots.append(i)
	mesh_instance=MultiMeshInstance2D.new()
	mesh_instance.multimesh=multimesh
	mesh_instance.material=burst_material
	add_child(mesh_instance)
	game.merge_burst_renderer=play

func _grow() -> void:
	var old:=capacity
	capacity*=2
	buffer.resize(capacity*SLOTS*STRIDE)
	multimesh.instance_count=capacity*SLOTS
	for i in range(capacity-1,old-1,-1):free_slots.append(i)
	dirty=true

func _write(index: int, center: Vector2, angle: float, color: Color, duration: float, kind: float, size: float) -> void:
	var i:=index*STRIDE
	var c:=cos(angle)
	var s:=sin(angle)
	# RenderingServer's TRANSFORM_2D rows: xx,yx,0,origin.x / xy,yy,0,origin.y.
	buffer[i]=c;buffer[i+1]=-s;buffer[i+2]=0;buffer[i+3]=center.x
	buffer[i+4]=s;buffer[i+5]=c;buffer[i+6]=0;buffer[i+7]=center.y
	buffer[i+8]=color.r;buffer[i+9]=color.g;buffer[i+10]=color.b;buffer[i+11]=color.a
	buffer[i+12]=clock;buffer[i+13]=duration;buffer[i+14]=kind;buffer[i+15]=size

func play(at: Vector2, color: Color, radius: float, combo: int, level: int, multiplier: float=1.0, damage: int=0) -> void:
	if not active:return
	if free_slots.is_empty():_grow()
	var slot: int=free_slots.pop_back()
	var power:=clampf(sqrt(float(maxi(0,damage))/20.0),0.0,4.0)
	var large:=level>=6
	var size:=clampf(0.65+radius/110.0,0.9,2.4)*(1.0+power*0.22)*maxf(1.0,multiplier)
	var duration:=0.34+(0.08 if large else 0.0)+minf(0.1,float(maxi(1,combo)-1)*0.025)+power*0.035
	var count:=12+mini(12,(maxi(1,combo)-1)*3)+(6 if large else 0)+roundi(power*5.0)
	var second:=combo>=2 or large or power>=1.5
	var center:=to_local(game.to_global(at))
	var ring:=color.lerp(Color.WHITE,0.55)
	var index:=slot*SLOTS
	var flash:=0.13+minf(0.14,float(maxi(1,combo)-1)*0.035)+(0.08 if large else 0.0)+power*0.025
	_write(index,center,0,Color(ring,flash),duration,0,size);index+=1
	_write(index,center,0,Color(ring,0.9),duration,1,size);index+=1
	if second:
		_write(index,center,0,Color(color.lerp(Color.WHITE,0.82),0.78),duration,2,size);index+=1
	if combo>=3 or power>=2.0:
		_write(index,center,0,Color(color,0.48),duration,3,size);index+=1
	for ray in count:
		var angle:=TAU*float(ray)/float(count)+randf_range(-0.12,0.12)
		randf_range(0.82,1.18) # Preserve the existing effect RNG consumption.
		var ray_color:=Color(color.lerp(Color.WHITE,0.35+0.15*float(ray%2)),1.0)
		var variant:=float(ray%3)*0.1
		_write(index,center,angle,ray_color,duration,4.0+variant,size);index+=1
		if ray%2==0:
			_write(index,center,angle,ray_color,duration,5.0+variant,size);index+=1
		if second and ray%3==0:
			_write(index,center,angle,ray_color,duration,6.0+variant,size);index+=1
	effects[slot]=clock+duration
	dirty=true
	spawned+=1

func _process(delta: float) -> void:
	if not active:return
	clock+=delta
	var highest:=-1
	for slot in effects.keys():
		if clock>=effects[slot]:
			effects.erase(slot)
			free_slots.append(slot)
		else:highest=maxi(highest,slot)
	if dirty:
		multimesh.buffer=buffer
		dirty=false
		uploads+=1
	multimesh.visible_instance_count=(highest+1)*SLOTS
	if warm_frames>0:
		multimesh.visible_instance_count=maxi(1,multimesh.visible_instance_count)
		warm_frames-=1
	burst_material.set_shader_parameter("effect_clock",clock)

func shutdown() -> void:
	active=false
	set_process(false)
	if is_instance_valid(game) and game.merge_burst_renderer==Callable(self,"play"):game.merge_burst_renderer=Callable()
	effects.clear()
	if multimesh!=null:multimesh.visible_instance_count=0

func _exit_tree() -> void:
	shutdown()
