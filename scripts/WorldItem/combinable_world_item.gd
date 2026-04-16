class_name CombinableWorldItem extends WorldItem

var next: CombinableWorldItem = null
var previous: CombinableWorldItem = null

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var combine_area: Area3D = $CombineArea

var can_combine: bool = true
var combine_pending: bool = false
@export var stack_padding: float = 0.02

func _ready() -> void:
	combine_area.body_entered.connect(_on_combine_area_body_entered)
	combine_area.body_exited.connect(_on_combine_area_body_exited)
	super._ready() # run world item ready

func _on_combine_area_body_entered(incoming: Node) -> void:
	if not can_combine or next != null: # if this node can't combine or already has a next item, we cant add more
		return

	if not incoming is CombinableWorldItem: # make sure the incoming item is a combinable world item
		return

	if incoming == null: # null guard
		return
	if incoming == self: # self guard
		return
	if incoming.previous != null: # does the incoming item already have a previous item?
		return
	if incoming.held_by == null: # is the incoming item held by the player? We dont want to combine with items laying on the ground.
		return
	if combine_pending: # avoid queueing duplicate combines while waiting for deferred execution
		return

	# body_entered runs during physics; defer stack mutations/reparenting.
	combine_pending = true
	call_deferred("_deferred_attach_next", incoming)

func _on_combine_area_body_exited(_body: Node) -> void:
	pass

func _deferred_attach_next(incoming: CombinableWorldItem) -> void:
	combine_pending = false

	if not is_instance_valid(incoming):
		return
	if incoming == self:
		return
	if next != null:
		return
	if incoming.previous != null:
		return
	if incoming.held_by == null:
		return
	attach_next(incoming)

func attach_next(incoming: CombinableWorldItem) -> void:
	if next != null: # make sure next is null
		return

	var recipient_position := global_position
	var recipient_basis := global_basis

	var holder := incoming.held_by # get the player holding the item
	if holder and holder.held_item == incoming: # make sure the player is actually holding the incoming item
		holder.drop_held_item()

	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	pickup_allowd = false

	incoming.freeze = false
	incoming.linear_velocity = Vector3.ZERO # remove velocity
	incoming.angular_velocity = Vector3.ZERO

		

	# Keep stacked items from pushing each other while preserving collision with the world.
	add_collision_exception_with(incoming) # make sure this item doesn't collide with the incoming item
	incoming.add_collision_exception_with(self) # make sure the incoming item doesn't collide with this item

	incoming.global_basis = recipient_basis
	incoming.global_position = recipient_position + Vector3.UP * get_stack_offset(incoming)

	reparent(incoming) # incoming becomes the parent so players can keep stacking upward.
	global_basis = recipient_basis
	global_position = recipient_position

	next = incoming # set next
	incoming.previous = self # set incoming previous
	move_collision_shape_up()
	

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

func can_interact(interacting_player: Player) -> bool:
	# Only the top item in a stack should be directly interactable.
	if next != null:
		return false
	return super.can_interact(interacting_player)

func get_interaction_text(interacting_player: Player) -> String:
	if next != null:
		return ""
	return super.get_interaction_text(interacting_player)

func get_stack_offset(incoming: CombinableWorldItem) -> float: # function to get the offset for incoming items to stack
	return get_half_height(collision_shape) + get_half_height(incoming.collision_shape) + stack_padding 

func get_half_height(shape_node: CollisionShape3D) -> float: # gets the half height of a collision shape
	if shape_node == null or shape_node.shape == null: # if the collision is null, returnn
		return 0.0

	var shape := shape_node.shape
	# determine what type of shape it is and get the half height
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size.y * 0.5
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		return capsule.height * 0.5 + capsule.radius
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).height * 0.5

	return 0.2

func _process(_delta: float) -> void:
	can_combine = held_by == null

	if next and not is_instance_valid(next):
		next = null
	
	super._process(_delta) # run world item process

func move_collision_shape_up() -> void:
	if next:
		var collision_shapes = get_children()
		for child in collision_shapes:
			if child is CollisionShape3D:
				child.reparent(next)