class_name WorldGrid
extends Node2D


const BLOCKS_SNAKE_DATA: StringName = &"blocks_snake"


@export_category("World")
@export var cells_in_playable_area: Dictionary
@export var blocked_cells: Dictionary


var _world_layers: Array[TileMapLayer] = []


func _ready() -> void:
	rebuild_playspace_cache()

func rebuild_playspace_cache() -> void:
	_world_layers.clear()
	blocked_cells.clear()
	cells_in_playable_area.clear()

	_find_world_layers(self)

	for layer in _world_layers:
		_cache_layer_collision_and_play_area(layer)

	print(
		"WorldGrid found %d layers containing %d playable cells of which %d are blocked."
		% [
			_world_layers.size(),
			cells_in_playable_area.size(),
			blocked_cells.size(),
		]
	)

# Get all layers associated with the world
func _find_world_layers(parent: Node) -> void:
	for child in parent.get_children():
		if child is TileMapLayer:
			_world_layers.append(child)

		_find_world_layers(child)


func _cache_layer_collision_and_play_area(layer: TileMapLayer) -> void:
	for cell in layer.get_used_cells():
		cells_in_playable_area[cell] = true
		var tile_data: TileData = layer.get_cell_tile_data(cell)

		if tile_data == null:
			continue

		if not tile_data.has_custom_data(BLOCKS_SNAKE_DATA):
			continue

		var blocks_snake: bool = bool(
			tile_data.get_custom_data(BLOCKS_SNAKE_DATA)
		)

		if blocks_snake:
			blocked_cells[cell] = true


func is_inside_world(cell: Vector2i) -> bool:
	return cells_in_playable_area.has(cell)

# Get if blocked, meaning, is the snake blocked from touching it?
# To set if a layer should be blocking, select a tile from the atlas 
# and set its custom data to blocks_snake
func is_blocked(cell: Vector2i) -> bool:
	if not is_inside_world(cell):
		return true

	return blocked_cells.has(cell)

func calculate_captured_area(player_occupied_cells: Array[Vector2i])  -> Dictionary[Vector2i, bool]:
	return CapturedCellsCalculator.get_all_captured_cells($GroundLayer, player_occupied_cells)

func add_blocked_cell(cell: Vector2i) -> void:
	if is_inside_world(cell):
		blocked_cells[cell] = true

func remove_blocked_cell(cell: Vector2i) -> void:
	blocked_cells.erase(cell)
