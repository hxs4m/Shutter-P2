extends Node
## Main Timer
## Retro Analog Countdown GUI (Flat / Digital Segment Aesthetic)

# ---------------------------------------------------------------------------
# 1. Duration & Audio Settings
# ---------------------------------------------------------------------------
@export var total_duration: float = 301.0:
	set(value):
		total_duration = value
		if is_instance_valid(timer):
			timer.wait_time = max(0.001, total_duration)

@export var timeout_sound: AudioStream  # Drag your timeout sound file here in the Inspector
@export var glitch_fonts: Array[Font] = []  # Drag multiple font files here in Inspector

# ---------------------------------------------------------------------------
# 2. Movement Settings
# ---------------------------------------------------------------------------
@export var target_position: Vector2 = Vector2(0.0, 50.0)  # Matches starting Y
@export var move_speed: float = 200.0                       # pixels / second
@export var glyph_spacing: int = 16                          # Wide spacing for digital/analog character alignment

@onready var time_display: RichTextLabel = $TimeDisplay
@onready var timer: Timer = $Timer

var audio_player: AudioStreamPlayer
var _last_built_second: int = -1
var _last_state: int = -1
var _is_finished: bool = false
var _is_frozen: bool = false

# --- Intro & Fade Sequence Trackers ---
# Intro Phase: 0 = Intro Fade In, 1 = Intro Hold, 2 = Intro Fade Out, 3 = Timer Active
var _intro_phase: int = 0
var _intro_timer: float = 0.0
var _intro_fade_duration: float = 1.0   # Duration to fade in / out "FIND THE DOOR"
var _intro_hold_duration: float = 2.5   # Increased hold time (seconds)

var _fade_in_timer: float = 0.0
var _fade_in_duration: float = 1.5      # Duration of initial stepped fade-in for countdown
var _is_fading_in: bool = false
var _fade_step_alpha: float = 0.0

# Signal Flicker & Teleport Tracker
var _flicker_timer: float = 0.0
var _teleport_timer: float = 0.0
var _base_teleport_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not is_in_group("MainTimer"):
		add_to_group("MainTimer")

	time_display.bbcode_enabled = true

	# --- Dynamic Audio Player Setup ---
	audio_player = AudioStreamPlayer.new()
	audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio_player)

	# --- Centering & Initial Position ---
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	time_display.custom_minimum_size.x = viewport_width
	time_display.size.x = viewport_width
	time_display.position = Vector2(0.0, 50.0)

	time_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_display.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	# --- Bigger Font Size for Intro ---
	time_display.add_theme_font_size_override("normal_font_size", 48)

	var base_font: Font = time_display.get_theme_font("normal_font")
	if base_font:
		var spaced_font := FontVariation.new()
		spaced_font.base_font = base_font
		spaced_font.spacing_glyph = glyph_spacing
		time_display.add_theme_font_override("normal_font", spaced_font)

	time_display.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- Completely Remove Stroke / Outline ---
	time_display.remove_theme_constant_override("outline_size")
	time_display.remove_theme_color_override("font_outline_color")

	# --- Analog Phosphor Glow / Shadow ---
	time_display.add_theme_color_override("font_shadow_color", Color(0.2, 0.0, 0.0, 0.6))
	time_display.add_theme_constant_override("shadow_offset_x", 0)
	time_display.add_theme_constant_override("shadow_offset_y", 0)
	time_display.add_theme_constant_override("shadow_outline_size", 6)

	# Start invisible for intro sequence
	time_display.modulate.a = 0.0
	time_display.text = "[center]FIND THE DOOR[/center]"

	timer.wait_time = max(0.001, total_duration)
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)


func _process(delta: float) -> void:
	if _is_frozen or not is_instance_valid(time_display):
		return

	# --- Phase 1: Intro Text Stepped Fade In / Out Sequence ---
	if _intro_phase < 3:
		_process_intro_sequence(delta)
		_apply_analog_flicker(delta)
		return

	# --- Phase 2: Standard Timer Movement ---
	if not _is_finished:
		time_display.position = time_display.position.move_toward(
			target_position,
			move_speed * delta
		)

	# --- Slow Stepped Fade-In for Timer ---
	if _is_fading_in:
		_fade_in_timer += delta
		var progress: float = clamp(_fade_in_timer / _fade_in_duration, 0.0, 1.0)
		_fade_step_alpha = snappedf(progress, 0.2)
		
		if progress >= 1.0:
			_is_fading_in = false
			_fade_step_alpha = 1.0

	# --- Signal Flicker, Stepped Shake & Teleport ---
	_apply_analog_flicker(delta)

	# --- Countdown Formatting ---
	if not timer.is_stopped() and not _is_finished:
		_update_display(timer.time_left)


