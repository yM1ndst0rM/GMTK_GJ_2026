class_name GameManager
extends Node


signal game_started
signal game_finished(player_won: bool)


@export_category("References")

@export var snake_controller: SnakeController
@export var food_spawner: FoodSpawner
@export var snake_decay_timer: SnakeDecayTimer


var _game_over: bool = false


func _ready() -> void:
	if not _references_are_valid():
		return

	snake_controller.snake_crashed.connect(
		_on_snake_crashed
	)

	snake_decay_timer.decay_time_expired.connect(
		_on_snake_decay_time_expired
	)

	# Wait until all sibling nodes have completed _ready().
	call_deferred(&"start_new_game")


func _unhandled_input(event: InputEvent) -> void:
	if not _game_over:
		return

	if event.is_action_pressed(&"restart"):
		start_new_game()
		get_viewport().set_input_as_handled()


func _references_are_valid() -> bool:
	var valid := true

	if snake_controller == null:
		push_error(
			"GameManager: Snake Controller has not been assigned."
		)
		valid = false

	if food_spawner == null:
		push_error(
			"GameManager: Food Spawner has not been assigned."
		)
		valid = false

	if snake_decay_timer == null:
		push_error(
			"GameManager: Snake Decay Timer has not been assigned."
		)
		valid = false

	return valid


func start_new_game() -> void:
	# Stop and clear anything left over from the previous game.
	snake_controller.set_movement_enabled(false)
	snake_decay_timer.stop_countdown()
	food_spawner.stop_spawning()

	_game_over = false

	var snake_reset_successful: bool = (
		snake_controller.reset_snake()
	)

	if not snake_reset_successful:
		_finish_game(false)
		return

	# FoodSpawner now creates and maintains all configured
	# food types, including blood oranges.
	food_spawner.start_spawning()

	snake_decay_timer.start_countdown()
	snake_controller.set_movement_enabled(true)

	game_started.emit()


func is_game_over() -> bool:
	return _game_over


func _on_snake_crashed() -> void:
	_finish_game(false)


func _on_snake_decay_time_expired() -> void:
	if _game_over:
		return

	var removed_segment: bool = (
		snake_controller.remove_tail_segment()
	)

	if not removed_segment:
		_finish_game(false)


func _finish_game(player_won: bool) -> void:
	if _game_over:
		return

	_game_over = true

	snake_controller.set_movement_enabled(false)
	snake_decay_timer.stop_countdown()
	food_spawner.stop_spawning()

	game_finished.emit(player_won)

	## Not sure what we want to do here yet. 
	if player_won:
		print("You won!")
	else:
		print("Game over.")
