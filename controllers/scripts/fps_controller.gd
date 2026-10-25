class_name Player
extends CharacterBody3D

@export var JUMP_VELOCITY : float = 4.5

@export var controllerSensitivity = 2
@export var TILT_LOWER_LIMIT := deg_to_rad(-90.0)
@export var TILT_UPPER_LIMIT := deg_to_rad(90.0)
var loadedTrap = null
var trapInstance = null
var hasInstancedTrap = false
@export_file("*.tscn") var currentHeldTrap = "":
	set(value):
		currentHeldTrap = value
		if currentHeldTrap: 
			loadedTrap = load(currentHeldTrap)

@onready var CAMERA_CONTROLLER : Camera3D = $CameraController/Camera3D
@onready var ANIMATIONPLAYER : AnimationPlayer = $AnimationPlayer
@onready var CROUCH_SHAPECAST : Node3D = %ShapeCast3D
@onready var weaponController : WeaponController = $CameraController/Camera3D/WeaponRig/Weapon
@onready var animationPlayer = $"Level Fade"
@onready var playerlabelname = $"Name Label"
@onready var stateMachine = $PlayerStateMachine
@onready var copModel = $"CollisionShape3D/Cop model"
@onready var robberModel = $"CollisionShape3D/Robber model"
@onready var damageVignette = $CameraController/Camera3D/CanvasLayer/damageVignette
@onready var interactionCast = %trapPlaceCast
@onready var trapPlaceCast = %trapPlaceCast
@onready var healDelayTimer = $"Heal Delay"

var MOUSE_SENSITIVITY : float = 0.125
var _mouse_input : bool = false
var _rotation_input : float
var _tilt_input : float
var _mouse_rotation : Vector3
var _player_rotation : Vector3
var _camera_rotation : Vector3
var isCrouching : bool = false

var currentRotation : float
var cameraOffset : Vector3
var spawnpoint

var gravity = 12
var stamina = 100

var is_interacting: bool = false
var autoHealing = false

var mapFiles = [
	"res://Maps/OverUnder.tscn",
	"res://Maps/gallery.tscn"
]

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():

	if not is_multiplayer_authority():
		CAMERA_CONTROLLER.current = false
		return

	CAMERA_CONTROLLER.make_current()

	velocity = Vector3.ZERO

	Global.player = self
	Global.playerCamera = CAMERA_CONTROLLER

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	CROUCH_SHAPECAST.add_exception(self)
	Global.isMainMenu = false
	playerlabelname.text = str(multiplayer.get_unique_id())
	weaponGlobal.weaponAmmoInventory = [[0,0], [0,0]]
	weaponGlobal.weaponInventory = ["res://Weapons/Empty Weapon.tres","res://Weapons/Empty Weapon.tres"]
	Global.weaponManager.loadWeapon()
	Global.weaponManager.addWeapon("res://Weapons/Blaster.tres", true, 0, 0)


func _unhandled_input(event: InputEvent) -> void:

	if not is_multiplayer_authority():
		return

	_mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED

	if _mouse_input:
		_rotation_input = -event.relative.x * MOUSE_SENSITIVITY
		_tilt_input = -event.relative.y * MOUSE_SENSITIVITY

func _input(event):

	if not is_multiplayer_authority():
		return
	
	if event.is_action_pressed("debug"):
		if get_tree().current_scene.scene_file_path == "res://Scenes/lobby.tscn":
			var pickedMap = mapFiles.pick_random()
			Global.rpc("changeScene", pickedMap)
			await get_tree().process_frame
			Global.changeScene(pickedMap)

func _update_camera(delta):

	if not is_multiplayer_authority():
		return

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


func _physics_process(delta):
	
	if not is_multiplayer_authority():
		return

		
	_update_camera(delta)

	Global.debug.addProperty("Speed", get_real_velocity().length(), 2)
	Global.debug.addProperty("Stamina", stamina, 2)


	
	
	## Add the gravity.
	#if not is_on_floor():
		#velocity.y -= gravity * delta
	


	if _mouse_input:
		return 

	var joy_rot = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var joy_tilt = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)

	# Apply deadzone to prevent drift
	if abs(joy_rot) > 0.1:
		_rotation_input = -joy_rot * controllerSensitivity
	else:
		_rotation_input = 0.0

	if abs(joy_tilt) > 0.1:
		_tilt_input = -joy_tilt * controllerSensitivity
	else:
		_tilt_input = 0.0
	
	
func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	holdingTrap()
	CAMERA_CONTROLLER.rotation = lerp(CAMERA_CONTROLLER.rotation, CAMERA_CONTROLLER.rotation + cameraOffset, 0.1)
	cameraOffset = lerp(cameraOffset, Vector3(0,0,0), 0.05)
	damageVignette.material.set_shader_parameter("intensity", move_toward(damageVignette.material.get_shader_parameter("intensity"), 0.0, 0.01))  

	if stamina < 101 and stateMachine.currentState != $PlayerStateMachine/SprintingPlayerState and stateMachine.currentState != $PlayerStateMachine/JumpingPlayerState:
		stamina += 0.15
	Global.staminaBar.value = stamina
	

	if Input.is_action_just_pressed("debugAction"):
		currentHeldTrap = "res://trapSystem/sawbladeTrap.tscn"

