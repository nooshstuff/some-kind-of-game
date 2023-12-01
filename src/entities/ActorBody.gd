class_name ActorBody
extends RigidBody3D
@onready var pivot:Node3D = get_node("Pivot")
@onready var cam:Camera3D = get_node("Pivot/FirstPerson")
@onready var _playerCollider:RID = self.get_rid()
const HU2M = 0.01905 	# 1 hu = 0.01905 m
var frametime:float = 0.05:
	get: return get_physics_process_delta_time()


############### 	i can just have some of the colission layers represent collision groups
############### 	and others represent those brush content tags 
############### 	:D

### STATE
var alive:bool = true
var data:UserData = UserData.new()
@onready var move_helper:MoveHelper = MoveHelper.new(self)
var buttons:Dictionary = {}

# self.global_transform.origin = true player->m_vecAbsOrigin
var global_origin:Vector3 = Vector3.ZERO ### player->m_vecAbsOrigin
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
var ground_entity:PhysicsBody3D

func set_ground_entity(pm:Trace):
	
	var new:PhysicsBody3D = (pm.collider if is_instance_valid(pm.collider as PhysicsBody3D) else null) if (pm != null) else null
	var old:PhysicsBody3D = ground_entity

	if (!old && new): # airborne -> grounded
		m_base_vel -= new.linear_velocity
		m_base_vel.y = new.linear_velocity.y
	elif (old && !new):	#grounded -> airborne (add ground velocity)
		m_base_vel += old.linear_velocity
		m_base_vel.y = old.linear_velocity.y
	ground_entity = new as PhysicsBody3D

	if (new): # if we're on something
		cur_surfprop = pm.physics_material_override
		surface_friction = cur_surfprop.friction
		# HACKHACK: Scale this to fudge the relationship between vphysics friction values and player friction values.
		# A value of 0.8f feels pretty normal for vphysics, whereas 1.0f is normal for players.
		# This scaling trivially makes them equivalent.  REVISIT if this affects low friction surfaces too much.
		surface_friction = max(surface_friction*1.25, 1.0)
		texture_type = cur_surfprop.material;
		water_jump_time = 0
		if (pm.collision_layer == LAYER.WORLD):
			pass # move_helper.add_touched(pm, move_vel)
		move_vel.y = 0.0
	
var touched_phys_object:bool = false

var output_wish_vel:Vector3 = Vector3.ZERO	# mv->m_outWishVel
var output_jump_vel:Vector3 = Vector3.ZERO	# mv->m_outJumpVel
var output_step_height:float = 0.0			# mv->m_outStepHeight
### MOVE DATA
var m_base_vel:Vector3 = Vector3.ZERO ## m_vecBaseVelocity (velocity of thing you're standing on)

var drive_control_vec:Vector3 = Vector3.ZERO
var control_vec:Vector3 = Vector3.ZERO## m_flForwardMove, m_flUpMove, m_flSideMove

var move_global_viewangles:Vector3 = Vector3.ZERO ## move->m_vecAbsViewAngles
var move_local_viewangles:Vector3 = Vector3.ZERO ## move->m_vecViewAngles

var move_max_speed:float = max_speed ## m_flClientMaxSpeed
var move_angles:Vector3 = Vector3.ZERO ## move->m_vecAngles
var move_vel:Vector3 = Vector3.ZERO	## move->m_vecVelocity (Global Velocity)
var move_global_origin:Vector3 = Vector3.ZERO

var vec_forward:Vector3 = Vector3.ZERO
var vec_right:Vector3 = Vector3.ZERO
var vec_up:Vector3 = Vector3.ZERO

### WATER
var is_underwater:bool = false # m_bPlayerUnderwater
var water_level:WATERLEVEL = WATERLEVEL.NONE
var m_old_water_level:WATERLEVEL = WATERLEVEL.NONE
var water_jump_flag:bool = false # FL_WATERJUMP
var water_jump_time:float = 0	# m_flWaterJumpTime
var water_jump_vel:Vector3 = Vector3.ZERO # m_vecWaterJumpVel


enum MOVETYPE {
	NONE		= 0,	# never moves
	WALK		= 1,		# Player only - moving on the ground
	#STEP,				# gravity, special edge handling -- monsters use this
	#FLY,				# No gravity, but still collides with stuff
	#FLYGRAVITY,		# flies through the air + is affected by gravity
	#VPHYSICS,			# uses VPHYSICS for simulation
	#PUSH,				# no clip to world, push and crush
	#NOCLIP,			# No gravity, no collisions, still do velocity/avelocity
	LADDER		= 2,	# Used by players only when going onto a ladder
	#OBSERVER,			# Observer movement, depends on player's observer mode
	#CUSTOM,			# Allows the entity to describe its own physics
	# should always be defined as the last item in the list
	#LAST = CUSTOM,
}

enum LAYER {
	WORLD = 0,
	PROP = 1
}

enum WATERLEVEL {
	NONE = 0,
	FEET = 1,
	WAIST = 2,
	EYES = 3
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
@export var s_accelerate:float = 10*HU2M
@export var s_air_accelerate:float = 10*HU2M

@export var crouch_speed_mod:float = 0.33333333
@export var backward_speed_mod:float = 0.90

@export var max_velocity:float = 3500*HU2M # sv_maxvelocity
@export var ground_friction:float = 4.0

# CROUCHING
var crouchjumping:bool = false
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
var jump_time:float = 0.0
@export var min_step_height:float = 5.25*HU2M # The minimum step height from moving fast
@export var max_step_height:float = 18*HU2M

func _ready():
	custom_integrator = true

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
	touched_phys_object = false
	move_oldangles = angles
	if (fixangle == 0): # 0:nothing, 1 (default):force view angles, 2:add avelocity
		angles = data.viewangles
	elif (fixangle == 2):
		angles = data.viewangles #+ anglechange;
	
