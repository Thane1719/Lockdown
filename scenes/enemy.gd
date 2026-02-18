#Sandbag is used for testing weapon damage at the moment, might also be cannibalised for sentry gun code down the line
#its also just an excuse for me to not have to work on anything actually important
extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
var SPEED = 3.0
const JUMP_VELOCITY = 4.5
var sandHealth = 0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func update_target_location (target_location):
	nav_agent.set_target_position(target_location)

func _physics_process(delta):
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	#look_at(next_location) # Enemy will turn to face player
	$Label3D.text = str(sandHealth)
	# Vector Maths
	var new_veloicty = (next_location-current_location).normalized() * SPEED

	velocity = new_veloicty
	
	move_and_slide()

func take_enemy_damage(ammount, type):
	print("mrsandbag has been hit by " + str(type) + " with damage " + str(ammount))
	sandHealth -= ammount
	
