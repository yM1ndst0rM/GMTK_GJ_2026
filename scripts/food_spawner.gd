class_name FoodSpawner
extends Node


signal food_collected(
	definition: FoodDefinition,
	seconds_remaining: int
)

signal food_expired(
	definition: FoodDefinition,
	cell: Vector2i
)

signal active_count_changed(
	food_id: StringName,
	active_count: int
)

## This is a sub class. Didn't even know you could do this until today.
## Anyways, this is so we can track each instance of food placed on 
## the field at any given time.
class FoodInstance:
	extends RefCounted

	var definition: FoodDefinition
	var cell: Vector2i
	var seconds_remaining: int
	var countdown_label: Label


	func _init(
		new_definition: FoodDefinition,
		new_cell: Vector2i,
		new_seconds_remaining: int,
		new_countdown_label: Label
	) -> void:
		definition = new_definition
		cell = new_cell
		seconds_remaining = new_seconds_remaining
		countdown_label = new_countdown_label

@export_category("References")

@export var world_grid: WorldGrid

@export var snake_controller: SnakeController

@export var food_layer: TileMapLayer

@export var countdown_labels: Node2D


@export_category("Food Types")

@export var food_definitions: Array[FoodDefinition] = []


@export_category("Countdown Appearance")

@export_range(8, 128, 1)
var countdown_font_size: int = 28


@export var second_timer: Timer 


# Key: Vector2i cell
# Value: FoodInstance
var _active_food: Dictionary = {}

var _running: bool = false


func _ready() -> void:
	if not _references_are_valid():
		return

	second_timer.wait_time = 1.0
	second_timer.one_shot = false
	second_timer.autostart = false

	second_timer.timeout.connect(
		_on_second_timer_timeout
	)
	
	snake_controller.head_entered_cell.connect(
		_on_snake_head_entered_cell
	)

	countdown_labels.z_index = food_layer.z_index + 1


func _references_are_valid() -> bool:
	var valid := true

	if world_grid == null:
		push_error(
			"FoodSpawner: World Grid has not been assigned."
		)
		valid = false

	if snake_controller == null:
		push_error(
			"FoodSpawner: Snake Controller has not been assigned."
		)
		valid = false

	if food_layer == null:
		push_error(
			"FoodSpawner: Food Layer has not been assigned."
		)
		valid = false

	if countdown_labels == null:
		push_error(
			"FoodSpawner: Countdown Labels has not been assigned."
		)
		valid = false

	return valid


func start_spawning() -> void:
	clear_all_food()

	_running = true
	second_timer.start()

	_maintain_spawn_targets()


func stop_spawning() -> void:
	_running = false
	second_timer.stop()

	clear_all_food()


func collect_at(cell: Vector2i) -> bool:
	if not _running:
		return false

	if not _active_food.has(cell):
		return false

	var instance: FoodInstance = _active_food[cell]

	var definition := instance.definition
	var seconds_remaining := instance.seconds_remaining

	_remove_food_instance(cell)

	food_collected.emit(
		definition,
		seconds_remaining
	)

	# Immediately replace the collected item.
	_maintain_spawn_targets()

	return true


func has_food_at(cell: Vector2i) -> bool:
	return _active_food.has(cell)


func clear_all_food() -> void:
	for instance_value in _active_food.values():
		var instance: FoodInstance = instance_value

		if is_instance_valid(instance.countdown_label):
			instance.countdown_label.queue_free()

	_active_food.clear()

	if food_layer != null:
		food_layer.clear()


func get_active_count(
	food_id: StringName
) -> int:
	var active_count := 0

	for instance_value in _active_food.values():
		var instance: FoodInstance = instance_value

		if instance.definition.food_id == food_id:
			active_count += 1

	return active_count


func _on_second_timer_timeout() -> void:
	if not _running:
		return

	var expired_cells: Array[Vector2i] = []

	for cell_value in _active_food.keys():
		var cell: Vector2i = cell_value
		var instance: FoodInstance = _active_food[cell]

		# Zero lifetime means this food does not expire.
		if instance.definition.lifetime_seconds <= 0:
			continue

		instance.seconds_remaining -= 1

		if instance.seconds_remaining <= 0:
			expired_cells.append(cell)
		else:
			_update_countdown_label(instance)

	for cell in expired_cells:
		var instance: FoodInstance = _active_food[cell]
		var definition: FoodDefinition = instance.definition

		_remove_food_instance(cell)

		food_expired.emit(
			definition,
			cell
		)

	_maintain_spawn_targets()


func _maintain_spawn_targets() -> void:
	for definition in food_definitions:
		if definition == null:
			continue

		while (
			_running
			and get_active_count(definition.food_id)
				< definition.maximum_active
		):
			if not _spawn_one(definition):
				# No suitable cells currently exist.
				break

func _spawn_one(
	definition: FoodDefinition
) -> bool:
	var head_cell := snake_controller.get_head_cell()

	var candidates := _get_spawn_candidates(
		definition,
		head_cell
	)

	if candidates.is_empty():
		return false

	var selected_cell: Vector2i = (
		candidates.pick_random()
	)

	_create_food_instance(
		definition,
		selected_cell
	)

	return true

