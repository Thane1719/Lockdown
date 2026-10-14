extends Node


const MAX_PLAYERS: int = 4
const PORT: int = 9999

const NAME_MENU_SCENE_PATH: String = "res://name_menu.tscn"

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/PanelContainer/VBoxContainer/AddressEntry
@onready var hud = $UserInterface
@onready var loading = $CanvasLayer/Loading
@onready var menuMusicNode = $CanvasLayer/MenuMusic
@onready var menuBackground = $"CanvasLayer/Menu Background"

@onready var GUI = $GUIwindow
@onready var GUI_viewport = %SubViewport

@export var GUI_window: Window

@onready var PlayerScene: PackedScene = preload(
    "res://controllers/fps_controller.tscn"
)

@onready var cop_spawns = $SpawnPoints2/Cops.get_children()
@onready var robber_spawns = $SpawnPoints2/Robber.get_children()

@onready var pauseHUD = $PauseLayer
@onready var money = $%moneyLabel

var myIDref: int

var tracked: bool = false
var player: Node = null

var teams: Dictionary = {}
var playercount: int = 0

var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

var debWin: PackedScene = preload("res://Menus/Debug.tscn")

var trapSetupMode: bool = true
var totalItems: int = 0

var minitask_scene: PackedScene = preload(
    "res://gameMechanics/hacking_minitask.tscn"
)

var active_instance: Node = null

var current_balance = moneyGlobal.get_bank_balance()



func _on_host_button_pressed() -> void:
	Global.should_host = true
	Global.should_join = false

	Global.server_address = "127.0.0.1"

	var error = get_tree().change_scene_to_file(
		NAME_MENU_SCENE_PATH
	)

	if error != OK:
		Global.should_host = false
		print("Failed to open Name Menu: ", error)


func _on_join_button_pressed() -> void:
	Global.should_host = false
	Global.should_join = true

	# Preserve the address entered on the main menu.
	Global.server_address = address_entry.text.strip_edges()

	if Global.server_address.is_empty():
		Global.server_address = "127.0.0.1"

	var error = get_tree().change_scene_to_file(
		NAME_MENU_SCENE_PATH
	)

	if error != OK:
		Global.should_join = false
		print("Failed to open Name Menu: ", error)



func host_game() -> void:
	var peer = ENetMultiplayerPeer.new()

	var error = peer.create_server(PORT, MAX_PLAYERS - 1)

	if error != OK:
		print("Failed to create server: ", error)
		return

	multiplayer.multiplayer_peer = peer
	enet_peer = peer

	if not multiplayer.peer_connected.is_connected(
		_on_peer_connected
	):
		multiplayer.peer_connected.connect(
			_on_peer_connected
		)

	if not multiplayer.peer_disconnected.is_connected(
		remove_player
	):
		multiplayer.peer_disconnected.connect(
			remove_player
		)

	add_player(multiplayer.get_unique_id())

	print("Server started successfully!")
	print("Maximum players: ", MAX_PLAYERS)

	loading.visible = false


func join_game() -> void:
	var peer = ENetMultiplayerPeer.new()

	var address = Global.server_address.strip_edges()

	if address.is_empty():
		address = "127.0.0.1"

	var error = peer.create_client(address, PORT)

	if error != OK:
		print("Failed to create client: ", error)
		return

	multiplayer.multiplayer_peer = peer
	enet_peer = peer

	if not multiplayer.server_disconnected.is_connected(
		_on_server_disconnected
	):
		multiplayer.server_disconnected.connect(
			_on_server_disconnected
		)

	print("Connecting to server: ", address)


