extends AudioStreamPlayer

const main_theme = preload("res://Assets/Music/jingly keys.ogg")

func _play_music(music: AudioStream):
	if stream == music:
		return
	
	stream = music
	play()

func play_main_theme():
	_play_music(main_theme)