	prethink()

	setup_movement()

	movement() #PLAYER MOVE 

	data.last_buttons = buttons.duplicate()	# CGameMovement::FinishMove() 

	finish_move() # CPlayerMove::FinishMove()

	# move_helper.process_impacts()
	
	post_think()

	post_think_physics()

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

func setup_movement():
	move_local_viewangles = data.viewangles
	# TODO: MoveParent / Vehicle shenanigans
	if (true): # if no moveparent
		move_global_viewangles = move_local_viewangles
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

func movement():
	check_parameters()

	#clear output applied velocity
	output_wish_vel = Vector3.ZERO
	output_jump_vel = Vector3.ZERO

	var b:Basis = Basis(Quaternion.from_euler(move_local_viewangles))
	vec_forward = -b.z
	vec_right = b.x
	vec_up = b.y

	# TODO: stuck detection, if not fixed, return
	if (movetype != MOVETYPE.WALK):
		categorize_position()
	else:
		if (move_vel.y > 250*HU2M):
			set_ground_entity(null)

	m_old_water_level = water_level

	#update_step_sound(cur_surfprop, move_global_origin, move_vel)

	#update_duck_jump_eye_offset()
	#duck()

	if (alive && true): # if alive and not on a train
		#if (!ladder_move() && movetype == MOVETYPE.LADDER):
			#movetype = MOVETYPE.WALK
			#movecollide = COLLIDETYPE.DEFAULT
		pass

	match movetype:
		MOVETYPE.NONE:
			pass
		MOVETYPE.WALK:
			walk_move()
		MOVETYPE.LADDER:
			#ladder_move()
			pass
		_:
			print_debug('bogus movetype with id '+str(movetype))
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
	side = absf(side)
	value = rollangle
	if (side < rollspeed):
		side = side * value / rollspeed
	else:
		side = value

	return side*signitude

const floor_offset:float = 2*HU2M
const non_jump_velocity:float = 140*HU2M
var in_vehicle:bool = false
func categorize_position():
	# Reset this each time we-recategorize, otherwise we have bogus friction when we jump into water and plunge downward really quickly
	surface_friction = 1.0
	check_water()

	var point:Vector3 = move_global_origin
	point.y -= floor_offset
	var bumpOrigin:Vector3 = move_global_origin

	var moving_up:bool = (move_vel.y > 0.0)
	var moving_up_rapidly:bool = (move_vel.y > non_jump_velocity)
	if (moving_up_rapidly):
		if (ground_entity):
			moving_up_rapidly = ( move_vel.y - get_entity_vel(ground_entity).y ) > non_jump_velocity;

	if (moving_up_rapidly or (moving_up && movetype == MOVETYPE.LADDER)):
		set_ground_entity(null)
	else:
		var pm:Trace = try_touch_ground(bumpOrigin, point, player_mins, player_maxs, MASK_PLAYERSOLID, -1 ) # COLLISION_GROUP_PLAYER_MOVEMENT
		# Was on ground, but now suddenly am not.  If we hit a steep plane, we are not on ground
		if (is_instance_valid((pm.collider as PhysicsBody3D)) && !pm.did_hit_world() || pm.normal.y < 0.7):
			try_touch_ground_quad(bumpOrigin, point, pm, MASK_PLAYERSOLID, -1) # COLLISION_GROUP_PLAYER_MOVEMENT
			if (is_instance_valid((pm.collider as PhysicsBody3D)) && !pm.did_hit_world() || pm.normal.y < 0.7):
				set_ground_entity(null)
				# probably want to add a check for a +z velocity too!
				if (move_vel.y > 0.0):
					surface_friction = 0.25;
			else:
				set_ground_entity(pm)
		else:
			set_ground_entity(pm)
	
		if (!in_vehicle):
			pass # TODO: If our gamematerial has changed, tell any player surface triggers that are watching

func check_water()->bool:
	return false # TODO: Check water

func try_touch_ground(start:Vector3, end:Vector3, mins:Vector3, maxs:Vector3, maskLayers:Array[int] = [-1], group:int = -1)-> Trace:
	var shape:BoxShape3D = BoxShape3D.new()
	#var startoffset:Vector3 = (maxs + mins)*0.5
	#var mstart:Vector3 = start + startoffset
	shape.size = maxs - mins # extents
	LineCast.update_space_state_with(self)
	return LineCast.shape_cast(start, end, shape, LineCast.calc_overall_mask(maskLayers), [_playerCollider], group)[0]

func try_touch_ground_quad(start:Vector3, end:Vector3, pm:Trace, maskLayers:Array[int] = [-1], group:int = -1)-> Trace:
	var mins:Vector3
	var maxs:Vector3
	var minsSrc:Vector3 = player_mins;
	var maxsSrc:Vector3 = player_maxs;

	var fraction:float = pm.fraction;
	var endpos:Vector3 = pm.endpos;

	LineCast.update_space_state_with(self)
	# Check the -x, -y quadrant
	mins = minsSrc;
	maxs = Vector3( min( 0, maxsSrc.x ), min( 0, maxsSrc.y ), maxsSrc.z );
	pm = try_touch_ground( start, end, mins, maxs, maskLayers, group)
	if (is_instance_valid((pm.collider as PhysicsBody3D))):
		if ( pm.did_hit_world() && pm.normal.y >= 0.7):
			pm.fraction = fraction;
			pm.endpos = endpos;
			return pm

