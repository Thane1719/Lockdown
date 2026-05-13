extends CharacterBody2D


#const SPEED = 300.0
@export var SPEED: float = 400.0
const JUMP_VELOCITY = -400.0
var screen_size: Vector2


func ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	screen_size = get_viewport_rect().size


func _physics_process(delta: float) -> void:
	var direction = Input.get_vector("left", "right", "forward", "backward")
	velocity = direction * SPEED
	if direction:
		velocity = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	move_and_slide()

func die(): 
	queue_free()
