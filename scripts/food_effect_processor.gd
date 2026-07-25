class_name FoodEffectProcessor
extends Node

## Maybe there is a better way to do this? 
@export_category("References")

@export var food_spawner: FoodSpawner
@export var snake_controller: SnakeController


func _ready() -> void:
	if food_spawner == null:
		push_error(
			"FoodEffectProcessor: Food Spawner is not assigned."
		)
		return

	if snake_controller == null:
		push_error(
			"FoodEffectProcessor: Snake Controller is not assigned."
		)
		return

	food_spawner.food_collected.connect(
		_on_food_collected
	)


func _on_food_collected(
	definition: FoodDefinition,
	seconds_remaining: int
) -> void:
	match definition.food_id:
		&"blood_orange":
			_apply_blood_orange(
				definition,
				seconds_remaining
			)

		_:
			push_warning(
				"FoodEffectProcessor: No effect exists for '%s'."
				% definition.food_id
			)


func _apply_blood_orange(
	definition: FoodDefinition,
	seconds_remaining: int
) -> void:
	var growth_amount: int = (
		definition.get_growth_amount(
			seconds_remaining
		)
	)

	snake_controller.add_growth(
		growth_amount
	)

	print(
		"Blood orange collected with %d seconds left: +%d bat tiles"
		% [
			seconds_remaining,
			growth_amount
		]
	)
