extends Node
## Autoload « Net » : coop en réseau local (même Wi-Fi), via ENet.
## L'hôte fait tourner la simulation ; l'autre joueur envoie ses ordres et reçoit l'état 10 fois par seconde.
## Deux transports :
##   « lan »    : ENet sur le même Wi-Fi, parties trouvées par annonce UDP.
##   « online » : par internet via le serveur relais (dossier server/), salon à code de 4 lettres.

signal partner_joined
signal partner_left
signal joined
signal join_failed
signal disconnected
signal hosts_changed
signal game_started(level_id: int)
signal snapshot_received(snap: Dictionary)
signal command_received(cmd: Dictionary)
signal command_refused(reason: String)
signal room_created(code: String)
signal online_error(message: String)

const PORT := 27777
const DISCOVERY_PORT := 27778
const DISCOVERY_TAG := "RTSD1"
## Adresse du serveur relais. À remplacer par l'adresse de ton déploiement (voir server/README.md).
const DEFAULT_RELAY := "wss://rts-defense-relay.onrender.com"

enum Msg { START, SNAPSHOT, COMMAND, REFUSED }

var online := false
var is_host := false
var transport := "lan"
var room_code := ""
var _ws: WebSocketPeer
var _ws_open := false
var _ws_pending: Dictionary = {} # message de contrôle à envoyer à l'ouverture
var partner_connected := false
## Parties trouvées sur le réseau : ip -> {"name": String, "seen": float}
var hosts := {}

var _announce: PacketPeerUDP
var _listen: PacketPeerUDP
var _announce_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(func(_id: int) -> void:
		partner_connected = true
		partner_joined.emit())
	multiplayer.peer_disconnected.connect(func(_id: int) -> void:
		partner_connected = false
		partner_left.emit())
	multiplayer.connected_to_server.connect(func() -> void:
		partner_connected = true
		joined.emit())
	multiplayer.connection_failed.connect(func() -> void:
		leave()
		join_failed.emit())
	multiplayer.server_disconnected.connect(func() -> void:
		leave()
		disconnected.emit())


func is_client() -> bool:
	return online and not is_host


# --- Connexion --------------------------------------------------------------------

func host_game() -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	is_host = true
	_announce = PacketPeerUDP.new()
	_announce.set_broadcast_enabled(true)
	_announce.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	return OK


