extends Node
## Autoload "Settings": persisted audio options and puzzle completion.
## Also owns the "SFX" audio bus (created at runtime, routed into Master).

const PATH := "user://settings.cfg"
const SFX_BUS := "SFX"

var master_volume := 0.8
var sfx_volume := 1.0
var muted := false
var completed := {} # image path -> true


func _ready() -> void:
	_ensure_sfx_bus()
	_load()
	apply()


func apply() -> void:
	AudioServer.set_bus_volume_db(0, _db(master_volume))
	AudioServer.set_bus_mute(0, muted)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), _db(sfx_volume))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("progress", "completed", completed.keys())
	cfg.save(PATH)


func mark_completed(image_path: String) -> void:
	if not completed.has(image_path):
		completed[image_path] = true
		save()


func is_completed(image_path: String) -> bool:
	return completed.has(image_path)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = cfg.get_value("audio", "master", master_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	muted = cfg.get_value("audio", "muted", muted)
	for path in cfg.get_value("progress", "completed", []):
		completed[path] = true


func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, SFX_BUS)
		AudioServer.set_bus_send(idx, "Master")


func _db(linear: float) -> float:
	return maxf(linear_to_db(linear), -80.0)
