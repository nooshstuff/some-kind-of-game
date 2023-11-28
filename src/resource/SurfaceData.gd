class_name SurfaceMaterial
extends PhysicsMaterial

### PHYSICS
#@export var friction:float = 0.8
#@export var elasticity:float = 0.25
@export var density:float = 2000.0		# physical density (in kg / m^3)
@export var dampening:float	= 0.0	# physical drag on an object when in contact with this surface (0 - x, 0 none to x a lot).

### SOUND PARAMETERS
@export var reflectivity:float = 0.66		# like elasticity, but how much sound should be reflected by this surface
@export var hardness_factor:float = 1.0	# like elasticity, but only affects impact sound choices
@export var roughness_factor:float = 1.0	# like friction, but only affects scrape sound choices
# audio thresholds
@export var rough_threshold:float = 0.5		# surface roughness > this causes "rough" scrapes, < this causes "smooth" scrapes
@export var hard_threshold:float = 0.5		# surface hardness > this causes "hard" impacts, < this causes "soft" impacts
@export var hard_vel_threshold:float = 0.0	# collision velocity > this causes "hard" impacts, < this causes "soft" impacts
											# NOTE: Hard impacts must meet both hardnessFactor AND velocity thresholds
											# velocity threshhold is mostly unused except by the car and flesh (both =500)

### SURFACE SOUNDS
@export var sounds:SurfaceSounds

### GAME
@export var max_speed_factor:float = 1.0		# Modulates player max speed when walking on this surface
@export var jump_factor:float = 1.0			# Indicates how much higher the player should jump when on the surface
@export var material:StringName = &"CONCRETE"		# Material ID
@export var climbable:bool = false			# Indicates whether or not the player is on a ladder.

# https://developer.valvesoftware.com/wiki/List_of_CS:GO_Surface_Types more advanced system here