extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/PanelContainer/VBoxContainer/AddressEntry
@onready var hud = $UserInterface
@onready var myIDref = multiplayer.get_unique_id()
@onready var menuMusicNode = $CanvasLayer/MenuMusic
@onready var menuBackground = $"CanvasLayer/Menu Background"
@onready var ipLabel = $"UserInterface/IP Label"

@onready var GUI = $GUIwindow
@onready var GUI_viewport = %SubViewport
@export var GUI_window: Window

@onready var PlayerScene = preload("res://controllers/fps_controller.tscn")

@onready var cop_spawns = $SpawnPoints2/Cops.get_children()
@onready var robber_spawns = $SpawnPoints2/Robber.get_children()

@onready var pauseHUD = $PauseLayer

@export var terminalDoor: Node3D
@export var copsSpectateLocation : Marker3D
@export var robbersSpectateLocation : Marker3D
@export var mapName : String

var tracked = false
var player

# Number of players currently in the game
var playercount = 0

# Maximum number of TOTAL players, including the host
const MAX_PLAYERS = 4

const PORT = 9999

var enet_peer = ENetMultiplayerPeer.new()

var debWin = preload("res://Menus/Debug.tscn")


var trapSetupMode = true
var totalItems = 0

func get_lan_ip() -> String:
	var addresses = IP.get_local_addresses()
	var valid_ips: Array[String] = []
	
	for ip in addresses:
		# Skip IPv6 and Loopback (localhost)
		if ip.contains(":") or ip.begins_with("127."):
			continue
			
		# Skip known virtual adapter IPs (VirtualBox, Docker, WSL, Windows Hotspot)
		if ip.begins_with("192.168.56."): continue # VirtualBox Host-Only
		if ip.begins_with("10.0.2."): continue # VirtualBox NAT
		if ip.begins_with("172.17.") or ip.begins_with("172.18.") or ip.begins_with("172.19.") or ip.begins_with("172.20."): continue # Docker / WSL
		if ip == "192.168.137.1": continue # Windows Mobile Hotspot
		
		# Filter for common private IPv4 ranges
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			if ip not in valid_ips:
				valid_ips.append(ip)

	if valid_ips.is_empty():
		# Fallback to any active IPv4 address if the first pass fails
		for ip in addresses:
			if not ip.contains(":") and not ip.begins_with("127."):
				if ip not in valid_ips:
					valid_ips.append(ip)
					
	if valid_ips.is_empty():
		return "Offline"
	
	# Return all found IPs separated by a newline. 
	# The Label node will automatically display these on multiple lines!
	return "\n".join(valid_ips)


func _on_host_button_pressed():

	hideMainMenu()
	hud.show()
	

	# Allow 2 remote clients.
	# The host counts as the third player.
	var error = enet_peer.create_server(PORT, MAX_PLAYERS - 1)

	if error != OK:
		print("Failed to create server. Error: ", error)
		return

	multiplayer.multiplayer_peer = enet_peer

	# Listen for players joining/leaving
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(remove_player)

	# Add the host as the first player
	add_player(multiplayer.get_unique_id())

	print("Server started.")
	print("Maximum players: ", MAX_PLAYERS)
	ipLabel.text = ipLabel.text + "\nPress G to start game"
	Global.roundReset.emit()

