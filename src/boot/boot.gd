extends Node
## Boot: menu → Club hub → match → results → hub.
## ESC goes back one step; F11 toggles fullscreen.

var _layer: CanvasLayer
var _menu: MenuScreen
var _hud: Hud
var _victory: VictoryScreen
var _match: Match
var _hub: Hub
var _admin: AdminConsole
var _loadout: LoadoutScreen
var _pause: PauseScreen
var _last_origin := Vector3.ZERO
var _last_mode := "tag"
var _pending_origin := Vector3.ZERO
var _pending_mode := ""
var _auto_deploy := false
var _want_loadout := false
var _shot_frames := -1
var _shot2_frames := -1
var _frame := 0
var _win_mode := ""
var _want_sit := false
var _want_vfx := false
var _want_admin := false
var _want_admin_tag := false
var _want_admin_mode := ""
var _want_end_mode := ""
var _want_region := ""
var _want_wallhug := false
var _want_connect := false
var _want_portrait := false
var _portrait_view := "front"
var _want_char_pose := ""
var _want_pause := false
var _net_connect: NetConnectPanel
var _net_match: NetMatch
var _net_host := false
var _net_join_ip := ""
var _net_test := false
var _net_auto := false
var _net_name := ""
var _net_run := 0.0
var _net_shot := false
var _net_mode := ""
var _net_lobby_shot := false
var _net_round_frames := 0
var _net_hub: NetHub
var _net_panel: NetLobbyPanel
var _flow_test := false


func _ready() -> void:
	# Debug captures must still reach their frame while the pause overlay freezes
	# gameplay. Normal gameplay is unaffected: only this boot shell keeps ticking.
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_title("THE CLUB")
	DisplayServer.window_set_min_size(Vector2i(960, 540))
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)

	_admin = AdminConsole.new()
	_admin.name = "AdminConsole"
	_admin.command.connect(_on_admin)
	add_child(_admin)

	var autostart := false
	var hub_start := false
	var selftest := false
	for a: String in OS.get_cmdline_user_args():
		if a == "--autostart":
			autostart = true
		elif a == "--hub":
			hub_start = true
		elif a == "--selftest":
			selftest = true
		elif a == "--flow-test":
			_flow_test = true
		elif a.begins_with("--shot2="):
			_shot2_frames = int(a.split("=")[1])
		elif a.begins_with("--shot="):
			_shot_frames = int(a.split("=")[1])
		elif a.begins_with("--win-mode="):
			_win_mode = a.split("=")[1]
		elif a == "--loadout":
			_want_loadout = true
		elif a == "--auto-deploy":
			_auto_deploy = true
		elif a == "--third":
			Loadout.third_person = true
		elif a.begins_with("--ability="):
			Loadout.ability = a.split("=")[1]
		elif a == "--sit":
			_want_sit = true
		elif a == "--vfx":
			_want_vfx = true
		elif a == "--pause":
			_want_pause = true
		elif a == "--admin":
			_want_admin = true
		elif a == "--admin-tag":
			_want_admin_tag = true
		elif a.begins_with("--admin-mode="):
			_want_admin_mode = a.split("=")[1]
		elif a.begins_with("--end-mode="):
			_want_end_mode = a.split("=")[1]
		elif a.begins_with("--region="):
			_want_region = a.split("=")[1]
		elif a == "--wallhug":
			_want_wallhug = true
			hub_start = true
		elif a == "--connect":
			_want_connect = true
			hub_start = true
		elif a.begins_with("--char-pose="):
			_want_char_pose = a.split("=")[1]
			hub_start = true
			Loadout.third_person = true
		elif a == "--portrait" or a == "--portrait-back" or a.begins_with("--portrait-view="):
			_want_portrait = true
			if a.begins_with("--portrait-view="):
				_portrait_view = a.split("=")[1]
			elif a == "--portrait-back":
				_portrait_view = "back"
			hub_start = true
			Loadout.third_person = true
		elif a == "--net-host":
			_net_host = true
		elif a.begins_with("--net-join="):
			_net_join_ip = a.split("=")[1]
		elif a == "--net-test":
			_net_test = true
		elif a == "--net-auto":
			_net_auto = true
		elif a.begins_with("--net-name="):
			_net_name = a.split("=")[1]
		elif a.begins_with("--net-run="):
			_net_run = float(a.split("=")[1])
		elif a == "--net-shot":
			_net_shot = true
		elif a.begins_with("--net-mode="):
			_net_mode = a.split("=")[1]

	if _want_admin_mode != "" or _win_mode != "" or _want_end_mode != "":
		_auto_deploy = true

	if selftest:
		var t := SelfTest.new()
		add_child(t)
		var code: int = await t.run()
		get_tree().quit(code)
		return

	if _flow_test:
		await _run_flow_test()
		return

	if _net_host or _net_join_ip != "":
		_init_network()
		return

	if autostart:
		await get_tree().process_frame
		_start_match()
	elif hub_start or _want_admin_mode != "" or _want_end_mode != "" or _win_mode != "" or _want_loadout:
		await get_tree().process_frame
		if _want_connect:
			_enter_online_club()
		else:
			_enter_hub()
	else:
		_show_menu()


