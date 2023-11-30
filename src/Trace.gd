class_name Trace
extends RefCounted

static var FAILIURE:Trace = Trace.new({}, false)
### REST INFO
## Colliding object's ID.
var collider_id:int	
## Colliding object's velocity Vector3. If the object is an Area3D, the result is (0, 0, 0)
var linear_velocity:Vector3 
## Object's surface normal at the intersection point
var normal:Vector3	
## Intersection point
var point:Vector3	
## Intersecting object's RID
var rid:RID
## Shape index of the colliding shape.
var shape:int

### GODOT INFO
var is_colliding:bool = false	#
var collider:CollisionObject3D # CBaseEntity *m_pEnt;

var fraction:float = 1.0	# time completed, 1.0 = didn't hit anything
var fraction_unsafe:float = 1.0

### CUSTOM
var distance:float
var startpos:Vector3
var endpos:Vector3

var impact_velocity:Vector3 = Vector3.ZERO # SPECIFICALLY FOR TOUCH LIST!!

### SOURCE
var allsolid:bool:
	get: return is_colliding && fraction_unsafe == 0 # FIXME, temp values
var startsolid:bool:
	get: return is_colliding && fraction_unsafe == 0 # FIXME, temp values

func _init(rest_info:Dictionary = {}, success:bool = true):
	if !rest_info.is_empty():
		collider_id = rest_info.get("collider_id")
		collider = rest_info.get("collider", fetch_collider())
		linear_velocity = rest_info.get("linear_velocity")
		normal = rest_info.get("normal")
		point = rest_info.get("point")
		rid = rest_info.get("rid")
		shape = rest_info.get("shape")
	is_colliding = success	

func fetch_collider()->Object:
	return instance_from_id(collider_id)

func did_hit_world()->bool:
	return is_bit_enabled(collider.collision_layer, 0) 	# TODO: check if hit entity is world

func did_hit()->bool:
	return is_colliding # or maybe = ( fraction < 1 or allsolid or startsolid )

func is_bit_enabled(mask, index):
	return mask & (1 << index) != 0
#cplane_t		plane;					# surface normal at impact

#float			fraction;				

#int			contents;				# contents on other side of surface hit
#unsigned short	dispFlags;				# displacement flags for marking surfaces with data



#float			fractionleftsolid;		# time we left a solid, only valid if we started in solid
#csurface_t		surface;				# surface hit (impact surface)

#int			hitgroup;				# 0 == generic, non-zero is specific body part
#short			physicsbone;			# physics bone hit by trace in studio


# NOTE: this member is overloaded.
# If hEnt points at the world entity, then this is the static prop index.
# Otherwise, this is the hitbox index.
#int			hitbox;					# box hit by trace in studio
