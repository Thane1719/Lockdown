extends Node3D

@onready var dropLocation = $"Item Spawn Location"
var rng = RandomNumberGenerator.new()
var weaponDrop = preload("res://Scenes/Weapon Drop.tscn")
var itemPaths = [
	"res://Items/Item Files/Amythest.tres",
	"res://Items/Item Files/Emerald.tres",
	"res://Items/Item Files/Gem.tres",
	"res://Items/Item Files/Goldbar.tres",
	"res://Items/Item Files/Painting.tres",
	"res://Items/Item Files/Potion.tres",
	"res://Items/Item Files/Star.tres",
	"res://Items/Item Files/Vase.tres"
]

# Track spawned items on the server so late joiners can receive them
var spawned_items = [] 

func _ready() -> void:
	rng.randomize()
	Global.joinButtonPressed.connect(requestItems)
	if not multiplayer.get_unique_id() == 1:
		return
	
	Global.roundReset.connect(spawnItem)
	Global.playerJoined.connect(spawnItem)
	
	# 1. FIXING THE RACE CONDITION:
	# When a client fully loads, they ask the server for any items that were 
	# already spawned (in case they joined after the round started).
func requestItems():
	if not multiplayer.get_unique_id() == 1:
		rpc_id(1, "request_item_sync")

func spawnItem():
	# 2. FIXING THE SERVER CHECK:
	# Use is_server() instead of ID 1 for safety and clarity
	if not multiplayer.get_unique_id() == 1:
		return
			
	# 1. Pick item and position immediately
	var loadedItem = itemPaths[rng.randi_range(0, itemPaths.size()-1)]
	var dropPos = dropLocation.global_position
	
	var dropName = "Item Drop %d" % rng.randi_range(1, 10000)
	
	# Ensure name is unique among our immediate children
	while has_node(dropName):
		dropName = "Item Drop %d" % rng.randi_range(1, 10000)
		
	# 2. Track the item so we can sync it to late joiners later
	spawned_items.append({
		"weapon": loadedItem,
		"pos": dropPos,
		"name": dropName
	})
		
	# 3. Tell all peers (including server via call_local) to spawn it instantly
	rpc("replicateDroppedItem", loadedItem, dropPos, dropName)
	var stack = get_stack()
	if stack.size() > 1:
		# Index 0 is my_function itself, Index 1 is the function that called it
		var caller = stack[1]
		print("Called by function: ", caller.function, " in script: ", caller.source, " at line: ", caller.line)


@rpc("authority", "call_local", "reliable")
func replicateDroppedItem(weapon, dropPos, dropName):
	# Safety check: Prevent duplicate spawns if packet arrives twice
	if has_node(dropName):
		return
		
	var dropInstance = weaponDrop.instantiate()
	dropInstance.name = dropName
	
	# 3. FIXING THE PARENTING ISSUE:
	# Add it directly to this Node3D instead of relying on a root "World" node.
	# This guarantees the path exists on the client.
	add_child(dropInstance) 
	
	# Configure item properties safely
	dropInstance.global_position = dropPos
	dropInstance.setWeapon(weapon)
	dropInstance.setModel(weapon)
	dropInstance.setAttribute("isItem", true)
	
	if multiplayer.is_server():
		# Make sure current_scene isn't null to avoid crashes
		if get_tree().current_scene:
			get_tree().current_scene.totalItems += 1

# 4. THE CATCH-UP SYSTEM:
# RPC for clients to ask the server for the current list of items
@rpc("any_peer", "reliable")
func request_item_sync():
	if not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Send all currently spawned items to the new client
	for item in spawned_items:
		rpc_id(sender_id, "replicateDroppedItem", item.weapon, item.pos, item.name)

# Optional: Call this when the round resets to clean up items and the list
func clear_items():
	spawned_items.clear()
	for child in get_children():
		if child.name.begins_with("Item Drop"):
			child.queue_free()
