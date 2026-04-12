class_name Player extends CharacterBody3D

@export_range(1.0, 40.0, 1.0) var speed: float = 10.0
@export_range(10.0, 400.0, 1.0) var acceleration: float = 100.0

@export_range(0.1, 3.0, 0.1) var jump_height: float = 1.0
@export_range(0.1, 3.0, 0.1) var camera_sensitivity: float = 1.0

@export_range(0.1, 2.0, 0.1) var run_multiplier: float = 2.0

var is_jumping: bool = false
var mouse_captured: bool = false

var grav: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var move_direction: Vector2 = Vector2.ZERO
var look_direction: Vector2 = Vector2.ZERO

var walk_velocity: Vector3 = Vector3.ZERO
var gravity_velocity: Vector3 = Vector3.ZERO
var jump_velocity: Vector3 = Vector3.ZERO

var held_item: WorldItem = null

var item_in_view: Node = null

signal interact_label(text: String, show: bool)
@onready var item_in_view_lbl: Label = get_node_or_null("/root/Gamer/UI/ItemInViewLbl")
@onready var held_item_socket: Node3D = $Arm/HeldItemSocket
@onready var arm: Node3D = $Arm

@onready var camera: Camera3D = $Camera

func _can_process_local_input() -> bool:
	return Network.is_singleplayer or is_multiplayer_authority()

func is_holding_item() -> bool:
	return held_item != null

func get_held_item() -> WorldItem:
	return held_item


func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func walk(delta: float, running: bool) -> Vector3:
	# Get the input vector for movement
	move_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_backwards") 
	# Calculate the forward direction based on the camera's orientation and the input vector
	var forward: Vector3 = camera.global_transform.basis * Vector3(move_direction.x, 0, move_direction.y) 
	# normalize the forward direction.
	var walk_direction: Vector3 = Vector3(forward.x,0,forward.z).normalized()
	# Move the walk velocity towards the target velocity based on the input and whether the player is running or not.
	walk_velocity = walk_velocity.move_toward(walk_direction * speed * move_direction.length() * (1.0 if not running else run_multiplier), acceleration * delta) 
	return walk_velocity

func gravity(delta: float) -> Vector3:
	gravity_velocity = Vector3.ZERO if is_on_floor() else gravity_velocity + Vector3.DOWN * grav * delta
	return gravity_velocity

func jump(delta: float) -> Vector3:
	if is_jumping:
		if is_on_floor():
			jump_velocity = Vector3(0, sqrt(4 * jump_height * grav),0)
			is_jumping = false
			return jump_velocity
	jump_velocity = Vector3.ZERO if is_on_floor() or is_on_ceiling_only() else jump_velocity.move_toward(Vector3.ZERO, grav * delta)
	return jump_velocity

func rotate_camera():
	rotation.y -= look_direction.x * camera_sensitivity
	camera.rotation.x = clamp(camera.rotation.x - look_direction.y * camera_sensitivity, -1.5, 1.5)
	if arm:
		arm.rotation.x = camera.rotation.x

func put_held_item_in_socket():
	if held_item and is_instance_valid(held_item) and held_item_socket:
		held_item.freeze = true
		held_item.get_node("CollisionShape3D").disabled = true
		held_item.reparent(held_item_socket)
		held_item.global_transform = held_item_socket.global_transform
		held_item.pickup_allowd = false

func drop_held_item():
	if held_item and is_instance_valid(held_item):
		held_item.freeze = false
		var scene := get_tree().current_scene
		if scene:
			held_item.reparent(scene)
		held_item.global_transform = held_item_socket.global_transform
		held_item.pickup_allowd = true
		held_item.get_node("CollisionShape3D").disabled = false
		held_item = null


func _ready() -> void:
	var is_local_player := _can_process_local_input()
	camera.current = is_local_player
	if is_local_player:
		capture_mouse()
	else:
		mouse_captured = false
	if arm:
		arm.hide()

func _unhandled_input(event: InputEvent) -> void:
	if not _can_process_local_input():
		return
	if event is InputEventMouseMotion:
		look_direction = event.relative * 0.001
		if mouse_captured: rotate_camera()

func _physics_process(delta: float) -> void:
	mouse_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if not _can_process_local_input():
		return
	
	var interact_result = interactable_in_view()
	if interact_result:
		set_item_in_view(interact_result)
	elif item_in_view:
		clear_item_in_view(item_in_view)
	item_in_view_lbl.text = "Item In View: %s \n 
	Held Item: %s \n
	Arm Rotation: %s \n, 
	Item Socket Pos: %s" % [item_in_view.name if item_in_view else "None", held_item.name if held_item else "None", arm.rotation if arm else "No Arm", held_item_socket.global_transform.origin if held_item_socket else "No Socket"]
	if Input.is_action_just_pressed("interact"):
		if item_in_view and Interactable.can_interact(item_in_view, self):
			Interactable.interact(item_in_view, self)
			if item_in_view == held_item:
				put_held_item_in_socket()
	if held_item and is_instance_valid(held_item):
		arm.show()
	else: arm.hide()

	if Input.is_action_just_pressed("drop_held_item"):
		if Network.is_singleplayer:
			drop_held_item()
		else:
			Network.request_drop()
	if Input.is_action_just_pressed("move_up"):
		is_jumping = true
	velocity = walk(delta, Input.is_action_pressed("move_run")) + gravity(delta) + jump(delta)
	move_and_slide()

func set_item_in_view(item: Node) -> void:
	if not is_instance_valid(item):
		return
	if not Interactable.can_interact(item, self):
		clear_item_in_view(item)
		return
	
	if item_in_view != item:
		item_in_view = item
		emit_signal("interact_label", Interactable.interaction_text(item_in_view, self), true)

func clear_item_in_view(item: Node) -> void:
	if item_in_view == item or (item_in_view and not is_instance_valid(item_in_view)):
		item_in_view = null
		emit_signal("interact_label", "", false)

func interactable_in_view(max_distance: float = 8.0) -> Node:
	var query = raycast_from_crosshair() # set up the ray query parameters for a raycast from the center of the screen
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 1 << 2 # only collide with physics layer 3 (bit index starts at 0)
	
	var result = get_world_3d().direct_space_state.intersect_ray(query) # perform the raycast and get the result

	if result and result.collider:
		var hit_distance = camera.global_position.distance_to(result.position)
		if hit_distance <= max_distance: #debugging
			return result.collider
	return null

func raycast_from_crosshair() ->PhysicsRayQueryParameters3D:

	var active_viewport := camera.get_viewport()
	var screen_center := active_viewport.get_visible_rect().get_center()
	
	#send out a ray from the center of the screen relative to where the camera is
	var ray_origin = camera.project_ray_origin(screen_center)
	var ray_direction = camera.project_ray_normal(screen_center)
	# set up the ray query parameters
	var query = PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * 1000.0
	)
	return query
