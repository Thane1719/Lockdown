class_name Items

extends Resource

@export var name : StringName
@export var weight = 1

@export_category("Item Orientation")
@export var position : Vector3
@export var rotation : Vector3
@export var scale : Vector3 = Vector3(1,1,1)

@export_category("Item Sway")
@export var sway_min : Vector2 = Vector2(-20.0,-20.0)
@export var sway_max : Vector2 = Vector2(20.0,20.0)
@export_range(0,0.2,0.01) var swaySpeedPosition : float = 0.07
@export_range(0,0.2,0.01) var swaySpeedRotation : float = 0.1
@export_range(0,0.25,0.01) var swayAmountPosition : float = 0.1
@export_range(0,50,0.1) var swayAmountRotation : float = 30

@export_category("Visual Settings")
@export var mesh : Mesh
@export var shadow : bool