func _process(_dt: float) -> void:
	# Once the transport is live, hosting or joining puts you in the 3D Club. The
	# flat connect panel only exists until the peer is actually connected.
	if is_instance_valid(_net_connect) and Net.connected and not is_instance_valid(_net_hub):
		_attach_net()
		return
	if _net_shot:
		_net_shot_tick()
	if _shot_frames > 0 or _shot2_frames > 0 or _win_mode != "":
		_frame += 1
		if _shot2_frames > 0 and _frame == _shot2_frames:
			await RenderingServer.frame_post_draw
			var img2 := get_viewport().get_texture().get_image()
			img2.save_png("res://shot_2.png")
			print("SHOT2_SAVED res://shot_2.png %dx%d" % [img2.get_width(), img2.get_height()])
		if _want_sit and _frame == 40 and is_instance_valid(_hub):
			_hub.debug_sit()
		if _want_admin and _frame == 30 and not _admin.visible:
			_admin.toggle()
		if _want_admin_tag and _frame == 25 and is_instance_valid(_hub):
			_on_admin("tag_here", "")
		if _want_region != "" and _frame == 12 and is_instance_valid(_hub):
			_hub.teleport_to(_want_region)
		if _want_portrait and _frame == 24 and is_instance_valid(_hub) and _hub.player != null:
			_hub.player.set_physics_process(false)
			if _want_char_pose != "" and _hub.player.body != null:
				_hub.player.body.force_state(_want_char_pose)
			_hub.player.global_position = Vector3(0, 0.0, 5.0)
			_hub.player.rotation.y = 0.0
			_hub.player.body.visible = true
			_hub.player.cam.current = true
			var p := _hub.player
			var target := p.global_position + Vector3(0, 1.02, 0)
			var pos := p.global_position + Vector3(0, 1.18, -2.5)
			var fov := 55.0
			match _portrait_view:
				"back":
					pos = p.global_position + Vector3(0, 1.18, 2.5)
				"left":
					pos = p.global_position + Vector3(-2.5, 1.18, 0)
				"right":
					pos = p.global_position + Vector3(2.5, 1.18, 0)
				"three_quarter":
					pos = p.global_position + Vector3(-1.9, 1.45, -1.9)
				"left_shoulder":
					target = p.global_position + Vector3(-0.36, 0.88, 0)
					pos = target + Vector3(-0.6, 0.12, -1.05)
					fov = 35.0
				"right_shoulder":
					target = p.global_position + Vector3(0.36, 0.88, 0)
					pos = target + Vector3(0.6, 0.12, -1.05)
					fov = 35.0
			p.cam.fov = fov
			p.cam.global_position = pos
			p.cam.look_at(target, Vector3.UP)
		if _want_wallhug and _frame == 14 and is_instance_valid(_hub) and _hub.player != null:
			Loadout.third_person = true
			_hub.player.global_position = Vector3(0, 0.1, 14.4)
			_hub.player.velocity = Vector3.ZERO
			_hub.player.rotation.y = 0.0
			_hub.player.debug_set_pitch(0.0)
		if _want_loadout and _frame == 20 and _loadout == null:
			_pending_mode = ""
			_show_loadout()
		if _want_admin_mode != "" and _frame == 28 and is_instance_valid(_hub):
			_on_admin("start_mode", _want_admin_mode)
		if _want_end_mode != "" and _frame == 28 and is_instance_valid(_hub):
			_on_admin("start_mode", _want_end_mode)
		if _win_mode != "" and _frame == 28 and is_instance_valid(_hub):
			_on_admin("start_mode", _win_mode)
		if _win_mode != "" and _frame == 70 and is_instance_valid(_match):
			_match.debug_force_win()
		if _want_end_mode != "" and _frame == 120 and is_instance_valid(_match):
			_match.debug_expire(0.3)
		if _want_vfx and _frame == 210 and is_instance_valid(_match):
			_match.debug_vfx()
		if _want_pause and _frame == 230 and is_instance_valid(_match) and not is_instance_valid(_pause):
			_show_pause()
		if _frame == _shot_frames:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png("res://shot.png")
			print("SHOT_SAVED res://shot.png ", img.get_width(), "x", img.get_height())
			get_tree().quit()


