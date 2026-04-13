class_name PlayerSpawner extends Node
@export var player_scene: PackedScene
@export var spawn_points: Array[Node3D]
@export var menu_scene: PackedScene

@export var player_models: Array[PackedScene] # models to add to the player_scene to give each player a different model, 5 in total.
var used_models: Array[PackedScene] = [] # models that have been used, to ensure each player gets a different model.
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Network.is_server: # if we are the server, we need to spawn a player for ourselves and for each client that is already connected.
		rpc("spawn_player", multiplayer.get_unique_id(), 0)
		var i = 1
		for id in multiplayer.get_peers():
			rpc("spawn_player", id, i)
			i += 1
		
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	elif !Network.is_server and !Network.is_singleplayer:
		multiplayer.server_disconnected.connect(_on_disconnected_from_server)
	
	if Network.is_singleplayer: # if we are in singleplayer mode, we just spawn a single player for the local user.
		spawn_singleplayer_player()
	
	# called when a client disconnects from the server
func _on_disconnected_from_server() -> void:
	print("Disconnected from server.")
	get_tree().change_scene_to_packed(menu_scene)

@rpc("authority", "call_local", "reliable")
func spawn_player(id: int, spawn_point: int) -> void: # spawns a player with the given ID at the given spawn point. The server calls this function on all clients when a new player joins, and also calls it for itself when the game starts.
	if spawn_point < 0 or spawn_point >= spawn_points.size():
		push_warning("Invalid spawn point %d for player %d" % [spawn_point, id])
		return

	print("Spawning player with ID: %d at spawn point %d" % [id, spawn_point])
	var spawn: Node3D = spawn_points[spawn_point]
	var player: Player = player_scene.instantiate()
	player.name = "Player_%d" % id
	if id == 1:
		player.get_node("Halo").visible = true
	else:
		player.get_node("Halo").visible = false
	player.set_meta("ID", id)
	player.set_multiplayer_authority(id, true)

	# Assign a unique model to the player
	if player_models.size() > 0:
		var model_scene = player_models.pop_front()
		used_models.append(model_scene)
		var model_instance = model_scene.instantiate()
		model_instance.name = "PlayerModel"
		player.add_child(model_instance)

	var synchronizer: MultiplayerSynchronizer = player.get_node_or_null("MultiplayerSynchronizer")
	if synchronizer:
		synchronizer.set_multiplayer_authority(id)
	else:
		push_warning("Player scene is missing a MultiplayerSynchronizer node.")

	add_child(player)
	player.global_position = spawn.global_position


func spawn_singleplayer_player() -> void:
	var spawn: Node3D = spawn_points[0]
	var player: Player = player_scene.instantiate()
	player.name = "Player"
	add_child(player)
	player.global_position = spawn.global_position
	
func _on_peer_disconnected(id: int) -> void:
	for node in get_children():
		if node is Player and node.has_meta("ID") and node.get_meta("ID") == id:
			node.queue_free()