func _process_intro_sequence(delta: float) -> void:
	_intro_timer += delta

	match _intro_phase:
		0: # Stepped Fade-In
			var progress: float = clamp(_intro_timer / _intro_fade_duration, 0.0, 1.0)
			_fade_step_alpha = snappedf(progress, 0.25)
			
			if progress >= 1.0:
				_intro_phase = 1
				_intro_timer = 0.0
				_fade_step_alpha = 1.0

		1: # Hold Fully Visible
			_fade_step_alpha = 1.0
			if _intro_timer >= _intro_hold_duration:
				_intro_phase = 2
				_intro_timer = 0.0

		2: # Stepped Fade-Out
			var progress: float = clamp(_intro_timer / _intro_fade_duration, 0.0, 1.0)
			_fade_step_alpha = snappedf(1.0 - progress, 0.25)
			
			if progress >= 1.0:
				# Transition to Timer Phase
				_intro_phase = 3
				_is_fading_in = true
				_fade_in_timer = 0.0
				_fade_step_alpha = 0.0
				
				# Reset font size back to normal timer sizing
				time_display.add_theme_font_size_override("normal_font_size", 34)
				
				# Start the timer and display countdown
				timer.start()
				_update_display(timer.wait_time)


## Stops the timer countdown
func freeze_timer() -> void:
	_is_frozen = true
	if is_instance_valid(timer):
		timer.stop()


## Freezes the timer and destroys the display node so it cannot remain visible
func hide_timer() -> void:
	_is_frozen = true
	if is_instance_valid(timer):
		timer.stop()
	if is_instance_valid(time_display):
		time_display.hide()


func _on_timer_timeout() -> void:
	if _is_finished or _is_frozen:
		return
	_is_finished = true

	get_tree().paused = true

	if is_instance_valid(time_display):
		time_display.self_modulate = Color(1.0, 0.1, 0.1, 1.0)
		time_display.add_theme_color_override("font_shadow_color", Color(0.5, 0.0, 0.0, 0.7))
		_set_font_glitch_text()

	if timeout_sound:
		audio_player.stream = timeout_sound
		audio_player.play()

	await get_tree().create_timer(3.0, true, false, true).timeout
	get_tree().quit()


func subtract_time(amount_seconds: float = 60.0) -> void:
	if timer.is_stopped() or _is_finished or _is_frozen:
		return

	var current_remaining: float = timer.time_left
	var new_time: float = max(0.0, current_remaining - amount_seconds)

	if new_time <= 0.0:
		timer.stop()
		_on_timer_timeout()
	else:
		timer.start(new_time)
		_update_display(new_time)


func _apply_analog_flicker(delta: float) -> void:
	if _is_frozen or not is_instance_valid(time_display):
		return

	_flicker_timer += delta

	# --- Stepped Shake + Teleport Mode (End Game) ---
	if _is_finished:
		_teleport_timer += delta

		if _teleport_timer >= 0.12 or _base_teleport_pos == Vector2.ZERO:
			_teleport_timer = 0.0
			var viewport_size: Vector2 = get_viewport().get_visible_rect().size
			var rx: float = randf_range(-viewport_size.x * 0.2, viewport_size.x * 0.2)
			var ry: float = randf_range(30.0, viewport_size.y - 120.0)
			_base_teleport_pos = Vector2(rx, ry)

		var raw_shake_x: float = randf_range(-6.0, 6.0)
		var raw_shake_y: float = randf_range(-6.0, 6.0)
		var stepped_shake := Vector2(snappedf(raw_shake_x, 4.0), snappedf(raw_shake_y, 4.0))

		time_display.position = _base_teleport_pos + stepped_shake

		if _flicker_timer >= 0.04:
			_flicker_timer = 0.0
			var glitch_steps := [0.0, 0.2, 0.6, 1.0]
			time_display.modulate.a = glitch_steps[randi() % glitch_steps.size()]

			_set_font_glitch_text()
		return

	# --- Standard Analog Signal Flicker ---
	if _flicker_timer >= 0.1:
		_flicker_timer = 0.0
		var current_base_alpha: float = _fade_step_alpha
		
		if randf() > 0.95:
			time_display.modulate.a = current_base_alpha * randf_range(0.4, 0.75)
		else:
			time_display.modulate.a = current_base_alpha