func _on_join_button_pressed():
	hideMainMenu()
	hud.show()

	var error
	# Trim any accidental spaces the user might have typed
	var target_ip = address_entry.text.strip_edges()
	
	if target_ip == "":
		error = enet_peer.create_client("127.0.0.1", PORT)
	else:
		error = enet_peer.create_client(target_ip, PORT)

	if error != OK:
		print("Failed to create client. Error: ", error)
		return

	multiplayer.multiplayer_peer = enet_peer
	
	# Add signals for better debugging
	multiplayer.connected_to_server.connect(_on_client_connected)
	multiplayer.connection_failed.connect(_on_client_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	Global.joinButtonPressed.emit()

func _on_client_connected():
	print("Successfully connected to the server!")

func _on_client_failed():
	print("Failed to connect to server. Check IP and Firewall.")

func _on_server_disconnected():
	print("Lost connection to the server.")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Global.reserveLabel = %Reserve
	Global.interactionLabel = %InteractionLabel
	Global.clipLabel = %Clip
	Global.pointsLabel = %TotalValue
	Global.healthLabel = %Health
	Global.staminaBar = %"Stamina Bar"
	Global.totalValue = 0
	GUI.hide()
	if Global.isMainMenu == false:
		main_menu.hide()
		hud.show()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print(Input.get_joy_name(0))
	get_viewport().set_embedding_subwindows(false)
	Global.recreatePlayers()
	Global.updateSpawnPoints(cop_spawns, robber_spawns)
	Global.respawnPlayers()
	menuMusicNode.playing = true
	
	update_money_display()
	

	var lan_ip = get_lan_ip()
	ipLabel.text = "My IP:\n" + lan_ip
	ipLabel.show()

	if Global.cameFromGame == true:
		Global.cameFromGame = false
		if multiplayer.get_unique_id() == 1:
			rpc("resetRound")
		hideMainMenu()
		hud.show()
		weaponGlobal.weaponAmmoInventory = [[0,0], [0,0]]
		weaponGlobal.weaponInventory = ["res://Weapons/Empty Weapon.tres","res://Weapons/Empty Weapon.tres"]
		Global.weaponManager.loadWeapon()
		Global.weaponManager.addWeapon("res://Weapons/Blaster.tres", true, 0, 0)
		return
	resetRound()

func _process(delta: float) -> void:
	Global.playerHealth = 100
	
	#var DebugPanel = debWin.instantiate()
	#add_child(DebugPanel)
	#DebugPanel.visible = true

func _on_peer_connected(peer_id: int):

	print("Peer connected: ", peer_id)

	# This check is performed on the server.
	# If there are already 4 players, reject the new player.
	if !multiplayer.is_server():
		return

	if playercount >= MAX_PLAYERS:
		print("LOBBY FULL! Rejecting peer: ", peer_id)

		# Disconnect the fourth player
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)

		return

	# There is room, so add the player
	add_player(peer_id)




func add_player(peer_id: int):

	# Safety check
	if playercount >= MAX_PLAYERS:
		print("Cannot add player. Lobby is full.")
		return

	var new_player = PlayerScene.instantiate()

	new_player.name = str(peer_id)

	add_child(new_player)

	new_player.set_multiplayer_authority(peer_id)

	# Assign Cop or Robber
	assign_team(peer_id)

	tracked = true

	# Increase player count
	playercount += 1

	print("Player ", peer_id, " joined.")
	print("Playercount is ", playercount, "/", MAX_PLAYERS)
	print(multiplayer.get_unique_id())
	Global.playerJoined.emit()




func remove_player(peer_id: int):

	print("Player ", peer_id, " disconnected.")

	player = get_node_or_null(str(peer_id))

	if player:
		player.queue_free()

	# Remove them from the team dictionary
	if Global.teams.has(peer_id):
		Global.teams.erase(peer_id)

	# Decrease player count
	playercount -= 1

	# Prevent negative values
	playercount = max(playercount, 0)

	print("Playercount is ", playercount, "/", MAX_PLAYERS)


func _on_single_player_button_pressed():

	hideMainMenu()
	hud.show()

	var my_id = multiplayer.get_unique_id()

	add_player(my_id)




func assign_team(id):

	# Only the server assigns teams
	if !multiplayer.is_server():
		return

	Global.cop_count = 0
	Global.robber_count = 0
	Global.aliveCopCount = 0
	Global.aliveRobberCount = 0

	for t in Global.teams.values():

		if t == "Cop":
			Global.cop_count += 1
			if multiplayer.get_unique_id() == 1:
				Global.aliveCopCount += 1

		elif t == "Robber":
			Global.robber_count += 1
			if multiplayer.get_unique_id() == 1:
				Global.aliveRobberCount += 1

	var team

	if Global.cop_count > Global.robber_count:
		team = "Robber"

	elif Global.robber_count > Global.cop_count:
		team = "Cop"


	else:
		team = "Cop" if randi() % 2 == 0 else "Robber"

	Global.teams[id] = team

	print("Player ", id, " assigned to ", team)
	
	if team == "Cop":
		Global.aliveCopCount += 1
		print("COP IS ALIVE")
	elif team == "Robber":
		Global.aliveRobberCount += 1
		print("ROBBER IS ALOVE")

	# Update local player's team
	if id == multiplayer.get_unique_id():

		Global.myCurrentTeam = team
		Global.player.updatePlayerModel()

	# Tell all clients the team assignment
	rpc("receive_team_assignment", id, team)

	# Spawn player
	spawn_player(id, team)


