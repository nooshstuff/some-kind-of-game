class_name MoveHelper
extends RefCounted

var owner:ActorBody
var touch_list:Dictionary = {}

func _init(creator:ActorBody):
	owner = creator

func process_impacts():
	# owner.physics_touch_triggers()
	
	if ( !true ): # TODO: if player isn't solid
		return
	
	var vel:Vector3 = owner.vel
	
	for ent_id in touch_list:
		if !is_instance_id_valid(ent_id): continue
		var entity:PhysicsBody3D = instance_from_id(ent_id)
		var trace:Trace = touch_list[ent_id]
		if !is_instance_valid(entity): continue
		
		# Don't ever collide with self!!!!
		if (entity == owner):
			continue
		# Run the impact function as if we had run it during movement.
		owner.set_abs_velocity(trace.impact_velocity)
		
		physics_impact(entity, trace)
	# Restore the velocity
	owner.vel = vel
	# So no stuff is ever left over, sigh...
	reset_touched()

func physics_impact(entity:PhysicsBody3D, trace:Trace):
	pass # TODO: you might not need to do this though i think godot will handle it

func add_touched(trace:Trace, impact_velocity:Vector3)->bool:
	if (!is_instance_valid((trace.collider as PhysicsBody3D))):
		return false
	
	var obj_id:int = (trace.collider as PhysicsBody3D).get_instance_id()
	
	if (trace.rid == owner._playerCollider):
		return false
	
	if touch_list.has(obj_id):
		return false
		
	trace.impact_velocity = impact_velocity
	touch_list[obj_id] = trace
	return true

func reset_touched():
	touch_list.clear()
