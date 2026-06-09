extends StaticBody2D

var crafting_ui_scene = preload("res://src/ui/crafting_ui.tscn")
var ui_instance = null

@onready var interact_label = $InteractLabel

func _ready():
	interact_label.hide()
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)
	
	# Instantiate UI globally on CanvasLayer so it stays on screen
	call_deferred("_setup_ui")

func _setup_ui():
	# Find CanvasLayer in world
	var canvas = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if canvas:
		ui_instance = crafting_ui_scene.instantiate()
		canvas.add_child(ui_instance)
		ui_instance.hide()

func _on_body_entered(body):
	if body.name == "Player":
		interact_label.show()
		set_process_unhandled_input(true)

func _on_body_exited(body):
	if body.name == "Player":
		interact_label.hide()
		set_process_unhandled_input(false)
		if ui_instance and ui_instance.visible:
			ui_instance.hide()

func _unhandled_input(event):
	if event.is_action_pressed("interact") and interact_label.visible:
		if ui_instance:
			ui_instance.toggle_ui()
