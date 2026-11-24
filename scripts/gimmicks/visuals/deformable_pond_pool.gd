extends Node2D
## Stage-owned pool of fully assembled balls, visuals and native soft bodies.
var game: MergeGame
var soft: Node2D
var reflections: Node2D
var launcher: Node2D
var buckets: Dictionary = {}
var defaults: Dictionary = {}
var templates: Dictionary = {}
var active := true
var warm_target := 4
var retained_limit := 8
var hits := 0
var misses := 0
var prepared := 0
var returned := 0

func configure(board: MergeGame, solver: Node2D, reflection_layer: Node2D, control: Node2D) -> void:
	game=board
	soft=solver
	reflections=reflection_layer
	launcher=control
	warm_target=soft.tuning.pool_spares_per_level
	retained_limit=maxi(warm_target,soft.tuning.pool_retained_per_level)
	process_priority=90
	game.pooled_ball_acquire=acquire
	game.pooled_ball_release=retire

func _capture_defaults(ball: MergeBall) -> Dictionary:
	# Built-in physics properties are excluded from PROPERTY_USAGE_SCRIPT_VARIABLE.
	# In-flight balls set gravity_scale to zero; never carry that into a new life.
	var result := {"gravity_scale":ball.gravity_scale}
	for property in ball.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE)==0: continue
		var value: Variant=ball.get(property.name)
		if typeof(value) in [TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING,TYPE_COLOR,TYPE_VECTOR2]:
			result[property.name]=value
	return result

func _process(_delta: float) -> void:
	if not active or not is_instance_valid(game) or not is_instance_valid(soft.world): return
	for level in buckets:
		var bucket: Array=buckets[level]
		for index in range(bucket.size()-1,-1,-1):
			if not is_instance_valid(bucket[index].state.ball):
				_dispose(bucket[index])
				bucket.remove_at(index)
	# One complete spare per rendered frame; never a burst of setup in play.
	for level in range(game.max_level_index+1):
		if buckets.get(level,[]).size()>=warm_target: continue
		var provider: Callable=game.pooled_ball_acquire
		game.pooled_ball_acquire=Callable()
		var ball: MergeBall=game._spawn_ball(Vector2(-10000,-10000),level)
		game.pooled_ball_acquire=provider
		if ball==null: return
		ball.hide()
		reflections._install(ball)
		soft._register(ball)
		var state: Dictionary=soft.states[ball.get_instance_id()]
		state.visuals.update_surface(state,soft.tuning)
		soft.Faces.update(state,soft.tuning)
		defaults[ball.get_instance_id()]=_capture_defaults(ball)
		templates[level]=defaults[ball.get_instance_id()]
		prepared+=1
		_release(ball)
		return

func acquire(level: int) -> MergeBall:
	var bucket: Array=buckets.get(level,[])
	if bucket.is_empty():
		misses+=1
		return null
	var bundle: Dictionary=bucket.pop_back()
	var state: Dictionary=bundle.state
	var ball: MergeBall=state.ball
	for key in defaults[ball.get_instance_id()]: ball.set(key,defaults[ball.get_instance_id()][key])
	for key in ball.get_meta_list(): ball.remove_meta(key)
	ball.set_meta("pool_generation",int(bundle.generation)+1)
	ball.position=Vector2.ZERO
	ball.rotation=0.0
	ball.scale=Vector2.ONE
	ball.modulate=Color.WHITE
	ball.self_modulate=Color.WHITE
	ball.linear_velocity=Vector2.ZERO
	ball.angular_velocity=0.0
	ball.constant_force=Vector2.ZERO
	ball.constant_torque=0.0
	ball.lock_rotation=false
	ball.contact_observer=Callable()
	ball.freeze=false
	ball.sleeping=false
	ball.process_mode=Node.PROCESS_MODE_INHERIT
	ball.collision_layer=soft.QUERY_LAYER
	ball.collision_mask=0
	ball.custom_integrator=true
	ball.continuous_cd=RigidBody2D.CCD_MODE_DISABLED
	ball.show()
	state.collider.disabled=false
	state.native.set("enabled",true)
	state.native.set_body_position(Vector2.ZERO,true)
	state.native.set_body_rotation(0.0,true)
	state.points=state.rest.duplicate()
	state.previous=state.rest.duplicate()
	state.velocities=PackedVector2Array()
	state.velocities.resize(state.rest.size())
	for i in state.rest.size():
		state.particles[i].set_global_position(state.rest[i])
		state.particles[i].set_previous_global_position(state.rest[i])
		state.particles[i].set_force(Vector2.ZERO)
	state.center=Vector2.ZERO
	state.rotation=0.0
	state.published_velocity=Vector2.ZERO
	state.native_sleeping=false
	state.touching={}
	state.seen={}
	state.boundary={}
	state.erase("external_force")
	state.surface_points=state.rest.duplicate()
	state.surface_dirty=true
	state.render_dirty=true
	var hull:=Geometry2D.convex_hull(state.rest)
	if hull.size()>1:hull.remove_at(hull.size()-1)
	state.collider.shape.points=hull
	soft.states[ball.get_instance_id()]=state
	soft.world.add_body_node(state.native)
	soft.native_to_game[state.native.get_instance_id()]=ball
	soft.world.set_body_search_radius(state.native,state.bound_radius*soft.tuning.deformation_hard_ratio)
	state.native.wake_up()
	if not bundle.reflection.is_empty():reflections.records[ball.get_instance_id()]=bundle.reflection
	hits+=1
	return ball

