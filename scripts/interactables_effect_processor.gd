class_name InteractableItemEffectProcessor
extends Node


func _enter_tree() -> void:
	if not EventBus.interactable_collected.is_connected(
		_on_interactable_collected
	):
		EventBus.interactable_collected.connect(
			_on_interactable_collected
		)


func _exit_tree() -> void:
	if EventBus.interactable_collected.is_connected(
		_on_interactable_collected
	):
		EventBus.interactable_collected.disconnect(
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

		&"garlic":
			_apply_garlic()

		_:
			print(
				"No effect configured for: ",
				definition.interactable_id
			)


func _apply_blood_orange(
	definition: InteractablesDefinition,
	seconds_remaining: int
) -> void:
	var growth_amount := definition.get_growth_amount(
		seconds_remaining
	)

	if growth_amount <= 0:
		return

	EventBus.interaction_triggered_health_change.emit(
		growth_amount
	)

	print(
		"Blood orange collected with %d seconds left: +%d bat tiles"
		% [seconds_remaining, growth_amount]
	)


func _apply_garlic() -> void:
	EventBus.interaction_triggered_snake_speed_effect.emit(
		EventBus.SnakeSpeedEffect.SLOW_DOWN
	)

	print("Garlic activated: snake slowed down.")
