class_name JumpingPlayerState

extends PlayerMovementState

@export var speed: float = 8.0
@export var acceleration : float = 0.1
@export var deceleration : float = 0.25
@export var jumpVelocity : float = 6
@export var inputMultiplier : float = 0.01

# Called when the node enters the scene tree for the first time.
func enter(previousState) -> void:
	PLAYER.velocity.y += jumpVelocity
	animation.pause()

func update(delta):
	PLAYER.updateGravity(delta)
	#Can be used for boost jumping (MOVEMENT GAME YEAHHH)
	PLAYER.updateInput(PLAYER.velocity.length() + speed * inputMultiplier, acceleration, deceleration)
	PLAYER.updateVelocity()
	weapon.sway_weapon(delta, false)
	
	if PLAYER.velocity.y < -3.0 and !PLAYER.is_on_floor():
		transition.emit("FallingPlayerState")
	
	if PLAYER.is_on_floor():
		transition.emit("IdlePlayerState")
		
	if Input.is_action_just_pressed("crouch") and !PLAYER.is_on_floor():
		transition.emit("SlammingPlayerState")
		
	if Input.is_action_just_pressed("shoot"):
		weapon.shoot()

	if Input.is_action_just_pressed("sprint") and PLAYER.stamina >= 33:
		transition.emit("DashingPlayerState")