	# Check the +x, +y quadrant
	mins = Vector3( max( 0, minsSrc.x ), max( 0, minsSrc.y ), minsSrc.z );
	maxs = maxsSrc;
	pm = try_touch_ground( start, end, mins, maxs, maskLayers, group )
	if (is_instance_valid((pm.collider as PhysicsBody3D))):
		if ( pm.did_hit_world() && pm.normal.y >= 0.7):
			pm.fraction = fraction;
			pm.endpos = endpos;
			return pm

	# Check the -x, +y quadrant
	mins = Vector3( minsSrc.x, max( 0, minsSrc.y ), minsSrc.z );
	maxs = Vector3( min( 0, maxsSrc.x ), maxsSrc.y, maxsSrc.z );
	pm = try_touch_ground( start, end, mins, maxs, maskLayers, group)
	if (is_instance_valid((pm.collider as PhysicsBody3D))):
		if ( pm.did_hit_world() && pm.normal.y >= 0.7):
			pm.fraction = fraction;
			pm.endpos = endpos;
			return pm

	# Check the +x, -y quadrant
	mins = Vector3( max( 0, minsSrc.x ), minsSrc.y, minsSrc.z );
	maxs = Vector3( maxsSrc.x, min( 0, maxsSrc.y ), maxsSrc.z );
	pm = try_touch_ground( start, end, mins, maxs, maskLayers, group )
	if (is_instance_valid((pm.collider as PhysicsBody3D))):
		if ( pm.did_hit_world() && pm.normal.y >= 0.7):
			pm.fraction = fraction;
			pm.endpos = endpos;
			return pm

	pm.fraction = fraction;
	pm.endpos = endpos;
	return pm

func walk_move():
	if (!check_water()):
		# start_gravity() code
		move_vel.y -= gravity_scale * gravity * 0.5 * frametime
		move_vel.y += m_base_vel.y * frametime
		m_base_vel.y = 0
		check_velocity()
		# end
	
	if (water_jump_time != 0):
		water_jump()
		try_move()
		check_water()
	
	# If we are swimming in the water, see if we are nudging against a place we can jump up out
	#  of, and, if so, start out jump.  Otherwise, if we are not moving up, then reset jump timer to 0
	if (water_level >= WATERLEVEL.WAIST): ### FINISH THIS ENTIRE SECTION LATER ONCE YOU WANT TO DO WATER
		if (water_level == WATERLEVEL.WAIST):
			#check_water_jump()
			pass 
		if ((move_vel.y < 0) && water_jump_time != 0):
			water_jump_time = 0
		
		if (buttons["jump"]):	# Was jump button pressed?
			check_jump_button()
		else:
			data.last_buttons["jump"] = false

		# water_move()	# TODO
		categorize_position()

		if (ground_entity != null):
			move_vel.y = 0.0
		
	else: # Not fully underwater
		if (buttons["jump"]):	# Was jump button pressed?
			check_jump_button()
		else:
			data.last_buttons["jump"] = false

		# Fricion is handled before we add in any base velocity. That way, if we are on a conveyor, 
		#  we don't slow when standing still, relative to the conveyor.
		if (ground_entity != null):
			move_vel.y = 0.0
			do_friction()

		# Make sure velocity is valid.
		check_velocity()

		if (ground_entity != null):
			ground_move()
		else:
			air_move()  # Take into account movement when in air.

		# Set final flags.
		categorize_position()
		# Make sure velocity is valid.
		check_velocity()
		# Add any remaining gravitational component.
		if (!check_water()):
			finish_gravity()
		# If we are on ground, no downward velocity.
		if (ground_entity != null):
			move_vel.y = 0.0
		check_falling()
	
	if ((m_old_water_level == WATERLEVEL.NONE && water_level != WATERLEVEL.NONE) || (m_old_water_level != WATERLEVEL.NONE && water_level == WATERLEVEL.NONE)):
		pass # TODO: PlaySwimSound()
		# player->Splash()

func ground_move():
	var b:Basis = Basis(Quaternion.from_euler(move_local_viewangles))
	var forward:Vector3 = -b.z
	var right:Vector3 = b.x
	#var up:Vector3 = b.y

	var oldground:PhysicsBody3D = ground_entity

	var fmove:float = control_vec.z
	var smove:float = control_vec.x

	if (forward.y != 0):
		forward.y = 0
		forward = forward.normalized()

	if (right.y != 0):
		right.y = 0
		right = right.normalized()

	var wishvel:Vector3 = Vector3(
		right.x*smove + forward.x*fmove,
		0,
		right.z*smove + forward.z*fmove
	)
	var wishdir:Vector3 = wishvel.normalized()
	var wishspeed:float = wishvel.length()

	if (!is_zero_approx(wishspeed) && (wishspeed > max_speed)):
		wishvel = wishvel * (max_speed/wishspeed)
		wishspeed = max_speed

	move_vel.y = 0
	accelerate(wishdir, wishspeed, s_accelerate)
	move_vel.y = 0

	move_vel += m_base_vel

	if (move_vel.length() < 1.0): 
		move_vel = Vector3.ZERO # Now pull the base velocity back out.
		move_vel -= m_base_vel #  Base velocity is set if you are on a moving object, like a conveyor (or maybe another monster?)
		return

	var dest:Vector3 = move_global_origin + move_vel*frametime
	dest.y = move_global_origin.y

