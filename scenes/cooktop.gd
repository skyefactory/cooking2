extends Area3D

@export var rate_of_cook: float = 2.5

var world_items: Array[WorldItem] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	for item in world_items:
		item.cooked_amount += rate_of_cook * delta
		print("Cooking %s: %.2f%%" % [item.name, item.cooked_amount])
	pass

func _on_body_entered(body: Node) -> void:
	print("Body entered cooktop area: %s" % body.name)
	if body is WorldItem:
		world_items.append(body)

func _on_body_exited(body: Node) -> void:
	if body is WorldItem:
		world_items.erase(body)
		
