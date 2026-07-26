extends AudioStreamPlayer2D


# Called when the node enters the scene tree for the first time.
func start_music() -> void:
	play()
func stop_music(win: bool) -> void:
	stop()
func _enter_tree() -> void:
	if !EventBus.game_started.is_connected(start_music):
		EventBus.game_started.connect(start_music)
	
	if !EventBus.game_ended.is_connected(stop_music):
		EventBus.game_ended.connect(stop_music)
		
func _exit_tree() -> void:
	if EventBus.game_started.is_connected(start_music):
		EventBus.game_started.disconnect(start_music)
	
	if EventBus.game_ended.is_connected(stop_music):
		EventBus.game_ended.disconnect(stop_music)
