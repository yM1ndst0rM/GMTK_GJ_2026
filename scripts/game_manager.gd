class_name GameManager
extends Node


signal game_started
signal game_finished(final_score: int, player_won: bool)

@export var snake_decay_timer: SnakeDecayTimer

@export_category("References")

@export var snake_controller: SnakeController

@export var food_spawner: FoodSpawner


var _game_over: bool = false


func _ready() -> void:
	if snake_controller == null:
		push_error(
			"GameManager: Snake Controller has not been assigned."
		)

		return

	if food_spawner == null:
		push_error(
			"GameManager: Food Spawner has not been assigned."
		)

		return

	snake_controller.snake_crashed.connect(
		_on_snake_crashed
	)

	snake_controller.food_consumed.connect(
		_on_food_consumed
	)
	
	if snake_decay_timer == null:
		push_error(
			"GameManager: Snake Decay Timer has not been assigned."
		)
		return

	snake_decay_timer.decay_time_expired.connect(
		_on_snake_decay_time_expired
	)

	# Ensures every sibling node has finished its _ready().
	call_deferred("start_new_game")

# Not sure if we want to have a dedicated button for restart but it's here just in case. 
func _unhandled_input(event: InputEvent) -> void:
	if (
		_game_over
		and event.is_action_pressed("restart")
	):
		start_new_game()
		get_viewport().set_input_as_handled()


func start_new_game() -> void:
	_game_over = false

	food_spawner.remove_food()

	var snake_reset_successful: bool = (
		snake_controller.reset_snake()
	)

	if not snake_reset_successful:
		_finish_game(false)
		return

	var food_spawned: bool = food_spawner.spawn_food(
		snake_controller.get_snake_cells()
	)

	if not food_spawned:
		_finish_game(true)
		return

	game_started.emit()
	
	snake_decay_timer.start_countdown()
	snake_controller.set_movement_enabled(true)

	snake_controller.set_movement_enabled(true)


func is_game_over() -> bool:
	return _game_over


func _on_food_consumed() -> void:
	if _game_over:
		return

	var food_spawned: bool = food_spawner.spawn_food(
		snake_controller.get_snake_cells()
	)

	if not food_spawned:
		_finish_game(true)


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

	game_finished.emit(
		player_won
	)

	#Not sure exactly what we want to do here yet. 
	if player_won:
		print(
			"You won!"
		)
	else:
		print(
			"Game over."
		)