func updateGravity(delta) -> void:

	if not is_multiplayer_authority():
		return

	velocity.y -= gravity * delta


func updateInput(speed: float, acceleration: float, deceleration: float) -> void:

	if not is_multiplayer_authority():
		return

	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var weightedSpeed = clamp(speed - (weaponGlobal.inventoryWeight / 2), 0.5, 10000)

	if direction:
		velocity.x = lerp(velocity.x,direction.x * weightedSpeed, acceleration)
		velocity.z = lerp(velocity.z,direction.z * weightedSpeed, acceleration)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration)
		velocity.z = move_toward(velocity.z, 0, deceleration)
	
	# pauses player
	if is_interacting:
		velocity = Vector3.ZERO
		move_and_slide()
		return

func updateVelocity() -> void:

	if not is_multiplayer_authority():
		return

	move_and_slide()

func spawnSpectate():
	if Global.myCurrentTeam == "Cop":
		position = get_tree().root.get_node("World").copsSpectateLocation.global_position
	else:
		position = get_tree().root.get_node("World").robbersSpectateLocation.global_position


@rpc("any_peer")
func take_damage(damage, type, team):
	if not is_multiplayer_authority():
		return
	if team != Global.myCurrentTeam:
		Global.playerHealth -= damage
		autoHealing = false
		healDelayTimer.start(6)
		damageVignette.material.set_shader_parameter("intensity", damageVignette.material.get_shader_parameter("intensity") + 0.25)
		damageVignette.material.set_shader_parameter("intensity", clampf(damageVignette.material.get_shader_parameter("intensity"), 0.0, 0.75))  
		Global.updateHealth()

		if Global.playerHealth <= 0:
			Global.playerHealth = 100
			spawnSpectate()
			damageVignette.material.set_shader_parameter("intensity", 1.0)
			if multiplayer.get_unique_id() != 1:
				get_node("/root/World").updateAlivePlayers.rpc(Global.myCurrentTeam)
				#Global.rpc("replicateSpecificObject", str(get_tree().current_scene.get_path()), "updateAlivePlayers", Global.myCurrentTeam)
			else:
				get_node("/root/World").updateAlivePlayers(Global.myCurrentTeam)

func updatePlayerModel():
	if Global.myCurrentTeam == "Cop":
		copModel.visible = true
	elif Global.myCurrentTeam == "Robber":
		robberModel.visible = true



func holdingTrap():
	if Global.myCurrentTeam == "Cop":
		if loadedTrap != null:
			if hasInstancedTrap == false:
				trapInstance = loadedTrap.instantiate()
				var trapName = "Trap %d" % weaponGlobal.rng.randi_range(1, 10000)
				while find_child(trapName) != null:
					trapName = "Trap %d" % weaponGlobal.rng.randi_range(1, 10000)
				trapInstance.name = trapName
				get_tree().root.get_node("World").add_child(trapInstance)
				hasInstancedTrap = true
				#rpc("replicateTrapPlacement", currentHeldTrap, trapName)
				trapPlaceCast.add_exception(trapInstance)
				for child in trapInstance.find_children("*", "CollisionObject3D", true, false):
					trapPlaceCast.add_exception(child)
			if trapInstance != null:
				if trapPlaceCast.is_colliding():
					trapInstance.global_position = trapPlaceCast.get_collision_point()
				else:
					trapInstance.global_position = trapPlaceCast.global_position + trapPlaceCast.global_transform.basis * trapPlaceCast.target_position
				trapInstance.look_at(global_position, Vector3.UP)
				trapInstance.rotation.x = 0
				trapInstance.rotation.z = 0

				if Input.is_action_just_pressed("interact"):
					rpc("replicateTrapPlacement", currentHeldTrap, trapInstance.name, trapInstance.global_position, trapInstance.rotation)
					trapInstance = null
					loadedTrap = null
					hasInstancedTrap = false
@rpc("any_peer")
func replicateTrapPlacement(trapPath, trapName, trapPos, traprot):
	var clientTrapLoad = load(trapPath)
	var trapInstanceClient = clientTrapLoad.instantiate()
	trapInstanceClient.name = trapName
	trapInstanceClient.global_position = trapPos
	trapInstanceClient.rotation = traprot
	get_tree().root.get_node("World").add_child(trapInstanceClient)


func _on_heal_delay_timeout() -> void:
	autoHealing = true


func _on_healing_tick_timeout() -> void:
	if Global.playerHealth < 100 and autoHealing:
		Global.playerHealth += 1
