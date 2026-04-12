class_name WorldItem extends RigidBody3D

@export var id: int = -1
@export var item_name: String = "World Item"

@export var cooked_amount: float = 0.0
const DEFAULT_COOK_AMOUNT: float = 0.0
const MAX_COOK_AMOUNT: float = 200.0
@export_range(0.0, MAX_COOK_AMOUNT, 0.1) var perfect_cook_amount: float = 100.0 # The ideal cooking amount for this item.

@export var mesh_instance: MeshInstance3D
var material: ShaderMaterial = null
var pickup_allowd: bool = true

func resolve_material() -> void:
	if not mesh_instance:
		mesh_instance = get_node_or_null("MeshInstance3D")

	if not mesh_instance:
		material = null
		return

	var active_material: Material = mesh_instance.get_active_material(0)
	if active_material is ShaderMaterial:
		var override_material: Material = mesh_instance.get_surface_override_material(0)
		if override_material == null:
			# Use a unique runtime material so this item's values do not get lost on shared resources.
			var unique_material := (active_material as ShaderMaterial).duplicate() as ShaderMaterial
			mesh_instance.set_surface_override_material(0, unique_material)
			material = unique_material
		else:
			material = override_material as ShaderMaterial
	else:
		material = null

func sync_shader_values() -> void:
	if not material:
		return

	material.set_shader_parameter("cook_amount", cooked_amount)
	material.set_shader_parameter("perfect_cook_amount", perfect_cook_amount)
	material.set_shader_parameter("max_cook_amount", MAX_COOK_AMOUNT)
	material.set_shader_parameter("default_cook_amount", DEFAULT_COOK_AMOUNT)

func clamp_cook_amount():
	cooked_amount = clamp(cooked_amount, DEFAULT_COOK_AMOUNT, MAX_COOK_AMOUNT)
	perfect_cook_amount = clamp(perfect_cook_amount, DEFAULT_COOK_AMOUNT, MAX_COOK_AMOUNT)

func get_undercooked_percentage() -> float:
	clamp_cook_amount()

	if perfect_cook_amount <= DEFAULT_COOK_AMOUNT:
		return 0.0

	if cooked_amount >= perfect_cook_amount:
		return 0.0

	return clamp((perfect_cook_amount - cooked_amount) / perfect_cook_amount, 0.0, 1.0)

func get_overcooked_percentage() -> float:
	clamp_cook_amount()

	if perfect_cook_amount >= MAX_COOK_AMOUNT:
		return 0.0

	if cooked_amount <= perfect_cook_amount:
		return 0.0

	return clamp((cooked_amount - perfect_cook_amount) / (MAX_COOK_AMOUNT - perfect_cook_amount), 0.0, 1.0)

func can_interact(interacting_player: Player) -> bool:
	return pickup_allowd and not interacting_player.is_holding_item()

func get_interaction_text(interacting_player: Player) -> String:
	if pickup_allowd and not interacting_player.is_holding_item():
		return "Press E to pick up %s" % item_name
	else:
		return ""

func interact(interacting_player: Player) -> void:
	if can_interact(interacting_player):
		if !Network.is_singleplayer:
			var path = get_path()
			Network.request_pickup(path)
		else:
			pickup_allowd = false
			interacting_player.held_item = self
			self.freeze = true
			self.reparent(interacting_player.held_item_socket)
			self.global_transform = interacting_player.held_item_socket.global_transform

func _ready() -> void:
	clamp_cook_amount()
	resolve_material()
	if not material:
		push_warning("WorldItem has no ShaderMaterial on mesh_instance material slot 0: %s" % get_path())
		return
	print("Initialized WorldItem: %s with material: %s" % [get_path(), material])
	sync_shader_values()

func _process(delta: float) -> void:
	clamp_cook_amount()
	sync_shader_values()
