extends Node
## Net — session transport and lobby state.
##
## Transport: Godot high-level multiplayer over ENetMultiplayerPeer (UDP).
## Host-authoritative tag: clients send their own movement to the host, the host
## owns roles/timer/tag transfers and broadcasts snapshots. This keeps the rule
## code in one place and lets a relay/Steam transport replace the peer later:
## only Net owns the peer, and gameplay talks to Net signals, never ENet directly.
##
## Internet play: this is direct IP. The host needs a forwarded UDP port (7777).
## Without forwarding/relay it works on LAN and on the same machine. A relay
## service can be added at `host/join` without touching NetMatch.

signal roster_changed
signal config_changed
signal round_started(map_id: String, mode_id: String)
signal round_aborted
signal peer_left(id: int)
signal state_received(id: int, pos: Vector3, yaw: float, speed: float)
signal snapshot_received(snap: Dictionary)
signal ability_event(id: int, kind: String)
signal event_received(kind: String, data: Dictionary)
signal connection_failed(reason: String)
signal disconnected
signal status(text: String)

const PORT := 7777
const MAX_PLAYERS := 8

var is_host := false
var connected := false
var local_id := 0
var players: Dictionary = {}
var host_name := "HOST"
var map_id := "floor"
var mode_id := "tag"
## Host session default: "player" (each member's loadout), "first" or "third".
var camera_mode := "player"
var auto_ready := false
var auto_start := false
var min_auto := 2
var running := false
var last_error := ""

var _peer: ENetMultiplayerPeer
var _join_name := "MEMBER"
var _join_ip := "127.0.0.1"
var _registered := false


func host_game(pname: String, port := PORT) -> void:
	close()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		last_error = "Could not open UDP %d (%s)" % [port, error_string(err)]
		connection_failed.emit(last_error)
		return
	multiplayer.multiplayer_peer = _peer
	is_host = true
	connected = true
	local_id = 1
	host_name = pname
	players = {1: _entry(pname, true)}
	_hook_multiplayer()
	status.emit("HOSTING ON UDP %d" % PORT)
	roster_changed.emit()


func join_game(ip: String, pname: String, port := PORT) -> void:
	close()
	_join_ip = ip
	_join_name = pname
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(ip, port)
	if err != OK:
		last_error = "Could not reach %s:%d (%s)" % [ip, port, error_string(err)]
		connection_failed.emit(last_error)
		return
	multiplayer.multiplayer_peer = _peer
	is_host = false
	connected = false
	local_id = 0
	_registered = false
	_hook_multiplayer()
	status.emit("CONNECTING TO %s:%d" % [ip, port])


func close() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = null
	is_host = false
	connected = false
	running = false
	players.clear()
	local_id = 0
	_registered = false


func is_ready(id: int) -> bool:
	return bool(players.get(id, {}).get("ready", false))


func all_ready() -> bool:
	if not is_host or players.size() < 2:
		return false
	for id: int in players:
		if id != 1 and not bool(players[id].get("ready", false)):
			return false
	return true


func set_ready(v: bool) -> void:
	if is_host:
		return
	if not connected:
		return
	_submit_ready.rpc_id(1, v)


func request_config(map: String, mode: String, camera := "") -> void:
	if not is_host:
		return
	map_id = map
	mode_id = mode
	if camera in ["first", "third", "player"]:
		camera_mode = camera
	for id: int in _live_peers():
		_config_msg.rpc_id(id, map_id, mode_id, camera_mode)
	config_changed.emit()


func start_round() -> void:
	if not is_host or running:
		return
	if players.size() < 2:
		status.emit("WAITING FOR ANOTHER MEMBER")
		return
	running = true
	_round_start_msg(map_id, mode_id, camera_mode)
	for id: int in _live_peers():
		_round_start_msg.rpc_id(id, map_id, mode_id, camera_mode)


## Test/ops hook: remove a client through the transport (a real ENet disconnect).
func drop_peer(id: int) -> void:
	if is_host and _peer != null:
		_peer.disconnect_peer(id)


func send_state(pos: Vector3, yaw: float, speed: float) -> void:
	if not connected or is_host:
		return
	_submit_state.rpc_id(1, pos, yaw, speed)


func send_ability(kind: String) -> void:
	if not connected:
		return
	if is_host:
		_ability_event_msg(local_id, kind)
		for id: int in _live_peers():
			_ability_event_msg.rpc_id(id, local_id, kind)
	else:
		_submit_ability.rpc_id(1, kind)