	var pm:Trace = trace_player_bbox(move_global_origin, dest, player_solid_mask(), -1) #COLLISION_GROUP_PLAYER_MOVEMENT

	# If we made it all the way, then copy trace end as new player position.
	output_wish_vel += wishdir * wishspeed

	if (!pm.is_colliding || pm.fraction == 1):
		move_global_origin = pm.endpos
		move_vel -= m_base_vel
		stay_on_ground()
		return

	if ((oldground == null) &&( water_level == WATERLEVEL.NONE)):
		move_vel -= m_base_vel
		return

	if (water_jump_time != 0):
		move_vel -= m_base_vel
		return

	step_move(dest, pm)
	move_vel -= m_base_vel
	stay_on_ground()

func accelerate(wishdir:Vector3, wishspeed:float, accel:float):
	if (!alive || (water_jump_time != 0)):
		return
	
	var currentspeed:float = move_vel.dot(wishdir)
	var addspeed:float = wishspeed - currentspeed
	if (addspeed <= 0):
		return
	
	var accelspeed = accel*frametime*wishspeed*surface_friction
	if (accelspeed > addspeed):
		accelspeed = addspeed
	
	move_vel +=  wishdir*accelspeed

func air_move():
	var b:Basis = Basis(Quaternion.from_euler(move_local_viewangles))
	var forward:Vector3 = -b.z
	var right:Vector3 = b.x
	# var up:Vector3 = b.y
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	
	var fmove:float = control_vec.z
	var smove:float = control_vec.x
	
	var wishvel:Vector3 = Vector3(
		right.x*smove + forward.x*fmove,
		0,
		right.z*smove + forward.z*fmove
	)
	var wishdir:Vector3 = wishvel.normalized()
	var wishspeed:float = wishvel.length()
	
	if (!is_zero_approx(wishspeed) && (wishspeed > max_speed)):
		wishvel = wishvel * (max_speed/wishspeed)
		wishspeed = max_speed
	
	air_accelerate( wishdir, wishspeed, s_air_accelerate)
	
	move_vel += m_base_vel
	try_move()
	move_vel -= m_base_vel
	
func air_accelerate(wishdir:Vector3, wishspeed:float, accel:float):
	var w_spd:float = wishspeed
	
	if (!alive || (water_jump_time != 0)):
		return
	
	if (w_spd > air_speed_cap):
		w_spd = air_speed_cap

	var currentspeed:float = move_vel.dot(wishdir)
	var addspeed = w_spd - currentspeed
	if (addspeed<= 0):
		return
		
	var accelspeed:float = accel*wishspeed*frametime*surface_friction
	if (accelspeed > addspeed): accelspeed = addspeed
	
	move_vel +=  wishdir*accelspeed
	output_wish_vel +=  wishdir*accelspeed

## Try to keep a walking player on the ground when running down slopes etc
func stay_on_ground():
	var start:Vector3 = move_global_origin
	var end:Vector3 = move_global_origin
	start.y += 2;
	end.y -= max_step_height

	# See how far up we can go without getting stuck
	var trace:Trace = trace_player_bbox( move_global_origin, start, player_solid_mask(), -1 ); # COLLISION_GROUP_PLAYER_MOVEMENT
	start = trace.endpos;
	# using trace.startsolid is unreliable here, it doesn't get set when tracing bounding box vs. terrain

	# Now trace down from a known safe position
	trace = trace_player_bbox( start, end, player_solid_mask(), -1 ); # COLLISION_GROUP_PLAYER_MOVEMENT
	# must go somewhere, must hit something, can't be embedded in a solid, can't hit a steep slope that we can't stand on anyway
	if (trace.fraction > 0.0 && trace.fraction < 1.0 && trace.normal.y >= 0.7 && !trace.startsolid):
		#This is incredibly hacky. The real problem is that trace returning that strange value we can't network over.
		if ( absf(move_global_origin.y - trace.endpos.y) > 0.5 * DIST_EPSILON):
			move_global_origin = trace.endpos

const DIST_EPSILON:float = 0.03125*1.33333*HU2M
func step_move(destination:Vector3, trace:Trace):
	var end:Vector3 = destination
	### Try sliding forward both on ground and up 16 pixels. take the move that goes farthest
	var pos:Vector3 = move_global_origin
	var velo:Vector3 = move_vel
	# Slide move down.
	try_move(end, trace)
	# Down results.
	var downpos:Vector3 = move_global_origin
	var downvel:Vector3 = move_vel
	# Reset original values
	move_global_origin = pos
	move_vel = velo
	# move up a stair height
	end = move_global_origin
	if (true): # player->m_Local.m_bAllowAutoMovement
		end.y += max_step_height + DIST_EPSILON
	trace = trace_player_bbox(move_global_origin, end, player_solid_mask(), -1) # COLLISION_GROUP_PLAYER_MOVEMENT
	if ( !trace.startsolid && !trace.allsolid ):
		move_global_origin = trace.endpos
	#slide move up
	try_move()
	end = move_global_origin
	if (true): # player->m_Local.m_bAllowAutoMovement
		end.y -= max_step_height + DIST_EPSILON
	trace = trace_player_bbox(move_global_origin, end, player_solid_mask(), -1) # COLLISION_GROUP_PLAYER_MOVEMENT
	# If we are not on the ground any more then use the original movement attempt.
	if ( trace.normal.y < 0.7 ):
		move_global_origin = downpos
		move_vel = downvel
		var step_dist:float = move_global_origin.y - pos.y
		if ( step_dist > 0.0 ):
			output_step_height += step_dist
		return
	
