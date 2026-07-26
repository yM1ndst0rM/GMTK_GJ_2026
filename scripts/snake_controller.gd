class_name SnakeController
extends Node


const MILLIS_IN_SECOND: float = 1000.0


signal snake_crashed
signal head_entered_cell(cell: Vector2i)
signal snake_moved(head_cell: Vector2i)
signal snake_length_changed(new_length: int)

var _movement_time_multipliers: Dictionary = {}
@export var garlic_repulsion_system: GarlicRepulsionSystem

@export_category("References")

@export var world_grid: WorldGrid
@export var snake_renderer: SnakeRenderer
@export var movement_timer: Timer


@export_category("Snake Length")

## The head counts as one segment.
@export_range(1, 100, 1)
var minimum_snake_length: int = 1


@export_category("Starting Position")

@export var starting_head_cell: Vector2i = Vector2i(32, 32)


@export_category("Movement")

@export_range(50, 2000, 10)
var millis_per_move: int = 150


var _snake_cells: Array[Vector2i] = []

# Used like a HashSet for fast self-collision checks.
var _occupied_cells: Dictionary = {}

var _direction: Vector2i = Vector2i.RIGHT
var _queued_direction: Vector2i = Vector2i.RIGHT

var _movement_enabled: bool = false

# Each point prevents the tail from moving for one movement.
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

	if movement_timer == null:
		push_error(
			"SnakeController: Movement Timer has not been assigned."
		)
		return

	movement_timer.wait_time = (
		millis_per_move / MILLIS_IN_SECOND
	)

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
	set_movement_enabled(false)

	var starting_cells: Array[Vector2i] = [
		starting_head_cell,
		starting_head_cell + Vector2i.LEFT,
		starting_head_cell + Vector2i.LEFT * 2,
		starting_head_cell + Vector2i.LEFT * 3,
		starting_head_cell + Vector2i.LEFT * 4,
		starting_head_cell + Vector2i.LEFT * 5
	]

	for cell in starting_cells:
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
	_pending_growth = 0

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
		_refresh_movement_wait_time()
		movement_timer.start()
	else:
		movement_timer.stop()


func is_movement_enabled() -> bool:
	return _movement_enabled


func set_movement_speed(
	new_millis_per_move: int
) -> void:
	millis_per_move = maxi(
		new_millis_per_move,
		50
	)

	_refresh_movement_wait_time()


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


func add_growth(amount: int) -> void:
	if amount <= 0:
		return

	_pending_growth += amount

	print(
		"Snake growth queued: ",
		amount,
		". Total pending: ",
		_pending_growth
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
	
	

	var next_head: Vector2i = (
		_snake_cells[0] + _direction
	)
	
	if (
		garlic_repulsion_system != null
		and garlic_repulsion_system.would_repel(
			next_head
		)
	):
		var forced_direction: Vector2i = (
			garlic_repulsion_system.trigger_repulsion(
				_snake_cells[0],
				next_head,
				_direction
			)
		)

		# Triggering the garlic removes one bat.
		if not remove_tail_segment():
			_crash()
			return

		# The garlic has already been removed at this point.
		# If there is no valid push direction, skip this move.
		if forced_direction == Vector2i.ZERO:
			return

		_direction = forced_direction
		_queued_direction = forced_direction

		next_head = (
			_snake_cells[0]
			+ forced_direction
		)

	if world_grid.is_blocked(next_head):
		_crash()
		return

	# Before entering the cell, only already-queued growth
	# determines whether the current tail will remain.
	var tail_will_remain: bool = (
		_pending_growth > 0
	)

	if _hits_self(next_head, tail_will_remain):
		_crash()
		return

	# Add the new head first.
	_snake_cells.push_front(next_head)
	_occupied_cells[next_head] = true

	# InteractableSpawner listens for this signal.
	#
	# When the entered cell contains a blood orange:
	# 1. InteractableSpawner removes it.
	# 2. InteractableSpawner emits interactable_collected.
	# 3. InteractableEffectProcessor calls add_growth().
	#
	# Signal callbacks happen before this function continues,
	# so _pending_growth will be updated below.
	head_entered_cell.emit(next_head)

	var grew_this_move: bool = (
		_pending_growth > 0
	)

	if grew_this_move:
		_pending_growth -= 1
	else:
		var removed_tail: Vector2i = (
			_snake_cells.pop_back()
		)

		# Protect the new head if it entered the cell
		# that the old tail was vacating.
		if removed_tail != next_head:
			_occupied_cells.erase(removed_tail)

	snake_renderer.draw_snake(
		_snake_cells
	)

	if grew_this_move:
		snake_length_changed.emit(
			_snake_cells.size()
		)

	snake_moved.emit(next_head)


func _hits_self(
	next_head: Vector2i,
	tail_will_remain: bool
) -> bool:
	if not _occupied_cells.has(next_head):
		return false

	# The snake may enter the current tail cell when
	# that tail will leave during this movement.
	if not tail_will_remain:
		var tail_cell: Vector2i = (
			_snake_cells.back()
		)

		if next_head == tail_cell:
			return false

	return true


func _crash() -> void:
	set_movement_enabled(false)
	snake_crashed.emit()


func remove_tail_segment() -> bool:
	if _snake_cells.size() <= minimum_snake_length:
		return false

	var removed_tail: Vector2i = (
		_snake_cells.pop_back()
	)

	_occupied_cells.erase(removed_tail)

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
	return (
		_snake_cells.size()
		> minimum_snake_length
	)

func set_movement_time_multiplier(
	source: StringName,
	multiplier: float
) -> void:
	_movement_time_multipliers[source] = maxf(
		multiplier,
		0.05
	)

	_refresh_movement_wait_time()


func remove_movement_time_multiplier(
	source: StringName
) -> void:
	_movement_time_multipliers.erase(source)
	_refresh_movement_wait_time()


func _get_effective_millis_per_move() -> int:
	var effective_millis := float(
		millis_per_move
	)

	for multiplier_value in (
		_movement_time_multipliers.values()
	):
		effective_millis *= float(
			multiplier_value
		)

	return roundi(effective_millis)


func _refresh_movement_wait_time() -> void:
	movement_timer.wait_time = (
		_get_effective_millis_per_move()
		/ MILLIS_IN_SECOND
	)