func retire(ball: MergeBall) -> bool:
	if not active or not soft.states.has(ball.get_instance_id()):return false
	# Marked/modified sources keep the ordinary destruction path; their visual
	# tweens or delayed status callbacks must never target a later activation.
	for key in [&"ingestion_marked",&"is_ice_frozen",&"ice_targeted",&"split_targeted",&"is_enlarged",&"is_heavy",&"is_submerged",&"is_merge_cursed",&"damage_background_marked"]:
		if ball.get(key):return false
	if ball.hazard_turns>0 or ball.rewind_turns>0:return false
	call_deferred("_release",ball)
	return true

func _release(ball: MergeBall) -> void:
	if not active or not is_instance_valid(ball) or not soft.states.has(ball.get_instance_id()):return
	var id:=ball.get_instance_id()
	var state: Dictionary=soft.states[id]
	if not defaults.has(id):
		# Non-pooled first allocations have already been locked by the merge.
		# Use a pristine same-stage template, never snapshot gameplay state.
		if templates.has(ball.merge_level):defaults[id]=templates[ball.merge_level]
	if not defaults.has(id):
		ball.queue_free()
		return
	soft.states.erase(id)
	# Restore force/gravity and disconnect the bound body_entered callback before
	# dropping the flight record. Otherwise it survives into the next activation.
	launcher._finish_flight(ball)
	launcher.original_ball_state.erase(id)
	soft.native_to_game.erase(state.native.get_instance_id())
	state.native.set("enabled",false)
	soft.world.remove_body_node(state.native)
	state.collider.disabled=true
	for signal_name in [&"merge_requested",&"first_contact"]:
		for connection in ball.get_signal_connection_list(signal_name):
			ball.disconnect(signal_name,connection.callable)
	ball.set_meta("pool_generation",int(ball.get_meta("pool_generation",0))+1)
	ball.freeze=true
	ball.collision_layer=0
	ball.collision_mask=0
	ball.process_mode=Node.PROCESS_MODE_DISABLED
	ball.pool_inactive=true
	ball.merge_locked=true
	ball.hide()
	var reflection: Dictionary=reflections.records.get(id,{})
	reflections.records.erase(id)
	var bucket: Array=buckets.get_or_add(ball.merge_level,[])
	var bundle: Dictionary={"state":state,"reflection":reflection,"generation":ball.get_meta("pool_generation"),"id":id}
	if bucket.size()<retained_limit:bucket.append(bundle)
	else:_dispose(bundle)
	returned+=1

func _dispose(bundle: Dictionary) -> void:
	var state: Dictionary=bundle.state
	defaults.erase(bundle.id)
	if is_instance_valid(state.native):state.native.free()
	if is_instance_valid(state.ball):
		defaults.erase(state.ball.get_instance_id())
		state.visuals.restore()
		soft.Faces.restore([state])
		state.ball.queue_free()

func shutdown() -> void:
	if not active:return
	active=false
	set_process(false)
	if is_instance_valid(game):
		if game.pooled_ball_acquire==Callable(self,"acquire"):game.pooled_ball_acquire=Callable()
		if game.pooled_ball_release==Callable(self,"retire"):game.pooled_ball_release=Callable()
	for bucket in buckets.values():
		for bundle in bucket:_dispose(bundle)
	buckets.clear()
	defaults.clear()
	templates.clear()

func _exit_tree() -> void:
	shutdown()
