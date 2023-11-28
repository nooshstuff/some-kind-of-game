class_name PlayerController
extends Node

@export var actor:ActorBody
@onready var FPCam:Camera3D = actor.get_node("Pivot/FirstPerson")
@export var lookSens:float = 0.3
var turnfactor:float = 0

func _unhandled_input(event:InputEvent):
	if (event is InputEventMouseMotion):
		actor.pivot.rotate_y(deg_to_rad(lookSens * -event.relative.x))
		FPCam.rotation.x = deg_to_rad(clamp(rad_to_deg(FPCam.rotation.x) + lookSens * -event.relative.y, -90, 90))

func _process(_delta):
	if Input.is_action_just_pressed("toggle_mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)\
			else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	var inp = actor.input_vec.normalized()
	var direction = (actor.pivot.transform.basis * Vector3(inp.y, 0, inp.x))
	if direction:
		actor.vel.x = direction.x * actor.max_speed * delta
		actor.vel.z = direction.z * actor.max_speed * delta
	else:
		actor.vel.x = move_toward(actor.vel.x, 0, actor.max_speed * delta)
		actor.vel.z = move_toward(actor.vel.z, 0, actor.max_speed * delta)
		
	actor.move_and_collide(actor.vel, false, 0.001, true)