func _on_server_disconnected() -> void:
	print("Disconnected from the server.")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	myIDref = multiplayer.get_unique_id()

	Global.reserveLabel = %Reserve
	Global.interactionLabel = %InteractionLabel
	Global.clipLabel = %Clip
	Global.pointsLabel = %TotalValue
	Global.healthLabel = %Health

	Global.totalValue = 0

	GUI.hide()

	get_viewport().set_embedding_subwindows(false)

	Global.recreatePlayers()
	Global.updateSpawnPoints(cop_spawns, robber_spawns)
	Global.respawnPlayers()

	update_money_display()

	# Host or join after returning from the Name Menu.
	if Global.should_host:
		Global.should_host = false

		main_menu.hide()
		hud.show()

		menuBackground.hide()
		menuMusicNode.playing = false

		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		host_game()

	elif Global.should_join:
		Global.should_join = false

		main_menu.hide()
		hud.show()

		menuBackground.hide()
		menuMusicNode.playing = false

		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		join_game()

	elif Global.isMainMenu == false:
		main_menu.hide()
		hud.show()

		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	else:
		menuMusicNode.playing = true

	print(Input.get_joy_name(0))



func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)

	if not multiplayer.is_server():
		return

	if playercount >= MAX_PLAYERS:
		print("Lobby full. Rejecting peer: ", peer_id)

		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return

	add_player(peer_id)


func add_player(peer_id: int) -> void:
	if playercount >= MAX_PLAYERS:
		print("Cannot add player. Lobby is full.")
		return

	if has_node(str(peer_id)):
		print("Player already exists: ", peer_id)
		return

	var new_player = PlayerScene.instantiate()

	new_player.name = str(peer_id)

	add_child(new_player)

	new_player.set_multiplayer_authority(peer_id)

	assign_team(peer_id)

	tracked = true

	playercount += 1

	print("Player ", peer_id, " joined.")
	print("Playercount: ", playercount, "/", MAX_PLAYERS)

	Global.playerJoined.emit()


func remove_player(peer_id: int) -> void:
	print("Player ", peer_id, " disconnected.")

	var player_node = get_node_or_null(str(peer_id))

	if player_node:
		player_node.queue_free()

	if teams.has(peer_id):
		teams.erase(peer_id)

	playercount = max(playercount - 1, 0)

	print("Playercount: ", playercount, "/", MAX_PLAYERS)




func _on_single_player_button_pressed() -> void:
	main_menu.hide()
	menuBackground.hide()
	hud.show()

	menuMusicNode.stop()

	add_player(multiplayer.get_unique_id())




func assign_team(id: int) -> void:
	if not multiplayer.is_server():
		return

	Global.cop_count = 0
	Global.robber_count = 0
	Global.aliveCopCount = 0
	Global.aliveRobberCount = 0

	for team_name in teams.values():
		if team_name == "Cop":
			Global.cop_count += 1
			Global.aliveCopCount += 1

		elif team_name == "Robber":
			Global.robber_count += 1
			Global.aliveRobberCount += 1

	var team: String

	if Global.cop_count > Global.robber_count:
		team = "Robber"

	elif Global.robber_count > Global.cop_count:
		team = "Cop"

	else:
		team = "Cop" if randi() % 2 == 0 else "Robber"

	teams[id] = team

	print("Player ", id, " assigned to ", team)

	if team == "Cop":
		Global.aliveCopCount += 1

	elif team == "Robber":
		Global.aliveRobberCount += 1

	if id == multiplayer.get_unique_id():
		Global.myCurrentTeam = team

		if Global.player != null:
			Global.player.updatePlayerModel()

	receive_team_assignment.rpc(id, team)

	spawn_player(id, team)



func spawn_player(id: int, team: String) -> void:
	var player_node = get_node_or_null(str(id))

	if player_node == null:
		print("Could not find player node: ", id)
		return

	var spawn_point: Node3D

	if team == "Cop":
		if cop_spawns.is_empty():
			print("No Cop spawn points available.")
			return

		spawn_point = cop_spawns.pick_random()
		Global.player.spawnpoint = cop_spawns

	else:
		if robber_spawns.is_empty():
			print("No Robber spawn points available.")
			return

		spawn_point = robber_spawns.pick_random()
		Global.player.spawnpoint = robber_spawns

	player_node.global_position = spawn_point.global_position


