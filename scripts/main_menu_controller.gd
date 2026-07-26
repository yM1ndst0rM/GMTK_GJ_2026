class_name MainMenu
extends Control


@export_file("*.tscn")
var game_scene_path: String

@onready var start_button: Button = (
	$ButtonContainer/VBoxContainer/StartButton
)

@onready var quit_button: Button = (
	$ButtonContainer/VBoxContainer/QuitButton
)


func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

	start_button.grab_focus()


func _on_start_button_pressed() -> void:
	if game_scene_path.is_empty():
		push_error("MainMenu: No game scene has been assigned.")
		return

	var error := get_tree().change_scene_to_file(game_scene_path)

	if error != OK:
		push_error(
			"MainMenu: Failed to load game scene. Error: %s"
			% error_string(error)
		)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
