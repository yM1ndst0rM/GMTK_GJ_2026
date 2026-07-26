class_name SnakeController
extends Node


const MILLIS_IN_SECOND: float = 1000.0


@export_category("References")

@export var world_grid: WorldGrid
@export var snake_renderer: SnakeRenderer
@export var movement_timer: Timer


@export_category("Snake Length")

## The head counts as one segment.
@export_range(1, 100, 1)
var minimum_snake_length: int = 1

@export_range(1, 100, 1)
var starting_snake_length: int = 5


@export_category("Starting Position")

@export var starting_head_cell: Vector2i = Vector2i(32, 32)


@export_category("Movement")

## Normal delay between movements in milliseconds.
@export_range(50, 2000, 10)
var millis_per_move: int = 150

## Multiplier used by SLOW_DOWN.
## 2.0 means twice as much time between movements.
@export_range(1.0, 5.0, 0.1)
var slow_down_time_scale: float = 2.0

## Multiplier used by SLOW_DOWN_HARD.
@export_range(1.0, 5.0, 0.1)
var hard_slow_down_time_scale: float = 3.0


var _snake_cells: Array[Vector2i] = []

# Used like a HashSet for fast self-collision checks.
var _occupied_cells: Dictionary = {}

var _direction: Vector2i = Vector2i.RIGHT
var _queued_direction: Vector2i = Vector2i.RIGHT

var _movement_enabled: bool = false

var _captured_cells: Dictionary[Vector2i, bool] = {}

# Positive values cause gradual growth.
# Negative values remove segments immediately.
var _current_health_change: int = 0

# Speed effects received before or during a movement are
# applied to the timer interval before the following movement.
var _next_move_time_scale: float = 1.0


func _enter_tree() -> void:
	if not EventBus.game_started.is_connected(
		_on_game_started
	):
		EventBus.game_started.connect(
			_on_game_started
		)

	if not EventBus.game_ended.is_connected(
		_on_game_ended
	):
		EventBus.game_ended.connect(
			_on_game_ended
		)

	if not EventBus.interaction_triggered_health_change.is_connected(
		_on_health_change_interaction
	):
		EventBus.interaction_triggered_health_change.connect(
			_on_health_change_interaction
		)

	if not EventBus.interaction_triggered_snake_speed_effect.is_connected(
		_on_speed_effect_applied_interaction
	):
		EventBus.interaction_triggered_snake_speed_effect.connect(
			_on_speed_effect_applied_interaction
		)


func _exit_tree() -> void:
	if EventBus.game_started.is_connected(
		_on_game_started
	):
		EventBus.game_started.disconnect(
			_on_game_started
		)

	if EventBus.game_ended.is_connected(
		_on_game_ended
	):
		EventBus.game_ended.disconnect(
			_on_game_ended
		)

	if EventBus.interaction_triggered_health_change.is_connected(
		_on_health_change_interaction
	):
		EventBus.interaction_triggered_health_change.disconnect(
			_on_health_change_interaction
		)

	if EventBus.interaction_triggered_snake_speed_effect.is_connected(
		_on_speed_effect_applied_interaction
	):
		EventBus.interaction_triggered_snake_speed_effect.disconnect(
			_on_speed_effect_applied_interaction
		)


func _ready() -> void:
	if world_grid == null:
		push_error(
			"SnakeController: World Grid has not been assigned."
		)

	if snake_renderer == null:
		push_error(
			"SnakeController: Snake Renderer has not been assigned."
		)

	if movement_timer == null:
		push_error(
			"SnakeController: Movement Timer has not been assigned."
		)
		return

	_configure_movement_timer()


func _configure_movement_timer() -> void:
	movement_timer.one_shot = true
	movement_timer.autostart = false

	if not movement_timer.timeout.is_connected(
		_on_movement_timer_timeout
	):
		movement_timer.timeout.connect(
			_on_movement_timer_timeout
		)


func _unhandled_input(
	event: InputEvent
) -> void:
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

	if world_grid.is_blocked(starting_head_cell):
		EventBus.unrecoverable_error_encountered.emit(
			"SnakeController: Starting cell %s is blocked."
			% starting_head_cell
		)

		return false

	_snake_cells.clear()
	_occupied_cells.clear()
	_captured_cells.clear()

	_snake_cells.append(
		starting_head_cell
	)

	_occupied_cells[
		starting_head_cell
	] = true

	_direction = Vector2i.RIGHT
	_queued_direction = Vector2i.RIGHT

	# The starting head already counts as one segment.
	_current_health_change = maxi(
		starting_snake_length - 1,
		0
	)

	_next_move_time_scale = 1.0

	snake_renderer.draw_snake(
		_snake_cells
	)

	_update_captured_cells()
	_emit_snake_state()

	return true


func set_movement_enabled(
	enabled: bool
) -> void:
	_movement_enabled = enabled

	if movement_timer == null:
		return

	if enabled:
		_start_movement_timer(1.0)
	else:
		movement_timer.stop()


func is_movement_enabled() -> bool:
	return _movement_enabled


func _start_movement_timer(
	time_scale: float
) -> void:
	if not _movement_enabled:
		return

	var safe_time_scale: float = maxf(
		time_scale,
		0.01
	)

	movement_timer.wait_time = (
		float(millis_per_move)
		/ MILLIS_IN_SECOND
	) * safe_time_scale

	movement_timer.start()


func _emit_snake_state() -> void:
	EventBus.snake_state_changed.emit(
		get_head_cell(),
		get_snake_cells()
	)


