extends "res://src/data/items/item_data.gd"
class_name WeaponData

@export var inner_color: Color = Color(0.85, 0.85, 0.85)
@export var outline_color: Color = Color(0.45, 0.48, 0.52)
@export var attack_duration: float = 0.3
@export var attack_cooldown: float = 0.3
@export var attack_anim: Resource # Optional custom animation

func _init():
	type = "weapon"
