extends RigidBody2D

var item_id: String = ""
var amount: int = 1

@onready var sprite = $Sprite2D

func _ready():
	# Small random bounce on spawn
	linear_velocity = Vector2(randf_range(-50, 50), randf_range(-150, -50))
	angular_velocity = randf_range(-5, 5)
	
	if item_id != "":
		var data = Global.get_item_data(item_id)
		if data and data.get("texture") != null:
			sprite.texture = data.texture
			
	# Disable pickup for 0.6s so item bounces away before being collectable
	$PickupArea/CollisionShape2D.set_deferred("disabled", true)
	get_tree().create_timer(0.6).timeout.connect(_enable_pickup)
		
	$PickupArea.body_entered.connect(_on_body_entered)

func _enable_pickup():
	if not is_instance_valid(self):
		return
	$PickupArea/CollisionShape2D.set_deferred("disabled", false)
	# Wait one physics frame, then check if player is already overlapping
	await get_tree().physics_frame
	if not is_instance_valid(self):
		return
	for body in $PickupArea.get_overlapping_bodies():
		if body.is_in_group("player") or body.name == "Player":
			_pickup()
			return

func _on_body_entered(body):
	if body.is_in_group("player") or body.name == "Player":
		_pickup()

func _pickup():
	Global.add_item(item_id, amount)
	queue_free()
