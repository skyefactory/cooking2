extends Node

#pass multiplayer signals through this node.
signal connected_to_server
signal connection_failed
signal server_disconnected
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

const MAX_PEERS: int = 5

var is_singleplayer: bool = false

# the peer of this instance.
var peer: ENetMultiplayerPeer = null
# is this instance the server?
var is_server: bool = false
var reject_new_clients: bool = false

# the path to the game scene to load when the game starts.
const GAME_SCENE_PATH: String = "res://scenes/gamer.tscn"

func reset() -> void:
	# clean up the peer and reset state
	if peer:
		peer.close()
	peer = null
	is_server = false
	reject_new_clients = false
	multiplayer.multiplayer_peer = null

func disconnect_client(peer_id: int, force: bool = true) -> void:
	if not is_server or peer == null:
		return
	peer.disconnect_peer(peer_id, force)

func set_reject_new_clients(reject: bool, disconnect_existing: bool = false) -> void:
	if not is_server or peer == null:
		return
	reject_new_clients = reject
	if disconnect_existing:
		for id in multiplayer.get_peers():
			peer.disconnect_peer(id, true)

# verify that a port number is valid (0-65535)
func verify_port(port: int) -> bool:
	return port >= 0 and port <= 65535

func _ready() -> void:
	_bind_multiplayer_signals()

# connect all multiplayer signals to the passthrough signals.
func _bind_multiplayer_signals() -> void:
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

#called when the player chooses host from the menu.
func host(port: int) -> int:
	_bind_multiplayer_signals()
	is_server = true # this is the server instance
	peer = ENetMultiplayerPeer.new() #setup peer
	if not verify_port(port): # check that port is valid
		print("Invalid port number: %d" % [port])
		return ERR_INVALID_PARAMETER
	# create the server and start listening
	var err_code = peer.create_server(port)
	if err_code == OK:
		multiplayer.multiplayer_peer = peer
		print("Server listening on port %d" % [port])
	else:
		print("Failed to create server: %s" % [err_code])
	return err_code

#called when the player chooses join from the menu.
func join(ip: String, port: int) -> int:
	_bind_multiplayer_signals()
	is_server = false # this is a client instance
	peer = ENetMultiplayerPeer.new() #setup peer
	if not verify_port(port): # check that port is valid
		print("Invalid port number: %d" % [port])
		return ERR_INVALID_PARAMETER
	# connect to the server
	var err_code = peer.create_client(ip, port)
	if err_code == OK:
		multiplayer.multiplayer_peer = peer
		print("Connected to server at %s:%d" % [ip, port])
	else:
		print("Failed to connect to server: %s" % [err_code])
	return err_code

func _on_connected_to_server() -> void:
	emit_signal("connected_to_server")

func _on_connection_failed() -> void:
	emit_signal("connection_failed")

func _on_server_disconnected() -> void:
	emit_signal("server_disconnected")

func _on_peer_connected(id: int) -> void:
	if is_server and reject_new_clients and peer:
		peer.disconnect_peer(id, true)
		return
	emit_signal("peer_connected", id)

func _on_peer_disconnected(id: int) -> void:
	emit_signal("peer_disconnected", id)

# this function is called by the server to spawn a player. It sends an RPC to all clients to spawn the player on their end.
func spawn_player(player_scene: PackedScene, spawn_position: Vector3) -> void:
	var player = player_scene.instantiate()
	player.position = spawn_position
	get_tree().current_scene.add_child(player)

# this function is called by the server to start the game. It sends an RPC to all clients to load the game scene.
func start_game(_client_list: Array) -> void:
	rpc("load_game_scene")

# this function is called on all clients when the server starts the game. It loads the game scene and frees the lobby scene.
@rpc("authority", "call_local", "reliable")
func load_game_scene() -> void:
	var game_scene = preload(GAME_SCENE_PATH)
	var game = game_scene.instantiate()
	var current_scene = get_tree().current_scene
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	if current_scene:
		current_scene.queue_free()

func _find_player_by_id(player_id: int) -> Player:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for node in scene.find_children("Player_%d" % player_id, "Player", true, false):
		if node is Player:
			return node
	return null

func _find_world_item(item_path: NodePath) -> WorldItem:
	var item_node := get_node_or_null(item_path)
	if item_node is WorldItem:
		return item_node as WorldItem

	var scene := get_tree().current_scene
	if scene == null:
		return null

	if item_path.get_name_count() <= 0:
		return null

	var item_name := str(item_path.get_name(item_path.get_name_count() - 1))
	for node in scene.find_children(item_name, "WorldItem", true, false):
		if node is WorldItem:
			return node as WorldItem

	return null

func request_pickup(item_path: NodePath) -> void:
	if multiplayer.is_server():
		pickup_item(item_path)
	else:
		rpc_id(1, "pickup_item", item_path)

@rpc("any_peer", "reliable")
func pickup_item(itemPath: NodePath):
	if is_server:
		var player_id = multiplayer.get_remote_sender_id()
		if player_id == 0:
			player_id = multiplayer.get_unique_id()
		var item = _find_world_item(itemPath)
		var player = _find_player_by_id(player_id)
		if item and is_instance_valid(item) and player and player.held_item == null and Interactable.can_interact(item, player):
			rpc("apply_pickup", item.get_path(), player_id)

@rpc("authority", "call_local", "reliable")
func apply_pickup(itemPath: NodePath, playerId: int):
	var item = _find_world_item(itemPath)
	var player = _find_player_by_id(playerId)
	if item == null or not is_instance_valid(item):
		return
	if player == null:
		return
	item.freeze = true #prevent physics from acting on the item
	# disable collisions
	item.get_node("CollisionShape3D").disabled = true
	item.reparent(player.held_item_socket)
	item.global_transform = player.held_item_socket.global_transform
	player.held_item = item
	item.pickup_allowd = false

func request_drop() -> void:
	if multiplayer.is_server():
		drop_item()
	else:
		rpc_id(1, "drop_item")

@rpc("any_peer", "reliable")
func drop_item():
	if is_server:
		var player_id = multiplayer.get_remote_sender_id()
		if player_id == 0:
			player_id = multiplayer.get_unique_id()
		var player = _find_player_by_id(player_id)
		if player and player.held_item:
			rpc("apply_drop", player_id)

@rpc("authority", "call_local", "reliable")
func apply_drop(playerId: int):
	var player = _find_player_by_id(playerId)
	if player == null:
		return
	if player.held_item and is_instance_valid(player.held_item):
		player.held_item.freeze = false
		var scene := get_tree().current_scene
		if scene:
			player.held_item.reparent(scene)
		player.held_item.global_transform = player.held_item_socket.global_transform
		player.held_item.pickup_allowd = true
		player.held_item.get_node("CollisionShape3D").disabled = false
		player.held_item = null


func disconnect_from_server() -> void:
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
