class_name Lobby extends Control

#UI elements
@onready var host_btn: Button = $HostBtn
@onready var join_btn: Button = $JoinBtn
@onready var ip_input: LineEdit = $IPInput
@onready var port_input: LineEdit = $PortInput
@onready var submit_ip_port_btn: Button = $SubmitIPPortBtn
@onready var submit_port_btn: Button = $SubmitPortBtn
@onready var start_btn: Button = $StartBtn
@onready var client_list: ItemList = $ClientList
@onready var client_list_lbl: Label = $ClientListLbl
@onready var client_amt_lbl: Label = $ClientAmtLbl
@onready var connecting_lbl: Label = $ConnectingLbl
@onready var status_lbl: Label = $StatusLbl
@onready var reset_btn: Button = $ResetBtn
@onready var bg1: TextureRect = $BG1
@onready var bg2: TextureRect = $BG2

#default port to host on or connect to
const DEFAULT_PORT: int = 42069
#how much time to wait before considering a connection attempt failed
const CONNECTION_TIMEOUT: float = 5.0

#Lobby state variables
enum LobbyMode {
	MENU, # choose host or join
	HOST_SETUP, #chose host
	JOIN_SETUP, # chose join
	HOST_WAIT, # waiting to start game as host
	CLIENT_CONNECT # connecting to host as client
}

var mode: LobbyMode = LobbyMode.MENU # default to menu mode

var host_port: int = DEFAULT_PORT # default port to host on
var is_listening: bool = false # is the server active and listening for connections
var clients: int = 0 # number of connected clients
var client_ids: Array[int] = [] # list of connected client IDs

var ip: String = "" # IP to connect to as client
var port: int = DEFAULT_PORT # port to connect to as client
var client_connecting: bool = false # is the client currently trying to connect to a server
var client_connected: bool = false # is the client currently connected to a server
var connection_failed: bool = false # did the connection attempt fail
var connection_timer: float = 0.0 # timer to track how long we've been trying to connect for
var dots: int = 0 # number of dots to show in the "Connecting..." label (0-3)
var dot_timer: float = 0.0 # timer to track when to add another dot to the "Connecting..." label

func _ready() -> void:
	#connect multiplayer signals from Network.gd to this lobby scene
	bind_network_signals()
	#connect button signals
	host_btn.pressed.connect(_on_host_btn_pressed)
	join_btn.pressed.connect(_on_join_btn_pressed)
	submit_ip_port_btn.pressed.connect(_on_submit_ip_port_btn_pressed)
	submit_port_btn.pressed.connect(_on_submit_port_btn_pressed)
	start_btn.pressed.connect(_on_start_btn_pressed)
	reset_btn.pressed.connect(_on_reset_btn_pressed)

	#initialize line edit fields
	ip_input.text = ""
	port_input.text = str(DEFAULT_PORT)
	#set mode to menu to show host/join options
	set_mode(LobbyMode.MENU)

func _process(delta: float) -> void:
	# if the client is trying to connect, update the connecting label, check for timeout, and show the debug status
	if mode == LobbyMode.CLIENT_CONNECT:
		iterate_dots(delta)
		connection_timeout(delta)
		update_debug_status()

func _exit_tree() -> void:
	unbind_network_signals()

func set_mode(new_mode: LobbyMode) -> void:
	mode = new_mode 

	# setup comparisons for which mode we're in to simplify visibility logic
	var in_menu: bool = mode == LobbyMode.MENU
	var in_host_setup: bool = mode == LobbyMode.HOST_SETUP
	var in_join_setup: bool = mode == LobbyMode.JOIN_SETUP
	var in_host_wait: bool = mode == LobbyMode.HOST_WAIT
	var in_client_connect: bool = mode == LobbyMode.CLIENT_CONNECT

	#the host and join buttons should only be visible in the main menu
	host_btn.visible = in_menu
	join_btn.visible = in_menu
	bg1.visible = in_menu
	bg2.visible = not in_menu

	# the IP and port input fields should only be visible when setting up to join a game, but the port input should also be visible when setting up to host
	ip_input.visible = in_join_setup
	port_input.visible = in_host_setup or in_join_setup
	submit_ip_port_btn.visible = in_join_setup
	submit_port_btn.visible = in_host_setup

	# the client list and start button should only be visible when hosting and waiting for players
	start_btn.visible = in_host_wait
	client_list.visible = in_host_wait
	client_list_lbl.visible = in_host_wait
	client_amt_lbl.visible = in_host_wait

	# the connecting label should only be visible when trying to connect as a client, and the reset button should only be visible in that case if the connection attempt failed
	connecting_lbl.visible = in_client_connect
	status_lbl.visible = in_client_connect
	reset_btn.visible = in_client_connect and connection_failed

	# if we're in the host wait state, update the connecting label to show the port we're hosting on and disable the start button if there are no clients connected
	if in_host_wait:
		connecting_lbl.text = "Hosting on port %d" % [host_port]
		start_btn.disabled = clients == 0

