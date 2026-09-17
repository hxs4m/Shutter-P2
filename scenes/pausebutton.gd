extends Button

@export var highlight_color: Color = Color(1.0, 1.0, 1.0, 1.0) # Bright White
@export var normal_color: Color = Color(0.6, 0.6, 0.6, 0.8)    # Dimmed Gray
@export var hover_scale: Vector2 = Vector2(1.05, 1.05)          # Slight size bump

var tween: Tween

func _ready() -> void:
	flat = true # Makes the default button background invisible
	pivot_offset = size / 2.0 # Keeps scaling centered on the text
	
	add_theme_color_override("font_color", normal_color)
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_mouse_entered) # Controller/Keyboard support
	focus_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	_animate_highlight(highlight_color, hover_scale)

func _on_mouse_exited() -> void:
	_animate_highlight(normal_color, Vector2.ONE)

func _animate_highlight(target_color: Color, target_scale: Vector2) -> void:
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween().set_parallel(true)
	# Allows hover animations to process even while get_tree().paused = true
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	
	# Transition text color
	tween.tween_property(self, "theme_override_colors/font_color", target_color, 0.12)
	# Pop scale effect
	tween.tween_property(self, "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
