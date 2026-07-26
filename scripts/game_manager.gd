class_name GameManager
extends Node

@export_category("References")

var _game_over: bool = false

func _ready() -> void:
	if !EventBus.villager_killed.is_connected(_on_villager_died) :
		EventBus.villager_killed.connect(_on_villager_died)
	
	if !EventBus.snake_health_changed.is_connected(_on_snake_health_changed) :
		EventBus.snake_health_changed.connect(_on_snake_health_changed)

	if !EventBus.unrecoverable_error_encountered.is_connected(_on_unrecoverable_error_encountered) :
		EventBus.unrecoverable_error_encountered.connect(_on_unrecoverable_error_encountered)

	# Ensures every sibling node has finished its _ready().
	start_new_game.call_deferred()

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
	EventBus.game_started.emit()


func is_game_over() -> bool:
	return _game_over


func _on_snake_health_changed(old_health: int, health: int) -> void:
	if health <= 0:
		_finish_game(false)


func _finish_game(player_won: bool) -> void:
	if _game_over:
		return

	_game_over = true

	EventBus.game_ended.emit(player_won)

	#Not sure exactly what we want to do here yet. 
	#Move to effect probably
	if player_won:
		print(
			"You won!"
		)
	else:
		print(
			"Game over."
		)
		

func _on_villager_died(_ignored_: Vector2i, remaining_villager_count: int):
	if remaining_villager_count == 0:
		_finish_game(true)
		
func _on_unrecoverable_error_encountered(message: String):
	push_error("Unrecoverable error occured: ", message)
	if(!_game_over):
		_finish_game(false)
