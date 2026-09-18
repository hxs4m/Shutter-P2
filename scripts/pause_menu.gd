extends CanvasLayer

@onready var continue_btn: Button = $MarginContainer/VBoxContainer/ContinueButton
@onready var settings_btn: Button = $MarginContainer/VBoxContainer/SettingsButton
@onready var back_btn: Button = $MarginContainer/VBoxContainer/BackToMenuButton 
@onready var quit_btn: Button = $MarginContainer/VBoxContainer/QuitGameButton

# Reference to the instantiated SettingsMenu scene
@onready var settings_menu: Control = $SettingsMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	
	continue_btn.pressed.connect(_on_continue_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	back_btn.pressed.connect(_on_back_to_menu_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# If the settings menu is currently open, pressing ESC should close settings first
		if settings_menu.visible:
			settings_menu.close_menu()
		else:
			toggle_pause()

func toggle_pause() -> void:
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	
	if is_paused:
		show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		# Close settings if it was left open when unpausing
		if settings_menu.visible:
			settings_menu.hide()
		hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_continue_pressed() -> void:
	toggle_pause()

func _on_settings_pressed() -> void:
	# Calls the smooth entrance animation function we built in SettingsMenu
	settings_menu.open_menu()

func _on_back_to_menu_pressed() -> void:
	get_tree().paused = false 
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/MainMenuScene.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
