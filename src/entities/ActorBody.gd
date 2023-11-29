class_name ActorBody
extends RigidBody3D
@onready var pivot = get_node("Pivot")
@onready var _playerCollider:RID = self.get_rid()
const HU2M = 0.01905 	# 1 hu = 0.01905 m

### STATE
var alive:bool = true
var data:UserData = UserData.new()
var buttons:Dictionary = {}

# self.global_transform.origin = m_vecAbsOrigin
var vel:Vector3 = Vector3.ZERO ## m_vecAbsVelocity (Global Velocity)
var angles:Vector3 = Vector3.ZERO ## v_angle
var ang_vel:Vector3 = Vector3.ZERO ## m_vecAngVelocity

var is_grounded:bool = false
var is_moving:bool = false:
	get: return !vel.is_zero_approx()
var is_crouching:bool = false
var is_slowing:bool = false
var is_sprinting:bool = false

var max_speed:float = 320*HU2M ## m_flMaxSpeed
# max accel?
var movetype:MOVETYPE = MOVETYPE.WALK

var cur_surfprop:SurfaceMaterial
var surface_friction:float = 1.0
var texture_type:StringName = &""

var ground_entity:PhysicsBody3D:
	set(pm):
		var new:PhysicsBody3D = pm
		var old:PhysicsBody3D = ground_entity

		if (!old && new): # airborne -> grounded
			m_base_vel -= new.linear_velocity
			m_base_vel.y = new.linear_velocity.y
		elif (old && !new):	#grounded -> airborne (add ground velocity)
			m_base_vel += old.linear_velocity
			m_base_vel.y = old.linear_velocity.y
		ground_entity = new

		if (new): # if we're on something
			cur_surfprop = pm.physics_material_override
			surface_friction = cur_surfprop.friction
			# HACKHACK: Scale this to fudge the relationship between vphysics friction values and player friction values.
			# A value of 0.8f feels pretty normal for vphysics, whereas 1.0f is normal for players.
			# This scaling trivially makes them equivalent.  REVISIT if this affects low friction surfaces too much.
			surface_friction = max(surface_friction*1.25, 1.0)
			texture_type = cur_surfprop.material;
			#water_jump_time = 0
			if (pm.collision_layer == LAYER.WORLD):
				pass #	add_to_touched(pm, move_vel)
			move_vel.y = 0.0


### MOVE DATA
var m_base_vel:Vector3 = Vector3.ZERO ## m_vecBaseVelocity (velocity of thing you're standing on)

var control_vec:Vector3 = Vector3.ZERO## m_flForwardMove, m_flUpMove, m_flSideMove


var move_global_viewangles:Vector3 = Vector3.ZERO ## move->m_vecAbsViewAngles
var move_local_viewangles:Vector3 = Vector3.ZERO ## move->m_vecViewAngles

var move_max_speed:float = max_speed ## m_flClientMaxSpeed
var move_angles:Vector3 = Vector3.ZERO ## move->m_vecAngles
var move_vel:Vector3 = Vector3.ZERO	## move->m_vecVelocity (Global Velocity)
var move_global_origin:Vector3 = Vector3.ZERO

enum MOVETYPE {
	NONE		= 0,	# never moves
	WALK,				# Player only - moving on the ground
	#STEP,				# gravity, special edge handling -- monsters use this
	#FLY,				# No gravity, but still collides with stuff
	#FLYGRAVITY,		# flies through the air + is affected by gravity
	#VPHYSICS,			# uses VPHYSICS for simulation
	#PUSH,				# no clip to world, push and crush
	#NOCLIP,			# No gravity, no collisions, still do velocity/avelocity
	LADDER,			# Used by players only when going onto a ladder
	#OBSERVER,			# Observer movement, depends on player's observer mode
	CUSTOM,			# Allows the entity to describe its own physics
	# should always be defined as the last item in the list
	LAST = CUSTOM,
}

enum LAYER {
	WORLD = 0,
	PROP = 1
}

### COLLISION HULL
@export var hull_radius:float = 16*HU2M # hull is actually 32 hu wide,
@export var base_height:float = 72*HU2M
@export var crouch_height:float = 36*HU2M

@export var base_cam_height:float = 64*HU2M
@export var crouch_cam_height:float = 28*HU2M
@export var dead_cam_height:float = 14*HU2M

