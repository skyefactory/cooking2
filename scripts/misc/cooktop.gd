extends Area3D

@export var rate_of_cook: float = 2.5 # how much the world items cook amount increases per second while on the cooktop.

var world_items: Array[WorldItem] = [] # the world items currently on the cooktop

func _process(delta: float) -> void:
	for item in world_items: # for each item
		item.cooked_amount += rate_of_cook * delta # increase the cook amount
		print("Cooking %s: %.2f%%" % [item.name, item.cooked_amount])
	pass

func _on_body_entered(body: Node) -> void:
	print("Body entered cooktop area: %s" % body.name)
	if body is WorldItem:
		world_items.append(body) # add the item to the list of items currently on the cooktop

func _on_body_exited(body: Node) -> void:
	if body is WorldItem:
		world_items.erase(body) # remove the item from the list of items currently on the cooktop
		
