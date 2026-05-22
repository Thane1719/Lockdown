extends Window


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	close_requested.connect(_GUI_window_close)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _GUI_window_close() -> void:
	self.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Global.taskMode = false
	print("player closed minitask")