@export var pickup_range:float = 9*HU2M # from collision hull, 25hu from center
@export var use_range:float = 82*HU2M 

var player_mins:Vector3:
	get:
		return  Vector3(-hull_radius, 0, -hull_radius)

var player_maxs:Vector3:
	get:
		return Vector3(hull_radius, base_height, hull_radius) if !fully_crouched else Vector3(hull_radius, crouch_height, hull_radius)



### HORIZONTAL MOVEMENT
var SPEEDLIMIT:Dictionary = {
	"walk" = 150*HU2M,	# The target ground speed when walking slowly.
	"base" = 190*HU2M,	# The target ground speed when running.
	"sprint" = 320*HU2M,	# The target ground speed when sprinting.
}
@export var s_rollangle:float = 25
@export var s_rollspeed:float = 200*HU2M

@export var acceleration_threshold:float = 450*HU2M

@export var crouch_speed_mod:float = 0.33333333
@export var backward_speed_mod:float = 0.90

@export var ground_friction:float = 4.0 

# CROUCHING
var crouch_frame_tolerated:bool = false; # Wait a frame before crouch speed.
var crouch_inprogress:bool = false; # player->m_Local.m_bDucking (If in the crouching transition)
var fully_crouched:bool = false # player->m_Local.m_bDucked (if fully crouched)
@export var crouch_time:float = 0.4; # in seconds
@export var uncrouch_time:float = 0.2; # in seconds
@export var crouchjump_time:float = 0.0; # in seconds
@export var uncrouchjump_time:float = 0.8; # in seconds
@export var uncrouch_check_factor:float = 0.75; # Fraction of uncrouch half-height to check for before doing starting an uncrouch.

## SLOPE
@export var walkable_angle:float = 45.573 # in degrees. Floor Z = 0.7f
@export var slide_limit:float = 0.5 # Threshold (0.0-1.0) relating to speed ratio and friction which causes us to catch air

## BRAKING
@export var brake_decel:float = 190.5; # *HU2M #?? whats this
@export var brake_decel_flying:float = brake_decel;
@export var brake_decel_swimming:float = brake_decel;
@export var brake_decel_falling:float = 0.0;
@export var brake_window:float = 0.015; #Time (in sec) the player has to rejump without applying friction.
var brake_window_timer:float = 0.0; #Progress checked against the Braking Window, incremented in millis.
var brake_window_over = true; #If the player has been on the ground past the Braking Window, start braking.

## AIRBORNE HORIZONTAL MOVEMENT
@export var air_control:float = 1.0
@export var air_speed_cap:float = 30*HU2M # The vector differential magnitude cap when in air.

### VERTICAL MOVEMENT
var gravity:float = -600*HU2M
@export var jump_strength:float = 140*HU2M
var jump_z_strength:float = 160*HU2M
@export var min_step_height:float = 5.25*HU2M # The minimum step height from moving fast
@export var max_step_height:float = 18*HU2M

# func _ready(): pass

# func _process(delta: float): pass

var move_oldangles:Vector3 = Vector3.ZERO
var fixangle:int = 1
#var anglechange:Vector3 = Vector3.ZERO
func _physics_process(_delta: float):
	data.check()
	# TODO: apply forced button changes to ucmd
	buttons = data.buttons.duplicate()

	# do weapon selection

	# TODO: CheckMovingGround( player, TICK_INTERVAL ); THIS IS FOR CONVEYORS 

	move_oldangles = angles
	if (fixangle == 0): # 0:nothing, 1 (default):force view angles, 2:add avelocity
		angles = data.viewangles
	elif (fixangle == 2):
		angles = data.viewangles #+ anglechange;
	
	prethink()

	setup_movement()

	movement() #PLAYER MOVE 

	# FINISH MOVE (game movement)

	# FINISH MOVE (player command)

	# PROCESS IMPACTS

	# FINISH COMMAND

var skip_prethink:bool = false
var fall_vel:float = 0.0
func prethink():
	if skip_prethink:
		return
	# hints system here
	item_preframe()
	# Water Move here
	#update HUD data here
	#damage over time
	#gordon suit notices
	#IF death in progress. update last known navigation position. then return 
	if !is_grounded:
		fall_vel = -vel.abs().y
	#update last known navigation position

