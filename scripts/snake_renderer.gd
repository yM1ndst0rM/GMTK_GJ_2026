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
		var head_replacement_type: Vector4i = _push_head_transactions_type[_push_head_transactions_type.size() - 1]
		snake_layer.set_cell(
				_current_head_cell, 
				_pick_cell_source_id(head_replacement_type, false),
				_pick_cell_atlas_coords(head_replacement_type, false),
				_pick_alternate_tile(head_replacement_type, false)
		)
	
	#fill in the new body or head parts as required
	var should_be_head: bool = true;
	while !_push_head_transactions_type.is_empty():
		var type = _push_head_transactions_type.pop_front()
		var location = _push_head_transactions_location.pop_front()
		
		if should_be_head:
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
	return 0
	
func _pick_cell_atlas_coords(type: Vector4i,  is_head: bool) -> Vector2i:
	var going_to: Vector2i = Vector2i(type.z, type.w)
	var coming_in_direction: Vector2i = Vector2i(type.x, type.y)
	
	if is_head:
		if going_to == Vector2i.DOWN: return Vector2i(0 , 1)
		if going_to == Vector2i.LEFT: return Vector2i(0, 2)
		if going_to == Vector2i.RIGHT: return Vector2i(0, 2)
		if going_to == Vector2i.UP: return Vector2i(0, 3)
	else:
		if coming_in_direction == going_to: return Vector2i(0, 0)
		else: return Vector2i(0 ,4)
	
	return Vector2i.ZERO
	
func _pick_alternate_tile(type: Vector4i, is_head: bool) -> int:
	var coming_in_direction: Vector2i = Vector2i(type.x, type.y)
	var going_to: Vector2i = Vector2i(type.z, type.w)
	
	if is_head:
		if going_to == Vector2i.DOWN: return 0
		if going_to == Vector2i.LEFT: return 0 
		if going_to == Vector2i.RIGHT: return 1
		if going_to == Vector2i.UP: return 0 
		
	else:
		if coming_in_direction == going_to:
			if going_to == Vector2i.DOWN: return 2
			if going_to == Vector2i.LEFT: return 3
			if going_to == Vector2i.RIGHT: return 1
			if going_to == Vector2i.UP: return 0
			
		else:
			if coming_in_direction == Vector2i.UP && going_to == Vector2i.LEFT: return 0
			if coming_in_direction == Vector2i.RIGHT && going_to == Vector2i.UP: return 1
			if coming_in_direction == Vector2i.DOWN && going_to == Vector2i.RIGHT: return 2
			if coming_in_direction == Vector2i.LEFT && going_to == Vector2i.DOWN: return 3
			if coming_in_direction == Vector2i.UP && going_to == Vector2i.RIGHT: return 4
			if coming_in_direction == Vector2i.LEFT && going_to == Vector2i.UP: return 5
			if coming_in_direction == Vector2i.DOWN && going_to == Vector2i.LEFT: return 6
			if coming_in_direction == Vector2i.RIGHT && going_to == Vector2i.DOWN: return 7


	return 0
