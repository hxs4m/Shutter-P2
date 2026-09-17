extends CanvasLayer

@onready var continue_btn: Button = $MarginContainer/VBoxContainer/ContinueButton
@onready var back_btn: Button = $MarginContainer/VBoxContainer/BackToMenuButton 
@onready var quit_btn: Button = $MarginContainer/VBoxContainer/QuitGameButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide() # Hides the menu when the game first loads
	
	continue_btn.pressed.connect(_on_continue_pressed)
	back_btn.pressed.connect(_on_back_to_menu_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _input(event: InputEvent) -> void:
	# "ui_cancel" is Godot's built-in action for the Escape key
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause() -> void:
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	
	if is_paused:
		show()
		# Unlocks and shows the mouse
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		hide()
		# Locks the mouse back to the center of the screen for gameplay
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) 

func _on_continue_pressed() -> void:
	toggle_pause()

func _on_back_to_menu_pressed() -> void:
	get_tree().paused = false 
	# Ensure the mouse stays visible when loading into the Main Menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/MainMenuScene.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
