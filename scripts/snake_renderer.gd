class_name SnakeRenderer
extends Node


@export_category("Layer")

@export var snake_layer: TileMapLayer


@export_category("Snake Tiles")

@export var source_id: int = 0

@export var head_atlas_coordinates: Vector2i = Vector2i(0, 0)

@export var body_atlas_coordinates: Vector2i = Vector2i(1, 0)


func _ready() -> void:
	if snake_layer == null:
		push_error(
			"SnakeRenderer: Snake Layer has not been assigned."
		)

# We may need to do this differently... I have no idea how big the player will be. 
func draw_initial_snake(
	snake_cells: Array[Vector2i]
) -> void:
	snake_layer.clear()

	for index in range(snake_cells.size()):
		var atlas_coordinates: Vector2i

		if index == 0:
			atlas_coordinates = head_atlas_coordinates
		else:
			atlas_coordinates = body_atlas_coordinates

		snake_layer.set_cell(
			snake_cells[index],
			source_id,
			atlas_coordinates
		)


func apply_move(
	new_head: Vector2i,
	previous_head: Vector2i,
	removed_tail: Vector2i,
	remove_tail: bool
) -> void:
	# Erase the tail first. This handles moving into the cell
	# that the tail is leaving during the same movement.
	if remove_tail:
		snake_layer.erase_cell(removed_tail)

	snake_layer.set_cell(
		previous_head,
		source_id,
		body_atlas_coordinates
	)

	snake_layer.set_cell(
		new_head,
		source_id,
		head_atlas_coordinates
	)


func clear_snake() -> void:
	if snake_layer != null:
		snake_layer.clear()
		
func erase_segment(cell: Vector2i) -> void:
	if snake_layer == null:
		return

	snake_layer.erase_cell(cell)


func cell_to_global(cell: Vector2i) -> Vector2:
	return snake_layer.to_global(
		snake_layer.map_to_local(cell)
	)