func _set_font_glitch_text() -> void:
	if not is_instance_valid(time_display):
		return

	var target_string: String = "TOO LATE"
	var bbcode_result: String = "[center]"

	for i in range(target_string.length()):
		var ch: String = target_string[i]
		
		if ch == " ":
			bbcode_result += " "
			continue

		if glitch_fonts.size() > 0:
			var font_res: Font = glitch_fonts[randi() % glitch_fonts.size()]
			if font_res and font_res.resource_path != "":
				bbcode_result += "[font=%s]%s[/font]" % [font_res.resource_path, ch]
			else:
				bbcode_result += ch
		else:
			bbcode_result += ch

	bbcode_result += "[/center]"
	time_display.text = bbcode_result


func _update_display(time_left: float) -> void:
	if _is_finished or _is_frozen or not is_instance_valid(time_display):
		return

	var clamped_time: float = max(0.0, time_left)

	var minutes: int = int(clamped_time) / 60
	var seconds: int = int(clamped_time) % 60
	var time_string: String = "%02d:%02d" % [minutes, seconds]

	var state: int
	if clamped_time > 30.0:
		state = 0
	elif clamped_time > 10.0:
		state = 1
	else:
		state = 2

	if state == 0:
		time_display.self_modulate = Color(0.85, 0.90, 0.85, 1.0)
		time_display.add_theme_color_override("font_shadow_color", Color(0.1, 0.3, 0.1, 0.4))
	elif state == 1:
		var progress: float = (30.0 - clamped_time) / 20.0
		var stepped_p: float = snappedf(progress, 0.33)
		time_display.self_modulate = Color(1.0, lerp(0.8, 0.3, stepped_p), 0.0, 1.0)
		time_display.add_theme_color_override("font_shadow_color", Color(0.4, 0.2, 0.0, 0.5))
	else:
		time_display.self_modulate = Color(1.0, 0.1, 0.1, 1.0)
		time_display.add_theme_color_override("font_shadow_color", Color(0.5, 0.0, 0.0, 0.7))

	var current_second: int = int(clamped_time)
	if state == _last_state and current_second == _last_built_second:
		return
	_last_state = state
	_last_built_second = current_second

	time_display.text = "[center]%s[/center]" % time_string

#new added func rq
func add_time(amount_seconds: float) -> void:
	if timer.is_stopped() or _is_finished or _is_frozen:
		return

	var current_remaining: float = timer.time_left
	# Add the bonus seconds to the clock structure
	var new_time: float = current_remaining + amount_seconds

	# Restart the timer with the updated combined remaining time
	timer.start(new_time)
	_update_display(new_time)

## Re-initializes the intro text sequence and clock duration values for a new map layout
func reset_for_next_level() -> void:
	_is_finished = false
	_is_frozen = false
	
	if is_instance_valid(time_display):
		# Turn display back on and snap sizes back to intro presentation styles
		time_display.show()
		time_display.modulate.a = 0.0
		time_display.self_modulate = Color(0.85, 0.90, 0.85, 1.0)
		time_display.add_theme_font_size_override("normal_font_size", 48)
		time_display.text = "[center]FIND THE DOOR[/center]"
		
		# Center positioning layout
		var viewport_width: float = get_viewport().get_visible_rect().size.x
		time_display.position = Vector2(0.0, 50.0)

	# Reset state counters to Step 0 (Intro text sequence)
	_intro_phase = 0
	_intro_timer = 0.0
	_fade_in_timer = 0.0
	_is_fading_in = false
	_fade_step_alpha = 0.0
	_last_built_second = -1
	_last_state = -1

	# Assign time window limits and prepare wait intervals
	if is_instance_valid(timer):
		timer.stop()
		timer.wait_time = max(0.001, total_duration)