func _on_host_btn_pressed() -> void:
	set_mode(LobbyMode.HOST_SETUP) # set mode to host
	port_input.text = str(DEFAULT_PORT) # set the port input to the default port for hosting

func _on_join_btn_pressed() -> void:
	set_mode(LobbyMode.JOIN_SETUP) # set mode to join
	ip_input.text = "" # clear the IP input field
	port_input.text = str(DEFAULT_PORT) # set the port input to the default port for joining

func _on_submit_port_btn_pressed() -> void:
	var parsed_port := parse_port(port_input.text) # check that the port is valid.
	if parsed_port == -1:
		print("Invalid port number: %s" % [port_input.text])
		return

	Network.reset() # clear any existing network state before hosting
	host_port = parsed_port # set the host port to the parsed port number
	clients = 0 # reset client count
	client_ids.clear() # clear client ID list
	client_amt_lbl.text = "0" # reset client count label
	update_client_list() # clear client list UI

	var err_code = Network.host(host_port) # try to start hosting on the specified port
	if err_code != OK: # if there was an error, print it and return to the host setup screen
		print("Failed to create server: %s" % [err_code])
		Network.reset()
		return

	is_listening = true # set listening state to true so we can start accepting connections
	set_mode(LobbyMode.HOST_WAIT) # switch to the host wait mode to show the client list and start button

func _on_submit_ip_port_btn_pressed() -> void:
	var input_ip = ip_input.text.strip_edges() # get the IP input and trim whitespace from the edges
	var parsed_port: int = parse_port(port_input.text)

	# check for empty IP
	if input_ip == "":
		print("IP cannot be empty.")
		return
	# check for valid port
	if parsed_port == -1:
		print("Invalid port number: %s" % [port_input.text])
		return

	Network.reset() # clear any existing network state before trying to connect
	ip = input_ip # set the IP to connect to
	port = parsed_port # set the port to connect to
	client_connecting = false # reset client connection states
	client_connected = false 
	connection_failed = false
	connection_timer = 0.0
	dot_timer = 0.0
	dots = 0
	connecting_lbl.text = "Connecting"
	reset_btn.hide()

	set_mode(LobbyMode.CLIENT_CONNECT) # switch to the client connect mode to show the connecting label
	connect_to_server() # attempt to connect to the server with the specified IP and port

func _on_start_btn_pressed() -> void:
	if mode != LobbyMode.HOST_WAIT:
		return
	Network.start_game(client_ids)

func _on_reset_btn_pressed() -> void:
	if mode != LobbyMode.CLIENT_CONNECT:
		return
	Network.reset()
	connection_failed = false
	client_connected = false
	connect_to_server()

func connect_to_server() -> void:
	# if we're already trying to connect or are connected or the connection has already failed, don't do anything
	if client_connecting or client_connected or connection_failed:
		return

	connection_timer = 0.0
	dot_timer = 0.0
	dots = 0
	connecting_lbl.text = "Connecting"
	reset_btn.hide()
	client_connecting = true
	var err_code = Network.join(ip, port) # attempt to connect to the server with the specified IP and port

	if err_code != OK: # if there was an error starting the connection attempt, print it and show the reset button
		print("Failed to create client: %s" % [err_code])
		connection_failed = true
		client_connecting = false
		_on_connection_failed()
	else:
		print("Connecting to server at %s:%d..." % [ip, port])

# ran when a client successfully connects to the server
func _on_connected_to_server() -> void:
	if mode != LobbyMode.CLIENT_CONNECT: # if we're not in the client connect mode, we shouldn't be getting this signal, so ignore it
		return
	print("Successfully connected to server!")
	connecting_lbl.text = "Connected to server!" # update the connecting label to show that we've connected
	client_connected = true
	client_connecting = false
	reset_btn.hide()

# ran when a client fails to connect to the server (either due to an error or a timeout)
func _on_connection_failed() -> void:
	if mode != LobbyMode.CLIENT_CONNECT: # if we're not in the client connect mode, we shouldn't be getting this signal, so ignore it
		return
	print("Failed to connect to server.")
	connecting_lbl.text = "Failed to connect to server."
	connection_failed = true
	client_connecting = false
	reset_btn.show()

# ran when the client is disconnected from the server (either by the server shutting down or the client losing connection)
func _on_server_disconnected() -> void:
	if mode != LobbyMode.CLIENT_CONNECT: # if we're not in the client connect mode, we shouldn't be getting this signal, so ignore it
		return
	print("Disconnected from server.")
	connecting_lbl.text = "Disconnected from server."
	client_connected = false
	connection_failed = true
	reset_btn.show()