func _init_network() -> void:
	if not Net.round_started.is_connected(_on_net_round):
		Net.round_started.connect(_on_net_round)
	if not Net.disconnected.is_connected(_on_net_disconnected):
		Net.disconnected.connect(_on_net_disconnected)
	if not Net.round_aborted.is_connected(_on_net_aborted):
		Net.round_aborted.connect(_on_net_aborted)
	Net.auto_ready = _net_test
	Net.auto_start = _net_auto
	Net.min_auto = 3 if (_net_test or _net_shot) else 2
	var pname := _net_name
	if pname == "":
		pname = "HOST" if _net_host else "MEMBER"
	if _net_host:
		Net.host_game(pname)
		if _net_mode in ["tag", "hush", "infection", "potato"]:
			Net.request_config(Net.map_id, _net_mode)
	else:
		Net.join_game(_net_join_ip, pname)
	_enter_online_club()


func _open_online() -> void:
	if not Net.round_started.is_connected(_on_net_round):
		Net.round_started.connect(_on_net_round)
	if not Net.disconnected.is_connected(_on_net_disconnected):
		Net.disconnected.connect(_on_net_disconnected)
	if not Net.round_aborted.is_connected(_on_net_aborted):
		Net.round_aborted.connect(_on_net_aborted)
	_enter_online_club()


## Online entry: you are already standing in the Club. The connect card is the
## only thing that appears until the transport is live; then it is replaced by
## the roster overlay. There is no flat lobby screen in the shipped flow.
func _enter_online_club() -> void:
	_clear_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hub = Hub.new()
	_hub.name = "Hub"
	add_child(_hub)
	_hub.entered_room.connect(_on_room)
	_net_connect = NetConnectPanel.new()
	_net_connect.back_pressed.connect(_leave_network)
	_layer.add_child(_net_connect)


func _attach_net() -> void:
	if is_instance_valid(_net_connect):
		_net_connect.queue_free()
	_net_connect = null
	if not is_instance_valid(_hub):
		_enter_net_hub()
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_net_hub = NetHub.new()
	_net_hub.name = "NetHub"
	add_child(_net_hub)
	_net_hub.attach(_hub)
	_net_panel = NetLobbyPanel.new()
	_net_panel.leave_pressed.connect(_leave_network)
	_layer.add_child(_net_panel)
	Net.log_line("LOBBY_SCENE hub local=%d players=%d host=%s" % [
		Net.local_id, Net.players.size(), str(Net.is_host)])


## The real lobby: you stand in the Club, the party stands with you, and the
## host's map/mode/start controls are a slim overlay instead of a separate screen.
func _enter_net_hub() -> void:
	_clear_world()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_hub = Hub.new()
	_hub.name = "Hub"
	add_child(_hub)
	_hub.entered_room.connect(_on_room)
	_net_hub = NetHub.new()
	_net_hub.name = "NetHub"
	add_child(_net_hub)
	_net_hub.attach(_hub)
	_net_panel = NetLobbyPanel.new()
	_net_panel.leave_pressed.connect(_leave_network)
	_layer.add_child(_net_panel)
	Net.log_line("LOBBY_SCENE hub local=%d players=%d host=%s" % [
		Net.local_id, Net.players.size(), str(Net.is_host)])