func spawn_player(id, team):

	var player_node = get_node_or_null(str(id))

	if player_node == null:
		print("Could not find player node: ", id)
		return

	var spawn_point

	if team == "Cop":

		spawn_point = cop_spawns.pick_random()

		Global.player.spawnpoint = cop_spawns

	else:

		spawn_point = robber_spawns.pick_random()

		Global.player.spawnpoint = robber_spawns

	player_node.global_position = spawn_point.global_position



@rpc("any_peer", "reliable")
func receive_team_assignment(id, team):

	Global.teams[id] = team

	if id == multiplayer.get_unique_id():

		Global.myCurrentTeam = team
		Global.player.updatePlayerModel()

	var player_node = get_node_or_null(str(id))

	if player_node == null:
		return

	var spawn_point

	if team == "Cop":

		spawn_point = cop_spawns.pick_random()

	else:

		spawn_point = robber_spawns.pick_random()

	player_node.global_position = spawn_point.global_position




func upnp_setup():

	var upnp = UPNP.new()

	var discover_result = upnp.discover()

	assert(
		discover_result == UPNP.UPNP_RESULT_SUCCESS,
		"UPNP Discover Failed! Error %s" % discover_result
	)

	assert(
		upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(),
		"UPNP Invalid Gateway!"
	)

	var map_result = upnp.add_port_mapping(PORT)

	assert(
		map_result == UPNP.UPNP_RESULT_SUCCESS,
		"UPNP Port Mapping Failed! Error %s" % map_result
	)

	print("Success! Join Address: %s" % upnp.query_external_address())



func _physics_process(delta):


	if Input.is_action_just_pressed("PauseMenu"):

		pause()





func pause():

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:

		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Global.isPaused = true

	elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:

		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Global.isPaused = false

	if Global.isPaused == true:

		pauseHUD.visible = true

	else:

		pauseHUD.visible = false

	print(str(Global.isPaused))



func _on_Quit_button_pressed() -> void:

	get_tree().quit()



var minitask = preload("res://gameMechanics/hacking_minitask.tscn").instantiate()

var active_instance: Node = null


func _GUI_window_open(_body: Player) -> void:

	if _body.is_multiplayer_authority():

		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		Global.taskMode = true

		GUI.show()

		GUI_viewport.add_child(minitask)

		print("player interacted with minitask")

		# Player quits window

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


func _on_exit_game_pressed() -> void:

	get_tree().quit()


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
	if Global.weaponManager:
		Global.weaponManager.loadWeapon()
		Global.weaponManager.addWeapon("res://Weapons/Blaster.tres", true, 0, 0)
	if Global.myCurrentTeam == "Cop":
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
				Global.rpc("changeScene", "res://Scenes/lobby.tscn")
				Global.changeScene("res://Scenes/lobby.tscn")
				return
			recalculateTeamNumbers()
			rpc("resetRound")

func recalculateTeamNumbers():
	Global.aliveCopCount = 0
	Global.aliveRobberCount = 0
	for t in Global.teams.values():
		if t == "Cop":
			Global.aliveCopCount += 1
		elif t == "Robber":
			Global.aliveRobberCount += 1

func hideMainMenu():
	menuMusicNode.playing = false
	menuBackground.visible = false
	main_menu.hide()

# Money balance
var current_balance = moneyGlobal.get_bank_balance()
@onready var money = $%moneyLabel

func update_money_display() -> void:
	money.text = "Money: " + str(current_balance)
	print("Player wallet: " + str(current_balance))
