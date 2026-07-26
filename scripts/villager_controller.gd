class_name VillagerController
extends Node


@onready var interactables_layer: TileMapLayer = (
	$InteractablesLayer
)


func _enter_tree() -> void:
	if not EventBus.snake_captured_area_changed.is_connected(
		_on_snake_captured_area_changed
	):
		EventBus.snake_captured_area_changed.connect(
			_on_snake_captured_area_changed
		)


func _exit_tree() -> void:
	if EventBus.snake_captured_area_changed.is_connected(
		_on_snake_captured_area_changed
	):
		EventBus.snake_captured_area_changed.disconnect(
			_on_snake_captured_area_changed
		)


func _ready() -> void:
	_emit_villager_cells_changed()


func get_all_villagers() -> Array[Vector2i]:
	return CellsTypes.get_all_cells_of_type(
		interactables_layer,
		CellsTypes.T_VILLAGER
	)


func kill_villager_on(
	cell: Vector2i
) -> bool:
	if not CellsTypes.is_cell_of_type(
		interactables_layer,
		cell,
		CellsTypes.T_VILLAGER
	):
		return false

	# Actually remove the villager from the TileMapLayer.
	interactables_layer.erase_cell(
		cell
	)

	var remaining_villagers: Array[Vector2i] = (
		get_all_villagers()
	)

	EventBus.villager_killed.emit(
		cell,
		remaining_villagers.size()
	)

	EventBus.villager_cells_changed.emit(
		remaining_villagers
	)

	return true


func _on_snake_captured_area_changed(
	captured_cells: Array[Vector2i]
) -> void:
	var villagers: Array[Vector2i] = (
		get_all_villagers()
	)

	for cell in captured_cells:
		if villagers.has(cell):
			kill_villager_on(
				cell
			)


func _emit_villager_cells_changed() -> void:
	EventBus.villager_cells_changed.emit(
		get_all_villagers()
	)