func _on_net_round(map_id: String, mode_id: String) -> void:
	_clear_world()
	_net_round_frames = 0
	_net_match = NetMatch.new()
	_net_match.name = "NetMatch"
	add_child(_net_match)
	_net_match.leave_requested.connect(_leave_network)
	_net_match.setup(map_id, mode_id, _net_test)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Net.log_line("ROUND_ENTERED local=%d map=%s" % [Net.local_id, map_id])
	if _net_run > 0.0:
		get_tree().create_timer(_net_run, true).timeout.connect(func(): get_tree().quit())


func _on_net_aborted() -> void:
	if is_instance_valid(_net_match):
		_net_match.queue_free()
		_net_match = null
	if Net.connected:
		_enter_net_hub()
	else:
		_enter_online_club()


func _on_net_disconnected() -> void:
	_clear_world()
	_show_menu()


func _leave_network() -> void:
	Net.close()
	_clear_world()
	_show_menu()


func _net_shot_tick() -> void:
	if not _net_lobby_shot and is_instance_valid(_net_panel) and Net.players.size() >= 3 and Net.all_ready():
		_net_lobby_shot = true
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://shot_net_lobby.png")
		print("NET_SHOT lobby saved players=%d" % Net.players.size())
		if Net.is_host:
			Net.start_round()
	if is_instance_valid(_net_match):
		_net_round_frames += 1
		if _net_round_frames == 20 and Net.is_host:
			_net_match.debug_pose_for_shot()
		if _net_round_frames == 120:
			await RenderingServer.frame_post_draw
			var img2 := get_viewport().get_texture().get_image()
			img2.save_png("res://shot_net_round.png")
			print("NET_SHOT round saved players=%d" % Net.players.size())
			get_tree().quit()


## Cold-launch flow proof: menu, offline Club, online Club. Exactly one lobby.
func _run_flow_test() -> void:
	_show_menu()
	await get_tree().process_frame
	var menu_ok := is_instance_valid(_menu)
	_enter_hub()
	await get_tree().process_frame
	var club_ok := is_instance_valid(_hub) and _menu == null and _net_connect == null
	var player_ok := is_instance_valid(_hub) and _hub.player != null
	_enter_online_club()
	await get_tree().process_frame
	var online_ok := is_instance_valid(_hub) and is_instance_valid(_net_connect) and not is_instance_valid(_net_panel)
	# The old label was a literal `false`, not a check. Assert what the shipped
	# flow actually promises: online entry is the in-world Club plus the connect
	# card, with no separate flat/full-screen lobby. A roster panel is created
	# only below so the real Tab input path can be exercised.
	var flat_lobby := is_instance_valid(_net_connect) and not is_instance_valid(_net_panel)
	# Tab must release the cursor from the roster overlay. Exercise the real
	# viewport -> boot._unhandled_input path, not a direct method call.
	_net_panel = NetLobbyPanel.new()
	_layer.add_child(_net_panel)
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	get_viewport().push_input(tab)
	await get_tree().process_frame
	var tab_ok := Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	print("FLOW_TEST menu=%s club=%s player=%s online_club=%s tab_release=%s flat_lobby=%s" % [
		menu_ok, club_ok, player_ok, online_ok, tab_ok, flat_lobby])
	get_tree().quit(0 if menu_ok and club_ok and player_ok and online_ok and tab_ok and flat_lobby else 1)


