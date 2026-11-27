extends Node
## What the member takes into a round: ability, body colour and camera.
## Persisted to user://loadout.cfg so a playtest keeps the same setup.

signal changed

const ABILITIES := {
	"dash": {"name": "DASH", "desc": "A burst of speed.\nChaser lunges instead.", "cd": 6.0},
	"blink": {"name": "BLINK", "desc": "Teleport 8 m ahead,\nthrough open air.", "cd": 7.5},
	"shock": {"name": "SHOCK", "desc": "Stun every member\nwithin 6 m for 1.5 s.", "cd": 9.0},
	"shield": {"name": "SHIELD", "desc": "2 s of immunity\nfrom tags and infection.", "cd": 11.0},
}

var ability := "dash"
var body_color: Color = Color.WHITE
var shape := 0
var third_person := false
var sensitivity := 1.0

const PATH := "user://loadout.cfg"


func _ready() -> void:
	load_from_disk()


func ability_name() -> String:
	return str(ABILITIES.get(ability, ABILITIES["dash"])["name"])


func ability_cooldown() -> float:
	return float(ABILITIES.get(ability, ABILITIES["dash"])["cd"])


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("loadout", "ability", ability)
	cfg.set_value("loadout", "color", body_color.to_html())
	cfg.set_value("loadout", "shape", shape)
	cfg.set_value("loadout", "third_person", third_person)
	cfg.save(PATH)
	changed.emit()


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	ability = str(cfg.get_value("loadout", "ability", "dash"))
	if not ABILITIES.has(ability):
		ability = "dash"
	body_color = Color(str(cfg.get_value("loadout", "color", Color.WHITE.to_html())))
	shape = 0
	third_person = bool(cfg.get_value("loadout", "third_person", false))
