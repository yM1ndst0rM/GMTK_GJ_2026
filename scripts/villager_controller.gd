extends Node
class_name VillagerController

func _enter_tree() -> void:
	if !EventBus.snake_captured_area_changed.is_connected(_on_snake_captured_area_changed):
		EventBus.snake_captured_area_changed.connect(_on_snake_captured_area_changed)
		
func _exit_tree() -> void:
	if EventBus.snake_captured_area_changed.is_connected(_on_snake_captured_area_changed):
		EventBus.snake_captured_area_changed.disconnect(_on_snake_captured_area_changed)

func get_all_villagers()-> Array[Vector2i]:
	return CellsTypes.get_all_cells_of_type($InteractablesLayer , CellsTypes.T_VILLAGER)

func kill_villager_on(cell: Vector2i):
	if(CellsTypes.is_cell_of_type($InteractablesLayer, cell, CellsTypes.T_VILLAGER)):
		EventBus.villager_killed.emit(cell, get_all_villagers().size())
		
func _on_snake_captured_area_changed(captured_cells: Array[Vector2i]):
	var vills: Array[Vector2i] = get_all_villagers()
	for cell in captured_cells:
		if vills.has(cell):
			kill_villager_on(cell)
