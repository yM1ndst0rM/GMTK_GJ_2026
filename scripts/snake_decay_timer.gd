class_name SnakeDecayTimer
extends Node


signal decay_time_expired
signal countdown_updated(seconds_remaining: float)


@export_category("Decay")

## Number of minutes between each lost snake segment.
@export_range(0.05, 60.0, 0.05, "or_greater")
var minutes_per_decay: float = 1.0

## How often the countdown_updated signal is emitted.
@export_range(0.05, 1.0, 0.05)
var countdown_update_interval: float = 0.1


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

	if _countdown_update_accumulator < countdown_update_interval:
		return

	_countdown_update_accumulator = 0.0

	countdown_updated.emit(
		get_seconds_remaining()
	)


func start_countdown() -> void:
	_running = true
	_countdown_update_accumulator = 0.0

	decay_timer.wait_time = get_decay_seconds()
	decay_timer.start()

	set_process(true)

	countdown_updated.emit(
		get_seconds_remaining()
	)


func stop_countdown() -> void:
	_running = false
	decay_timer.stop()

	set_process(false)

	countdown_updated.emit(0.0)


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


func set_minutes_per_decay(new_minutes: float) -> void:
	minutes_per_decay = maxf(new_minutes, 0.05)

	if _running:
		restart_countdown()


func get_decay_seconds() -> float:
	return minutes_per_decay * 60.0


func get_seconds_remaining() -> float:
	if not _running:
		return 0.0

	return decay_timer.time_left

# May or may not be useful.. likely used for UI
func get_formatted_time_remaining() -> String:
	var total_seconds := ceili(get_seconds_remaining())

	var minutes = total_seconds / 60
	var seconds = total_seconds % 60

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