## Uses bounded brute force search
## I'm not sure if there's an easier way to do this. 

func _get_spawn_candidates(
	definition: FoodDefinition,
	center_cell: Vector2i
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []

	var minimum_radius := maxi(
		0,
		definition.minimum_spawn_radius
	)

	var maximum_radius := maxi(
		minimum_radius,
		definition.maximum_spawn_radius
	)

	var minimum_distance_squared := (
		minimum_radius * minimum_radius
	)

	var maximum_distance_squared := (
		maximum_radius * maximum_radius
	)

	for offset_y in range(
		-maximum_radius,
		maximum_radius + 1
	):
		for offset_x in range(
			-maximum_radius,
			maximum_radius + 1
		):
			var offset := Vector2i(
				offset_x,
				offset_y
			)

			var distance_squared := (
				offset.x * offset.x
				+ offset.y * offset.y
			)

			if (
				distance_squared
				< minimum_distance_squared
			):
				continue

			if (
				distance_squared
				> maximum_distance_squared
			):
				continue

			var candidate := center_cell + offset

			if not _is_valid_spawn_cell(candidate):
				continue

			candidates.append(candidate)

	return candidates


## We can't spawn outside the world, in a blocked cell, in a
## cell the player occupies or one where there is already a food item.
func _is_valid_spawn_cell(cell: Vector2i) -> bool:
	if not world_grid.is_inside_world(cell):
		return false

	if world_grid.is_blocked(cell):
		return false

	if snake_controller.occupies_cell(cell):
		return false

	if _active_food.has(cell):
		return false

	return true


func _create_food_instance(
	definition: FoodDefinition,
	cell: Vector2i
) -> void:
	food_layer.set_cell(
		cell,
		definition.source_id,
		definition.atlas_coordinates
	)

	var countdown_label: Label = null

	if (
		definition.show_countdown
		and definition.lifetime_seconds > 0
	):
		countdown_label = _create_countdown_label(
			cell,
			definition.lifetime_seconds
		)

	var instance := FoodInstance.new(
		definition,
		cell,
		definition.lifetime_seconds,
		countdown_label
	)

	_active_food[cell] = instance

	_update_countdown_label(instance)

	active_count_changed.emit(
		definition.food_id,
		get_active_count(definition.food_id)
	)

func _remove_food_instance(cell: Vector2i) -> void:
	if not _active_food.has(cell):
		return

	var instance: FoodInstance = _active_food[cell]
	var food_id := instance.definition.food_id

	food_layer.erase_cell(cell)

	if is_instance_valid(instance.countdown_label):
		instance.countdown_label.queue_free()

	_active_food.erase(cell)

	active_count_changed.emit(
		food_id,
		get_active_count(food_id)
	)


func _update_countdown_label(
	instance: FoodInstance
) -> void:
	if not is_instance_valid(instance.countdown_label):
		return

	instance.countdown_label.text = str(
		instance.seconds_remaining
	)

func _on_snake_head_entered_cell(
	cell: Vector2i
) -> void:
	_collect_food_at(cell)
	
func _collect_food_at(cell: Vector2i) -> void:
	if not _running:
		return

	if not _active_food.has(cell):
		return

	var instance: FoodInstance = _active_food[cell]

	## What food are we dealing with?
	var definition: FoodDefinition = (
		instance.definition
	)

	var seconds_remaining: int = (
		instance.seconds_remaining
	)

	if (
		definition.lifetime_seconds > 0
		and seconds_remaining <= 0
	):
		_remove_food_instance(cell)
		_maintain_spawn_targets()
		return

	_remove_food_instance(cell)

	food_collected.emit(
		definition,
		seconds_remaining
	)

	_maintain_spawn_targets()

func _create_countdown_label(
	cell: Vector2i,
	seconds: int
) -> Label:
	var countdown_label := Label.new()

	countdown_label.text = str(seconds)

	countdown_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	countdown_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	countdown_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	countdown_label.add_theme_font_size_override(
		&"font_size",
		countdown_font_size
	)

	countdown_label.add_theme_color_override(
		&"font_color",
		Color.WHITE
	)

	countdown_label.add_theme_color_override(
		&"font_outline_color",
		Color.BLACK
	)

	countdown_label.add_theme_constant_override(
		&"outline_size",
		4
	)

	var tile_size := Vector2(64.0, 64.0)

	if food_layer.tile_set != null:
		tile_size = Vector2(
			food_layer.tile_set.tile_size.x,
			food_layer.tile_set.tile_size.y
		)

	countdown_label.size = tile_size

	countdown_labels.add_child(
		countdown_label
	)

	var cell_global_position := (
		food_layer.to_global(
			food_layer.map_to_local(cell)
		)
	)

	var label_local_position := (
		countdown_labels.to_local(
			cell_global_position
		)
	)

	countdown_label.position = (
		label_local_position
		- tile_size * 0.5
	)

	return countdown_label
