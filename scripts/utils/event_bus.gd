extends Node

## Global event bus
# Only events, that are of interest to many different parts of the game should be exposed here
# This script will be autoloaded so every component can subscribe to and unsubscribe from all events of interest
# Naming convention:
# Try to be as clear as possible, what kind of action triggered the signal, so that it is clear, who
# should react to it and why.



#game events
signal game_started
signal game_ended(win: bool)
signal unrecoverable_error_encountered(message: String)

#player events
signal snake_head_entered_cell(cell: Vector2i)
signal snake_moved(old_head_cell: Vector2i, head_cell: Vector2i, body: Array[Vector2i])
signal snake_captured_area_changed(captured_cells: Array[Vector2i])
signal snake_health_changed(old_health: int, health: int)
signal snake_state_changed(
	head_cell: Vector2i,
	body_cells: Array[Vector2i]
)


#interactables
signal interaction_triggered_health_change(health_change: int)
signal interactable_collected(
	definition: InteractablesDefinition,
	seconds_remaining: int
)
signal interactable_expired(
	definition: InteractablesDefinition,
	cell: Vector2i
)
signal interactable_active_count_changed(
	interactable_id: StringName,
	active_count: int
)

enum SnakeSpeedEffect{NO_EFFECT, SLOW_DOWN, SLOW_DOWN_HARD}
signal interaction_triggered_snake_speed_effect(speed_effect: SnakeSpeedEffect)

#villager events
signal villager_killed(villager_location_cell: Vector2i, number_of_remaining_villagers: int)

signal villager_cells_changed(
	villager_cells: Array[Vector2i]
)
