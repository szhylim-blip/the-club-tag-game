extends Node
## Global tuning + input bootstrap. Everything that decides "feel" lives here.

# --- world ---------------------------------------------------------------
const GRAVITY := 22.0
const STAND_H := 1.30
const CROUCH_H := 0.80
const EYE := 1.10
const EYE_CROUCH := 0.62
const RADIUS := 0.34

# --- movement (Club Sprint) ---------------------------------------------
const WALK := 3.2
const SPRINT := 5.6
const GROUND_ACCEL := 52.0
const FRICTION := 6.4
const AIR_ACCEL := 3.4
const AIR_CAP := 0.70
const JUMP := 7.2
## 7.2 m/s at 22 m/s² clears a 1.18 m apex: every 1 m crate is jumpable.
const SLIDE_FRICTION := 0.95
const SLIDE_MIN_SPEED := 4.2
const SLIDE_BOOST := 1.35
const COYOTE := 0.10
const JUMP_BUFFER := 0.13
const BHOP_WINDOW := 0.14
const TERMINAL := 26.0
## Chained hops add momentum until this hard cap. Readable, never infinite.
const SPEED_CAP := 8.6
const BHOP_GAIN := 1.06
## Once a hop is chained, strafing in the air can still shape and add speed.
const AIR_STRAFE_ACCEL := 2.4

# --- role kit ------------------------------------------------------------
const STAMINA_MULT := 1.18
const STAMINA_TIME := 4.0
const SLOW_MULT := 0.55
const SLOW_DRAG := 16.0
const TRAP_RADIUS := 2.6
const ROLE_COOLDOWNS := {
	"scan": 8.0, "trap": 11.0, "decoy": 9.0, "stamina": 12.0,
}

# --- feel ----------------------------------------------------------------
const FOV_BASE := 78.0
const FOV_MAX_BONUS := 11.0
const MOUSE_SENS := 0.0022
const PITCH_LIMIT := 1.52

# --- palette (single source of truth for scripts too) --------------------
const INK := Color("#100c16")
const PANEL := Color("#1b1626")
const PANEL_HI := Color("#241d31")
const GOLD := Color("#e8b04b")
const GOLD_DIM := Color("#9a7130")
const MINT := Color("#5fe3a1")
const CORAL := Color("#ff5d5d")
const CREAM := Color("#f6f2ea")
const MUTED := Color("#9c93a8")
## monochrome member shades for the imported cast (tag games only)
const BOT_COLORS := [
	Color("#d8d8de"), Color("#b0b0b9"), Color("#8a8a94"), Color("#e8e8ee"),
	Color("#6c6c76"), Color("#c4c4cc"), Color("#9696a0"), Color("#f2f2f6"),
]
const HAIRLINE := Color(1, 1, 1, 0.08)

# --- rules ---------------------------------------------------------------
const ROUND_TIME := 105.0
const TAG_DISTANCE := 1.35
const TAG_IMMUNITY := 1.4
const BOT_COUNT := 7

var _actions := {
	"forward": [KEY_W, KEY_UP],
	"back": [KEY_S, KEY_DOWN],
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],
	"ability": [KEY_Q],
	"ability_two": [KEY_E],
	"ability_three": [KEY_F],
	"punch": [],
	"respawn": [KEY_R],
}


func _ready() -> void:
	_ensure_actions()


func _ensure_actions() -> void:
	for action: String in _actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in _actions[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	# Punch is a mouse click, not a keyboard key.
	if not InputMap.has_action("punch"):
		InputMap.add_action("punch")
	var p := InputEventMouseButton.new()
	p.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("punch", p)
