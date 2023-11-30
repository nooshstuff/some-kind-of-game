class_name PlayerController
extends Node

@export var actor:ActorBody
@onready var FPCam:Camera3D = actor.get_node("Pivot/FirstPerson")
@export var lookSens:float = 0.3
var turnfactor:float = 0

func _unhandled_input(event:InputEvent):
	if (event is InputEventMouseMotion):
		pass #actor.pivot.rotate_y(deg_to_rad(lookSens * -event.relative.x))
		#FPCam.rotation.x = deg_to_rad(clamp(rad_to_deg(FPCam.rotation.x) + lookSens * -event.relative.y, -90, 90))

func _process(_delta):
	if Input.is_action_just_pressed("toggle_mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)\
			else Input.MOUSE_MODE_CAPTURED

#func _physics_process(delta):
#	pass
