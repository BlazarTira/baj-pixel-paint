class_name TentacleVersion

## The addon's version, and the oldest Godot it supports.
##
## The addon's version always matches the Tentacle desktop app's, so the version a
## session shows in Tentacle's Engines list is the release it belongs to.

# Kept in lockstep with the Tentacle desktop app, exactly as the Unity package and the
# tentacle-web package are: a release bumps all of them together.
#
# Enforced by packages/app/tests/godot-plugin.test.ts, which compares PLUGIN, and the
# version in plugin.cfg, to packages/app/src-tauri/Cargo.toml. That test lives in the bun
# workspace on purpose: the Godot toolchain is outside CI, so a guard written in GDScript
# would never run on a push.
#
# It reaches two places a drift would show: the session handshake puts it in
# pluginVersion, and `just godot::package` names the archive after it.

## The addon's version, matching the Tentacle app's.
const PLUGIN: String = "1.2.0-alpha.6"

# The floor is set by typed dictionaries, which are load-bearing for the generated types'
# typing policy. Deliberately not 4.5, which would add @abstract: that is a convenience
# for this codebase, whereas the floor is a constraint on every user, and GDScript has no
# ABI coupling that would force the floor up later.
#
# Declared here so it is one fact rather than several: the release publisher reads it to
# name the download archive and to label it on the download page, and
# packages/app/tests/godot-plugin.test.ts holds the docs to it.
## The oldest Godot version this addon supports. It works on this and newer.
##
## The addon uses typed dictionaries, which arrived in Godot 4.4.
const MINIMUM_GODOT: String = "4.4"