func item_preframe():
	#use_handler()

	#get active weapon id

	## update all holstered weapons	
	#loop through held weapons and skip (continue) if it's null or = to active weapon
	
	# RUN weapon's holsterframe

	#return if current time is less than next attack time?? might be NPC thing
	#return if active weapon is null

	# RUN active weapon's preframe
	pass

var drive_control_vec:Vector3 = Vector3.ZERO

func setup_movement():
	data.local_viewangles = data.viewangles
	# TODO: MoveParent / Vehicle shenanigans
	if (true): # if no moveparent
		data.global_viewangles = data.local_viewangles
	else:
		pass # matrix math
	if (false): # if controlling vehicle or other
		drive_control_vec = control_vec
		control_vec = Vector3.ZERO
	else:
		control_vec.z = -data.forwardmove
		control_vec.x = data.sidemove
		control_vec.y = data.upmove
		
	
	move_max_speed = max_speed
	move_angles = angles
	move_vel = vel
	move_global_origin = self.global_transform.origin
	#get constraint information

var vec_forward:Vector3 = Vector3.ZERO
var vec_right:Vector3 = Vector3.ZERO
var vec_up:Vector3 = Vector3.ZERO
func movement():
	check_parameters()

	#clear output applied velocity
	#mv->m_outWishVel.Init();
	#mv->m_outJumpVel.Init();

	var b:Basis = Basis(Quaternion.from_euler(move_local_viewangles))
	vec_forward = -b.z
	vec_right = b.x
	vec_up = b.y

	# TODO: stuck detection, if not fixed, return
	if (movetype != MOVETYPE.WALK):
		categorize_position()
	else:
		if (move_vel.y > 250*HU2M):
			ground_entity = null

	# MOVETYPE -> FULL WALK MOVE (or ladder. whatever)

## Check Movement Parameters
func check_parameters():
	var spd:float = control_vec.length_squared()

	if (move_max_speed != 0.0):
		max_speed = min(max_speed, move_max_speed)

	var speed_factor:float = 1.0
	if cur_surfprop:
		speed_factor = cur_surfprop.max_speed_factor
	
	#var constraint_speed_factor:float = compute_constraint_speed_factor()
	#if (constraint_speed_factor < speed_factor):
	#	speed_factor = constraint_speed_factor
	max_speed *= speed_factor
	
	if ((spd != 0.0) && (spd > max_speed*max_speed)):
		var spd_ratio:float = max_speed / sqrt(spd)
		control_vec.x *= spd_ratio
		control_vec.y *= spd_ratio
		control_vec.z *= spd_ratio

	if (false): # if frozen or on train or dead
		control_vec = Vector3.ZERO

	# TODO: DECAY PUNCH ANGLE

	
	if (alive):
		var v_angle:Vector3
		v_angle = move_angles
		#v_angle = v_angle + player->m_Local.m_vecPunchAngle;

		move_angles.x = v_angle.x
		move_angles.y = v_angle.y
		if (s_rollangle != 0.0):
			move_angles.z = calc_roll(v_angle, move_vel, s_rollangle, s_rollspeed)
		else:
			move_angles.z = 0.0
	else:
		move_angles = move_oldangles
		# SET DEAD VIEW OFFSET

