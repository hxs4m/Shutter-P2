extends CharacterBody3D

@export_category("References")
@export var player: Node3D
@export var main_timer: Node # Drag your Main Timer node here

@export_category("Movement")
@export var move_speed: float = 4.0
@export var float_height: float = 1.5
@export var bob_speed: float = 2.0
@export var bob_height: float = 0.5

@export_category("Jumpscare Settings")
@export var catch_distance: float = 1.5
@export var time_penalty: float = 60.0 # 1 minute
@export var jumpscare_duration: float = 1.2
@export var jumpscare_shake_intensity: float = 0.5

var is_chasing: bool = true
var time_alive: float = 0.0

@onready var mesh: MeshInstance3D = $MeshInstance3D # Ensure your slime mesh is named this

func _ready() -> void:
	# Ensure the slime doesn't collide with the player and push them around
	# Put the slime on a different collision layer, or use an Area3D for detection if you prefer.
	# For now, we will just disable collision with the player character body if needed.
	pass

func _physics_process(delta: float) -> void:
	if not is_chasing or player == null:
		return
		
	time_alive += delta
	
	# 1. Calculate direction to player
	var direction = global_position.direction_to(player.global_position)
	
	# 2. Add floating bob effect
	var current_float_offset = sin(time_alive * bob_speed) * bob_height
	
	# 3. Apply movement (ignoring gravity since it flies)
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	
	# Smoothly adjust Y to match player height + float offset
	var target_y = player.global_position.y + float_height + current_float_offset
	velocity.y = (target_y - global_position.y) * 2.0
	
	# 4. Look at the player (but keep it level)
	var look_pos = player.global_position
	look_pos.y = global_position.y
	look_at(look_pos, Vector3.UP)
	
	move_and_slide()
	
	# 5. Check for catch
	if global_position.distance_to(player.global_position) <= catch_distance:
		trigger_jumpscare()

func trigger_jumpscare() -> void:
	is_chasing = false
	
	# Deduct time from the main timer
	if main_timer and main_timer.has_method("subtract_time"):
		main_timer.subtract_time(time_penalty)
		
	# Get the player's camera
	var camera: Camera3D = get_viewport().get_camera_3d()
	
	if camera:
		# Snap the slime directly in front of the camera
		# Adjust the Z offset (-1.0) if it's too close or too far
		var forward_dir = -camera.global_transform.basis.z
		global_position = camera.global_position + (forward_dir * 1.0) 
		
		# Look directly at the camera
		look_at(camera.global_position, Vector3.UP)
		
		# Create a tween for the wiggle/shake effect
		var tween = create_tween()
		tween.set_loops(int(jumpscare_duration * 10)) # Wiggle rapidly
		
		for i in range(int(jumpscare_duration * 10)):
			var random_offset = Vector3(
				randf_range(-jumpscare_shake_intensity, jumpscare_shake_intensity),
				randf_range(-jumpscare_shake_intensity, jumpscare_shake_intensity),
				0
			)
			# Shake the mesh locally
			tween.tween_property(mesh, "position", random_offset, 0.05)
			tween.tween_property(mesh, "position", Vector3.ZERO, 0.05)
			
		# Wait for the jumpscare to finish, then delete the slime
		await get_tree().create_timer(jumpscare_duration).timeout
		queue_free()
	else:
		# Fallback if no camera is found
		queue_free()
