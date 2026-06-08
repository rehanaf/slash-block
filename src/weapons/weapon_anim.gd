extends Resource
class_name WeaponAnim

export(float) var duration = 1.0
export(bool) var loop = false
export(Array) var keyframes = [] # Each entry: {"time": float, "rotations": {bone_name: {"rot": float, "off": Vector2, "scl": Vector2, "skw": Vector2}}}
