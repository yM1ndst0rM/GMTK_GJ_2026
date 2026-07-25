class_name FoodSpawner
extends Node


@export_category("References")

@export var world_grid: WorldGrid

@export var food_layer: TileMapLayer


@export_category("Food Tile")

@export var source_id: int = 0

@export var food_atlas_coordinates: Vector2i = Vector2i(0, 0)


var _food_cell: Vector2i = Vector2i.ZERO
var _has_food: bool = false


func _ready() -> void:
	if world_grid == null:
		push_error(
			"FoodSpawner: World Grid has not been assigned."
		)

	if food_layer == null:
		push_error(
			"FoodSpawner: Food Layer has not been assigned."
		)


func spawn_food(
	occupied_snake_cells: Array[Vector2i]
) -> bool:
	var occupied_cells: Dictionary = {}

	for cell in occupied_snake_cells:
		occupied_cells[cell] = true

	var available_cells: Array[Vector2i] = []

	for y in range(world_grid.world_size.y):
		for x in range(world_grid.world_size.x):
			var cell := Vector2i(x, y)

			if world_grid.is_blocked(cell):
				continue

			if occupied_cells.has(cell):
				continue

			available_cells.append(cell)

	if available_cells.is_empty():
		remove_food()
		return false

	_food_cell = available_cells.pick_random()
	_has_food = true

	_draw_food()

	return true


func is_food_at(cell: Vector2i) -> bool:
	return _has_food and cell == _food_cell


func get_food_cell() -> Vector2i:
	return _food_cell


func has_food() -> bool:
	return _has_food


func remove_food() -> void:
	_has_food = false

	if food_layer != null:
		food_layer.clear()


func _draw_food() -> void:
	food_layer.clear()

	food_layer.set_cell(
		_food_cell,
		source_id,
		food_atlas_coordinates
	)
