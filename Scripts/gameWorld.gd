extends Node

@onready var hud = $UserInterface
@onready var myIDref = multiplayer.get_unique_id()

@onready var GUI = %GUIwindow
@onready var GUI_viewport = %SubViewport
@export var GUI_window: Window 

@onready var Player = preload("res://controllers/fps_controller.tscn")
#@onready var Player = $Player
@onready var cop_spawns = $SpawnPoints/Cops.get_children()
@onready var robber_spawns = $SpawnPoints/Robber.get_children()

@onready var pauseHUD = $PauseLayer

@export var terminalDoor: Node3D
@export var copsSpectateLocation : Marker3D
@export var robbersSpectateLocation : Marker3D
@export var mapName : String
var tracked = false
var player
var playercount = 0
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()
var rng = RandomNumberGenerator.new()

var avaliableTraps = [
	#"res://trapSystem/sawbladeTrap.tscn",
	#"res://trapSystem/gasTrap.tscn",
	"res://trapSystem/tackShooter.tscn"
]

#Game Manager Variables
var trapSetupMode = true
var totalItems = 0
var hasCompletedMiniTask = false

func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Discover Failed! Error %s" % discover_result)

	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), "UPNP Invalid Gateway!")

	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Port Mapping Failed! Error %s" % map_result)
	
	print("Success! Join Address: %s" % upnp.query_external_address())

func _physics_process(delta):
	if Input.is_action_just_pressed("PauseMenu"):
		pause()
	#if tracked:
		#get_tree().call_group("enemy", "update_target_location", player.global_transform.origin)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Global.reserveLabel = %Reserve
	Global.interactionLabel = %InteractionLabel
	Global.clipLabel = %Clip
	Global.pointsLabel = %TotalValue
	Global.healthLabel = %Health
	Global.staminaBar = %"Stamina Bar"
	Global.totalValue = 0
	GUI.hide()
	print(Input.get_joy_name(0))
	get_viewport().set_embedding_subwindows(false)
	Global.recreatePlayers()
	Global.updateSpawnPoints(cop_spawns, robber_spawns)
	Global.player.spawnSpectate()
	showAnnounceText("Welcome to " + mapName, 5)
	await get_tree().create_timer(5.0).timeout
	showAnnounceText("First team to 3 wins", 5)
	await get_tree().create_timer(5.0).timeout
	if multiplayer.get_unique_id() == 1:
		rpc("resetRound")
	#var DebugPanel = debWin.instantiate()
	#add_child(DebugPanel)
	#DebugPanel.visible = true


		
func pause(): #this probably isnt the best way to do this but it works
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE #Un-captures the mouse
		Global.isPaused = true
	elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED #Re-captures the mouse
		Global.isPaused = false
	if Global.isPaused == true:
		pauseHUD.visible = true
	elif Global.isPaused == false:
		pauseHUD.visible = false
	print(str(Global.isPaused))
	
# GUI window code :

var minitask = preload("res://gameMechanics/hacking_minitask.tscn").instantiate()
var active_instance: Node = null

func _GUI_window_open(_body: Player) -> void:
	if _body.is_multiplayer_authority() and Global.myCurrentTeam == "Robber" and hasCompletedMiniTask == false:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Release mouse
		Global.taskMode = true
		GUI.show()
		GUI_viewport.add_child(minitask)
		print("player interacted with minitask")

# player quits window
		if GUI_window != null:
			swap_to_new_instance()
			GUI_window.emit_signal("close_requested")
			Global.taskMode = false
			print("player closed minitask")

func swap_to_new_instance():
	if is_instance_valid(active_instance):
		active_instance.queue_free()
		var new_instance = minitask.instantiate()
		add_child(new_instance)
		active_instance = new_instance

func openTerminalDoors():
	if terminalDoor:
		terminalDoor.open()

@rpc("any_peer", "call_local")
func showAnnounceText(text : String, duration : int):
	var announceBox = $"UserInterface/Spawn Text"
	var announceLabel = %AnnounceLabel
	announceLabel.text = text
	announceBox.show()
	await get_tree().create_timer(duration).timeout
	announceBox.hide()

@rpc("reliable", "any_peer")
func exitTrapSetup():
	if trapSetupMode == true:
		trapSetupMode = false
		Global.player.trapInstance = null
		Global.player.loadedTrap = null
		Global.player.hasInstancedTrap = false
		Global.respawnPlayers()
		weaponGlobal.weaponAmmoInventory = [[0,0], [0,0]]
		weaponGlobal.weaponInventory = ["res://Weapons/Empty Weapon.tres","res://Weapons/Empty Weapon.tres"]
		Global.weaponManager.loadWeapon()
		Global.weaponManager.addWeapon("res://Weapons/Blaster.tres", true, 0, 0)


@rpc("reliable", "any_peer", "call_local")
func resetRound():
	totalItems = 0
	Global.roundReset.emit()
	Global.respawnPlayers()
	trapSetupMode = true
	weaponGlobal.weaponAmmoInventory = [[0,0], [0,0]]
	weaponGlobal.weaponInventory = ["res://Weapons/Empty Weapon.tres","res://Weapons/Empty Weapon.tres"]
	Global.weaponManager.loadWeapon()
	Global.weaponManager.addWeapon("res://Weapons/Blaster.tres", true, 0, 0)
	if Global.myCurrentTeam == "Cop":
		Global.player.currentHeldTrap = avaliableTraps.pick_random()
		showAnnounceText("Trap setup mode", 3)
		await get_tree().create_timer(3.0).timeout
		showAnnounceText("Place your traps and ready yourselves", 4)
	else:
		showAnnounceText("Round setup", 3)
		await get_tree().create_timer(3.0).timeout
		showAnnounceText("Plan your attack!", 4)

@rpc("reliable", "call_local", "any_peer")
func updateAlivePlayers(team):
	if multiplayer.get_unique_id() == 1:
		if team == "Cop":
			Global.aliveCopCount -= 1
		elif team == "Robber":
			Global.aliveRobberCount -= 1
		
		if Global.aliveCopCount <= 0:
			rpc("showAnnounceText", "Robbers have won", 3)
			Global.robberWins += 1
			await get_tree().create_timer(3.0).timeout
			if Global.robberWins >= 3:
				rpc("cameFromGameUpdate")
				Global.rpc("changeScene", "res://Scenes/lobby.tscn")
				Global.changeScene("res://Scenes/lobby.tscn")
				return
			recalculateTeamNumbers()
			rpc("resetRound")
		elif Global.aliveRobberCount <= 0:
			rpc("showAnnounceText", "Cops have won", 3)
			Global.copWins += 1
			await get_tree().create_timer(3.0).timeout
			if Global.copWins >= 3:
				rpc("cameFromGameUpdate")
				Global.rpc("changeScene", "res://Scenes/lobby.tscn")
				Global.changeScene("res://Scenes/lobby.tscn")
				return
			recalculateTeamNumbers()
			rpc("resetRound")

@rpc("call_local", "reliable", "any_peer")
func cameFromGameUpdate():
	Global.cameFromGame = true

func recalculateTeamNumbers():
	Global.aliveCopCount = 0
	Global.aliveRobberCount = 0
	for t in Global.teams.values():
		if t == "Cop":
			Global.aliveCopCount += 1
		elif t == "Robber":
			Global.aliveRobberCount += 1

# Money balance
var current_balance = moneyGlobal.get_bank_balance()
@onready var money = $%moneyLabel

func update_money_display() -> void:
	money.text = "Money: " + str(current_balance)
	print("Player wallet: " + str(current_balance))


func _on_exit_game_pressed() -> void:

	get_tree().quit()
