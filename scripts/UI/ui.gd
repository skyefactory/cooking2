extends Control

@onready var menu = $Menu
@onready var disconnect_btn = $Menu/DisconnectBtn
@onready var settings_btn = $Menu/SettingsBtn
@onready var resume_btn = $Menu/ResumeBtn
@onready var manage_players_btn = $Menu/ManagePlayersBtn

var player: Player
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var players = get_tree().root.find_children("*", "Player", true, false)
	for p in players:
		if p.is_multiplayer_authority():
			player = p
			break
	if player:
		player.interact_label.connect(_on_interact_label)
	else:
		push_warning("Player node not found in scene. Interaction labels will not work.")
	
	menu.visible = false
	if Network.is_singleplayer:
		disconnect_btn.text = "Quit"
	disconnect_btn.pressed.connect(_on_disconnect_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	resume_btn.pressed.connect(_on_resume_pressed)
	manage_players_btn.pressed.connect(_on_manage_players_pressed)

func _process(_delta: float) -> void:
	if Input.is_action_just_released("pause"):
		if menu.visible:
			_on_resume_pressed()
		else:
			menu.visible = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_disconnect_pressed() -> void:
	if Network.is_singleplayer:
		get_tree().quit()
	else:
		Network.disconnect_from_server()
		get_tree().change_scene("res://scenes/main_menu.tscn")

func _on_settings_pressed() -> void:
	pass

func _on_resume_pressed() -> void:
	menu.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_manage_players_pressed() -> void:
	pass

func _on_interact_label(text: String, showText: bool) -> void:
	$InteractionLabel.text = text
	$InteractionLabel.visible = showText
