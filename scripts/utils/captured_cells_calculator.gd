class_name CapturedCellsCalculator

static func get_all_captured_cells(targetLayer: TileMapLayer, player_occupied_cells: Array[Vector2i]) -> Dictionary[Vector2i, bool]:
	#we mark every single used cell as captured
	var captured_cells: Dictionary[Vector2i, bool] = {}
	var used_cells: Array[Vector2i] = targetLayer.get_used_cells()
	for cell in used_cells:
		captured_cells[cell] = true
	
	# now we go through every single used cell.
	# If we find a saved cell we remove it from the captured set and mark all neighbours as saved recursively 	
	for cell in used_cells:
		if(not captured_cells.has(cell)):
			continue
		
		if(player_occupied_cells.has(cell)):
			captured_cells.erase(cell) # we consider cells underneath the player as not captured
			continue
		
		var surrounding_cells: Array[Vector2i] = targetLayer.get_surrounding_cells(cell)
		for surr_cell in surrounding_cells:
			if(targetLayer.get_cell_source_id(surr_cell) == -1):
				# here we know, that this cell is next to the border, so we consider it saved
				# additional saving conditions can be added here
				_save_cell_and_neighbours(cell, captured_cells, targetLayer, player_occupied_cells)
				
			
	return captured_cells

	
# if we consider this cell saved, it will spread its saved state to all neighbours recursively
static func _save_cell_and_neighbours(cell: Vector2i, captured_cells:  Dictionary[Vector2i, bool], targetLayer: TileMapLayer, player_occupied_cells: Array[Vector2i]):
	if(!captured_cells.has(cell)): return
	if(targetLayer.get_cell_source_id(cell) == -1): return
	if(player_occupied_cells.has(cell)): return
	
	captured_cells.erase(cell)
	for surr_cell in targetLayer.get_surrounding_cells(cell):
		_save_cell_and_neighbours(surr_cell, captured_cells, targetLayer, player_occupied_cells)
	
	