const floor_offset:float = 2*HU2M
const non_jump_velocity:float = 140*HU2M
var in_vehicle:bool = false
func categorize_position():
	# Reset this each time we-recategorize, otherwise we have bogus friction when we jump into water and plunge downward really quickly
	surface_friction = 1.0
	# check_water()

	var point:Vector3 = self.global_transform.origin
	point.y -= floor_offset
	var bumpOrigin:Vector3 = self.global_transform.origin

	var moving_up:bool = (move_vel.y > 0.0)
	var moving_up_rapidly:bool = (move_vel.y > non_jump_velocity)
	if (moving_up_rapidly):
		if (ground_entity):
			moving_up_rapidly = ( move_vel.y - ground_entity.linear_velocity.y ) > non_jump_velocity;

	if (moving_up_rapidly or (moving_up && movetype == MOVETYPE.LADDER)):
		ground_entity = null
	else:
		var pm:Dictionary = try_touch_ground(bumpOrigin, point, player_mins, player_maxs)[0]
		# Was on ground, but now suddenly am not.  If we hit a steep plane, we are not on ground
		if (is_instance_valid((pm["object"] as PhysicsBody3D)) && (!pm["object"].get_collision_layer_bit(LAYER.WORLD) or Vector3(pm["normal"]).y < 0.7)):
			try_touch_ground_quad(bumpOrigin, point, pm)
			if (is_instance_valid((pm["object"] as PhysicsBody3D)) && (!pm["object"].get_collision_layer_bit(LAYER.WORLD) or Vector3(pm["normal"]).y < 0.7)):
				ground_entity = null
				# probably want to add a check for a +z velocity too!
				if (move_vel.y > 0.0):
					surface_friction = 0.25;
			else:
				ground_entity = pm["object"] as PhysicsBody3D
		else:
			ground_entity = pm["object"] as PhysicsBody3D
	
		if (!in_vehicle):
			pass # TODO: If our gamematerial has changed, tell any player surface triggers that are watching


func try_touch_ground(start:Vector3, end:Vector3, mins:Vector3, maxs:Vector3)-> Array[Dictionary]:
	var out:Array[Dictionary]
	var shape:BoxShape3D = BoxShape3D.new()
	#var startoffset:Vector3 = (maxs + mins)*0.5
	#var mstart:Vector3 = start + startoffset
	shape.size = maxs - mins # extents
	shape_cast(get_world_3d().direct_space_state, start, end, shape, out)
	return out

func try_touch_ground_quad(start:Vector3, end:Vector3, pm:Dictionary):
	var mins:Vector3
	var maxs:Vector3
	var minsSrc:Vector3 = player_mins;
	var maxsSrc:Vector3 = player_maxs;

	var fraction:float = pm["safe_t"];
	var endpos:Vector3 = pm["endpos"];

	# Check the -x, -y quadrant
	mins = minsSrc;
	maxs = Vector3( min( 0, maxsSrc.x ), min( 0, maxsSrc.y ), maxsSrc.z );
	pm = try_touch_ground( start, end, mins, maxs )[0];
	if (is_instance_valid((pm["object"] as PhysicsBody3D))):
		if ( pm["object"].get_collision_layer_bit(LAYER.WORLD) && Vector3(pm["normal"]).y >= 0.7):
			pm["safe_t"] = fraction;
			pm["endpos"] = endpos;
			return

	# Check the +x, +y quadrant
	mins = Vector3( max( 0, minsSrc.x ), max( 0, minsSrc.y ), minsSrc.z );
	maxs = maxsSrc;
	pm = try_touch_ground( start, end, mins, maxs )[0];
	if (is_instance_valid((pm["object"] as PhysicsBody3D))):
		if ( pm["object"].get_collision_layer_bit(LAYER.WORLD) && Vector3(pm["normal"]).y >= 0.7):
			pm["safe_t"] = fraction;
			pm["endpos"] = endpos;
			return

	# Check the -x, +y quadrant
	mins = Vector3( minsSrc.x, max( 0, minsSrc.y ), minsSrc.z );
	maxs = Vector3( min( 0, maxsSrc.x ), maxsSrc.y, maxsSrc.z );
	pm = try_touch_ground( start, end, mins, maxs)[0];
	if (is_instance_valid((pm["object"] as PhysicsBody3D))):
		if ( pm["object"].get_collision_layer_bit(LAYER.WORLD) && Vector3(pm["normal"]).y >= 0.7):
			pm["safe_t"] = fraction;
			pm["endpos"] = endpos;
			return

	# Check the +x, -y quadrant
	mins = Vector3( max( 0, minsSrc.x ), minsSrc.y, minsSrc.z );
	maxs = Vector3( maxsSrc.x, min( 0, maxsSrc.y ), maxsSrc.z );
	pm = try_touch_ground( start, end, mins, maxs )[0];
	if (is_instance_valid((pm["object"] as PhysicsBody3D))):
		if ( pm["object"].get_collision_layer_bit(LAYER.WORLD) && Vector3(pm["normal"]).y >= 0.7):
			pm["safe_t"] = fraction;
			pm["endpos"] = endpos;
			return

	pm["safe_t"] = fraction;
	pm["endpos"] = endpos;

