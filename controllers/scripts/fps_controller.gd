class_name Player 
extends CharacterBody3D

@export var JUMP_VELOCITY : float = 4.5
@export var MOUSE_SENSITIVITY : float = 0.5
@export var TILT_LOWER_LIMIT := deg_to_rad(-90.0)
@export var TILT_UPPER_LIMIT := deg_to_rad(90.0)
@onready var CAMERA_CONTROLLER : Camera3D = $CameraController/Camera3D
@onready var ANIMATIONPLAYER : AnimationPlayer = $AnimationPlayer
@onready var CROUCH_SHAPECAST : Node3D = %ShapeCast3D
@onready var weaponController : WeaponController = $CameraController/Camera3D/WeaponRig/Weapon
@onready var hud = $UserInterface

var _mouse_input : bool = false
var _rotation_input : float
var _tilt_input : float
var _mouse_rotation : Vector3
var _player_rotation : Vector3
var _camera_rotation : Vector3
var isCrouching : bool = false

var currentRotation : float
var cameraOffset : Vector3

# Get the gravity from the project settings to be synced with RigidBody nodes.
#var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var gravity = 12
var stamina = 100

func _enter_tree():
	print(name)
	set_multiplayer_authority(str(name).to_int())


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	_mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if _mouse_input:
		_rotation_input = -event.relative.x * MOUSE_SENSITIVITY
		_tilt_input = -event.relative.y * MOUSE_SENSITIVITY
		
		
func _input(event):
	if not is_multiplayer_authority(): return
	if event.is_action_pressed("exit"):
		get_tree().quit()

func _update_camera(delta):
	if not is_multiplayer_authority(): return
	# Rotates camera using euler rotation
	_mouse_rotation.x += _tilt_input * delta
	_mouse_rotation.x = clamp(_mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
	_mouse_rotation.y += _rotation_input * delta
	
	_player_rotation = Vector3(0.0,_mouse_rotation.y,0.0)
	_camera_rotation = Vector3(_mouse_rotation.x,0.0,0.0)

	CAMERA_CONTROLLER.transform.basis = Basis.from_euler(_camera_rotation)
	global_transform.basis = Basis.from_euler(_player_rotation)
	
	CAMERA_CONTROLLER.rotation.z = 0.0

	_rotation_input = 0.0
	_tilt_input = 0.0

func _ready():
	if not is_multiplayer_authority(): 
		CAMERA_CONTROLLER.current = false
		return
	CAMERA_CONTROLLER.make_current()
	position = get_node("/root/World/Spawnpoint").position
	velocity = Vector3(0, 0, 0)
	Global.player = self
	Global.playerCamera = CAMERA_CONTROLLER
	# Get mouse input
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#Prevents player from activating crouch cast
	CROUCH_SHAPECAST.add_exception($".")

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	# Update camera movement based on mouse movement
	_update_camera(delta)
	
	if stamina < 101:
		stamina += 16.5 * delta
	
	
	## Add the gravity.
	#if not is_on_floor():
		#velocity.y -= gravity * delta
	CAMERA_CONTROLLER.rotation = lerp(CAMERA_CONTROLLER.rotation, CAMERA_CONTROLLER.rotation + cameraOffset, 0.1)
	cameraOffset = lerp(cameraOffset, Vector3(0,0,0), 0.05)
	
	
func updateGravity(delta) -> void:
	if not is_multiplayer_authority(): return
	velocity.y -= gravity * delta
	

func updateInput(speed: float, acceleration: float, deceleration: float) -> void:
	if not is_multiplayer_authority(): return
		# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	
	if direction:
		velocity.x = lerp(velocity.x,direction.x * speed, acceleration)
		velocity.z = lerp(velocity.z,direction.z * speed, acceleration)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration)
		velocity.z = move_toward(velocity.z, 0, deceleration)

func updateVelocity() -> void:
	if not is_multiplayer_authority(): return
	move_and_slide()

@rpc("any_peer")
func take_damage(damage, type):
	Global.playerHealth -= damage
	Global.updateHealth()
	if Global.playerHealth <= 0:
		position = get_node("/root/World/Spawnpoint").position
		velocity = Vector3(0, 0, 0)
		Global.playerHealth = 100
