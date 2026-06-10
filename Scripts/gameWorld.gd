extends Node

@onready var hud = $UserInterface
@onready var myIDref = multiplayer.get_unique_id()

@onready var GUI = %GUIwindow
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
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()
#var debWin = preload("res://Scenes/Debug.tscn")

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
	Global.totalValue = 0
	GUI.hide()
	print(Input.get_joy_name(0))
	get_viewport().set_embedding_subwindows(false)
	Global.recreatePlayers()
	#var DebugPanel = debWin.instantiate()
	#add_child(DebugPanel)
	#DebugPanel.visible = true

func _unhandled_input(_event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()


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
		Global.player.spawnpoint = cop_spawns
	else:
		spawn_point = robber_spawns.pick_random()
		Global.player.spawnpoint = robber_spawns

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
	if _body.is_multiplayer_authority():
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
