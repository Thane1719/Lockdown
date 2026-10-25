extends StaticBody3D


@export var health = 100

@rpc("any_peer", "call_local")
func take_damage(damage, type, team):
	if type != "trap" and team == "Robber":
		health -= damage
	
	if health <= 0:
		rpc("deleteTrap")

@rpc("any_peer", "call_local")
func deleteTrap():
	get_parent().queue_free()
