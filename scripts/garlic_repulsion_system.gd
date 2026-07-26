class_name GarlicRepulsionSystem
extends Node


const GARLIC_ID: StringName = &"garlic"


@export_category("References")

@export var interactable_spawner: InteractableSpawner

# These can remain exported so existing scene assignments
# do not need to be removed.
@export var world_grid: WorldGrid
@export var snake_controller: SnakeController


@export_category("Garlic")

@export_range(0, 5, 1)
var activation_radius: int = 1


func try_trigger_garlic(
	trigger_cell: Vector2i
) -> bool:
	for garlic_cell in interactable_spawner.get_cells_for_id(
		GARLIC_ID
	):
		if not _is_cell_inside_garlic_radius(
			trigger_cell,
			garlic_cell
		):
			continue

		var definition := interactable_spawner.get_definition_at(
			garlic_cell
		)

		if definition == null:
			return false

		# Remove the garlic without immediately spawning
		# a replacement.
		interactable_spawner.remove_interactable_at(
			garlic_cell,
			false
		)

		# The effect processor receives this and emits the
		# snake-speed-change event.
		EventBus.interactable_collected.emit(
			definition,
			0
		)

		return true

	return false


func _is_cell_inside_garlic_radius(
	cell: Vector2i,
	garlic_cell: Vector2i
) -> bool:
	var difference: Vector2i = cell - garlic_cell

	var distance := maxi(
		absi(difference.x),
		absi(difference.y)
	)

	return distance <= activation_radius
