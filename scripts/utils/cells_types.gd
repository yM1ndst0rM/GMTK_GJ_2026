class_name CellsTypes

const T_VILLAGER: StringName = &"is_villager"
const T_BLOCKS_SNAKE: StringName = &"blocks_snake"
#add more constant types as necessary

static func get_all_cells_of_type(cell_layer:  TileMapLayer, type: String) -> Array[Vector2i]:
	var collectedCells: Array[Vector2i] = []
	
	for cell in cell_layer.get_used_cells():
		if is_cell_of_type(cell_layer, cell, type):
			collectedCells.append(cell)
				
	return collectedCells	
	
	
static func is_cell_of_type(cell_layer:  TileMapLayer, coords: Vector2i, type: String) -> bool:
	var data: TileData = cell_layer.get_cell_tile_data(coords)
	if data:
		return data.get_custom_data(type)

	else: return false
