class_name SnakeDecayTimer
extends Node

var _decay_interval_overrides: Dictionary = {}
const MILLIS_IN_SECOND = 1000.0
const SECONDS_IN_MINUTE = 60.0

signal decay_time_expired
signal countdown_updated(millis_remaining: int)


@export_category("Decay")

## Number of milliseconds between each lost snake segment.
@export_range(50, 60_000, 50, "or_greater")
var decay_after_millis: int = 1000

## How often the countdown_updated signal is emitted.
@export_range(50, 1_000, 50)
var countdown_update_interval_millis: int = 100


@onready var decay_timer: Timer = $DecayTimer


var _countdown_update_accumulator: float = 0.0
var _running: bool = false


func _ready() -> void:
	decay_timer.one_shot = false
	decay_timer.autostart = false
	decay_timer.timeout.connect(_on_decay_timer_timeout)

	set_process(false)


func _process(delta: float) -> void:
	if not _running:
		return

	_countdown_update_accumulator += delta

	if _countdown_update_accumulator < (countdown_update_interval_millis / MILLIS_IN_SECOND):
		return

	_countdown_update_accumulator = 0.0

	countdown_updated.emit(
		get_millis_remaining()
	)


func start_countdown() -> void:
	_running = true
	_countdown_update_accumulator = 0.0

	decay_timer.wait_time = (
		_get_effective_decay_millis()
		/ MILLIS_IN_SECOND
	)
	decay_timer.start()

	set_process(true)

	countdown_updated.emit(
		get_millis_remaining()
	)


func stop_countdown() -> void:
	_running = false
	decay_timer.stop()

	set_process(false)

	countdown_updated.emit(0)


func restart_countdown() -> void:
	stop_countdown()
	start_countdown()


func pause_countdown() -> void:
	if not _running:
		return

	decay_timer.paused = true
	set_process(false)


func resume_countdown() -> void:
	if not _running:
		return

	decay_timer.paused = false
	set_process(true)


func set_decay_after_millis(new_millis: int) -> void:
	decay_after_millis = maxf(new_millis, 50)

	if _running:
		restart_countdown()


func get_decay_after_millis() -> int:
	return decay_after_millis


func get_millis_remaining() -> int:
	if not _running:
		return 0.0

	return roundi(decay_timer.time_left * MILLIS_IN_SECOND)

# May or may not be useful.. likely used for UI
func get_formatted_time_remaining() -> String:
	var total_millis := ceili(get_millis_remaining())

	var seconds = total_millis / MILLIS_IN_SECOND
	var minutes = seconds / SECONDS_IN_MINUTE

	return "%02d:%02d" % [
		minutes,
		seconds
	]


func is_running() -> bool:
	return _running


func _on_decay_timer_timeout() -> void:
	if not _running:
		return

	decay_time_expired.emit()
	
func set_decay_interval_override(
	source: StringName,
	millis: int
) -> void:
	_decay_interval_overrides[source] = maxi(
		millis,
		50
	)

	_refresh_decay_timer()


func remove_decay_interval_override(
	source: StringName
) -> void:
	_decay_interval_overrides.erase(source)
	_refresh_decay_timer()


func _get_effective_decay_millis() -> int:
	var effective_millis := decay_after_millis

	for override_value in (
		_decay_interval_overrides.values()
	):
		effective_millis = mini(
			effective_millis,
			int(override_value)
		)

	return effective_millis


func _refresh_decay_timer() -> void:
	if not _running:
		return

	decay_timer.wait_time = (
		_get_effective_decay_millis()
		/ MILLIS_IN_SECOND
	)

	decay_timer.start()
