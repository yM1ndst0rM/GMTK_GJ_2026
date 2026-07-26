extends Node
class_name VillagerController

func get_all_villagers()-> Array[Vector2i]:
	return CellsTypes.get_all_cells_of_type($InteractablesLayer , CellsTypes.T_VILLAGER)

func kill_villager_on(cell: Vector2i):
	if(CellsTypes.is_cell_of_type($InteractablesLayer, cell, CellsTypes.T_VILLAGER)):
		EventBus.villager_killed.emit(cell, get_all_villagers().size())
		
