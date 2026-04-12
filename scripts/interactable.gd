class_name Interactable extends RefCounted

# Checks to see if the target is an interactable. Does this by first checking if the target 
# is valid, then if it has a valid interact method, then if it has a can interact method.
# if all checks pass, the target's can interact method is called to see if the player can interact with it.
static func can_interact(target: Node, player: Player) -> bool:
	if target == null:
		return false
	if not target.has_method("interact"):
		return false
	if target.has_method("can_interact"):
		return target.can_interact(player)
	return true

#used for defining the interact label that shows up. 
static func interaction_text(target: Node, player: Player) -> String:
	if target and target.has_method("get_interaction_text"):
		return str(target.get_interaction_text(player))
	return "Press E to interact"

# calls the interact method on the target if it is a valid interactable and the player can interact with it.
static func interact(target: Node, player: Player) -> void:
	if can_interact(target, player):
		target.interact(player)