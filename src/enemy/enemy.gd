extends CharacterBody2D

var health: int = 100
var max_health: int = 100
var knockback: Vector2 = Vector2.ZERO
var flash_timer: float = 0.0

# Zombie chase parameters
const DETECT_RANGE = 220.0
const ZOMBIE_WALK_SPEED = 30.0

# Gravity
var gravity = 980.0

var spawn_position: Vector2 = Vector2.ZERO

# UI display
@onready var health_bar = $HealthBar
@onready var visual = $Visual

func _ready():
	spawn_position = global_position
	add_to_group("enemies")
	collision_layer = 4 # Match player's attack mask
	collision_mask = 1  # Collides only with TileMap (environment)
	
	# Face left by default (towards player spawn)
	if visual:
		visual.scale.x = -1.0
		
	# Create a simple health bar programmatically if not present
	update_health_bar()

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Apply knockback or chase player
	if knockback.length() > 5.0:
		velocity.x = knockback.x
		# Apply vertical knockback directly if starting knockback
		if knockback.y != 0:
			velocity.y = knockback.y
			knockback.y = 0 # Only apply vertical impulse once
		# Friction on knockback
		knockback.x = move_toward(knockback.x, 0.0, 400.0 * delta)
		
		# Face the direction of the player who hit us
		if abs(velocity.x) > 10.0:
			visual.scale.x = -sign(velocity.x)
			
		# Disable walk animation during hitstun
		if visual:
			visual.is_moving = false
	else:
		# Chase AI
		var player = get_parent().get_node_or_null("Player")
		if player:
			var diff_x = player.global_position.x - global_position.x
			var diff_y = player.global_position.y - global_position.y
			
			# If player is within distance horizontally and vertically
			if abs(diff_x) < DETECT_RANGE and abs(diff_y) < 80.0:
				velocity.x = sign(diff_x) * ZOMBIE_WALK_SPEED
				if visual:
					visual.scale.x = sign(diff_x)
					visual.is_moving = true
				
				# Apply contact damage if player is close enough, not dead, and not invulnerable
				if abs(diff_x) < 14.0 and abs(diff_y) < 20.0 and not player.is_dead and player.invulnerability_timer <= 0.0:
					var kb_dir = Vector2(sign(diff_x), -0.5).normalized()
					player.take_damage(10, kb_dir * 180.0)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
				if visual:
					visual.is_moving = false
		else:
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			if visual:
				visual.is_moving = false
		
	move_and_slide()
	
	# Handle flash animation
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			visual.modulate = Color.WHITE
		else:
			# Red flashing
			visual.modulate = Color(1.0, 0.3, 0.3, 1.0)

func take_damage(amount: int, kb: Vector2):
	health -= amount
	flash_timer = 0.15
	knockback = kb
	
	# Spawn damage text popup
	spawn_damage_text(amount)
	
	# Spawn particles
	spawn_hit_particles()
	
	if health <= 0:
		die()
	else:
		update_health_bar()

func update_health_bar():
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		# Hide health bar if full, show if damaged
		health_bar.visible = (health < max_health)

func spawn_damage_text(amount: int):
	var label = Label.new()
	label.text = str(amount)
	# Custom style for damage text
	label.scale = Vector2(0.4, 0.4) # Since camera zoom is 2.5x
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = global_position + Vector2(-10, -20) + Vector2(randf_range(-5, 5), randf_range(-5, 2))
	
	# Font override
	label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	label.add_theme_font_size_override("font_size", 32)
	
	get_parent().add_child(label)
	
	# Tween to float up and fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 15, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func spawn_respawn_text():
	var label = Label.new()
	label.text = "RESPAWN!"
	label.scale = Vector2(0.3, 0.3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = global_position + Vector2(-20, -25)
	label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))
	label.add_theme_font_size_override("font_size", 32)
	get_parent().add_child(label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 12, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func spawn_hit_particles():
	if get_parent() and get_parent().has_method("create_particles"):
		# Red/dark particles for zombie hit
		get_parent().create_particles(global_position, Color(0.6, 0.1, 0.1, 0.8), 8)

func die():
	# Spawn XP / Smoke particles
	if get_parent() and get_parent().has_method("create_particles"):
		get_parent().create_particles(global_position, Color(0.7, 0.9, 0.3, 0.8), 12) # XP green
		get_parent().create_particles(global_position, Color(0.9, 0.9, 0.9, 0.5), 8)  # Smoke
		
	# Create a respawn timer in the parent node (world)
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(func():
		var enemy_scene = load("res://src/enemy/enemy.tscn")
		var new_enemy = enemy_scene.instantiate()
		new_enemy.position = spawn_position
		get_parent().add_child(new_enemy)
		timer.queue_free()
	)
	get_parent().add_child(timer)
	timer.start()
	
	queue_free()
