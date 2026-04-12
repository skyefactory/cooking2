class_name CombinableWorldItem extends WorldItem

var next: CombinableWorldItem = null
var previous: CombinableWorldItem = null

func get_list() -> Array:
	# first, find the head of the list
	var list: Array = []
	var current: CombinableWorldItem = self

	while current.previous:
		current = current.previous
	# next, go from the head to the tail.
	list.append(current)
	while current.next:
		current = current.next
		list.append(current)
	return list

func set_next(item: CombinableWorldItem) -> void:
	next = item
	if item:
		item.previous = self

func set_previous(item: CombinableWorldItem) -> void:
	previous = item
	if item:
		item.next = self