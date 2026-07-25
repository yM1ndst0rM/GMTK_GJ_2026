class_name FoodDefinition
extends Resource


@export_category("Identity")

@export var food_id: StringName = &"food"


@export_category("Tile")

@export var source_id: int = 0
@export var atlas_coordinates: Vector2i = Vector2i.ZERO


@export_category("Spawning")

@export_range(1, 20, 1)
var maximum_active: int = 1

@export_range(0, 100, 1)
var minimum_spawn_radius: int = 0

@export_range(1, 100, 1)
var maximum_spawn_radius: int = 10


@export_category("Lifetime")

## Zero means the food never expires.
@export_range(0, 600, 1)
var lifetime_seconds: int = 0

@export var show_countdown: bool = false


@export_category("Snake Growth")
## Not all food/drop item allow the player to grow. Toggle here.
@export var contributes_to_growth: bool = true
## Reward when collected with more than
## medium_reward_max_seconds remaining.
@export_range(0, 100, 1)
var normal_growth_amount: int = 1

## Reward when collected with this many seconds
## or fewer remaining.
@export_range(0, 600, 1)
var medium_reward_max_seconds: int = 3

@export_range(0, 100, 1)
var medium_growth_amount: int = 2

## Reward when collected with this many seconds
## or fewer remaining.
@export_range(0, 600, 1)
var low_time_reward_max_seconds: int = 1

@export_range(0, 100, 1)
var low_time_growth_amount: int = 3


func get_growth_amount(
	seconds_remaining: int
) -> int:
	if contributes_to_growth:
		if lifetime_seconds <= 0:
			return normal_growth_amount

		if seconds_remaining <= 0:
			return 0

		if seconds_remaining <= low_time_reward_max_seconds:
			return low_time_growth_amount

		if seconds_remaining <= medium_reward_max_seconds:
			return medium_growth_amount

		return normal_growth_amount
	else: 
		return 0
