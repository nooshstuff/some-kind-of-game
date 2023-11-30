class_name LineCast

static var space_state:PhysicsDirectSpaceState3D = null

static func update_space_state_with(node:Node3D):
	space_state = node.get_world_3d().direct_space_state

static func determine_collision_mask(mask:int, group:int)->int:
	return mask & ~(1 << group) # is disable bit the correct call here?

static func calc_overall_mask(layers:Array[int]):
	var total:int = 0
	for m in layers:
		total |= 1 << m
	return total

static func shape_cast(start:Vector3, end:Vector3, shape:Shape3D, mask:int = -1, excludes:Array[RID] = [], group:int = -1, limit:int = 1) -> Array[Trace]:
	var hits:Array[Dictionary] = []
	var shapeTrace:PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	shapeTrace.shape = shape
	shapeTrace.exclude += excludes
	if (mask >= 0 and group >= 0):
		shapeTrace.collision_mask = determine_collision_mask(mask, group)
	shapeTrace.transform = Transform3D(Basis.IDENTITY, start)
	shapeTrace.motion = end - start
	
	var motion:PackedFloat32Array = space_state.cast_motion(shapeTrace)
	if motion[1] < 1.0:
		var xf:Transform3D = shapeTrace.transform
		xf.origin = shapeTrace.transform.origin + shapeTrace.motion * (motion[1] + 0.000001) # CMP_EPSILON
		shapeTrace.transform = xf
		pass
	
	shapeTrace.motion = Vector3.ZERO
	var intersected:bool = true
	while intersected && hits.size() < limit:
		var rest_info:Dictionary = space_state.get_rest_info(shapeTrace)
		intersected = !rest_info.is_empty()
		if intersected:
			hits.push_back(rest_info)
			shapeTrace.exclude += [rest_info.get("rid")]
	
	#DebugDraw.draw_ray(shapeTrace.transform.origin, direction, distance, Color.RED if hits.is_empty() else Color.GREEN, 5.0)
	#DebugDraw.draw_sphere(shapeTrace.transform.origin, shapeTrace.shape.radius, Color.RED if hits.is_empty() else Color.GREEN, 5.0)
	if !hits.is_empty():
		var traces:Array[Trace] = []
		for hit in hits:
			#DebugDraw.set_text(str(trace.distance))
			#DebugDraw.draw_line_hit(origin, shapeTrace.transform.origin + shapeTrace.motion, hit["point"], true)
			var trace:Trace = Trace.new(hit)
			# TODO: i think this value isn't accounting for something else i did
			trace.distance = start.distance_to(hit["point"])
			trace.fraction = motion[0]
			trace.fraction_unsafe = motion[1]
			trace.startpos = start
			trace.endpos = start + (end - start) * motion[0]
			traces.append(trace)
		return traces
	else:
		return [Trace.FAILIURE]

static func ray_cast(start:Vector3, end:Vector3, mask:int = -1, excludes:Array[RID] = [], group:int = -1) -> Trace:

	var rayTrace:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	rayTrace.from = start
	rayTrace.to = end
	if (mask >= 0 and group >= 0):
		rayTrace.collision_mask = determine_collision_mask(mask, group)
	rayTrace.exclude += excludes
	# FIXME: intersect ray causes a crash if the ray hits a second collision shape in a physics object
	# not sure if that's my fault
	var hit:Dictionary = space_state.intersect_ray(rayTrace)
	if !hit.is_empty():
		#DebugDraw.draw_ray(start, direction, distance, Color.RED if RaycastHit.is_empty() else Color.GREEN, 5.0)
		var trace:Trace = Trace.new(hit)
		trace.distance = rayTrace.from.distance_to(hit["position"])
		# trace.fraction = 
		# trace.fraction_unsafe = 
		trace.startpos = start
		# trace.endpos =
		return trace
	else:
		return Trace.FAILIURE

static func ray_cast_distance(origin:Vector3, direction:Vector3, distance:float = 1.0, mask:int = -1, excludes:Array[RID] = [], group:int = -1) -> Trace:
	
	var rayTrace:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	rayTrace.from = origin
	rayTrace.to = origin + (direction * distance)
	if (mask >= 0 and group >= 0):
		rayTrace.collision_mask = determine_collision_mask(mask, group)
	rayTrace.exclude += excludes
	# FIXME: intersect ray causes a crash if the ray hits a second collision shape in a physics object
	# not sure if that's my fault
	var hit:Dictionary = space_state.intersect_ray(rayTrace)
	if !hit.is_empty():
		#DebugDraw.draw_ray(origin, direction, distance, Color.RED if RaycastHit.is_empty() else Color.GREEN, 5.0)
		var trace:Trace = Trace.new(hit)
		trace.distance = rayTrace.from.distance_to(hit["position"])
		# trace.fraction = 
		# trace.fraction_unsafe = 
		trace.startpos = origin
		# trace.endpos =
		return trace
	else:
		return Trace.FAILIURE
