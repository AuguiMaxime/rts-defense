extends Control
## Salon multijoueur : héberger une partie coop ou rejoindre celle d'un ami sur le même Wi-Fi.

var _status: Label
var _hosts_box: VBoxContainer
var _host_panel: PanelContainer
var _maps_box: HBoxContainer
var _start_btn: Button
var _ip_edit: LineEdit
var _chosen_level := 1


func _ready() -> void:
	var root := Ui.screen_root(self)
	var head := Ui.header("COOP · RÉSEAU LOCAL")
	root.add_child(head)
	root.add_child(Ui.label("Jouez à deux sur le même Wi-Fi : même base, mêmes ressources, chacun commande les ouvriers.", 20, Ui.MUTED))

	var row := Ui.hbox(24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)

	# Héberger
	_host_panel = Ui.panel(Vector2(0, 0), true)
	_host_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var hv := Ui.vbox(12)
	hv.add_child(Ui.title("HÉBERGER", 22, Ui.CYAN))
	hv.add_child(Ui.label("Tu crées la partie, ton ami la rejoint.", 20, Ui.MUTED))
	var host_btn := Ui.button("CRÉER UNE PARTIE", true, Vector2(0, 62))
	host_btn.pressed.connect(_on_host)
	hv.add_child(host_btn)
	hv.add_child(Ui.label("Secteur à jouer :", 20))
	_maps_box = Ui.hbox(8)
	hv.add_child(_maps_box)
	_start_btn = Ui.button("LANCER LA PARTIE", true, Vector2(0, 62))
	_start_btn.disabled = true
	_start_btn.pressed.connect(func() -> void: Net.start_game(_chosen_level))
	hv.add_child(_start_btn)
	_host_panel.add_child(hv)
	row.add_child(_host_panel)

	# Rejoindre
	var join := Ui.panel()
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var jv := Ui.vbox(12)
	jv.add_child(Ui.title("REJOINDRE", 22, Ui.MAGENTA))
	jv.add_child(Ui.label("Parties trouvées sur ton réseau :", 20, Ui.MUTED))
	_hosts_box = Ui.vbox(8)
	jv.add_child(_hosts_box)
	jv.add_child(Ui.label("Ou entre l'adresse affichée chez ton ami :", 20, Ui.MUTED))
	var ip_row := Ui.hbox(10)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "192.168.1.20"
	_ip_edit.custom_minimum_size = Vector2(240, 54)
	_ip_edit.add_theme_font_size_override("font_size", 22)
	_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_row.add_child(_ip_edit)
	var go := Ui.button("REJOINDRE", false, Vector2(170, 54))
	go.pressed.connect(func() -> void: _join(_ip_edit.text.strip_edges()))
	ip_row.add_child(go)
	jv.add_child(ip_row)
	join.add_child(jv)
	row.add_child(join)

	_status = Ui.label("", 22, Ui.CYAN, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status)

	_build_maps()
	_refresh_hosts()
	Net.hosts_changed.connect(_refresh_hosts)
	Net.partner_joined.connect(_on_partner_joined)
	Net.partner_left.connect(func() -> void:
		_status.text = "Ton ami s'est déconnecté. En attente…"
		_start_btn.disabled = true)
	Net.joined.connect(func() -> void: _status.text = "Connecté ! L'hôte va lancer la partie…")
	Net.join_failed.connect(func() -> void: _status.text = "Connexion impossible. Vérifie l'adresse et le Wi-Fi.")
	Net.disconnected.connect(func() -> void: _status.text = "L'hôte a fermé la partie.")
	Net.game_started.connect(_on_game_started)

	if Net.is_host:
		_show_hosting()
	elif Net.online and Net.partner_connected:
		_status.text = "Connecté ! L'hôte va lancer la partie…"
	else:
		Net.start_discovery()
	head.get_child(0).pressed.connect(func() -> void:
		Net.stop_discovery()
		Net.leave())


func _exit_tree() -> void:
	Net.stop_discovery()


func _build_maps() -> void:
	for c in _maps_box.get_children():
		c.queue_free()
	for l in Content.LEVELS:
		if not Save.is_level_unlocked(l.id):
			continue
		var b := Ui.button("%02d" % l.id, l.id == _chosen_level, Vector2(70, 50))
		b.pressed.connect(func() -> void:
			_chosen_level = l.id
			_build_maps())
		_maps_box.add_child(b)


func _refresh_hosts() -> void:
	for c in _hosts_box.get_children():
		c.queue_free()
	if Net.hosts.is_empty():
		_hosts_box.add_child(Ui.label("Recherche en cours…", 20, Ui.MUTED))
		return
	for ip in Net.hosts:
		var b := Ui.button("▶  PARTIE DE %s  ·  %s" % [str(Net.hosts[ip].name).to_upper(), ip], false, Vector2(0, 56))
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(func() -> void: _join(ip))
		_hosts_box.add_child(b)


func _on_host() -> void:
	Net.stop_discovery()
	var err := Net.host_game()
	if err != OK:
		_status.text = "Impossible de créer la partie (erreur %d)" % err
		return
	_show_hosting()


func _show_hosting() -> void:
	var ips := Net.local_ips()
	var where := " · ton adresse : %s" % ", ".join(ips) if not ips.is_empty() else ""
	_status.text = ("Ton ami est connecté ! Choisis le secteur et lance." if Net.partner_connected
			else "Partie créée, en attente de ton ami%s" % where)
	_start_btn.disabled = not Net.partner_connected


func _join(ip: String) -> void:
	if ip == "":
		_status.text = "Entre une adresse IP"
		return
	Net.stop_discovery()
	_status.text = "Connexion à %s…" % ip
	if Net.join_game(ip) != OK:
		_status.text = "Adresse invalide"


func _on_partner_joined() -> void:
	if Net.is_host:
		Sfx.play("built", -4.0)
		_show_hosting()


func _on_game_started(level_id: int) -> void:
	Ui.play_level(level_id)
