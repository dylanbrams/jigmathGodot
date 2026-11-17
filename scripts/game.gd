extends Node
## Autoload "Game": image catalogue (one section per folder under assets/images),
## the current puzzle selection, and fade transitions between scenes.

const IMAGE_DIR := "res://assets/images"
const SECTION_ORDER: Array[String] = ["art", "nature", "space", "glass"]
const HOME_SCENE := "res://scenes/main_menu.tscn"
const SELECT_SCENE := "res://scenes/puzzle_select.tscn"
const PUZZLE_SCENE := "res://scenes/main.tscn"
const FADE_TIME := 0.18
## Friendlier names for files whose names don't capitalize nicely.
const NAME_OVERRIDES := {
	"20130722_annotated_earth-moon_from_saturn_1920x1080": "Earth and Moon from Saturn",
	"PIA24839_Main_4_Hazcam_stretched": "Perseverance Hazcam View",
	"SantaCruzPerPerseverance": "Santa Cruz Ridge, Mars",
	"IngenuityStartsBlades": "Ingenuity Spins Its Blades",
	"theCardPlayersCezanne": "The Card Players",
	"theAuctioneerRembrandt": "The Auctioneer",
	"theFallenCaryatidRodin": "The Fallen Caryatid",
	"theSpanishSingerManet": "The Spanish Singer",
	"the_japanese_footbridge_1992": "The Japanese Footbridge",
	"green_wheat_fields_auvers_2013": "Green Wheat Fields, Auvers",
	"potato_eaters_1951": "The Potato Eaters",
	"HokusaiGreatWave": "The Great Wave",
	"Apollo11EVA": "Apollo 11 EVA",
}

## Each: { key: String, title: String, images: Array[String] }
var sections: Array[Dictionary] = []
var current_section := ""
var current_image := ""

var _fade: ColorRect
var _busy := false


func _ready() -> void:
	_scan()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.05, 0.09, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


# ---------------------------------------------------------------- catalogue

func _scan() -> void:
	sections.clear()
	var keys := Array(DirAccess.get_directories_at(IMAGE_DIR))
	keys.sort_custom(func(a: String, b: String) -> bool:
		var ia := SECTION_ORDER.find(a)
		var ib := SECTION_ORDER.find(b)
		ia = 999 if ia == -1 else ia
		ib = 999 if ib == -1 else ib
		return ia < ib if ia != ib else a < b)
	for key: String in keys:
		var images: Array[String] = []
		for f in DirAccess.get_files_at(IMAGE_DIR + "/" + key):
			f = f.trim_suffix(".import") # exported builds list only the .import files
			var path := IMAGE_DIR + "/" + key + "/" + f
			if f.get_extension().to_lower() in ["jpg", "jpeg", "png"] and not images.has(path):
				images.append(path)
		if images.is_empty():
			continue
		images.sort()
		sections.append({"key": key, "title": key.capitalize(), "images": images})
	if current_section == "" and not sections.is_empty():
		current_section = sections[0].key


func get_section(key: String) -> Dictionary:
	for s in sections:
		if s.key == key:
			return s
	return {}


func pretty_name(image_path: String) -> String:
	var base := image_path.get_file().get_basename()
	return NAME_OVERRIDES.get(base, base.capitalize())


## Used when the puzzle scene is run directly (F6) without going through the menus.
func ensure_image() -> void:
	if current_image == "" and not sections.is_empty():
		current_section = sections[0].key
		current_image = sections[0].images[0]


## Next image within the current section (wraps around).
func advance_image() -> void:
	var images: Array = get_section(current_section).get("images", [])
	if images.is_empty():
		return
	current_image = images[(images.find(current_image) + 1) % images.size()]


# ---------------------------------------------------------------- navigation

func go_home() -> void:
	change_scene(HOME_SCENE)


func go_select() -> void:
	change_scene(SELECT_SCENE)


func start_puzzle(section_key: String, image_path: String) -> void:
	current_section = section_key
	current_image = image_path
	change_scene(PUZZLE_SCENE)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	await out.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, FADE_TIME)
	await back.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
