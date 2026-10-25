class_name FallingPlayerState 

extends PlayerMovementState

@export var speed: float = 3.0
@export var acceleration: float = 0.1
@export var deceleration: float = 0.1
var updatedSpeed = 0.0

func enter(previous_state) -> void:
	animation.pause()
	updatedSpeed = PLAYER.velocity.length()

func exit() -> void:
	pass

func update(delta: float) -> void:
	PLAYER.updateGravity(delta)
	PLAYER.updateInput(updatedSpeed / 1.25, acceleration, deceleration)
	PLAYER.updateVelocity()
	weapon.sway_weapon(delta, false)

	if PLAYER.is_on_floor():
		transition.emit("IdlePlayerState")

	if Input.is_action_just_pressed("shoot"):
		weapon.shoot()
