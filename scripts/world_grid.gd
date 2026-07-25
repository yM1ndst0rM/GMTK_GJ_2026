class_name WorldGrid
extends Node2D


const BLOCKS_SNAKE_DATA: StringName = &"blocks_snake"


@export_category("World")
# 64x64 for now. We can change later...
@export var world_size: Vector2i = Vector2i(64, 64)


var _world_layers: Array[TileMapLayer] = []
var _blocked_cells: Dictionary = {}


func _ready() -> void:
	rebuild_collision_cache()


func rebuild_collision_cache() -> void:
	_world_layers.clear()
	_blocked_cells.clear()

	_find_world_layers(self)

	for layer in _world_layers:
		_cache_layer_collision(layer)

	print(
		"WorldGrid found %d layers and %d blocked cells."
		% [
			_world_layers.size(),
			_blocked_cells.size()
		]
	)

# Get all layers associated with the world
func _find_world_layers(parent: Node) -> void:
	for child in parent.get_children():
		if child is TileMapLayer:
			_world_layers.append(child)

		_find_world_layers(child)


func _cache_layer_collision(layer: TileMapLayer) -> void:
	for cell in layer.get_used_cells():
		var tile_data: TileData = layer.get_cell_tile_data(cell)

		if tile_data == null:
			continue

		if not tile_data.has_custom_data(BLOCKS_SNAKE_DATA):
			continue

		var blocks_snake: bool = bool(
			tile_data.get_custom_data(BLOCKS_SNAKE_DATA)
		)

		if blocks_snake:
			_blocked_cells[cell] = true


func is_inside_world(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < world_size.x
		and cell.y >= 0
		and cell.y < world_size.y
	)

# Get if blocked, meaning, is the snake blocked from touching it?
# To set if a layer should be blocking, select a tile from the atlas 
# and set its custom data to blocks_snake
func is_blocked(cell: Vector2i) -> bool:
	if not is_inside_world(cell):
		return true

	return _blocked_cells.has(cell)


func add_blocked_cell(cell: Vector2i) -> void:
	if is_inside_world(cell):
		_blocked_cells[cell] = true


func remove_blocked_cell(cell: Vector2i) -> void:
	_blocked_cells.erase(cell)
