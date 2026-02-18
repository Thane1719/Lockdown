@tool

extends Node

var mouseMovement : Vector2
var randomSwayX
var randomSwayY
var randomSwayAmount = 0
var time : float = 0.0
var idleSwayAdjustment = 0
var idleSwayRotationStrength
var rng = RandomNumberGenerator.new()
var weaponBobAmount : Vector2 = Vector2(0,0)
var weaponBulletPhysics
var weaponBulletScene

#var currentWeaponPath


var reserveAmmo:
	set(value):
		reserveAmmo = value
		Global.reserveLabel.text = str(weaponGlobal.reserveAmmo)
var maxClipAmmo
var clipAmmo:
	set(value):
		clipAmmo = value
		Global.clipLabel.text = str(weaponGlobal.clipAmmo)


var canShoot : bool = true
var weaponName
var weaponAccuracy
var time_per_shot: float = 0.1  # Default time between shots (calculated dynamically)
var cooldown_timer: float = 0.0  # Tracks the remaining cooldown time
var maxInventorySize = 2 #Arrays start at 0, we have 2 weapon slots
var weaponInventory = ["res://Weapons/Empty Weapon.tres","res://Weapons/Empty Weapon.tres"]
var weaponAmmoInventory = [[0,0], [0,0]]
var currentWeaponIndex : int = 0
var shotgun
var fireMode
var reloadMode

var verticalRecoil
var horizontalRecoil

var hasSpawned = false
