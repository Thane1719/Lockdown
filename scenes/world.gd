extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var hud = $UserInterface


@onready var Player = preload("res://controllers/fps_controller.tscn")
#@onready var Player = $Player
var tracked = false
var player
var teams = {} # peer_id -> "Cop" or "Robber"


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
	
	#upnp_setup()
func _on_join_button_pressed():
	main_menu.hide()
	hud.show()
	
	enet_peer.create_client(address_entry.text, PORT)
	multiplayer.multiplayer_peer = enet_peer

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


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Global.reserveLabel = %Reserve
	Global.interactionLabel = %InteractionLabel
	Global.clipLabel = %Clip
	Global.pointsLabel = %Points
	Global.healthLabel = %Health


func _physics_process(delta):
	pass
	#if tracked:
		#get_tree().call_group("enemy", "update_target_location", player.global_transform.origin)

func _unhandled_input(event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func _on_single_player_button_pressed():
	main_menu.hide()
	hud.show()
	var my_id = multiplayer.get_unique_id()
	#multiplayer.multiplayer_peer = enet_peer
	add_player(my_id)
	


func add_player(peer_id):
	player = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)
	assign_team(peer_id)
	tracked = true
	#if player.is_multiplayer_authority():
		#player.health_changed.connect(update_health_bar)

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
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
	# Keep teams balanced first
	if cop_count > robber_count:
		team = "Robber"
	elif robber_count > cop_count:
		team = "Cop"
	else:
		# If equal, randomly assign
		team = "Cop" if randi() % 2 == 0 else "Robber"
	teams[id] = team
	print("Player ", id, " assigned to ", team)
	rpc("receive_team_assignment", id, team)


@rpc("any_peer", "reliable")
func receive_team_assignment(id, team):
	teams[id] = team
	print("Synced: Player ", id, " is ", team)
	# If this is me, confirm team locally
	if id == multiplayer.get_unique_id():
		print("I am on team: ", team)