	# If the trace ended up in empty space, copy the end over to the origin.
	if ( !trace.startsolid && !trace.allsolid ):
		move_global_origin = trace.endpos
	
	# Copy this origin to up.
	var uppos:Vector3 = move_global_origin
	
	# decide which one went farther
	if ( pos.distance_squared_to(downpos) > pos.distance_squared_to(uppos) ):
		move_global_origin = downpos
		move_vel = downvel
	else: # copy y value from slide move
		move_vel.y = downvel.y	
	
	var step_disto:float = move_global_origin.y - pos.y
	if ( step_disto > 0 ):
		output_step_height += step_disto

var sv_stopspeed:float = 100*HU2M
func do_friction():
	var control:float
	var drop:float = 0
	if (water_jump_time != 0):
		return
	
	var speed:float = move_vel.length()
	var newspeed:float
	if (speed < 0.1):
		return
	
	# apply ground friction
	if (ground_entity != null): # On an entity that is the ground
		var f:float = ground_friction * surface_friction

		# Bleed off some speed, but if we have less than the bleed
		#  threshold, bleed the threshold amount.
		control = sv_stopspeed if (speed < sv_stopspeed) else speed
		drop += control*f*frametime
	
	newspeed = speed - drop
	if (newspeed < 0):
		newspeed = 0
	if (newspeed != speed):
		newspeed = newspeed / speed
		move_vel = move_vel*newspeed
	
	output_wish_vel -= (1.0-newspeed)*move_vel

func get_entity_vel(entity:PhysicsBody3D)->Vector3:
	match entity.get_class():
		"ActorBody":
			return (entity as ActorBody).move_vel
		"RigidBody3D":
			return (entity as RigidBody3D).linear_velocity
		"StaticBody3D":
			return (entity as StaticBody3D).constant_linear_velocity
		_:
			return Vector3.ZERO

var PLAYER_MAX_SAFE_FALL_SPEED:float = 580*HU2M #temp
var PLAYER_MIN_BOUNCE_SPEED:float = 200*HU2M #temp
func check_falling():
	if (ground_entity == null || fall_vel <= 0):
		return
	if (alive && fall_vel >= 350): # PLAYER_FALL_PUNCH_THRESHOLD
		var balive:bool = true
		var vol:float = 0.5
		if (water_level > WATERLEVEL.NONE):
			pass #landed in water. all good
		else:
			# Scale it down if we landed on something that's floating...
			#if ( ground_entity.floating ): fall_vel -= PLAYER_LAND_ON_FLOATING_OBJECT

			#
			# They hit the ground.
			#
			if(get_entity_vel(ground_entity).y < 0.0):
				# Player landed on a descending object. Subtract the velocity of the ground entity.
				fall_vel += get_entity_vel(ground_entity).y
				fall_vel = max(0.1, fall_vel)

			if ( fall_vel > PLAYER_MAX_SAFE_FALL_SPEED): # If they hit the ground going this fast they may take damage (and die).
				# balive = MoveHelper( )->PlayerFallingDamage()
				vol = 1.0;
			elif ( fall_vel > PLAYER_MAX_SAFE_FALL_SPEED / 2 ):
				vol = 0.85;
			elif ( fall_vel < PLAYER_MIN_BOUNCE_SPEED ):
				vol = 0;
		
		rough_landing_effects( vol );

		if (balive):
			pass # MoveHelper( )->PlayerSetAnimation( PLAYER_WALK ); # TODO: ANIMATION shit

	# let any subclasses know that the player has landed and how hard
	# OnLand(player->m_Local.m_flFallVelocity);
	
	fall_vel = 0	# Clear the fall velocity so the impact doesn't happen again.

func check_velocity(do_clamp:bool = true):
	# check if move_vel & move_global_origin's values are NaN (prob not necessary) and set them to 0 if so
	if (do_clamp):
		move_vel.x = clamp(move_vel.x, -max_velocity, max_velocity)
		move_vel.y = clamp(move_vel.x, -max_velocity, max_velocity)
		move_vel.z = clamp(move_vel.x, -max_velocity, max_velocity)

const jump_grav_power:float = 160*HU2M	# approx. 21 units. Assert( GetCurrentGravity() == 600.0f );
#const jump_grav_power:float = 268.3281572999747*HU2M 		Assert( GetCurrentGravity() == 800.0f );	
func check_jump_button():
	if (!alive):
		data.last_buttons["jump"] = false
		return false
	
	if (water_jump_time != 0):
		water_jump_time -= frametime
		if (water_jump_time < 0):
			water_jump_time = 0
		return false

	if (water_level >= WATERLEVEL.WAIST):
		set_ground_entity(null)
		#if(water_type == CONTENTS_WATER)    # We move up a certain amount
		#	move_vel.y = 100*HU2M
		#elif (water_type == CONTENTS_SLIME)
		#	move_vel.y = 80*HU2M
		move_vel.y = 100*HU2M
		#if (swim_sound_time <= 0):
		#	swim_sound_time = 1000
		#	play_swim_sound()
		return false
	
	if (ground_entity == null):
		data.last_buttons["jump"] = false
		return false # in air, so no effect


	if (data.last_buttons["jump"]):
		return false	# don't pogo stick

	# Cannot jump will in the unduck transition.
	if ( crouch_inprogress && fully_crouched ):
		return false

	# Still updating the eye position.
	if ( crouchjump_time > 0.0 ):
		return false


	# In the air now.
	set_ground_entity(null)
	
