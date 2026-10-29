extends PanelContainer


@onready var round_time_label = $Settings/RoundTime/RoundTimeLabel
@onready var round_time_slider = $Settings/RoundTime/RoundTimeSlider

@onready var cooldown_time_label = $Settings/RoundTime/CooldownTime/CooldownTimeLabel
@onready var cooldown_time_slider = $Settings/RoundTime/CooldownTime/CooldownTimeSlider


func _ready():
	round_time_slider.value = GameManager.round_time
	round_time_label.text = "ROUND TIME: %d SECONDS" % round_time_slider.value
	round_time_slider.value_changed.connect(round_time_changed)
	
	cooldown_time_slider.value = GameManager.cooldown_time
	cooldown_time_label.text = "COOLDOWN TIME: %d SECONDS" % cooldown_time_slider.value
	cooldown_time_slider.value_changed.connect(cooldown_changed)

func round_time_changed(value: int):
	GameManager.round_time = value
	round_time_label.text = "ROUND TIME: %d SECONDS" % value

func cooldown_changed(value: int):
	GameManager.cooldown_time = value
	cooldown_time_label.text = "COOLDOWN TIME: %d SECONDS" % value
