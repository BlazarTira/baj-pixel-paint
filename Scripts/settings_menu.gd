extends PanelContainer


@onready var round_time_label = %RoundTimeLabel
@onready var round_time_slider = %RoundTimeSlider

@onready var cooldown_time_label = %CooldownTimeLabel
@onready var cooldown_time_slider = %CooldownTimeSlider

@onready var bomb_cooldown_label = %BombCooldownTimeLabel
@onready var bomb_cooldown_slider = %BombCooldownTimeSlider

@onready var bomb_radius_label = %BombRadiusLabel
@onready var bomb_radius_slider = %BombRadiusSlider

@onready var guide_hide_time_label = %GuideHideTimeLabel
@onready var guide_hide_time_slider = %GuideHideTimeSlider

@onready var guide_hide_cooldown_label = %GuideHideCooldownLabel
@onready var guide_hide_cooldown_slider = %GuideHideCooldownSlider


@onready var music_volume_slider = %MusicVolumeSlider


func _ready():
	round_time_slider.value = GameManager.round_time
	round_time_label.text = "ROUND TIME: %d SECONDS" % round_time_slider.value
	round_time_slider.value_changed.connect(round_time_changed)
	
	cooldown_time_slider.value = GameManager.erase_cooldown_time
	cooldown_time_label.text = "ERASE COOLDOWN: %d SECONDS" % cooldown_time_slider.value
	cooldown_time_slider.value_changed.connect(erase_cooldown_changed)
	
	bomb_cooldown_slider.value = GameManager.bomb_cooldown_time
	bomb_cooldown_label.text = "BOMB COOLDOWN: %d SECONDS" % bomb_cooldown_slider.value
	bomb_cooldown_slider.value_changed.connect(bomb_cooldown_changed)
	
	bomb_radius_slider.value = GameManager.bomb_radius
	bomb_radius_label.text = bomb_radius_text(bomb_radius_slider.value)
	bomb_radius_slider.value_changed.connect(bomb_radius_changed)
	
	guide_hide_time_slider.value = GameManager.guide_hide_time
	guide_hide_time_label.text = "GUIDE HIDE TIME:\n%d SECONDS" % guide_hide_time_slider.value
	guide_hide_time_slider.value_changed.connect(guide_hide_changed)
	
	guide_hide_cooldown_slider.value = GameManager.guide_cooldown_time
	guide_hide_cooldown_label.text = "GUIDE COOLDOWN:\n%d SECONDS" % guide_hide_cooldown_slider.value
	guide_hide_cooldown_slider.value_changed.connect(guide_cooldown_changed)
	
	music_volume_slider.value_changed.connect(music_changed)

func round_time_changed(value: int):
	GameManager.round_time = value
	round_time_label.text = "ROUND TIME: %d SECONDS" % value

func erase_cooldown_changed(value: int):
	GameManager.erase_cooldown_time = value
	cooldown_time_label.text = "ERASE COOLDOWN: %d SECONDS" % value

func bomb_cooldown_changed(value: int):
	GameManager.bomb_cooldown_time = value
	bomb_cooldown_label.text = "BOMB COOLDOWN: %d SECONDS" % value

func bomb_radius_changed(value: int):
	GameManager.bomb_radius = value
	bomb_radius_label.text = bomb_radius_text(value)

func bomb_radius_text(radius: int) -> String:
	var size = radius * 2 + 1
	return "BOMB RADIUS: %d x %d" % [size, size]

func guide_hide_changed(value: int):
	GameManager.guide_hide_time = value
	guide_hide_time_label.text = "GUIDE HIDE TIME:\n%d SECONDS" % value

func guide_cooldown_changed(value: int):
	GameManager.guide_cooldown_time = value
	guide_hide_cooldown_label.text = "GUIDE COOLDOWN:\n%d SECONDS" % value

func music_changed(value: float):
	var bus = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(bus, linear_to_db(value))