	#play_step_sound( move_global_origin, cur_surfprop, 1.0, true ) # TODO
	
	#MoveHelper()->PlayerSetAnimation( PLAYER_JUMP ); # TODO: Animation System

	var ground_factor:float = 1.0
	if (cur_surfprop):
		ground_factor = cur_surfprop.jump_factor; 

	# Acclerate upward
	# If we are ducking...
	var startz:float = move_vel.y
	if ( crouch_inprogress || fully_crouched ):
		# d = 0.5 * g * t^2		- distance traveled with linear accel
		# t = sqrt(2.0 * 45 / g)	- how long to fall 45 units
		# v = g * t				- velocity at the end (just invert it to jump up that high)
		# v = g * sqrt(2.0 * 45 / g )
		# v^2 = g * g * 2.0 * 45 / g
		# v = sqrt( g * 2.0 * 45 )
		move_vel.y = ground_factor * jump_grav_power;  # 2 * gravity * height
	else:
		move_vel.y += ground_factor * jump_grav_power;  # 2 * gravity * height

	# Add a little forward velocity based on your current forward velocity - if you are not sprinting.
	var vfwd:Vector3
	vfwd.angle_to(move_local_viewangles)

	vfwd.y = 0;
	vfwd = vfwd.normalized()
	
	# We give a certain percentage of the current forward movement as a bonus to the jump speed.  That bonus is clipped
	# to not accumulate over time.
	var speed_boost_perc:float = 0.5 if ( !is_sprinting && !fully_crouched ) else 0.1
	var speed_addition:float = absf( control_vec.x * speed_boost_perc )
	var boost_max_speed:float = max_speed + ( max_speed * speed_boost_perc )
	var new_speed:float = ( speed_addition + length2D(move_vel) )

	# If we're over the maximum, we want to only boost as much as will get us to the goal speed
	if ( new_speed > boost_max_speed ):
		speed_addition -= new_speed - boost_max_speed;

	if ( control_vec.x < 0.0 ):
		speed_addition *= -1.0;

	# Add it on
	move_vel +=  (vfwd * speed_addition)

	finish_gravity()
	

	output_jump_vel.y += move_vel.y - startz;
	output_step_height += 0.15;

	# OnJump(output_jump_vel.y) 	# allow overridden versions to respond to jumping

	# Set jump time.
	jump_time = 0.51
	crouchjumping = true

	#if (uncrouch_on_jump): # Uncrouch when jump occurs
	#	if ( player->GetToggledDuckState() ):
	#		player->ToggleDuck();

	# Flag that we jumped.
	data.last_buttons["jump"] = false	# don't jump again until released
	return true;

func water_jump():
	water_jump_time = clamp(water_jump_time, 0.0, 10.0)
	if water_jump_time == 0: 
		return
	water_jump_time -= frametime
	if (water_jump_time <= 0 || water_level != WATERLEVEL.NONE):
		water_jump_time = 0.0
		water_jump_flag = false
	move_vel.x = water_jump_vel.x
	move_vel.z = water_jump_vel.z

func finish_gravity():
	if (water_jump_time != 0):
		move_vel.y -= gravity_scale * gravity * 0.5 * frametime
		check_velocity()

var sv_bounce:float = 0.0 # sv_bounce : Bounce multiplier for when physically simulated objects collide with other objects.
var max_safe_fall_speed:float = 500*HU2M # PLAYER_MAX_SAFE_FALL_SPEED = 500 hu
func try_move(pFirstDest:Vector3 = Vector3.INF, pFirstTrace:Trace = null)-> int:
	#var bumpcount:int = 0
	var numbumps:int = 4
	var numplanes:int = 0
	var blocked:int = 0

	var d:float = 0.0
	var time_left:float = 0.0
	var allFraction:float = 0.0

	var dir:Vector3 = Vector3.ZERO
	var planes:Array[Vector3] = []
	var primal_velocity:Vector3 = Vector3.ZERO
	var original_velocity:Vector3 = Vector3.ZERO
	var new_velocity:Vector3 = Vector3.ZERO
	var end:Vector3
	var pm:Trace

	for bumpcount in range(numbumps):
		if is_zero_approx(move_vel.length()):
			break
		# Assume we can move all the way from the current origin to the end point.
		end = move_global_origin+move_vel*time_left

		# See if we can make it from origin to end point.
		# If their velocity Z is 0, then we can avoid an extra trace here during WalkMove.
		if (end == pFirstDest):
			pm = pFirstTrace;
		else:
			pm = trace_player_bbox( move_global_origin, end, player_solid_mask(), -1 ) # COLLISION_GROUP_PLAYER_MOVEMENT

		allFraction += pm.fraction

		# If we started in a solid object, or we were in solid space
		#  the whole way, zero out our velocity and return that we
		#  are blocked by floor and wall.
		if (false): # ACTUALLY pm.allsolid
			# entity is trapped in another solid
			move_vel = Vector3.ZERO
			return 4

		# If we moved some portion of the total distance, then
		#  copy the end position into the pmove.origin and 
		#  zero the plane counter.
		if( pm.fraction > 0 ):
			if ( numbumps > 0 && pm.fraction == 1 ):
				# There's a precision issue with terrain tracing that can cause a swept box to successfully trace
				# when the end position is stuck in the triangle.  Re-run the test with an uswept box to catch that
				# case until the bug is fixed.
				# If we detect getting stuck, don't allow the movement
				var stuck:Trace = trace_player_bbox( pm.endpos, pm.endpos, player_solid_mask(), -1 ) # COLLISION_GROUP_PLAYER_MOVEMENT
				if ( stuck.startsolid or stuck.fraction != 1.0 ): # if ( stuck.startsolid or stuck.fraction != 1.0 ):
					#Msg( "Player will become stuck!!!\n" );
					move_vel = Vector3.ZERO
					break

