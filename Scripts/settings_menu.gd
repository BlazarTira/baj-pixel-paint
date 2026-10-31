extends PanelContainer


@onready var round_time_label = $Settings/ActualSettings/RoundTime/RoundTimeLabel
@onready var round_time_slider = $Settings/ActualSettings/RoundTime/RoundTimeSlider

@onready var cooldown_time_label = $Settings/ActualSettings/CooldownTime/CooldownTimeLabel
@onready var cooldown_time_slider = $Settings/ActualSettings/CooldownTime/CooldownTimeSlider
@onready var music_volume_slider = $Settings/ActualSettings/MusicVolume/MusicVolumeSlider


func _ready():
	round_time_slider.value = GameManager.round_time
	round_time_label.text = "ROUND TIME: %d SECONDS" % round_time_slider.value
	round_time_slider.value_changed.connect(round_time_changed)
	
	cooldown_time_slider.value = GameManager.cooldown_time
	cooldown_time_label.text = "COOLDOWN TIME: %d SECONDS" % cooldown_time_slider.value
	cooldown_time_slider.value_changed.connect(cooldown_changed)
	
	music_volume_slider.value_changed.connect(music_changed)

func round_time_changed(value: int):
	GameManager.round_time = value
	round_time_label.text = "ROUND TIME: %d SECONDS" % value

func cooldown_changed(value: int):
	GameManager.cooldown_time = value
	cooldown_time_label.text = "COOLDOWN TIME: %d SECONDS" % value

func music_changed(value: float):
	var bus = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(bus, linear_to_db(value))
