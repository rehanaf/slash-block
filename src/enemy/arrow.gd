extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 140.0
var damage: int = 8
var lifetime: float = 3.5
var stopped: bool = false

func _ready():
	# Arrow sprite (7x2 pixels, drawn programmatically)
	var sprite = Sprite2D.new()
	var img = Image.create(7, 2, false, Image.FORMAT_RGBA8)
	# Fletching (feather)
	img.set_pixel(0, 0, Color(0.9, 0.9, 0.85))
	img.set_pixel(0, 1, Color(0.85, 0.85, 0.8))
	# Shaft (wood brown)
	for x in range(1, 5):
		img.set_pixel(x, 0, Color(0.55, 0.35, 0.2))
		img.set_pixel(x, 1, Color(0.45, 0.28, 0.15))
	# Tip (iron gray)
	img.set_pixel(5, 0, Color(0.65, 0.65, 0.7))
	img.set_pixel(5, 1, Color(0.55, 0.55, 0.6))
	img.set_pixel(6, 0, Color(0.5, 0.5, 0.55))
	img.set_pixel(6, 1, Color(0.45, 0.45, 0.5))
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	
	# Collision shape
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(7, 2)
	col.shape = shape
	add_child(col)
	
	# Physics layers: don't occupy any layer, detect environment (1) + player (2)
	collision_layer = 0
	collision_mask = 3
	
	# Rotate sprite to match flight direction
	rotation = direction.angle()
	
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if stopped:
		return
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body):
	if stopped:
		return
	if body.has_method("take_damage"):
		var kb = direction.normalized() * 100.0
		body.take_damage(damage, kb)
		queue_free()
	else:
		# Hit environment - stick and fade
		stopped = true
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.6)
		tween.tween_callback(queue_free)
