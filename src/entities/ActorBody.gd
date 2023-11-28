class_name ActorBody
extends RigidBody3D
@onready var pivot = get_node("Pivot")
const HU2M = 0.01905 	# 1 hu = 0.01905 m

### CONTROL
var data:UserData = UserData.new()
var buttons:Dictionary = {}

var input_vec:Vector3 = Vector3.ZERO

### STATE
var accel:Vector3 = Vector3.ZERO
var vel:Vector3 = Vector3.ZERO
func get_loc() -> Vector3:
	return self.global_transform.origin
var view_angles:Vector3 = Vector3.ZERO

var is_grounded:bool = false
var is_moving:bool = false:
	get: return !vel.is_zero_approx()
var is_crouching:bool = false
var is_slowing:bool = false
var is_sprinting:bool = false

var current_surface:SurfaceMaterial

var max_speed:float = 320*HU2M
# max accel?

### COLLISION BODY
@export var base_height:float = 72*HU2M
@export var base_cam_height:float = 64*HU2M
@export var crouch_height:float = 36*HU2M
@export var crouch_cam_height:float = 28*HU2M

@export var pickup_range:float = 9*HU2M # from collision hull, 25hu from center
@export var use_range:float = 82*HU2M 


### HORIZONTAL MOVEMENT
var SPEEDLIMIT:Dictionary = {
	"walk" = 150*HU2M,	# The target ground speed when walking slowly.
	"base" = 190*HU2M,	# The target ground speed when running.
	"sprint" = 320*HU2M,	# The target ground speed when sprinting.
}
@export var acceleration_threshold:float = 450*HU2M

@export var crouch_speed_mod:float = 0.33333333
@export var backward_speed_mod:float = 0.90

@export var ground_friction:float = 4.0 

# CROUCHING
var crouch_frame_tolerated:bool = false; # Wait a frame before crouch speed.
var crouch_inprogress:bool = false; # If in the crouching transition
var fully_crouched:bool = false # if fully crouched
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

func _physics_process(_delta: float):
	# TODO: apply forced button changes to ucmd
	buttons = data.buttons.duplicate()

	# do weapon selection

	prethink()

	setup_movement()

	# PROCESS MOVEMENT	# TODO: run vehicle movement instead of this if mounted

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

var drive_input_vec:Vector3 = Vector3.ZERO
var client_max_speed:float = max_speed
func setup_movement():
	#get moveparent
	# if no moveparent
		#world view angles = local view angles
	# else
		#maths
	if (false): # if controlling vehicle or other
		drive_input_vec = input_vec
		input_vec = Vector3.ZERO
	else:
		input_vec.x = data.forwardmove
		input_vec.z = data.sidemove
		input_vec.y = data.upmove
	
	client_max_speed = max_speed




func movement():
	check_parameters()

	# etc. etc.

	# MOVETYPE -> FULL WALK MOVE (or ladder. whatever)

## Check Movement Parameters
func check_parameters():
	var spd:float = input_vec.length_squared()

	#client maxspeed compare thing

	var speed_factor:float = 1.0
	if current_surface:
		speed_factor = current_surface.max_speed_factor
	
	var constraint_speed_factor:float = compute_constraint_speed_factor()
	if (constraint_speed_factor < speed_factor):
		speed_factor = constraint_speed_factor
	
	if ((spd != 0.0) && (spd > max_speed*max_speed)):
		var spd_ratio:float = max_speed / sqrt(spd)
		input_vec.x *= spd_ratio
		input_vec.y *= spd_ratio
		input_vec.z *= spd_ratio

	if (false): # if frozen or on train or dead
		input_vec = Vector3.ZERO

	# DECAY PUNCH ANGLE

	# PROCESS ANGLES

	# SET DEAD VIEW OFFSET


func compute_constraint_speed_factor() -> float:
	return 1.0 # TODO


func _integrate_forces(state: PhysicsDirectBodyState3D):
	#state.transform.basis = Basis(rot)
	state.linear_velocity = vel # + curPlatVel