@rpc("authority", "call_local", "reliable")
func receive_team_assignment(id: int, team: String) -> void:
	teams[id] = team

	if id == multiplayer.get_unique_id():
		Global.myCurrentTeam = team

		if Global.player != null:
			Global.player.updatePlayerModel()

	var player_node = get_node_or_null(str(id))

	if player_node == null:
		return

	var spawn_point: Node3D

	if team == "Cop":
		if cop_spawns.is_empty():
			return

		spawn_point = cop_spawns.pick_random()

	else:
		if robber_spawns.is_empty():
			return

		spawn_point = robber_spawns.pick_random()

	player_node.global_position = spawn_point.global_position



func upnp_setup() -> void:
	var upnp = UPNP.new()

	var discover_result = upnp.discover()

	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		print("UPNP discovery failed: ", discover_result)
		return

	if not upnp.get_gateway() or not upnp.get_gateway().is_valid_gateway():
		print("UPNP invalid gateway.")
		return

	var map_result = upnp.add_port_mapping(PORT)

	if map_result != UPNP.UPNP_RESULT_SUCCESS:
		print("UPNP port mapping failed: ", map_result)
		return

	print("Join Address: ", upnp.query_external_address())



func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("PauseMenu"):
		pause()


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()


func pause() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Global.isPaused = true

	elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Global.isPaused = false

	pauseHUD.visible = Global.isPaused


func _on_Quit_button_pressed() -> void:
	get_tree().quit()


func _on_exit_game_pressed() -> void:
	get_tree().quit()


func _GUI_window_open(_body: Player) -> void:
	if not _body.is_multiplayer_authority():
		return

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	Global.taskMode = true

	GUI.show()

	swap_to_new_instance()


func swap_to_new_instance() -> void:
	if is_instance_valid(active_instance):
		active_instance.queue_free()

	var new_instance = minitask_scene.instantiate()

	GUI_viewport.add_child(new_instance)

	active_instance = new_instance


func showAnnounceText(text: String) -> void:
	var announceBox = $"UserInterface/Spawn Text"
	var announceLabel = %AnnounceLabel

	announceLabel.text = text
	announceBox.show()

	await get_tree().create_timer(3.0).timeout

	if is_instance_valid(announceBox):
		announceBox.hide()


@rpc("any_peer", "reliable")
func exitTrapSetup() -> void:
	if trapSetupMode:
		trapSetupMode = false

		Global.roundReset.emit()
		Global.respawnPlayers()

		showAnnounceText("Rob stuff I guess")


func resetRound() -> void:
	Global.roundReset.emit()
	Global.respawnPlayers()

	trapSetupMode = true

	recieveReset.rpc()

	if Global.myCurrentTeam == "Cop":
		showAnnounceText("Trap setup mode")


@rpc("any_peer", "call_local", "reliable")
func recieveReset() -> void:
	Global.roundReset.emit()
	Global.respawnPlayers()

	trapSetupMode = true

	if Global.myCurrentTeam == "Cop":
		showAnnounceText("Trap setup mode")


@rpc("any_peer", "call_local", "reliable")
func updateAlivePlayers(team: String) -> void:
	if multiplayer.get_unique_id() != 1:
		return

	if team == "Cop":
		Global.aliveCopCount -= 1

	elif team == "Robber":
		Global.aliveRobberCount -= 1

	if Global.aliveCopCount <= 0 or Global.aliveRobberCount <= 0:
		Global.aliveCopCount = 0
		Global.aliveRobberCount = 0

		for team_name in teams.values():
			if team_name == "Cop":
				Global.aliveCopCount += 1

			elif team_name == "Robber":
				Global.aliveRobberCount += 1

		resetRound()


func hideMainMenu() -> void:
	menuMusicNode.playing = false
	loading.visible = true
	menuBackground.visible = false
	main_menu.hide()


func update_money_display() -> void:
	money.text = "Money: " + str(current_balance)

	print("Player wallet: ", current_balance)
