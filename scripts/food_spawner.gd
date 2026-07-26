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
var _occupied_cells: Dictionary = {}

func _enter_tree() -> void:
	if !EventBus.game_started.is_connected(_on_game_start):
		EventBus.game_started.connect(_on_game_start)

	if !EventBus.snake_moved.is_connected(_on_snake_moved):
		EventBus.snake_moved.connect(_on_snake_moved)
		
func _exit_tree() -> void:
	if EventBus.game_started.is_connected(_on_game_start):
		EventBus.game_started.disconnect(_on_game_start)

	if EventBus.snake_moved.is_connected(_on_snake_moved):
		EventBus.snake_moved.disconnect(_on_snake_moved)

func _ready() -> void:
	if world_grid == null:
		push_error(
			"FoodSpawner: World Grid has not been assigned."
		)

	if food_layer == null:
		push_error(
			"FoodSpawner: Food Layer has not been assigned."
		)

func _on_snake_moved(oldHead: Vector2i, head:  Vector2i, body: Array[Vector2i]):
	_occupied_cells.clear()
	for cell in body:
		_occupied_cells[cell] = true
		
	for cell in _occupied_cells:
		if is_food_at(cell):
			remove_food()
			EventBus.interaction_triggered_health_change.emit(+1)
			spawn_food()

func _on_game_start():
	remove_food()
	var success: bool = spawn_food()
	if !success:
		EventBus.unrecoverable_error_encountered.emit("Something went wrong when distributing food at game start.")
	

func spawn_food() -> bool:

	var available_cells: Array[Vector2i] = []

	for cell in world_grid.cells_in_playable_area.keys():
		if world_grid.is_blocked(cell):
			continue

		if _occupied_cells.has(cell):
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
