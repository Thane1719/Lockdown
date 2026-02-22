@tool

extends Node


var player
var playerPoints = 0:
	set(value):
		playerPoints = value
		updatePoints()
var playerHealth = 100:
	set(value):
		healthLabel.text = str(value)
		playerHealth = value
var playerCamera
var debug
var weaponManager
var reserveLabel : Label
var clipLabel : Label
var pointsLabel : Label
var healthLabel: Label
var interactionLabel: Label

var myCurrentTeam : String

func updateLabels(clipAmmo, reserveAmmo):
	clipLabel.text = str(clipAmmo)
	reserveLabel.text = str(reserveAmmo)

func updatePoints():
	pointsLabel.text = str(playerPoints)

func updateHealth():
	#DEPRECATED FUNCTION but still here for old code
	healthLabel.text = str(playerHealth)

# if status is true, increases the size of the window and scales on-screen elements to window size
# allows for better viewing on retina (or similar resolution) displays
func high_resolution_display_mode(status):
	if status == true:
		if OS.get_name()=="macOS": # Checks if MacOS. Unsure if required.
			print("resizine window")
			get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT # scales UI elements to window size.
			DisplayServer.window_set_size(Vector2i(2560, 1440)) # Sets windows dimensions
			get_window().move_to_center() # Centres the screen

# Called when the node enters the scene tree for the first time.
func _ready():
	high_resolution_display_mode(true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
