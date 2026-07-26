class_name GameOverScreen
extends CanvasLayer


@export var win_condition_label: Label
@export var restart_button: Button

@export_category("Text")
@export var win_text: String = "YOU WIN!"
@export var lose_text: String = "GAME OVER"


func _enter_tree() -> void:
	if not EventBus.game_ended.is_connected(_on_game_ended):
		EventBus.game_ended.connect(_on_game_ended)


func _exit_tree() -> void:
	if EventBus.game_ended.is_connected(_on_game_ended):
		EventBus.game_ended.disconnect(_on_game_ended)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if restart_button != null:
		restart_button.pressed.connect(
			_on_restart_pressed
		)


func _on_game_ended(
	player_won: bool
) -> void:
	if player_won:
		win_condition_label.text = win_text
	else:
		win_condition_label.text = lose_text

	visible = true
	get_tree().paused = true

	if restart_button != null:
		restart_button.grab_focus()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