func join_game(ip: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	is_host = false
	return OK


## Adresse du relais : variable d'environnement RTSD_RELAY, sinon réglage sauvegardé, sinon défaut.
func relay_url() -> String:
	var env := OS.get_environment("RTSD_RELAY")
	if env != "":
		return env
	var saved: String = Save.data.settings.get("relay_url", "")
	return saved if saved != "" else DEFAULT_RELAY


func host_online() -> Error:
	return _ws_connect({"op": "host"}, true)


func join_online(code: String) -> Error:
	return _ws_connect({"op": "join", "code": code.strip_edges().to_upper()}, false)


func _ws_connect(first: Dictionary, as_host: bool) -> Error:
	leave()
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 20
	_ws.outbound_buffer_size = 1 << 20
	var err := _ws.connect_to_url(relay_url())
	if err != OK:
		_ws = null
		return err
	transport = "online"
	online = true
	is_host = as_host
	_ws_open = false
	_ws_pending = first
	return OK


func leave() -> void:
	if _ws != null:
		_ws.close()
		_ws = null
	_ws_open = false
	room_code = ""
	transport = "lan"
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	is_host = false
	partner_connected = false
	if _announce != null:
		_announce.close()
		_announce = null


## Écoute les annonces des parties sur le réseau local.
func start_discovery() -> void:
	stop_discovery()
	_listen = PacketPeerUDP.new()
	if _listen.bind(DISCOVERY_PORT) != OK:
		_listen = null


func stop_discovery() -> void:
	if _listen != null:
		_listen.close()
		_listen = null
	hosts.clear()


## Adresses IP locales de cet appareil (pour la saisie manuelle).
func local_ips() -> Array[String]:
	var out: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			out.append(ip)
	return out


func _poll_ws() -> void:
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _ws_open:
			_ws_open = true
			_ws.send_text(JSON.stringify(_ws_pending))
		while _ws != null and _ws.get_available_packet_count() > 0:
			var pkt := _ws.get_packet()
			if _ws.was_string_packet():
				_on_control(JSON.parse_string(pkt.get_string_from_utf8()))
			else:
				_on_game_message(bytes_to_var(pkt))
	elif st == WebSocketPeer.STATE_CLOSED:
		var was_open := _ws_open
		var had_partner := partner_connected
		var was_host := is_host
		leave()
		if not was_open:
			online_error.emit("Serveur en ligne injoignable")
		elif had_partner or not was_host:
			disconnected.emit()
		else:
			online_error.emit("Connexion au serveur perdue")


func _on_control(m: Variant) -> void:
	if not m is Dictionary:
		return
	match m.get("op", ""):
		"room":
			room_code = m.code
			room_created.emit(room_code)
		"partner":
			partner_connected = true
			partner_joined.emit()
		"joined":
			room_code = m.code
			partner_connected = true
			joined.emit()
		"left":
			partner_connected = false
			partner_left.emit()
		"closed":
			leave()
			disconnected.emit()
		"error":
			var msg: String = m.get("msg", "Erreur")
			leave()
			online_error.emit(msg)


func _on_game_message(m: Variant) -> void:
	if not m is Array or m.is_empty():
		return
	match int(m[0]):
		Msg.START:
			game_started.emit(int(m[1]))
		Msg.SNAPSHOT:
			_rpc_snapshot(m[1], m[2])
		Msg.COMMAND:
			if is_host:
				command_received.emit(m[1])
		Msg.REFUSED:
			command_refused.emit(m[1])


func _ws_send(m: Array) -> void:
	if _ws != null and _ws_open:
		_ws.send(var_to_bytes(m))


func _process(delta: float) -> void:
	if _ws != null:
		_poll_ws()
	if _announce != null and is_host and not partner_connected:
		_announce_timer -= delta
		if _announce_timer <= 0.0:
			_announce_timer = 1.0
			_announce.put_packet(("%s|%s" % [DISCOVERY_TAG, OS.get_name()]).to_utf8_buffer())
	if _listen != null:
		var changed := false
		while _listen.get_available_packet_count() > 0:
			var msg := _listen.get_packet().get_string_from_utf8()
			var ip := _listen.get_packet_ip()
			if msg.begins_with(DISCOVERY_TAG + "|"):
				if not hosts.has(ip):
					changed = true
				hosts[ip] = {"name": msg.get_slice("|", 1), "seen": Time.get_ticks_msec() / 1000.0}
		var now := Time.get_ticks_msec() / 1000.0
		for ip in hosts.keys():
			if now - float(hosts[ip].seen) > 4.0:
				hosts.erase(ip)
				changed = true
		if changed:
			hosts_changed.emit()


# --- Messages ---------------------------------------------------------------------

## Hôte : lance la partie chez les deux joueurs.
func start_game(level_id: int) -> void:
	if transport == "online":
		_ws_send([Msg.START, level_id])
		game_started.emit(level_id)
	else:
		_rpc_start.rpc(level_id)


## Les photos sont compressées (zstd) pour rester sous la taille d'un paquet réseau.
func send_snapshot(snap: Dictionary) -> void:
	if partner_connected:
		var raw := var_to_bytes(snap)
		var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
		if transport == "online":
			_ws_send([Msg.SNAPSHOT, raw.size(), packed])
		else:
			_rpc_snapshot.rpc(raw.size(), packed)


func send_command(cmd: Dictionary) -> void:
	if transport == "online":
		_ws_send([Msg.COMMAND, cmd])
	else:
		_rpc_command.rpc_id(1, cmd)


@rpc("authority", "call_local", "reliable")
func _rpc_start(level_id: int) -> void:
	game_started.emit(level_id)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_snapshot(raw_size: int, data: PackedByteArray) -> void:
	var snap: Variant = bytes_to_var(data.decompress(raw_size, FileAccess.COMPRESSION_ZSTD))
	if snap is Dictionary:
		snapshot_received.emit(snap)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_command(cmd: Dictionary) -> void:
	if is_host:
		command_received.emit(cmd)


## Hôte -> client : ordre refusé (pas assez de métal, case occupée…).
@rpc("authority", "call_remote", "reliable")
func _rpc_refused(reason: String) -> void:
	command_refused.emit(reason)


func send_refused(reason: String) -> void:
	if partner_connected:
		if transport == "online":
			_ws_send([Msg.REFUSED, reason])
		else:
			_rpc_refused.rpc(reason)
