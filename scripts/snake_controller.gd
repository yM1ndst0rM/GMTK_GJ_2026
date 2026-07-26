class_name SnakeController
extends Node

const MILLIS_IN_SECOND: float = 1000.0

@export_category("References")

@export var world_grid: WorldGrid
@export var snake_renderer: SnakeRenderer

@export_category("Snake Length")

## The head counts as one segment.
@export_range(1, 100, 1)
var minimum_snake_length: int = 1

@export_range(1, 100, 1)
var starting_snake_length: int = 5

@export_category("Starting Position")

@export var starting_head_cell: Vector2i = Vector2i(32, 32)


@export_category("Movement")

@export_range(50, 2000, 10)
var millis_per_move: int = 150

@export_range(1, 2, .01) var max_speed_time_scale: float = 1.5
@export_range(.01, 1, .01) var min_speed_time_scale: float = .5

@export var movement_timer: Timer

var _snake_cells: Array[Vector2i] = []

# Used like a HashSet for fast self-collision checks.
var _occupied_cells: Dictionary = {}

var _direction: Vector2i = Vector2i.RIGHT
var _queued_direction: Vector2i = Vector2i.RIGHT

var _movement_enabled: bool = false

var _captured_cells: Dictionary[Vector2i,  bool] = {}
var _current_health_change: int  = 0
var _current_speed_effect_modifier: int = 0

func _enter_tree() -> void:
	if !EventBus.game_started.is_connected(_on_game_started):
		EventBus.game_started.connect(_on_game_started)
	
	if !EventBus.game_ended.is_connected(_on_game_ended):
		EventBus.game_ended.connect(_on_game_ended)
		
	if !EventBus.interaction_triggered_health_change.is_connected(_on_health_change_interaction):
		EventBus.interaction_triggered_health_change.connect(_on_health_change_interaction)

	if !EventBus.interaction_triggered_snake_speed_effect.is_connected(_on_speed_effect_applied_interaction):
		EventBus.interaction_triggered_snake_speed_effect.connect(_on_speed_effect_applied_interaction)

func _exit_tree() -> void:
	if EventBus.game_started.is_connected(_on_game_started):
		EventBus.game_started.disconnect(_on_game_started)

	if EventBus.game_ended.is_connected(_on_game_ended):
		EventBus.game_ended.disconnect(_on_game_ended)
		
	if EventBus.interaction_triggered_health_change.is_connected(_on_health_change_interaction):
		EventBus.interaction_triggered_health_change.disconnect(_on_health_change_interaction)

	if EventBus.interaction_triggered_snake_speed_effect.is_connected(_on_speed_effect_applied_interaction):
		EventBus.interaction_triggered_snake_speed_effect.disconnect(_on_speed_effect_applied_interaction)

func _ready() -> void:
	if world_grid == null:
		push_error(
			"SnakeController: World Grid has not been assigned."
		)

	if snake_renderer == null:
		push_error(
			"SnakeController: Snake Renderer has not been assigned."
		)
	
	_set_up_movement_timer()

func _unhandled_input(event: InputEvent) -> void:
	if not _movement_enabled:
		return

	if event.is_action_pressed(&"snake_up"):
		_queue_direction(Vector2i.UP)

	elif event.is_action_pressed(&"snake_down"):
		_queue_direction(Vector2i.DOWN)

	elif event.is_action_pressed(&"snake_left"):
		_queue_direction(Vector2i.LEFT)

	elif event.is_action_pressed(&"snake_right"):
		_queue_direction(Vector2i.RIGHT)


func reset_snake() -> bool:
	set_movement_enabled(false)

	# Should hopefully never happen... but just in case. 
	if world_grid.is_blocked(starting_head_cell):
		EventBus.unrecoverable_error_encountered.emit(
			"SnakeController: Starting cell %s is blocked."
			% starting_head_cell
		)

		return false

	_snake_cells.clear()
	_occupied_cells.clear()

	_snake_cells.append(starting_head_cell)
	_occupied_cells[starting_head_cell] = true

	_direction = Vector2i.RIGHT
	_queued_direction = Vector2i.RIGHT

	_current_health_change += starting_snake_length

	snake_renderer.clear_snake()

	_update_captured_cells()
	_emit_snake_state()

	return true


func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled

	if enabled:
		_set_up_movement_timer()
		movement_timer.start()
	else:
		movement_timer.stop()


func is_movement_enabled() -> bool:
	return _movement_enabled


func _emit_snake_state() -> void:
	EventBus.snake_state_changed.emit(
		get_head_cell(),
		get_snake_cells()
	)

func _set_up_movement_timer(time_scale: float = 1):
	print("Setting time scale to: ", time_scale)
	movement_timer.wait_time = (millis_per_move / MILLIS_IN_SECOND) * time_scale
	movement_timer.one_shot = false
	movement_timer.autostart = false

	if !movement_timer.timeout.is_connected(_on_movement_timer_timeout):
		movement_timer.timeout.connect(_on_movement_timer_timeout)

func get_snake_cells() -> Array[Vector2i]:
	var copied_cells: Array[Vector2i] = []
	copied_cells.assign(_snake_cells)

	return copied_cells


func get_head_cell() -> Vector2i:
	if _snake_cells.is_empty():
		return Vector2i.ZERO

	return _snake_cells[0]