			# actually covered some distance
			move_global_origin = pm.endpos
			original_velocity = move_vel
			numplanes = 0

		# If we covered the entire distance, we are done
		#  and can return.
		if (pm.fraction == 1):
			break	# moved the entire distance

		# Save entity that blocked us (since fraction was < 1.0) for contact
		# Add it if it's not already in the list!!!
		
		# move_helper.add_touched( pm, move_vel )

		# If the plane we hit has a high z component in the normal, then
		#  it's probably a floor
		if (pm.normal.y > 0.7):
			blocked |= 1		# floor
		# If the plane has a zero z component in the normal, then it's a 
		#  step or wall
		if (!pm.normal.y):
			blocked |= 2		# step / wall

		# Reduce amount of m_flFrameTime left by total time left * fraction
		#  that we covered.
		time_left -= time_left * pm.fraction;

		# Did we run out of planes to clip against?
		if (numplanes >= 5):
			# this shouldn't really happen
			#  Stop our movement if so.
			move_vel = Vector3.ZERO
			#Con_DPrintf("Too many planes 4\n");
			break

		# Set up next clipping plane
		planes[numplanes] = pm.normal
		numplanes += 1

		# modify original_velocity so it parallels all of the clip planes

		# reflect player velocity 
		# Only give this a try for first impact plane because you can get yourself stuck in an acute corner by jumping in place
		#  and pressing forward and nobody was really using this bounce/reflection feature anyway...
		if (numplanes == 1 and movetype == MOVETYPE.WALK and ground_entity == null):
			for i in range(numplanes):
				if ( planes[i].y > 0.7 ):
					# floor or slope
					new_velocity = clip_velocity( original_velocity, planes[i], 1 ).out
					original_velocity = new_velocity
				else:
					new_velocity = clip_velocity( original_velocity, planes[i], 1.0 + sv_bounce * (1 - surface_friction) ).out
					move_vel = new_velocity
			original_velocity = new_velocity
		else:
			var ie = 0
			for i in range(numplanes):
				ie += 1
				move_vel = clip_velocity( original_velocity, planes[i], 1).out

				var jay = 0
				for j in range(numplanes):
					jay += 1
					if (j != i):
						# Are we now moving against this plane?
						if (move_vel.dot(planes[j]) < 0):

							break	# not ok
				if (jay == numplanes):  # Didn't have to clip, so we're ok
					break
			
			# Did we go all the way through plane set
			if (ie != numplanes):
				# go along this plane
				# pmove.velocity is set in clipping call, no need to set again.
				pass
			else:
				# go along the crease
				if (numplanes != 2):
					move_vel = Vector3.ZERO
					break
				dir = planes[0].cross(planes[1])
				dir = dir.normalized()
				d = dir.dot(move_vel);
				move_vel = dir * d

			#
			# if original velocity is against the original velocity, stop dead
			# to avoid tiny occilations in sloping corners
			#
			d = move_vel.dot(primal_velocity);
			if (d <= 0):
				#Con_DPrintf("Back\n");
				move_vel = Vector3.ZERO
				break;

	if ( allFraction == 0 ):
		move_vel = Vector3.ZERO

	# Check if they slammed into a wall
	
	var lateral_stopping_amount:float = length2D(primal_velocity) - length2D(move_vel)
	var slam_vol:float = 0.0
	if (lateral_stopping_amount > max_safe_fall_speed*2): slam_vol = 1.0
	elif (lateral_stopping_amount > max_safe_fall_speed): slam_vol = 0.85
	rough_landing_effects(slam_vol)

	return blocked

func trace_player_bbox(start:Vector3, end:Vector3, maskLayers:Array[int] = [-1], group:int = -1)-> Trace:
	var shape:BoxShape3D = BoxShape3D.new()
	#var startoffset:Vector3 = (maxs + mins)*0.5
	#var mstart:Vector3 = start + startoffset
	shape.size = player_maxs - player_mins # extents
	LineCast.update_space_state_with(self)
	return LineCast.shape_cast(start, end, shape, LineCast.calc_overall_mask(maskLayers), [_playerCollider], group)[0]

var MASK_PLAYERSOLID_BRUSHONLY:Array[int] = [-1] #TEMP
var MASK_PLAYERSOLID:Array[int] = [-1]	#TEMP
func player_solid_mask(brushOnly:bool = false)->Array[int]:
	return MASK_PLAYERSOLID_BRUSHONLY if ( brushOnly ) else MASK_PLAYERSOLID;

func clip_velocity(input:Vector3, normal:Vector3, overbounce:float )->Dictionary:
	var backoff:float = 0.0
	var change:float = 0.0
	var angle:float = normal.y
	var out:Vector3 = Vector3.ZERO

	var blocked:int = 0x00;         # Assume unblocked.
	if (angle > 0):			# If the plane that is blocking us has a positive z component, then assume it's a floor.
		blocked |= 0x01;	# 
	if (!angle):		# If the plane has no Z, it is vertical (wall/step)
		blocked |= 0x02;	# 
	
	# Determine how far along plane to slide based on incoming direction.
	backoff = input.dot(normal) * overbounce;

	for i in range(3):
		change = normal[i]*backoff;
		out[i] = input[i] - change;
	
