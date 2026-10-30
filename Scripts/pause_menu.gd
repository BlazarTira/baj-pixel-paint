extends PanelContainer

func _ready():
	hide()

func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		get_tree().paused = !get_tree().paused
		visible = get_tree().paused

func _on_resume_button_pressed():
	get_tree().paused = false
	visible = false

func _on_main_menu_button_pressed():
	get_tree().paused = false
	await Fade.fade(1.0, 0.5).finished
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
	Fade.fade(0.0, 0.5)