func broadcast_snapshot(snap: Dictionary) -> void:
	if not is_host:
		return
	for id: int in _live_peers():
		_snapshot_msg.rpc_id(id, snap)


func broadcast_event(kind: String, data: Dictionary) -> void:
	if not is_host:
		return
	for id: int in _live_peers():
		_event_msg.rpc_id(id, kind, data)
	event_received.emit(kind, data)


## Peers that still have a live ENet channel. Avoids writes to a peer that has
## already been dropped, which would log a channel error on the host.
func _live_peers() -> Array[int]:
	var out: Array[int] = []
	if _peer == null:
		return out
	for id: int in multiplayer.get_peers():
		var ep := _peer.get_peer(id)
		if ep != null and ep.get_state() == ENetPacketPeer.STATE_CONNECTED:
			out.append(id)
	return out


func log_line(text: String) -> void:
	print("NET_LOG ", text)


# --- transport hooks ----------------------------------------------------

func _hook_multiplayer() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_peer_connected(id: int) -> void:
	if not is_host:
		return
	status.emit("MEMBER %d CONNECTING" % id)


func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	players.erase(id)
	_sync_roster()
	peer_left.emit(id)
	log_line("DISCONNECT id=%d remaining=%d" % [id, players.size()])
	if running and players.size() < 2:
		status.emit("ALL OTHER MEMBERS LEFT — ROUND CONTINUES")


func _on_connected_to_server() -> void:
	connected = true
	local_id = multiplayer.get_unique_id()
	status.emit("CONNECTED AS MEMBER %d" % local_id)
	_register.rpc_id(1, _join_name, Loadout.body_color.to_html(), Loadout.shape,
		Loadout.ability, Loadout.third_person)


func _on_connection_failed() -> void:
	connected = false
	last_error = "CONNECTION FAILED"
	connection_failed.emit(last_error)


func _on_server_disconnected() -> void:
	connected = false
	players.clear()
	disconnected.emit()


# --- client → host ------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _register(pname: String, color_html: String, shape: int, ability: String, third: bool) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	players[id] = {
		"name": pname, "ready": false, "color": color_html,
		"shape": clampi(shape, 0, 2), "ability": ability, "third": third,
	}
	log_line("JOIN id=%d name=%s players=%d" % [id, pname, players.size()])
	_sync_roster()
	# A late joiner needs the current lobby selection too, not only the next round start.
	_config_msg.rpc_id(id, map_id, mode_id, camera_mode)


@rpc("any_peer", "call_remote", "reliable")
func _submit_ready(v: bool) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id]["ready"] = v
		_sync_roster()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_state(pos: Vector3, yaw: float, speed: float) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	state_received.emit(id, pos, yaw, speed)


@rpc("any_peer", "call_remote", "reliable")
func _submit_ability(kind: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	_ability_event_msg(id, kind)
	for pid: int in _live_peers():
		_ability_event_msg.rpc_id(pid, id, kind)


# --- host → clients -----------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _sync_roster_data(data: Dictionary) -> void:
	players = data
	roster_changed.emit()
	if auto_ready and not is_host and not bool(players.get(local_id, {}).get("ready", false)):
		set_ready(true)


@rpc("authority", "call_remote", "reliable")
func _config_msg(map: String, mode: String, camera: String) -> void:
	map_id = map
	mode_id = mode
	camera_mode = camera
	config_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _round_start_msg(map: String, mode: String, camera: String) -> void:
	map_id = map
	mode_id = mode
	camera_mode = camera
	round_started.emit(map_id, mode_id)


@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot_msg(snap: Dictionary) -> void:
	snapshot_received.emit(snap)


@rpc("authority", "call_remote", "reliable")
func _ability_event_msg(id: int, kind: String) -> void:
	ability_event.emit(id, kind)


@rpc("authority", "call_remote", "reliable")
func _event_msg(kind: String, data: Dictionary) -> void:
	event_received.emit(kind, data)


func _sync_roster() -> void:
	for id: int in _live_peers():
		_sync_roster_data.rpc_id(id, players)
	roster_changed.emit()


func _entry(pname: String, ready: bool) -> Dictionary:
	return {
		"name": pname, "ready": ready,
		"color": Loadout.body_color.to_html(), "shape": Loadout.shape,
		"ability": Loadout.ability, "third": Loadout.third_person,
	}
