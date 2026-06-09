extends StaticBody2D

@export var node_type: String = "tree" # "tree" or "rock"
@export var max_health: float = 30.0
@export var drop_item_id: String = "wood"
@export var drop_amount: int = 2
@export var respawn_time: float = 300.0 # 5 minutes in-game

var health: float
var is_destroyed: bool = false
var respawn_timer: float = 0.0

var drop_scene = preload("res://src/world/drop_item.tscn")

func _ready():
	health = max_health
	_setup_visuals()

func _process(delta):
	if is_destroyed and respawn_timer > 0:
		respawn_timer -= delta * Global.tick_speed
		if respawn_timer <= 0:
			_respawn()


func _setup_visuals():
	# Clear existing children that might be placeholders
	for child in get_children():
		if child is Sprite2D:
			child.queue_free()
			
	if node_type == "tree":
		_build_tree()
	elif node_type == "rock":
		_build_rock()

func _build_tree():
	# 3 blocks high log
	var log_tex = load("res://assets/blocks/log_oak.png")
	for i in range(3):
		var s = Sprite2D.new()
		s.texture = log_tex
		s.position = Vector2(0, -16 * i)
		add_child(s)
		
	# Leaves on top
	var leaves_tex = load("res://assets/blocks/leaves_oak.tga")
	var leaf_positions = [
		Vector2(0, -48), Vector2(-16, -48), Vector2(16, -48),
		Vector2(0, -64), Vector2(-16, -64), Vector2(16, -64),
		Vector2(0, -80)
	]
	for p in leaf_positions:
		var s = Sprite2D.new()
		s.texture = leaves_tex
		s.position = p
		add_child(s)
		
	# Collision shape covers the logs
	var shape = RectangleShape2D.new()
	shape.size = Vector2(16, 48)
	var cs = $CollisionShape2D
	cs.shape = shape
	cs.position = Vector2(0, -16) # Center of the 3 logs

func _build_rock():
	var tex = load("res://assets/blocks/stone.png")
	var s = Sprite2D.new()
	s.texture = tex
	s.position = Vector2(0, 0)
	add_child(s)
	
	var shape = RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	var cs = $CollisionShape2D
	cs.shape = shape
	cs.position = Vector2(0, 0)

func take_damage(amount: float, _kb_dir: Vector2 = Vector2.ZERO):
	if is_destroyed: return
	
	health -= amount
	
	# Shake effect
	var tween = create_tween()
	var original_pos = position
	tween.tween_property(self, "position", original_pos + Vector2(2, 0), 0.05)
	tween.tween_property(self, "position", original_pos - Vector2(2, 0), 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)
	
	if health <= 0:
		_destroy()

func _destroy():
	is_destroyed = true
	
	# Spawn drops
	for i in range(drop_amount):
		var drop = drop_scene.instantiate()
		drop.item_id = drop_item_id
		drop.position = position + Vector2(randf_range(-8, 8), -16)
		get_parent().call_deferred("add_child", drop)
		
	# Hide visuals and disable collision
	visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Start respawn timer based on tick speed
	respawn_timer = respawn_time

func _respawn():
	is_destroyed = false
	health = max_health
	visible = true
	$CollisionShape2D.set_deferred("disabled", false)
