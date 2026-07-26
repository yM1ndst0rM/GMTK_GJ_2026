extends Node
class_name VillagerController

signal villager_died(cell: Vector2i) 

func get_all_villagers()-> Array[Vector2i]:
	return CellsTypes.get_all_cells_of_type($InteractablesLayer , CellsTypes.T_VILLAGER)

func kill_villager_on(cell: Vector2i):
	if(CellsTypes.is_cell_of_type($InteractablesLayer, cell, CellsTypes.T_VILLAGER)):
		_villager_died_effect(cell)
		villager_died.emit($InteractablesLayer, cell)
		

func _villager_died_effect(cell: Vector2i):
	$InteractablesLayer.erase_cell(cell)