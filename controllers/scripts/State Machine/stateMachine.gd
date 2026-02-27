class_name StateMachine

extends Node

@export var currentState : State
var states: Dictionary = {}

func _ready():
	if not is_multiplayer_authority(): return
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.transition.connect(onChildTransition)
		else:
			push_warning("State machine contains incompatible child node")
	await owner.ready
	currentState.enter(null)

func _process(delta):
	if not is_multiplayer_authority(): return
	currentState.update(delta)
	
func _physics_process(delta):
	if not is_multiplayer_authority(): return
	Global.debug.addProperty("Current State", currentState, 4)
	currentState.physics_update(delta)
	
func onChildTransition(new_state_name: StringName):
	if not is_multiplayer_authority(): return
	var newState = states.get(new_state_name)
	if newState != null:
		if newState != currentState:
			currentState.exit()
			newState.enter(currentState)
			currentState = newState
	else:
		push_warning("State does not exist HELP!!")
