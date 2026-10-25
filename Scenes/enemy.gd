#Sandbag is used for testing weapon damage at the moment, might also be cannibalised for sentry gun code down the line
#its also just an excuse for me to not have to work on anything actually important
#Good Job Miranda!!
extends CharacterBody3D
var sandHealth = 100
@onready var healthLabel = $Label3D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(_delta):
	if sandHealth < 100:
		sandHealth += 1
	healthLabel.text = str(sandHealth)

func take_enemy_damage(ammount, type):
	sandHealth -= ammount
	