func calc_roll(ang:Vector3, velocity:Vector3, rollangle, rollspeed) -> float:
	var signitude:float
	var side:float
	var value:float
	
	var b:Basis = Basis(Quaternion.from_euler(ang))
	# var forward:Vector3 = -b.z
	# var right:Vector3 = b.x
	# var up:Vector3 = b.y
	
	side = velocity.dot(b.x)
	signitude = -1 if (side < 0) else 1
	side = abs(side)
	value = rollangle
	if (side < rollspeed):
		side = side * value / rollspeed
	else:
		side = value

	return side*signitude

func _integrate_forces(state: PhysicsDirectBodyState3D):
	#state.transform.basis = Basis(rot)
	state.linear_velocity = vel # + curPlatVel

func ray_cast(state:PhysicsDirectSpaceState3D, origin:Vector3, direction:Vector3, out:Array[Dictionary], distance:float = 1.0) -> bool:
	var RaycastHit:Dictionary
	var rayTrace:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	rayTrace.from = origin
	rayTrace.to = origin + (direction * distance)
	rayTrace.exclude += [_playerCollider]
	# FIXME: intersect ray causes a crash if the ray hits a second collision shape in a physics object
	# not sure if that's my fault
	RaycastHit = state.intersect_ray(rayTrace)
	if !RaycastHit.is_empty():
		var hit_distance:float = rayTrace.from.distance_to(RaycastHit["position"])
		RaycastHit["distance"] = hit_distance
		out.assign([RaycastHit])
	#DebugDraw.draw_ray(origin, direction, distance, Color.RED if RaycastHit.is_empty() else Color.GREEN, 5.0)
	return !RaycastHit.is_empty()

func shape_cast(state:PhysicsDirectSpaceState3D, start:Vector3, end:Vector3, shape:Shape3D, out:Array[Dictionary]) -> bool: # consider using official shapecast3d
	var shapeHit:Array[Dictionary]
	var shapeTrace:PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	shapeTrace.shape = shape
	shapeTrace.exclude += [_playerCollider]
	#shapeTrace.collision_mask = 
	shapeTrace.transform = Transform3D(Basis.IDENTITY, start)
	shapeTrace.motion = end - start
	
	var motion:PackedFloat32Array = state.cast_motion(shapeTrace)
	if motion[1] < 1.0:
		var xf:Transform3D = shapeTrace.transform
		xf.origin = shapeTrace.transform.origin + shapeTrace.motion * (motion[1] + 0.000001) # CMP_EPSILON
		shapeTrace.transform = xf
		pass
	
	
	shapeTrace.motion = Vector3.ZERO
	var intersected:bool = true
	while intersected && shapeHit.size() < 4:
		var rest_info:Dictionary = state.get_rest_info(shapeTrace)
		intersected = !rest_info.is_empty()
		if intersected:
			shapeHit.push_back(rest_info)
			shapeTrace.exclude += [rest_info.get("rid")]
	
	#DebugDraw.draw_ray(shapeTrace.transform.origin, direction, distance, Color.RED if shapeHit.is_empty() else Color.GREEN, 5.0)
	#DebugDraw.draw_sphere(shapeTrace.transform.origin, shapeTrace.shape.radius, Color.RED if shapeHit.is_empty() else Color.GREEN, 5.0)
	if !shapeHit.is_empty():
		for hit in shapeHit:
			# TODO: i think this value isn't accounting for something else i did
			var hit_distance:float = start.distance_to(hit["point"])
			hit["distance"] = hit_distance
			hit["safe_t"] = motion[0]
			hit["unsafe_t"] = motion[1]
			hit["endpos"] = start + (end - start) * motion[0]
			hit["object"] = instance_from_id(hit["collider_id"])
			#DebugDraw.set_text(str(hit["distance"]))
			#DebugDraw.draw_line_hit(origin, shapeTrace.transform.origin + shapeTrace.motion, hit["point"], true)
	
	out.assign(shapeHit)
	return !shapeHit.is_empty()

func is_bit_enabled(mask, index):
	return mask & (1 << index) != 0

func enable_bit(mask, index):
	return mask | (1 << index)

func disable_bit(mask, index):
	return mask & ~(1 << index)