	# iterate once to make sure we aren't still moving through the plane
	var adjust:float = out.dot(normal)
	if( adjust < 0.0 ):
		out -= ( normal * adjust )

	# Return blocking flags.
	return {"out": out, "blocked": blocked}

func length2D(vec:Vector3)->float:
	return sqrt(vec.x*vec.x + vec.z*vec.z)

var predicted_global_origin:Vector3 = Vector3.ZERO
func finish_move():
	global_origin = move_global_origin
	predicted_global_origin = move_global_origin
	vel = move_vel
	
	var pitch:float = move_angles.x
	if (pitch > 180): pitch -= 360
	pitch = clamp(pitch, -90, 90)
	move_angles.x = pitch
	cam.rotation_degrees.x = pitch
	
	# TODO: CONSTRAINT SHIT

func rough_landing_effects(vol:float = 0.0):
	if (vol > 0.0):
		pass	# TODO

func post_think():
	# if ( !g_fGameOver && !m_iPlayerLocked )
	if (alive):
		#TODO: Set correct collision bounds for crouch
		# if (use_entity != null): # handle controlling entity (this is code for stationary guns)
		if (is_grounded):
			if (fall_vel > 64*HU2M):
				#CSoundEnt::InsertSound ( SOUND_PLAYER, GetAbsOrigin(), m_Local.m_flFallVelocity, 0.2, this );
				pass # Msg( "fall %f\n", m_Local.m_flFallVelocity );
			fall_vel = 0
		# If he's in a vehicle, sit down
		if (false): # TODO: if IsInAVehicle():
			pass # TODO: SetAnimation( PLAYER_IN_VEHICLE );
		elif (is_zero_approx(vel.z) && is_zero_approx(vel.x)):
			pass # TODO: SetAnimation( PLAYER_IDLE )
		elif ((!is_zero_approx(vel.z) || !is_zero_approx(vel.x)) && is_grounded):
			pass # TODO: SetAnimation( PLAYER_WALK )
		elif (water_level > WATERLEVEL.FEET):
			pass # TODO: SetAnimation( PLAYER_WALK )
	# Don't allow bogus sequence on player
	#	if ( GetSequence() == -1 ):
	#		SetSequence( 0 )
	#if ( m_bForceOrigin ):
	#		SetLocalOrigin( m_vForcedOrigin );
	#		SetLocalAngles( m_Local.m_vecPunchAngle );
	#		m_Local.m_vecPunchAngle = RandomAngle( -25, 25 );
	#		m_Local.m_vecPunchAngleVel.Init();

var old_origin:Vector3 = Vector3.ZERO
func post_think_physics():
	var newpos:Vector3 = self.global_transform.origin
	var dt:float = frametime
	if ( dt <= 0 ||   dt > 0.1):
		dt = 0.1
	
	var phys_ground:RigidBody3D = (null if (ground_entity.get_class() == "StaticBody3D") else ground_entity) if (ground_entity != null) else null
	
	if (phys_ground && touched_phys_object && output_step_height <= 0.0 && is_grounded):
		newpos = old_origin + dt*output_wish_vel
		newpos = self.global_transform.origin*0.5 + newpos*0.5
	
	# var collision_state:int = 0 # VPHYS_WALK
	# if (fully_crouched): collision_state = 1 # VPHYS_CROUCH
	# if ( collisionState != m_vphysicsCollisionState ):
	#	SetVCollisionState( GetAbsOrigin(), GetAbsVelocity(), collisionState );
	
	if !(touched_phys_object || phys_ground):	# if not standing on prop
		var maxspeed:float = max_speed if (max_speed > 0.0) else SPEEDLIMIT["sprint"]
		output_wish_vel = Vector3(maxspeed,maxspeed,maxspeed)
	
	if (output_step_height > 0.1):
		if (output_step_height > 4.0):
			new_phys_pos = global_origin
		else:
			var pos:Vector3 = new_phys_pos
			var end:Vector3 = pos
			end.y += output_step_height
			var trace:Trace = LineCast.ray_cast(pos, end, LineCast.calc_overall_mask(MASK_PLAYERSOLID), [_playerCollider], -1) # COLLISION_GROUP_PLAYER_MOVEMENT
			if (trace.did_hit()):
				output_step_height = trace.endpos.y - pos.y
			# TODO: m_pPhysicsController->StepUp(output_step_height)
		# TODO: m_pPhysicsController->Jump()
	output_step_height = 0
	
	new_phys_pos = newpos
	new_phys_vel = output_wish_vel
	
	old_origin = global_origin

@onready var new_phys_pos:Vector3 = self.global_transform.origin
@onready var new_phys_vel:Vector3 = vel
func _integrate_forces(state: PhysicsDirectBodyState3D):
	# If we've got a moveparent, we must simulate that first.
	#if (move_parent):
	#	pass # TODO ???
	#var rot = Quaternion().from_euler(move_angles) * state.transform.basis.get_rotation_quaternion()
	#state.transform.origin = new_phys_pos
	state.linear_velocity = new_phys_vel
	
	#var facing:Vector3 = Vector3(move_angles.dot(-self.global_transform.basis.z), move_angles.dot(self.global_transform.basis.y.cross(-self.global_transform.basis.z)), 0.0).normalized()
	#state.transform.basis = Basis.IDENTITY.rotated(Vector3.UP, Vector3.UP.angle_to(facing))

func physics_shadow_update():
	pass

func is_bit_enabled(mask, index):
	return mask & (1 << index) != 0
func enable_bit(mask, index):
	return mask | (1 << index)
func disable_bit(mask, index):
	return mask & ~(1 << index)
