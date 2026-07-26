class_name InteractableItemEffectProcessor
extends Node


@export_category("References")

@export var interactable_spawner: InteractableSpawner
@export var snake_controller: SnakeController


func _ready() -> void:
	if interactable_spawner == null:
		push_error(
			"InteractableItemEffectProcessor: "
			+ "Interactable Spawner has not been assigned."
		)
		return

	if snake_controller == null:
		push_error(
			"InteractableItemEffectProcessor: "
			+ "Snake Controller has not been assigned."
		)
		return

	interactable_spawner.interactable_collected.connect(
		_on_interactable_collected
	)


func _on_interactable_collected(
	definition: InteractablesDefinition,
	seconds_remaining: int
) -> void:
	match definition.interactable_id:
		&"blood_orange":
			_apply_blood_orange(
				definition,
				seconds_remaining
			)

		_:
			print(
				"No effect configured for: ",
				definition.interactable_id
			)


func _apply_blood_orange(
	definition: InteractablesDefinition,
	seconds_remaining: int
) -> void:
	var growth_amount: int = (
		definition.get_growth_amount(
			seconds_remaining
		)
	)

	if growth_amount <= 0:
		return

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
