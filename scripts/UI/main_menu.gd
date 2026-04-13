extends Control

@onready var singleplayer_btn: Button = $SingleplayerBtn
@onready var multiplayer_btn: Button = $MultiplayerBtn
@onready var quit_btn: Button = $QuitBtn
@onready var settings_btn: Button = $SettingsBtn

@export var lobby_scene: PackedScene
@export var game_scene: PackedScene

const LOBBY_SCENE_PATH := "res://scenes/lobby.tscn"
const GAME_SCENE_PATH := "res://scenes/gamer.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	singleplayer_btn.pressed.connect(_on_singleplayer_btn_pressed)
	multiplayer_btn.pressed.connect(_on_multiplayer_btn_pressed)
	quit_btn.pressed.connect(_on_quit_btn_pressed)
	settings_btn.pressed.connect(_on_settings_btn_pressed)

	pass # Replace with function body.


func _on_singleplayer_btn_pressed() -> void:
	Network.is_singleplayer = true
	load_scene(game_scene, GAME_SCENE_PATH)

func _on_multiplayer_btn_pressed() -> void:
	Network.is_singleplayer = false
	load_scene(lobby_scene, LOBBY_SCENE_PATH)
	

func _on_quit_btn_pressed() -> void:
	get_tree().quit()

func _on_settings_btn_pressed() -> void:
	pass

func load_scene(scene: PackedScene, fallback_path: String = "") -> void:
	var scene_to_load := scene
	if scene_to_load == null and fallback_path != "":
		scene_to_load = load(fallback_path) as PackedScene

	if scene_to_load == null:
		return

	var err := get_tree().change_scene_to_packed(scene_to_load)
	if err != OK:
		push_error("Failed to change scene to %s (error: %d)" % [scene_to_load.resource_path, err])
