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
			
	$PickupArea/CollisionShape2D.set_deferred("disabled", true)
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(self) and $PickupArea:
			$PickupArea/CollisionShape2D.set_deferred("disabled", false)
	)
		
	$PickupArea.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Check by group (more reliable than checking node name)
	if body.is_in_group("player") or body.name == "Player":
		Global.add_item(item_id, amount)
		queue_free()
