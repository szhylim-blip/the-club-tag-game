class_name NetHub
extends Node
## Lobby presence, not gameplay netcode: every peer is a real RemoteMember
## standing in the 3D Club while the host picks a map and starts a round.
##
## The host aggregates client positions and broadcasts them at 14 Hz; clients
## send their own position at 20 Hz. When the round starts, NetMatch takes over
## and this node is freed with the hub.

const SNAPSHOT_HZ := 14.0
const STATE_HZ := 20.0

var hub: Hub
var remotes: Dictionary = {}

var _states: Dictionary = {}
var _snap_acc := 0.0
var _state_acc := 0.0


func attach(p_hub: Hub) -> void:
	hub = p_hub
	Net.state_received.connect(_on_state)
	Net.snapshot_received.connect(_on_snapshot)
	Net.roster_changed.connect(_rebuild)
	Net.peer_left.connect(_on_peer_left)

	var me := _spawn_for(Net.local_id)
	if hub.player != null:
		hub.player.camera_override = 1 if Net.camera_mode == "third" else (0 if Net.camera_mode == "first" else -1)
		hub.player.global_position = me
		hub.player.velocity = Vector3.ZERO
		hub.player.rotation.y = 0.0
		hub.player.cam.current = true
	_rebuild()
	Net.log_line("HUB_ENTER local=%d players=%d" % [Net.local_id, Net.players.size()])


func _ids() -> Array:
	var out := []
	for id: int in Net.players:
		out.append(id)
	out.sort()
	if not out.has(Net.local_id):
		out.append(Net.local_id)
		out.sort()
	return out


## Authored lobby stances: host at the south edge looking into the lounge, the
## party fanned out ahead of them. Beats a circle (nobody faces a back wall).
const SPOTS: Array[Vector3] = [
	Vector3(0, 0.0, 9.2),
	Vector3(-2.2, 0.0, 5.6),
	Vector3(2.2, 0.0, 5.6),
	Vector3(-4.0, 0.0, 3.6),
	Vector3(4.0, 0.0, 3.6),
	Vector3(0, 0.0, 4.6),
	Vector3(-5.6, 0.0, 1.4),
	Vector3(5.6, 0.0, 1.4),
]


func _spawn_for(id: int) -> Vector3:
	var ids := _ids()
	var idx := maxi(ids.find(id), 0)
	return SPOTS[idx % SPOTS.size()]


func _rebuild() -> void:
	if hub == null:
		return
	var ids := _ids()
	for id: int in ids:
		if id == Net.local_id:
			continue
		if remotes.has(id):
			continue
		var r := RemoteMember.new()
		r.name = "Member%d" % id
		hub.add_child(r)
		r.setup(id, Net.players.get(id, {}))
		var p := _spawn_for(id)
		r.snap_to(p, 0.0)
		remotes[id] = r
	for id: int in remotes.keys():
		if not ids.has(id):
			var old: Node = remotes[id]
			remotes.erase(id)
			if is_instance_valid(old):
				old.queue_free()


func _process(dt: float) -> void:
	if hub == null or hub.player == null or not Net.connected:
		return
	var p := hub.player
	var spd := Vector2(p.velocity.x, p.velocity.z).length()

	if Net.is_host:
		_states[Net.local_id] = {
			"p": p.global_position, "y": p.rotation.y, "s": spd,
		}
		_snap_acc += dt
		if _snap_acc >= 1.0 / SNAPSHOT_HZ:
			_snap_acc = 0.0
			_broadcast()
	else:
		_state_acc += dt
		if _state_acc >= 1.0 / STATE_HZ:
			_state_acc = 0.0
			Net.send_state(p.global_position, p.rotation.y, spd)


func _broadcast() -> void:
	var packed := {}
	for id: int in _states:
		var s: Dictionary = _states[id]
		packed[id] = [s["p"], s["y"], s["s"]]
	Net.broadcast_snapshot({"hub": true, "p": packed})


func _on_state(id: int, pos: Vector3, yaw: float, speed: float) -> void:
	if not Net.is_host:
		return
	_states[id] = {"p": pos, "y": yaw, "s": speed}


func _on_snapshot(snap: Dictionary) -> void:
	if Net.is_host or not bool(snap.get("hub", false)):
		return
	var packed: Dictionary = snap.get("p", {})
	for id: int in packed:
		if not remotes.has(int(id)):
			continue
		var row: Array = packed[id]
		if row.size() < 3:
			continue
		var r: RemoteMember = remotes[int(id)]
		r.apply_state(row[0] as Vector3, float(row[1]), float(row[2]))


func _on_peer_left(id: int) -> void:
	if remotes.has(id):
		var r: Node = remotes[id]
		remotes.erase(id)
		if is_instance_valid(r):
			r.queue_free()