func get_snake_cells() -> Array[Vector2i]:
	var copied_cells: Array[Vector2i] = []

	copied_cells.assign(
		_snake_cells
	)

	return copied_cells


func get_head_cell() -> Vector2i:
	if _snake_cells.is_empty():
		return Vector2i.ZERO

	return _snake_cells[0]


func occupies_cell(
	cell: Vector2i
) -> bool:
	return _occupied_cells.has(
		cell
	)


func _on_movement_timer_timeout() -> void:
	if not _movement_enabled:
		return

	_move_snake()


func _queue_direction(
	new_direction: Vector2i
) -> void:
	# Do not allow an immediate 180-degree turn.
	if new_direction == -_direction:
		return

	_queued_direction = new_direction


func _move_snake() -> void:
	if _snake_cells.is_empty():
		return

	_direction = _queued_direction

	var previous_head: Vector2i = (
		_snake_cells[0]
	)

	var next_head: Vector2i = (
		previous_head + _direction
	)

	if world_grid.is_blocked(next_head):
		_crash()
		return

	var will_grow: bool = (
		_current_health_change > 0
	)

	if _hits_self(
		next_head,
		will_grow
	):
		_crash()
		return

	if will_grow:
		var old_health: int = get_health()

		_snake_cells.push_front(
			next_head
		)

		_occupied_cells[
			next_head
		] = true

		_current_health_change -= 1

		EventBus.snake_health_changed.emit(
			old_health,
			get_health()
		)

	else:
		var removed_tail: Vector2i = (
			_snake_cells.pop_back()
		)

		_occupied_cells.erase(
			removed_tail
		)

		_snake_cells.push_front(
			next_head
		)

		_occupied_cells[
			next_head
		] = true

	snake_renderer.draw_snake(
		_snake_cells
	)

	# InteractableSpawner receives this synchronously.
	# If the snake is near garlic, the speed-effect event
	# is emitted before this function continues.
	EventBus.snake_moved.emit(
		previous_head,
		next_head,
		get_snake_cells()
	)

	_emit_snake_state()
	_update_captured_cells()

	# Apply any effect received during snake_moved to the
	# interval before the next movement.
	var applied_time_scale: float = (
		_next_move_time_scale
	)

	# Effects must be emitted again next movement to persist.
	_next_move_time_scale = 1.0

	_start_movement_timer(
		applied_time_scale
	)


func _on_health_change_interaction(
	delta_health: int
) -> void:
	_current_health_change += delta_health

	# Negative health changes remove segments immediately.
	while _current_health_change < 0:
		_current_health_change += 1

		if not can_remove_tail_segment():
			break

		remove_tail_segment()


func _on_speed_effect_applied_interaction(
	effect: EventBus.SnakeSpeedEffect
) -> void:
	match effect:
		EventBus.SnakeSpeedEffect.SLOW_DOWN:
			_next_move_time_scale = maxf(
				_next_move_time_scale,
				slow_down_time_scale
			)

		EventBus.SnakeSpeedEffect.SLOW_DOWN_HARD:
			_next_move_time_scale = maxf(
				_next_move_time_scale,
				hard_slow_down_time_scale
			)

		EventBus.SnakeSpeedEffect.NO_EFFECT:
			pass


func _hits_self(
	next_head: Vector2i,
	will_grow: bool
) -> bool:
	if not _occupied_cells.has(next_head):
		return false

	# The snake may enter its current tail cell when the
	# tail leaves during the same movement.
	if not will_grow:
		var tail_cell: Vector2i = (
			_snake_cells.back()
		)

		if next_head == tail_cell:
			return false

	return true


func _crash() -> void:
	set_movement_enabled(false)

	EventBus.snake_health_changed.emit(
		get_health(),
		0
	)


func remove_tail_segment() -> void:
	if not can_remove_tail_segment():
		return

	var old_health: int = get_health()

	var removed_tail: Vector2i = (
		_snake_cells.pop_back()
	)

	_occupied_cells.erase(
		removed_tail
	)

	snake_renderer.draw_snake(
		_snake_cells
	)

	EventBus.snake_health_changed.emit(
		old_health,
		get_health()
	)

	_emit_snake_state()
	_update_captured_cells()


func get_snake_length() -> int:
	return _snake_cells.size()


func get_health() -> int:
	return maxi(
		_snake_cells.size()
		- minimum_snake_length,
		0
	)


func can_remove_tail_segment() -> bool:
	return (
		_snake_cells.size()
		> minimum_snake_length
	)


func _on_game_started() -> void:
	var success: bool = reset_snake()

	if not success:
		EventBus.unrecoverable_error_encountered.emit(
			"Snake initialization failed"
		)
		return

	set_movement_enabled(true)


func _on_game_ended(
	_is_won: bool
) -> void:
	set_movement_enabled(false)


func _update_captured_cells() -> void:
	var captured_cells: Dictionary[Vector2i, bool] = (
		world_grid.calculate_captured_area(
			get_snake_cells()
		)
	)

	var captured_area_changed: bool = (
		captured_cells.size()
		!= _captured_cells.size()
		or not captured_cells.has_all(
			_captured_cells.keys()
		)
	)

	if not captured_area_changed:
		return

	_captured_cells.clear()
	_captured_cells.merge(
		captured_cells
	)

	var captured_cell_array: Array[Vector2i] = []

	for cell_value in captured_cells.keys():
		var cell: Vector2i = cell_value

		captured_cell_array.append(
			cell
		)

	EventBus.snake_captured_area_changed.emit(
		captured_cell_array
	)