func _show_menu() -> void:
	_clear_world()
	Sfx.stop_casino_bed()
	Sfx.play("menu", -20.0, 1.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu = MenuScreen.new()
	_menu.join_pressed.connect(_enter_hub)
	_menu.online_pressed.connect(_open_online)
	_menu.customise_pressed.connect(_open_customise)
	_menu.mode_pressed.connect(_on_menu_mode)
	_menu.exit_pressed.connect(func(): get_tree().quit())
	_layer.add_child(_menu)


func _on_menu_mode(mode: String) -> void:
	_start_match(Vector3.ZERO, mode)


func _enter_hub() -> void:
	_clear_world()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_hub = Hub.new()
	_hub.name = "Hub"
	add_child(_hub)
	_hub.entered_room.connect(_on_room)


func _on_room(room: String) -> void:
	if Net.connected:
		# The host owns round start; walking into a door must never launch a
		# local bot match out from under an online session.
		Sfx.play("beep", -14.0, 0.94)
		return
	match room:
		"floor":
			_start_match()
		_:
			Sfx.play("beep", -14.0, 0.94)


func _on_admin(kind: String, value: String) -> void:
	match kind:
		"start_mode":
			var origin := Vector3.ZERO
			if is_instance_valid(_hub) and _hub.player != null:
				origin = _hub.player.global_position
				origin.y = 0.0
			_admin.visible = false
			_pending_origin = origin
			_pending_mode = value
			_show_loadout()
		"customise":
			_admin.visible = false
			_pending_mode = ""
			_show_loadout()
		"tag_here":
			var origin := Vector3.ZERO
			if is_instance_valid(_hub) and _hub.player != null:
				origin = _hub.player.global_position
				origin.y = 0.0
			_admin.visible = false
			_start_match(origin)
		"tag":
			_admin.visible = false
			_start_match(Vector3.ZERO)
		"travel":
			_admin.visible = false
			if is_instance_valid(_hub):
				_hub.teleport_to(value)
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				_enter_hub()
				await get_tree().process_frame
				if is_instance_valid(_hub):
					_hub.teleport_to(value)
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		"close":
			_admin.visible = false
			if is_instance_valid(_match) or is_instance_valid(_hub):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_customise() -> void:
	if _loadout != null and is_instance_valid(_loadout):
		return
	_pending_mode = ""
	_pending_origin = Vector3.ZERO
	_show_loadout()


func _show_loadout() -> void:
	if _loadout != null and is_instance_valid(_loadout):
		_loadout.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# a mid-round loadout change pauses the match instead of letting bots run
	get_tree().paused = is_instance_valid(_match)
	_loadout = LoadoutScreen.new()
	_loadout.process_mode = Node.PROCESS_MODE_ALWAYS
	_loadout.deploy_pressed.connect(_deploy)
	_loadout.back_pressed.connect(_close_loadout)
	_layer.add_child(_loadout)
	if _auto_deploy:
		await get_tree().create_timer(0.4, true, false, true).timeout
		if _loadout != null and is_instance_valid(_loadout):
			_deploy()


func _deploy() -> void:
	get_tree().paused = false
	if _loadout != null and is_instance_valid(_loadout):
		_loadout.queue_free()
		_loadout = null
	if _pending_mode == "":
		if is_instance_valid(_match) or is_instance_valid(_hub):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	_start_match(_pending_origin, _pending_mode)


func _close_loadout() -> void:
	get_tree().paused = false
	if _loadout != null and is_instance_valid(_loadout):
		_loadout.queue_free()
		_loadout = null
	if is_instance_valid(_match) or is_instance_valid(_hub):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _start_match(origin: Vector3 = Vector3.ZERO, mode_id: String = "tag") -> void:
	_last_origin = origin
	_last_mode = mode_id
	_clear_world()
	_match = Match.new()
	_match.name = "Match"
	add_child(_match)

	# HUD exists before start so the round intro and first feed land on a live layer.
	_hud = Hud.new()
	_hud.match = _match
	_layer.add_child(_hud)
	_match.round_over.connect(_on_round_over)
	_match.hud_event.connect(_on_hud_event)
	_match.start(origin, mode_id, true)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_hud.set_hint(_match.mode_hint())
	_hud.feed("YOU ARE %s  ·  %s" % [_match.player_role_text(), _match.mode_objective()],
		_match.player_role_color())


func _on_hud_event(kind: String, payload: Dictionary) -> void:
	if not is_instance_valid(_hud):
		return
	match kind:
		"became_it":
			# The role line under the clock already says YOU ARE IT; a second
			# banner on top of it read as duplicate UI rather than impact.
			_hud.flash(0.55)
		"tagged_someone":
			_hud.toast("TAGGED", Cfg.GOLD)
		"feed":
			_hud.feed(str(payload.get("text", "")), payload.get("color", Cfg.GOLD))
		"toast":
			_hud.toast(str(payload.get("text", "")), payload.get("color", Cfg.GOLD))
		"ability":
			if payload.get("kind", "") == "lunge":
				_hud.flash(0.12)
			elif payload.get("kind", "") == "dash":
				_hud.dash()


func _on_round_over(rows: Array, result: String) -> void:
	var title := "THE FLOOR"
	if is_instance_valid(_match):
		title = _match.mode_title
	if is_instance_valid(_hud):
		_hud.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	print("ROUND_RESULT mode=%s result=%s" % [title, result])
	_victory = VictoryScreen.new()
	_layer.add_child(_victory)
	# add_child runs _ready, which builds the panel setup() fills
	_victory.setup(rows, result, title)
	_victory.continue_pressed.connect(_enter_hub)
	Sfx.play("win", -8.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed:
			return
		if k.keycode == KEY_F1:
			get_viewport().set_input_as_handled()
			_admin.toggle()
			if not _admin.visible and (is_instance_valid(_match) or is_instance_valid(_hub)):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			return
		if k.keycode == KEY_C and (_loadout == null or not is_instance_valid(_loadout)):
			get_viewport().set_input_as_handled()
			if not is_instance_valid(_victory):
				_open_customise()
			return
		if k.keycode == KEY_TAB and is_instance_valid(_net_panel):
			get_viewport().set_input_as_handled()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			return
		if k.keycode == KEY_ENTER and is_instance_valid(_net_panel) and Net.is_host and Net.all_ready():
			get_viewport().set_input_as_handled()
			Net.start_round()
			return
		if k.keycode == KEY_R and is_instance_valid(_net_panel) and not Net.is_host:
			get_viewport().set_input_as_handled()
			Net.set_ready(not Net.is_ready(Net.local_id))
			return
		if k.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if is_instance_valid(_pause):
				_resume_match()
			elif is_instance_valid(_net_match) or is_instance_valid(_net_connect) or is_instance_valid(_net_panel):
				_leave_network()
			elif is_instance_valid(_match):
				_show_pause()
			elif is_instance_valid(_victory):
				_enter_hub()
			elif is_instance_valid(_hub):
				_show_menu()
		elif k.keycode == KEY_F11:
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN else Window.MODE_EXCLUSIVE_FULLSCREEN


func _show_pause() -> void:
	if is_instance_valid(_pause) or not is_instance_valid(_match):
		return
	get_tree().paused = true
	_pause = PauseScreen.new()
	_pause.name = "Pause"
	_layer.add_child(_pause)
	_pause.setup(_match.mode_title, _match.time_left)
	_pause.resume_pressed.connect(_resume_match)
	_pause.restart_pressed.connect(_restart_match)
	_pause.loadout_pressed.connect(_pause_loadout)
	_pause.leave_pressed.connect(_leave_match_to_club)
	_pause.menu_pressed.connect(_leave_match_to_menu)


func _resume_match() -> void:
	get_tree().paused = false
	if is_instance_valid(_pause):
		_pause.queue_free()
	_pause = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _pause_loadout() -> void:
	get_tree().paused = false
	if is_instance_valid(_pause):
		_pause.queue_free()
		_pause = null
	_open_customise()


func _restart_match() -> void:
	get_tree().paused = false
	if is_instance_valid(_pause):
		_pause.queue_free()
		_pause = null
	_start_match(_last_origin, _last_mode)


func _leave_match_to_club() -> void:
	get_tree().paused = false
	if is_instance_valid(_pause):
		_pause.queue_free()
		_pause = null
	_enter_hub()


func _leave_match_to_menu() -> void:
	get_tree().paused = false
	if is_instance_valid(_pause):
		_pause.queue_free()
		_pause = null
	_show_menu()


func _clear_world() -> void:
	get_tree().paused = false
	for n in [_menu, _hud, _victory, _net_connect, _net_match, _net_panel, _net_hub, _pause]:
		if is_instance_valid(n):
			n.queue_free()
	_menu = null
	_hud = null
	_victory = null
	_net_connect = null
	_net_match = null
	_net_panel = null
	_net_hub = null
	_pause = null
	if is_instance_valid(_match):
		_match.queue_free()
		_match = null
	if is_instance_valid(_hub):
		_hub.queue_free()
		_hub = null
