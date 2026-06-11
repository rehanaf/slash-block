extends Resource
class_name WeaponAnim

@export var duration: float = 1.0
@export var loop: bool = false
@export var keyframes: Array = [] # Each entry: {"time": float, "rotations": {bone_name: {"rot": float, "off": Vector2, "scl": Vector2, "skw": Vector2}}}
