extends Node3D
var damage : int = 25
var dangerous = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
@rpc("reliable", "any_peer")
func becomeDangerous(): #this code sucks and if i can find a better way to do it i will
	var material = $MeshInstance3D.get_active_material(0)
	if dangerous == true:
		dangerous = false
		material.albedo_color = Color(0.133, 1.0, 0.0, 1.0)      
		print ("Death cube is off")
	elif dangerous == false:
		dangerous = true   
		material.albedo_color = Color(1.0, 0.0, 0.741, 1.0)          
		print ("Death cube has been turned on")
	rpc("updateCube")
@rpc("reliable", "any_peer")
func updateCube():
	var material = $MeshInstance3D.get_active_material(0)
	if dangerous == true:
		dangerous = false
		material.albedo_color = Color(0.133, 1.0, 0.0, 1.0)      
		print ("Death cube is off")
	elif dangerous == false:
		dangerous = true   
		material.albedo_color = Color(1.0, 0.0, 0.741, 1.0)          
		print ("Death cube has been turned on")

func _on_death_cube_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if dangerous == true:
			if body.has_method("take_damage"):
				body.take_damage(damage, "bullet")
		elif dangerous == false:
			print ("everythings fine")
	else: pass
