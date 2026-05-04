extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var hud = $UserInterface
@onready var myIDref = multiplayer.get_unique_id()

@onready var GUI = $GUItasktest
@onready var GUI_viewport = %SubViewport
@export var GUI_window: Window 

@onready var Player = preload("res://controllers/fps_controller.tscn")
#@onready var Player = $Player

@onready var cop_spawns = $SpawnPoints2/Cops.get_children()
@onready var robber_spawns = $SpawnPoints2/Robber.get_children()

@onready var pauseHUD = $PauseLayer
var tracked = false
var player
var teams = {} # peer_id -> "Cop" or "Robber"
var playercount = 0
var isPaused : bool = false
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()


func _on_host_button_pressed():

	main_menu.hide()
	hud.show()

	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer

	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)

	add_player(multiplayer.get_unique_id())


func _on_join_button_pressed():

	main_menu.hide()
	hud.show()
	if playercount < 4:
		enet_peer.create_client(address_entry.text, PORT)
		multiplayer.multiplayer_peer = enet_peer
	else:
		print("TOO MANY PLAYERS!")

#func _on_multiplayer_spawner_spawned(node):
	#if node.is_multiplayer_authority():
		#node.health_changed.connect(update_health_bar)
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
		deboggled()
		
	if isPaused == true:
		pauseHUD.visible = true
	elif isPaused == false:
		pauseHUD.visible = false
	#if tracked:
		#get_tree().call_group("enemy", "update_target_location", player.global_transform.origin)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Global.reserveLabel = %Reserve
	Global.interactionLabel = %InteractionLabel
	Global.clipLabel = %Clip
	Global.pointsLabel = %Points
	Global.healthLabel = %Health
	GUI.hide()
	print(Input.get_joy_name(0))

func _unhandled_input(_event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func _on_single_player_button_pressed():

	main_menu.hide()
	hud.show()

	var my_id = multiplayer.get_unique_id()
	add_player(my_id)


func add_player(peer_id):

	var player = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)

	player.set_multiplayer_authority(peer_id)

	assign_team(peer_id)

	tracked = true
	playercount += 1 #adds player to playercount
	print ("playercount is " + str(playercount)) #prints playercount
	#if player.is_multiplayer_authority():
		#player.health_changed.connect(update_health_bar)
@rpc ("authority")
func removeplayercount():
	playercount -= 1 #removes player from playercount
	print ("playercount is " + str(playercount)) #prints that
func remove_player(peer_id):
	player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()


func assign_team(id):

	if !multiplayer.is_server():
		return

	var cop_count = 0
	var robber_count = 0

	for t in teams.values():

		if t == "Cop":
			cop_count += 1
		elif t == "Robber":
			robber_count += 1


	var team

	if cop_count > robber_count:
		team = "Robber"
	elif robber_count > cop_count:
		team = "Cop"
	else:
		team = "Cop" if randi() % 2 == 0 else "Robber"


	teams[id] = team

	print("Player ", id, " assigned to ", team)
	if id == multiplayer.get_unique_id():
		Global.myCurrentTeam = team
		Global.player.updatePlayerModel()
	rpc("receive_team_assignment", id, team)
	spawn_player(id, team)


func spawn_player(id, team):

	var player = get_node(str(id))

	var spawn_point

	if team == "Cop":
		spawn_point = cop_spawns.pick_random()
	else:
		spawn_point = robber_spawns.pick_random()

	player.global_position = spawn_point.global_position


@rpc("any_peer", "reliable")
func receive_team_assignment(id, team):

	teams[id] = team

	if id == multiplayer.get_unique_id():
		Global.myCurrentTeam = team
		Global.player.updatePlayerModel()
		
	var player = get_node(str(id))
	var spawn_point

	if team == "Cop":
		spawn_point = cop_spawns.pick_random()
	else:
		spawn_point = robber_spawns.pick_random()

	player.global_position = spawn_point.global_position
		
func deboggled(): #this probably isnt the best way to do this but it works
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE #Un-captures the mouse
		isPaused = true
	elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED #Re-captures the mouse
		isPaused = false
	print(str(isPaused))


func _on_guitasktest_pressed() -> void:
	main_menu.hide()
	get_tree().change_scene_to_file("res://gameMechanics/hacking_minitask.tscn")


func _GUI_window_open(_body: Player) -> void:
	var minitask = preload("res://gameMechanics/hacking_minitask.tscn").instantiate()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Release mouse
	GUI.show()
	GUI_viewport.add_child(minitask)
	print("player interacted with minitask")
	if GUI_window != null:
		GUI_window.emit_signal("close_requested")
