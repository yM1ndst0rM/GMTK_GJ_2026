class_name SnakeRenderer
extends Node


@export_category("References")

@export var snake_layer: TileMapLayer


@export_category("Snake Tiles")

@export var source_id: int = 0

@export var head_atlas_coordinates: Vector2i = Vector2i.ZERO

@export var body_atlas_coordinates: Vector2i = Vector2i.ZERO

@export var terrain_set: int = 0
@export var terrain_id: int  = 0

var _push_head_transactions_type: Array[Vector4i] = []
var _push_head_transactions_location: Array[Vector2i] = []
var _previous_direction: Vector2i = Vector2i.RIGHT
var _current_head_cell: Vector2i = Vector2i.MIN
var _current_head_cell_type: Vector4i = Vector4i.MIN

var _clear_cell_transactions: Array[Vector2i] = []

func _ready() -> void:
	if snake_layer == null:
		push_error(
			"SnakeRenderer: Snake Layer has not been assigned."
		)
		
func push_head(new_head_cell: Vector2i, direction: Vector2i):
	_push_head_transactions_type.push_front(Vector4i(_previous_direction.x, _previous_direction.y, direction.x, direction.y))
	_push_head_transactions_location.push_front(new_head_cell)
	_previous_direction = direction
	
func clear_cell(cell_to_clear: Vector2i):
	_clear_cell_transactions.push_front(cell_to_clear)
	

func draw_snake() -> void:
	if snake_layer == null:
		return

	
	# Redraw the snake using the current snake data.
	while !_clear_cell_transactions.is_empty():
		snake_layer.erase_cell(_clear_cell_transactions.pop_front())
		
	# if we have a new head, replace the previous one with the appropriate body part
	if _current_head_cell != Vector2i.MIN && !_push_head_transactions_type.is_empty():
		snake_layer.set_cell(
				_current_head_cell, 
				_pick_cell_source_id(_current_head_cell_type, false),
				_pick_cell_atlas_coords(_current_head_cell_type, false),
				_pick_alternate_tile(_current_head_cell_type, false)
		)
	
	#fill in the new body or head parts as required
	var should_be_head: bool = true;
	while !_push_head_transactions_type.is_empty():
		var type = _push_head_transactions_type.pop_front()
		var location = _push_head_transactions_location.pop_front()
		
		if should_be_head:
			_current_head_cell_type = type
			_current_head_cell = location
		
		var curr_source_id: int = _pick_cell_source_id(type, should_be_head)
		var atlas_coors: Vector2i = _pick_cell_atlas_coords(type, should_be_head)
		var alternate_id: int = _pick_alternate_tile(type, should_be_head)
		snake_layer.set_cell(location, curr_source_id, atlas_coors, alternate_id)
		
		should_be_head = false
	
	

func clear_snake() -> void:
	if snake_layer == null:
		return

	snake_layer.clear()


func _pick_cell_source_id(type: Vector4i,  is_head: bool) -> int:
	return source_id
	
func _pick_cell_atlas_coords(type: Vector4i,  is_head: bool) -> Vector2i:
	if is_head:
		return head_atlas_coordinates
	else:
		return body_atlas_coordinates
	
func _pick_alternate_tile(type: Vector4i, is_head: bool) -> int:
	return 0
