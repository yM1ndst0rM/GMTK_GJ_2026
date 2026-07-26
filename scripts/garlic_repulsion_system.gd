class_name GarlicRepulsionSystem
extends Node


const CARDINAL_DIRECTIONS = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT
]


@export_category("References")

@export var interactable_spawner: InteractableSpawner
@export var world_grid: WorldGrid
@export var snake_controller: SnakeController


@export_category("Garlic")

@export_range(0, 5, 1)
var repulsion_radius: int = 1


func would_repel(cell: Vector2i) -> bool:
	return _is_inside_garlic_radius(cell)


func choose_push_direction(
	current_cell: Vector2i,
	attempted_direction: Vector2i
) -> Vector2i:
	var best_directions: Array[Vector2i] = []
	var best_distance: int = -1

	for direction in CARDINAL_DIRECTIONS:
		# The push should change Count Moro's direction.
		if direction == attempted_direction:
			continue

		var candidate_cell = (
			current_cell + direction
		)

		if world_grid.is_blocked(candidate_cell):
			continue

		if snake_controller.occupies_cell(
			candidate_cell
		):
			continue

		if _is_inside_garlic_radius(
			candidate_cell
		):
			continue

		var garlic_distance := (
			_get_nearest_garlic_distance_squared(
				candidate_cell
			)
		)

		if garlic_distance > best_distance:
			best_distance = garlic_distance
			best_directions.clear()
			best_directions.append(direction)

		elif garlic_distance == best_distance:
			best_directions.append(direction)

	if best_directions.is_empty():
		return Vector2i.ZERO

	return best_directions.pick_random()


func _is_inside_garlic_radius(
	cell: Vector2i
) -> bool:
	for garlic_cell in (
		interactable_spawner.get_cells_for_id(
			CellsTypes.T_GARLIC
		)
	):
		if _is_cell_inside_garlic_radius(
			cell,
			garlic_cell
		):
			return true

	return false


func _get_nearest_garlic_distance_squared(
	cell: Vector2i
) -> int:
	var nearest_distance := 1_000_000_000

	for garlic_cell in (
		
		interactable_spawner.get_cells_for_id(
			CellsTypes.T_GARLIC
		)
	):
		nearest_distance = mini(
			nearest_distance,
			cell.distance_squared_to(
				garlic_cell
			)
		)

	return nearest_distance
	
	
func trigger_repulsion(
	current_cell: Vector2i,
	trigger_cell: Vector2i,
	attempted_direction: Vector2i
) -> Vector2i:
	# Calculate the push while the garlic still exists.
	var forced_direction := choose_push_direction(
		current_cell,
		attempted_direction
	)

	_remove_triggering_garlic(trigger_cell)

	return forced_direction
	
func _remove_triggering_garlic(
	trigger_cell: Vector2i
) -> void:
	for garlic_cell in (
		interactable_spawner.get_cells_for_id(
			CellsTypes.T_GARLIC
		)
	):
		if not _is_cell_inside_garlic_radius(
			trigger_cell,
			garlic_cell
		):
			continue

		# False means do not immediately spawn replacement garlic.
		interactable_spawner.remove_interactable_at(
			garlic_cell,
			false
		)

		print(
			"Garlic activated and removed at ",
			garlic_cell
		)

		return
		
func _is_cell_inside_garlic_radius(
	cell: Vector2i,
	garlic_cell: Vector2i
) -> bool:
	var difference: Vector2i = (
		cell - garlic_cell
	)

	var distance := maxi(
		absi(difference.x),
		absi(difference.y)
	)

	return distance <= repulsion_radius
