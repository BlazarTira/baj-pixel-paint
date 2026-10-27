# Tentacle for Godot

Connect your Godot game to the [Tentacle](https://www.tentacle.live) desktop app: stream events, chat, custom events, custom controls, viewer properties, and OBS calls, delivered as ordinary Godot signals.

## Requirements

- Godot 4.4 or newer
- The Tentacle desktop app

Pure GDScript, so there is nothing to compile and nothing platform-specific. It imports and exports everywhere Godot does, and on a platform Tentacle does not run on it simply never connects rather than breaking your project.

## Install

1. Unzip this folder into your project so it sits at `res://addons/tentacle/`.
2. Open **Project > Project Settings > Plugins** and tick **Tentacle**.

Enabling the plugin is what installs the `Tentacle` autoload, which is how your game reaches everything. No restart needed.

## Use

```gdscript
extends Node

func _ready() -> void:
    Tentacle.OnChatMessage.connect(_on_chat_message)
    Tentacle.OnDonation.connect(_on_donation)

func _on_chat_message(chat_message: TclStreamEvent_Anywhere_ChatMessage, viewer: TclViewer) -> void:
    print("%s: %s" % [viewer.display_name, chat_message.text])

func _on_donation(_event: TclStreamEvent_Anywhere_Donation, viewer: TclViewer) -> void:
    $Fireworks.burst(viewer.color)
```

The autoload's own stream signals work across platforms: `OnChatMessage` fires for a chat message on Twitch or Kick. Each platform's own events are on `Tentacle.twitch` and `Tentacle.kick`, with a signal per event kind named as that platform's documentation names it and carrying that kind's type, such as `Tentacle.twitch.OnChannelCheer`, `Tentacle.twitch.OnChannelRaid`, and `Tentacle.kick.OnChannelFollow`, so a handler never casts.

The other surfaces hang off the autoload too: `custom_controls`, `custom_events`, `viewer_properties`, `viewers`, `obs`, `bot`, and `timers`. To connect signals from the editor's Node dock instead of from code, add a `TentacleEventRelay` node to your scene, plus a `TentacleTwitchEventRelay` or `TentacleKickEventRelay` for a platform's own signals.

For a custom control, add a `TclCustomControlComponent_Slider` (or Button, Color, Int, Number, Select, Switch, Text, Vector2, Vector3, Vector4) node to your scene, set its label in the Inspector, and connect `OnValueCommittedFromApp`. Nothing to register, no ids to keep unique.

The connection settings (Auto Connect, Session Label and the rest) are under **Project > Project Settings > General > Tentacle**.

Tentacle does not have to be running when your game starts. The addon keeps looking for it and connects whenever it appears, backing off from one second to thirty between attempts, so a closed Tentacle costs your game nothing, and no call here will throw into your game loop because Tentacle is closed.

Full documentation: <https://www.tentacle.live/docs/Godot/Setup/>

## Licence

See LICENSE beside this file.
