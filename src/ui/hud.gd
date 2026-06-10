extends Node2D # Atau Node2D

func _ready():
    add_to_group("hud") # Daftarkan ke grup agar bisa dipanggil global

func update_hp_bar(hp):
    $HPBar.value = hp