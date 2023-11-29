class_name UserData

### USERCMD
var forwardmove:float = 0.0:
	get: return Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
var sidemove:float = 0.0:
	get: return Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
var upmove:float = 0.0:
	get: return 0.0
var viewangles:Vector3 = Vector3.ZERO
var buttons:Dictionary = {}	# every control input
var weaponselect:int = 0;
var weaponsubtype:int = 0;
var mousedx:int = 0;
var mousedy:int = 0;

var last_buttons:Dictionary = {}

func reset(gameplay_inert:bool = false):	## gameplay_inert = true if you only want to affect gameplay values
	forwardmove = 0.0
	sidemove = 0.0
	upmove = 0.0
	viewangles = Vector3.ZERO
	buttons = {}
	if (!gameplay_inert):
		weaponselect = 0
		weaponsubtype = 0
		mousedx = 0
		mousedy = 0

func check():
	last_buttons = buttons.duplicate()

	buttons["jump"] = Input.is_action_pressed("move_jump")
	buttons["jump_pressed"] = Input.is_action_just_pressed("move_jump")
	buttons["jump_released"] = Input.is_action_just_released("move_jump")