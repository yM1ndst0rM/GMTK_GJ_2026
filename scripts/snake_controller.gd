class_name SnakeController
extends Node


signal snake_crashed
signal food_consumed
signal snake_moved(head_cell: Vector2i)
signal snake_length_changed(new_length: int)
## Emit the position of the head  to check whether or not we have
## "Collided" with food"
signal head_entered_cell(cell: Vector2i)
@export_category("References")

@export var world_grid: WorldGrid
@export var snake_renderer: SnakeRenderer


@export_category("Snake Length")

## The head counts as one segment.
@export_range(1, 100, 1)
var minimum_snake_length: int = 1

@export_category("Starting Position")

@export var starting_head_cell: Vector2i = Vector2i(32, 32)


@export_category("Movement")

@export_range(0.05, 1.0, 0.01)
var seconds_per_move: float = 0.15


@export var movement_timer: Timer


var _snake_cells: Array[Vector2i] = []

# Used like a HashSet for fast self-collision checks.
var _occupied_cells: Dictionary = {}

var _direction: Vector2i = Vector2i.RIGHT
var _queued_direction: Vector2i = Vector2i.RIGHT

var _movement_enabled: bool = false
## Since we have the ability to add x amount 
## of bats at once, we need to pending(ly?)
## add the bats. 
var _pending_growth: int = 0


func _ready() -> void:
	if world_grid == null:
		push_error(
			"SnakeController: World Grid has not been assigned."
		)

	if snake_renderer == null:
		push_error(
			"SnakeController: Snake Renderer has not been assigned."
		)

	movement_timer.wait_time = seconds_per_move
	movement_timer.one_shot = false
	movement_timer.autostart = false

	movement_timer.timeout.connect(
		_on_movement_timer_timeout
	)


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
	_pending_growth = 0
	set_movement_enabled(false)

	var starting_cells: Array[Vector2i] = [
		starting_head_cell,
		starting_head_cell + Vector2i.LEFT,
		starting_head_cell + Vector2i.LEFT * 2
	]

	for cell in starting_cells:
		# Should hopefully never happen... but just in case. 
		if world_grid.is_blocked(cell):
			push_error(
				"SnakeController: Starting cell %s is blocked."
				% cell
			)

			return false

	_snake_cells.clear()
	_occupied_cells.clear()

	for cell in starting_cells:
		_snake_cells.append(cell)
		_occupied_cells[cell] = true

	_direction = Vector2i.RIGHT
	_queued_direction = Vector2i.RIGHT

	snake_renderer.draw_snake(
		_snake_cells
	)

	snake_length_changed.emit(
		_snake_cells.size()
	)

	return true


func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled

	if enabled:
		movement_timer.wait_time = seconds_per_move
		movement_timer.start()
	else:
		movement_timer.stop()


func is_movement_enabled() -> bool:
	return _movement_enabled


func set_movement_speed(new_seconds_per_move: float) -> void:
	seconds_per_move = maxf(
		new_seconds_per_move,
		0.05
	)

	movement_timer.wait_time = seconds_per_move


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

	_direction = _queued_direction

	var next_head: Vector2i = (
		_snake_cells[0] + _direction
	)

	if world_grid.is_blocked(next_head):
		_crash()
		return

	var will_grow := _pending_growth > 0

	if _hits_self(next_head, will_grow):
		_crash()
		return

	_snake_cells.push_front(next_head)
	_occupied_cells[next_head] = true

	if _pending_growth > 0:
		_pending_growth -= 1

		snake_length_changed.emit(
			_snake_cells.size()
		)
	else:
		var removed_tail: Vector2i = (
			_snake_cells.pop_back()
		)

		if removed_tail != next_head:
			_occupied_cells.erase(removed_tail)

	snake_renderer.draw_snake(_snake_cells)

	snake_moved.emit(next_head)
	head_entered_cell.emit(next_head)
	
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
	snake_crashed.emit()
	
func remove_tail_segment() -> bool:
	if _snake_cells.size() <= minimum_snake_length:
		return false

	var removed_tail: Vector2i = _snake_cells.pop_back()

	_occupied_cells.erase(removed_tail)

	# Redraw the complete snake after changing its cells.
	snake_renderer.draw_snake(
		_snake_cells
	)

	snake_length_changed.emit(
		_snake_cells.size()
	)

	return true


func get_snake_length() -> int:
	return _snake_cells.size()


func can_remove_tail_segment() -> bool:
	return _snake_cells.size() > minimum_snake_length
	
func add_growth(amount: int) -> void:
	if amount <= 0:
		return

	_pending_growth += amount
