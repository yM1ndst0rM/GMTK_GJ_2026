class_name InteractableSpawner
extends Node


signal interactable_collected(
	definition: InteractablesDefinition,
	seconds_remaining: int
)

signal interactable_expired(
	definition: InteractablesDefinition,
	cell: Vector2i
)

signal active_count_changed(
	interactable_id: StringName,
	active_count: int
)


## Stores the state of one interactable currently placed
## somewhere on the map.
class InteractableInstance:
	extends RefCounted


	var definition: InteractablesDefinition
	var cell: Vector2i
	var seconds_remaining: int
	var countdown_label: Label


	func _init(
		new_definition: InteractablesDefinition,
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
@export var villager_controller: VillagerController
@export var interactable_layer: TileMapLayer
@export var countdown_labels: Node2D
@export var second_timer: Timer


@export_category("Interactable Types")


@export var interactable_defintions: Array[InteractablesDefinition] = []

@export_category("Countdown Appearance")

@export_range(8, 256, 1)
var countdown_font_size: int = 72


# Key: Vector2i cell
# Value: InteractableInstance
var _active_interactable: Dictionary = {}


# Key: StringName interactable ID
# Value: whether that interactable type may currently spawn.
var _spawn_enabled: Dictionary = {}


# Increased whenever spawning starts or stops.
# This invalidates delayed spawn operations from an old game.
var _spawn_session_id: int = 0


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

	countdown_labels.z_index = (
		interactable_layer.z_index + 1
	)


func _references_are_valid() -> bool:
	var valid := true

	if world_grid == null:
		push_error(
			"InteractableSpawner: World Grid has not been assigned."
		)
		valid = false

	if snake_controller == null:
		push_error(
			"InteractableSpawner: Snake Controller has not been assigned."
		)
		valid = false

	if interactable_layer == null:
		push_error(
			"InteractableSpawner: Interactable Layer has not been assigned."
		)
		valid = false

	if countdown_labels == null:
		push_error(
			"InteractableSpawner: Countdown Labels has not been assigned."
		)
		valid = false

	if second_timer == null:
		push_error(
			"InteractableSpawner: Second Timer has not been assigned."
		)
		valid = false

	return valid


func start_spawning() -> void:
	clear_all_interactable()

	_spawn_session_id += 1

	var current_session_id: int = (
		_spawn_session_id
	)

	_spawn_enabled.clear()

	_running = true

	second_timer.start()

	for definition in interactable_defintions:
		if definition == null:
			continue

		var interactable_id: StringName = (
			definition.interactable_id
		)

		if (
			definition.initial_spawn_delay_seconds
			<= 0.0
		):
			_spawn_enabled[interactable_id] = true
		else:
			_spawn_enabled[interactable_id] = false

			_enable_spawn_after_delay(
				definition,
				current_session_id
			)

	# Immediately spawn types that have no delay.
	_maintain_spawn_targets()


func stop_spawning() -> void:
	_running = false

	# Any delayed function from the previous game will
	# see a different session ID and stop.
	_spawn_session_id += 1

	second_timer.stop()

	_spawn_enabled.clear()

	clear_all_interactable()


func _enable_spawn_after_delay(
	definition: InteractablesDefinition,
	session_id: int
) -> void:
	await get_tree().create_timer(
		definition.initial_spawn_delay_seconds
	).timeout

	if not _running:
		return

	if session_id != _spawn_session_id:
		return

	_spawn_enabled[
		definition.interactable_id
	] = true

	print(
		"Spawn delay finished for ",
		definition.interactable_id
	)

	_fill_spawn_target(definition)


func collect_at(cell: Vector2i) -> bool:
	return _collect_interactable_at(cell)


func has_interactable_at(cell: Vector2i) -> bool:
	return _active_interactable.has(cell)


func get_definition_at(
	cell: Vector2i
) -> InteractablesDefinition:
	if not _active_interactable.has(cell):
		return null

	var instance: InteractableInstance = (
		_active_interactable[cell]
	)

	return instance.definition


func get_cells_for_id(
	interactable_id: StringName
) -> Array[Vector2i]:
	var matching_cells: Array[Vector2i] = []

	for cell_value in _active_interactable.keys():
		var cell: Vector2i = cell_value

		var instance: InteractableInstance = (
			_active_interactable[cell]
		)

		if (
			instance.definition.interactable_id
			== interactable_id
		):
			matching_cells.append(cell)

	return matching_cells


func get_active_count(
	interactable_id: StringName
) -> int:
	var active_count := 0

	for instance_value in _active_interactable.values():
		var instance: InteractableInstance = (
			instance_value
		)

		if (
			instance.definition.interactable_id
			== interactable_id
		):
			active_count += 1

	return active_count


func remove_interactable_at(
	cell: Vector2i,
	spawn_replacement: bool = true
) -> bool:
	if not _active_interactable.has(cell):
		return false

	var instance: InteractableInstance = (
		_active_interactable[cell]
	)

	var definition: InteractablesDefinition = (
		instance.definition
	)

	var interactable_id: StringName = (
		definition.interactable_id
	)

	_remove_interactable_instance(cell)

	if spawn_replacement:
		_fill_spawn_target(definition)
	else:
		# A false value makes this interactable single-use
		# for the remainder of the current game.
		_spawn_enabled[interactable_id] = false

	return true


func clear_all_interactable() -> void:
	for instance_value in _active_interactable.values():
		var instance: InteractableInstance = (
			instance_value
		)

		if is_instance_valid(
			instance.countdown_label
		):
			instance.countdown_label.queue_free()

	_active_interactable.clear()

	if interactable_layer != null:
		interactable_layer.clear()


func _on_second_timer_timeout() -> void:
	if not _running:
		return

	var expired_cells: Array[Vector2i] = []

	for cell_value in _active_interactable.keys():
		var cell: Vector2i = cell_value

		var instance: InteractableInstance = (
			_active_interactable[cell]
		)

		# A lifetime of zero means the interactable
		# does not expire automatically.
		if instance.definition.lifetime_seconds <= 0:
			continue

		instance.seconds_remaining -= 1

		if instance.seconds_remaining <= 0:
			expired_cells.append(cell)
		else:
			_update_countdown_label(instance)

	for cell in expired_cells:
		if not _active_interactable.has(cell):
			continue

		var instance: InteractableInstance = (
			_active_interactable[cell]
		)

		var definition: InteractablesDefinition = (
			instance.definition
		)

		_remove_interactable_instance(cell)

		interactable_expired.emit(
			definition,
			cell
		)

	_maintain_spawn_targets()


func _maintain_spawn_targets() -> void:
	for definition in interactable_defintions:
		if definition == null:
			continue

		var spawning_enabled: bool = bool(
			_spawn_enabled.get(
				definition.interactable_id,
				false
			)
		)

		if not spawning_enabled:
			continue

		_fill_spawn_target(definition)


func _fill_spawn_target(
	definition: InteractablesDefinition
) -> void:
	if not _running:
		return

	var spawning_enabled: bool = bool(
		_spawn_enabled.get(
			definition.interactable_id,
			false
		)
	)

	if not spawning_enabled:
		return

	while (
		_running
		and get_active_count(
			definition.interactable_id
		) < definition.maximum_active
	):
		if not _spawn_one(definition):
			break


func _spawn_one(
	definition: InteractablesDefinition
) -> bool:
	var spawn_centers: Array[Vector2i] = (
		_get_spawn_centers(definition)
	)

	if spawn_centers.is_empty():
		push_warning(
			"InteractableSpawner: No spawn centers found for '%s'."
			% definition.interactable_id
		)

		return false

	# Dictionary prevents duplicate cells when multiple
	# village spawn radiuses overlap.
	var candidate_lookup: Dictionary = {}

	for center_cell in spawn_centers:
		var center_candidates: Array[Vector2i] = (
			_get_spawn_candidates(
				definition,
				center_cell
			)
		)

		for candidate in center_candidates:
			candidate_lookup[candidate] = true

	var candidates: Array[Vector2i] = []

	for cell_value in candidate_lookup.keys():
		var candidate_cell: Vector2i = cell_value
		candidates.append(candidate_cell)

	if candidates.is_empty():
		push_warning(
			"InteractableSpawner: No valid spawn cells found for '%s'."
			% definition.interactable_id
		)

		return false

	var selected_cell: Vector2i = (
		candidates.pick_random()
	)

	_create_interactable_instance(
		definition,
		selected_cell
	)

	print(
		"Spawning ",
		definition.interactable_id,
		" at ",
		selected_cell
	)

	return true


func _get_spawn_centers(
	definition: InteractablesDefinition
) -> Array[Vector2i]:
	match definition.spawn_origin:
		InteractablesDefinition.SpawnOrigin.NEAR_VILLAGERS:
			if villager_controller == null:
				push_warning(
					"InteractableSpawner: Villager Controller "
					+ "has not been assigned."
				)

				return []

			return villager_controller.get_all_villagers()

		InteractablesDefinition.SpawnOrigin.NEAR_SNAKE:
			return [
				snake_controller.get_head_cell()
			]

		_:
			return []


## Uses a bounded brute-force search around the supplied
## center cell.
func _get_spawn_candidates(
	definition: InteractablesDefinition,
	center_cell: Vector2i
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []

	var minimum_radius: int = maxi(
		0,
		definition.minimum_spawn_radius
	)

	var maximum_radius: int = maxi(
		minimum_radius,
		definition.maximum_spawn_radius
	)

	var minimum_distance_squared: int = (
		minimum_radius * minimum_radius
	)

	var maximum_distance_squared: int = (
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

			var distance_squared: int = (
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

			var candidate: Vector2i = (
				center_cell + offset
			)

			if not _is_valid_spawn_cell(
				candidate,
				definition
			):
				continue

			candidates.append(candidate)

	return candidates


func _is_valid_spawn_cell(
	cell: Vector2i,
	definition: InteractablesDefinition
) -> bool:
	if not world_grid.is_inside_world(cell):
		return false

	if world_grid.is_blocked(cell):
		return false

	if snake_controller.occupies_cell(cell):
		return false

	if _active_interactable.has(cell):
		return false

	var minimum_distance: int = (
		definition.minimum_distance_from_snake
	)

	if minimum_distance > 0:
		var snake_head: Vector2i = (
			snake_controller.get_head_cell()
		)

		var minimum_distance_squared: int = (
			minimum_distance * minimum_distance
		)

		# Exact minimum distance is allowed.
		if (
			cell.distance_squared_to(snake_head)
			< minimum_distance_squared
		):
			return false

	return true


func _create_interactable_instance(
	definition: InteractablesDefinition,
	cell: Vector2i
) -> void:
	interactable_layer.set_cell(
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

	var instance := InteractableInstance.new(
		definition,
		cell,
		definition.lifetime_seconds,
		countdown_label
	)

	_active_interactable[cell] = instance

	_update_countdown_label(instance)

	active_count_changed.emit(
		definition.interactable_id,
		get_active_count(
			definition.interactable_id
		)
	)


func _remove_interactable_instance(
	cell: Vector2i
) -> void:
	if not _active_interactable.has(cell):
		return

	var instance: InteractableInstance = (
		_active_interactable[cell]
	)

	var interactable_id: StringName = (
		instance.definition.interactable_id
	)

	interactable_layer.erase_cell(cell)

	if is_instance_valid(instance.countdown_label):
		instance.countdown_label.queue_free()

	_active_interactable.erase(cell)

	active_count_changed.emit(
		interactable_id,
		get_active_count(interactable_id)
	)


func _update_countdown_label(
	instance: InteractableInstance
) -> void:
	if not is_instance_valid(
		instance.countdown_label
	):
		return

	instance.countdown_label.text = str(
		instance.seconds_remaining
	)


func _on_snake_head_entered_cell(
	cell: Vector2i
) -> void:
	var definition: InteractablesDefinition = (
		get_definition_at(cell)
	)

	if definition == null:
		return

	if not definition.collect_on_contact:
		return

	_collect_interactable_at(cell)


func _collect_interactable_at(
	cell: Vector2i
) -> bool:
	if not _running:
		return false

	if not _active_interactable.has(cell):
		return false

	var instance: InteractableInstance = (
		_active_interactable[cell]
	)

	var definition: InteractablesDefinition = (
		instance.definition
	)

	var seconds_remaining: int = (
		instance.seconds_remaining
	)

	if (
		definition.lifetime_seconds > 0
		and seconds_remaining <= 0
	):
		_remove_interactable_instance(cell)
		_maintain_spawn_targets()

		return false

	_remove_interactable_instance(cell)

	interactable_collected.emit(
		definition,
		seconds_remaining
	)

	_maintain_spawn_targets()

	return true


func _create_countdown_label(
	cell: Vector2i,
	seconds: int
) -> Label:
	var countdown_label := Label.new()

	countdown_label.text = str(seconds)
	countdown_label.visible = true

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
		6
	)

	var tile_size := Vector2(128.0, 128.0)

	if interactable_layer.tile_set != null:
		tile_size = Vector2(
			interactable_layer.tile_set.tile_size
		)

	var label_height := 96.0

	countdown_label.custom_minimum_size = Vector2(
		tile_size.x,
		label_height
	)

	countdown_label.size = Vector2(
		tile_size.x,
		label_height
	)

	countdown_label.z_index = 1

	countdown_labels.add_child(
		countdown_label
	)

	var interactable_center_global: Vector2 = (
		interactable_layer.to_global(
			interactable_layer.map_to_local(cell)
		)
	)

	var interactable_center_local: Vector2 = (
		countdown_labels.to_local(
			interactable_center_global
		)
	)

	countdown_label.position = (
		interactable_center_local
		- Vector2(
			tile_size.x * 0.5,
			tile_size.y * 0.5
				+ label_height
		)
	)

	return countdown_label
