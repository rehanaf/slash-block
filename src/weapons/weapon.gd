extends Resource
class_name Weapon

export(String) var name = ""
export(String) var texture = ""
export(Color) var inner = Color(1,1,1)
export(Resource) var attack_anim
export(Color) var outline = Color(0,0,0)
export(float) var attack_duration = 0.3
export(float) var attack_cooldown = 0.4