# ran when the server receieves a new client connection
func _on_peer_connected(id: int) -> void:
	if mode != LobbyMode.HOST_WAIT or not is_listening: # if we're not in the host wait mode or we're not currently listening for connections, we shouldn't be getting this signal, so ignore it
		return
	clients += 1 # increment client count
	client_ids.append(id) # add the new client's ID to the list of connected client IDs
	client_amt_lbl.text = "%d" % [clients] # update the client count label
	update_client_list() # update the client list UI to show the new client
	start_btn.disabled = clients == 0
	print("Peer connected with ID: %d" % [id])

	#check to see if we should set connections to reject if we have reached the max number of allowed clients
	if clients >= Network.MAX_PEERS:
		Network.set_reject_new_clients(true, false)
		print("Max clients reached, rejecting new connections.")
	else:		
		Network.set_reject_new_clients(false, false)

#ran when the server detects that a client has disconnected
func _on_peer_disconnected(id: int) -> void:
	if mode != LobbyMode.HOST_WAIT or not is_listening: # if we're not in the host wait mode or we're not currently listening for connections, we shouldn't be getting this signal, so ignore it
		return

	var index := client_ids.find(id) # find the index of the disconnected client's ID in the list of connected client IDs
	if index != -1: # if the ID was found in the list, remove it
		client_ids.remove_at(index)
	clients = max(0, clients - 1) # decrement client count but don't let it go below 0
	client_amt_lbl.text = "%d" % [clients] # update the client count label
	update_client_list() # update the client list UI to remove the disconnected client
	start_btn.disabled = clients == 0 # disable the start button if there are no clients connected
	print("Peer disconnected with ID: %d" % [id])

func update_client_list() -> void:
	client_list.clear() # clear the client list UI
	for id in client_ids: # add each connected client's ID to the client list UI
		client_list.add_item("Client %d" % [id]) # display the client's ID in the list


func iterate_dots(delta: float) -> void:
	if not client_connecting:
		return
	dot_timer += delta
	if dot_timer >= 0.5:
		dot_timer = 0.0
		dots = (dots + 1) % 4
		connecting_lbl.text = "Connecting"
		for i in range(dots):
			connecting_lbl.text += "."

# iterates the connection timeout and calls on connection failed when it elapses
func connection_timeout(delta: float) -> void:
	if not client_connecting:
		return
	connection_timer += delta
	if connection_timer >= CONNECTION_TIMEOUT:
		print("Connection timed out!")
		_on_connection_failed()

# update the debug status label with the current IP, port, and connection status
func update_debug_status() -> void:
	if status_lbl:
		var peer_status = str(Network.peer.get_connection_status()) if Network.peer else "No Peer"
		status_lbl.text = "IP: %s, Port: %d Status: %s" % [ip, port, peer_status]

func parse_port(raw: String) -> int:
	if raw == "": # is the port empty
		return -1
	if not raw.is_valid_int(): # is the port all numeric
		return -1
	var parsed := int(raw) # parse the port to an integer
	if not Network.verify_port(parsed): # is the port in the valid range
		return -1
	return parsed # return the parsed port if all checks passed

#connect all the signals from network.gd 
func bind_network_signals() -> void:
	if not Network.connected_to_server.is_connected(_on_connected_to_server):
		Network.connected_to_server.connect(_on_connected_to_server)
	if not Network.connection_failed.is_connected(_on_connection_failed):
		Network.connection_failed.connect(_on_connection_failed)
	if not Network.server_disconnected.is_connected(_on_server_disconnected):
		Network.server_disconnected.connect(_on_server_disconnected)
	if not Network.peer_connected.is_connected(_on_peer_connected):
		Network.peer_connected.connect(_on_peer_connected)
	if not Network.peer_disconnected.is_connected(_on_peer_disconnected):
		Network.peer_disconnected.connect(_on_peer_disconnected)
		
#disconnect all the signals from network.gd
func unbind_network_signals() -> void:
	if Network.connected_to_server.is_connected(_on_connected_to_server):
		Network.connected_to_server.disconnect(_on_connected_to_server)
	if Network.connection_failed.is_connected(_on_connection_failed):
		Network.connection_failed.disconnect(_on_connection_failed)
	if Network.server_disconnected.is_connected(_on_server_disconnected):
		Network.server_disconnected.disconnect(_on_server_disconnected)
	if Network.peer_connected.is_connected(_on_peer_connected):
		Network.peer_connected.disconnect(_on_peer_connected)
	if Network.peer_disconnected.is_connected(_on_peer_disconnected):
		Network.peer_disconnected.disconnect(_on_peer_disconnected)
