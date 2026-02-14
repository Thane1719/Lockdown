extends RigidBody3D


@onready var weaponMesh : MeshInstance3D = %WeaponMesh
@onready var weaponMagazine : MeshInstance3D = %WeaponMagazine
@onready var weaponBolt : MeshInstance3D = %WeaponBolt
@onready var weaponShadow : MeshInstance3D = %WeaponShadow
@onready var weaponParent = $Weapon

@export var objectName : String = ""
@export_file("*.tres") var weaponPath

@export var defaultStats = true
@export var clip = 0
@export var reserve = 0

var weaponWeight = 1
var weaponReturning = false
var returning = false

#defaultStats tells the Weapon Manager to use the files default ammo
#Turning it off will pull the ammo from the values here, which are set when the weapon is dropped.
#Can be used to give custom ammo, such as guns with extra ammo, or no ammo for specific level.
func _ready():
	if weaponPath != null:
		setModel(weaponPath)


func update():
	pass


func interact():
	Global.weaponManager.addWeapon(weaponPath, defaultStats, clip, reserve)
	deleteWeaponDrop()
	rpc("deleteWeaponDrop")

@rpc("any_peer")
func deleteWeaponDrop():
	queue_free()

func setWeapon(path):
	weaponPath = path
	defaultStats = false

func parseAmmo(clipAmmo, reserveAmmo):
	clip = clipAmmo
	reserve = reserveAmmo

func setModel(weaponType):
	var loadedWeapon = load(weaponType)
	objectName = str(loadedWeapon.name)
	weaponMesh.mesh = loadedWeapon.mesh
	weaponMagazine.mesh = loadedWeapon.magazine
	weaponBolt.mesh = loadedWeapon.bolt
	weaponShadow.mesh = loadedWeapon.mesh
	weaponWeight = loadedWeapon.weight
	weaponReturning = loadedWeapon.returnThrownForce
	weaponParent.scale = loadedWeapon.scale



func changeVel(vel):
	apply_impulse(vel)
	angular_velocity = transform.basis * Vector3(-vel.length(), 0, 0)

func _on_area_3d_body_entered(body: Node3D) -> void:
	var hitVelocity = linear_velocity.length()
	if hitVelocity >= 1 and body.is_in_group("Enemy"):
		linear_velocity = (Vector3(0, 8, 0))
		if weaponReturning == true:
			returning = true
		body.take_damage(roundi(hitVelocity * (2 + weaponWeight)), "throw")


func _physics_process(delta: float) -> void:
	if returning:
		var playerPosition = global_position.direction_to(Global.player.position)
		linear_velocity += playerPosition * (position.distance_to(Global.player.position) / 16)