func occupies_cell(cell: Vector2i) -> bool:
	return _occupied_cells.has(cell)


func _on_movement_timer_timeout() -> void:
	if not _movement_enabled:
		return

	_move_snake()


func _queue_direction(new_direction: Vector2i) -> void:
	# Do not allow an immediate 180-degree turn.
	if new_direction == -_direction:
		return

	_queued_direction = new_direction


func _move_snake() -> void:
	if _snake_cells.is_empty():
		return
	
	#affect speed of triggering the next movement signal based on the speed affects
	# We calculate speed in such a way, that it approaches the upper or lower bounds of the time scale smoothly
	# based on the strength of the effect.
	if _current_speed_effect_modifier < 0:
		#we are slowing down
		var variable_time_scale_part: float = 1.0 - min_speed_time_scale
		var time_scale: float = variable_time_scale_part  / absf(_current_speed_effect_modifier) + min_speed_time_scale
		_set_up_movement_timer(time_scale)
		
	if _current_speed_effect_modifier > 0:
		#we are speeding up
		var variable_time_scale_part: float = max_speed_time_scale - 1.0
		var time_scale: float = variable_time_scale_part  / _current_speed_effect_modifier + 1.0
		_set_up_movement_timer(time_scale)
		
	else:
		#reset to normal time scale
		_set_up_movement_timer()
		
	# reset the modifier - effects need to be applied each tick again to persist
	_current_speed_effect_modifier = 0

	_direction = _queued_direction

	var previous_head: Vector2i = _snake_cells[0]
	var next_head: Vector2i = previous_head + _direction


	if world_grid.is_blocked(next_head):
		_crash()
		return

	if _hits_self(next_head, _current_health_change > 0):
		_crash()
		return

	var removed_tail := Vector2i.ZERO
	var remove_tail := false

	if _current_health_change > 0:
		_snake_cells.push_front(next_head)
		snake_renderer.push_head(next_head, _direction)
		_occupied_cells[next_head] = true
		_current_health_change -= 1
		EventBus.snake_health_changed.emit(get_health() - 1, get_health())
		
	else:
		removed_tail = _snake_cells.pop_back()
		remove_tail = true
		snake_renderer.clear_cell(removed_tail)
		_occupied_cells.erase(removed_tail)

		_snake_cells.push_front(next_head)
		snake_renderer.push_head(next_head, _direction)
		_occupied_cells[next_head] = true

	snake_renderer.draw_snake()

	EventBus.snake_moved.emit(previous_head, next_head, get_snake_cells())
	_emit_snake_state()
	_update_captured_cells()

func _on_health_change_interaction(delta_health: int):
	_current_health_change += delta_health
	#if we have a negative health interaction, we remove segements instantly, otherwise
	# new segments will be added on every move, so the snake grows gradually
	
	while not _current_health_change >= 0:
		_current_health_change += 1
		remove_tail_segment()
		
func _on_speed_effect_applied_interaction(effect: EventBus.SnakeSpeedEffect):
	match effect:
		EventBus.SnakeSpeedEffect.SLOW_DOWN:
			_current_speed_effect_modifier += -1
		EventBus.SnakeSpeedEffect.SLOW_DOWN_HARD:
			_current_speed_effect_modifier += -2
		EventBus.SnakeSpeedEffect.NO_EFFECT:
			pass

func _hits_self(
	next_head: Vector2i,
	will_grow: bool
) -> bool:
	if not _occupied_cells.has(next_head):
		return false

	# The snake may enter its current tail cell when that
	# tail is leaving during the same movement.
	if not will_grow:
		var tail_cell: Vector2i = _snake_cells.back()

		if next_head == tail_cell:
			return false

	return true


func _crash() -> void:
	set_movement_enabled(false)
	EventBus.snake_health_changed.emit(get_health(), 0)
	
func remove_tail_segment() -> void:
	if get_health() <= 0:
		return

	var old_health: int = get_health()
	var removed_tail: Vector2i = _snake_cells.pop_back()

	snake_renderer.clear_cell(removed_tail)
	_occupied_cells.erase(removed_tail)

	# SnakeRenderer redraws the complete snake.
	snake_renderer.draw_snake()

	EventBus.snake_health_changed.emit(
		old_health,
		get_health()
	)

	_emit_snake_state()
	_update_captured_cells()

func get_snake_length() -> int:
	return _snake_cells.size()

func get_health() -> int:
	return maxi(_snake_cells.size() - minimum_snake_length, 0)

func can_remove_tail_segment() -> bool:
	return _snake_cells.size() > minimum_snake_length

func _on_game_started():
	var success: bool = reset_snake()
	set_movement_enabled(true)
	if !success:
		EventBus.unrecoverable_error_encountered.emit("Snake initialization failed")
		
func _on_game_ended(is_won: bool):
	set_movement_enabled(false)
		
func _update_captured_cells():
	var captured_cells: Dictionary[Vector2i, bool] = world_grid.calculate_captured_area(get_snake_cells())
	if captured_cells.size() != _captured_cells.size() || !captured_cells.has_all(_captured_cells.keys()):
		_captured_cells.clear()
		_captured_cells.merge(captured_cells)
		EventBus.snake_captured_area_changed.emit(captured_cells.keys())
		
