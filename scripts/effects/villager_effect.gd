extends Node
class_name VillagerEffect

func _enter_tree() -> void:
	if(!EventBus.villager_killed.is_connected(_on_villager_died)):
		EventBus.villager_killed.connect(_on_villager_died)

func _exit_tree() -> void:
	EventBus.villager_killed.disconnect(_on_villager_died)

func _on_villager_died(location: Vector2i , _ignored_ : int):
	$"../InteractablesLayer".erase_cell(location)
