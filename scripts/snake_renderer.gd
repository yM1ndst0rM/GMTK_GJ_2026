class_name SnakeRenderer
extends Node


@export_category("References")

@export var snake_layer: TileMapLayer


@export_category("Snake Tiles")

@export var source_id: int = 0

@export var head_atlas_coordinates: Vector2i = Vector2i(5, 0)

@export var body_atlas_coordinates: Vector2i = Vector2i(6, 0)


func _ready() -> void:
	if snake_layer == null:
		push_error(
			"SnakeRenderer: Snake Layer has not been assigned."
		)


func draw_snake(
	snake_cells: Array[Vector2i]
) -> void:
	if snake_layer == null:
		return

	# Clear all previously drawn snake tiles.
	snake_layer.clear()

	# Redraw the snake using its current cell data.
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


func clear_snake() -> void:
	if snake_layer != null:
		snake_layer.clear()
