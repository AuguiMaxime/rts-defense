extends Control
## Salon multijoueur : coop en ligne (code de salon) ou sur le même Wi-Fi.

var _tab := "online"
var _tabs := {}
var _body: VBoxContainer
var _status: Label
var _maps_box: HBoxContainer
var _start_btn: Button
var _hosts_box: VBoxContainer
var _code_label: Label
var _chosen_level := 1


func _ready() -> void:
	var root := Ui.screen_root(self)
	var head := Ui.header("COOP À DEUX")
	root.add_child(head)
	head.get_child(0).pressed.connect(func() -> void:
		Net.stop_discovery()
		Net.leave())

	var tabs := Ui.hbox(12)
	for pair in [["online", "EN LIGNE"], ["lan", "MÊME WI-FI"]]:
		var b := Ui.button(pair[1], false, Vector2(240, 54))
		b.pressed.connect(func() -> void:
			if Net.online and not Net.partner_connected:
				Net.leave()
			_show(pair[0]))
		_tabs[pair[0]] = b
		tabs.add_child(b)
	tabs.add_child(Ui.spacer())
	tabs.add_child(Ui.label("Même base, mêmes ressources : chacun commande les ouvriers.", 19, Ui.MUTED))
	root.add_child(tabs)

	_body = Ui.vbox(16)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_body)

	_status = Ui.label("", 22, Ui.CYAN, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status)

	Net.hosts_changed.connect(_refresh_hosts)
	Net.partner_joined.connect(_on_partner_joined)
	Net.partner_left.connect(func() -> void:
		_status.text = "Ton ami s'est déconnecté. En attente…"
		_update_start())
	Net.joined.connect(func() -> void: _status.text = "Connecté ! L'hôte va lancer la partie…")
	Net.join_failed.connect(func() -> void: _status.text = "Connexion impossible. Vérifie l'adresse et le Wi-Fi.")
	Net.disconnected.connect(func() -> void: _status.text = "L'hôte a fermé la partie.")
	Net.online_error.connect(func(msg: String) -> void:
		_status.text = msg
		_status.add_theme_color_override("font_color", Ui.RED)
		_show(_tab))
	Net.room_created.connect(func(code: String) -> void:
		_status.add_theme_color_override("font_color", Ui.CYAN)
		_status.text = "Salon créé : donne le code %s à ton ami" % code
		_show(_tab))
	Net.game_started.connect(func(level_id: int) -> void: Ui.play_level(level_id))

	if Net.online:
		_tab = Net.transport
	_show(_tab)


func _exit_tree() -> void:
	Net.stop_discovery()


func _show(tab: String) -> void:
	_tab = tab
	for k in _tabs:
		(_tabs[k] as Button).theme_type_variation = "PrimaryButton" if k == tab else ""
	for c in _body.get_children():
		c.queue_free()
	_code_label = null
	_hosts_box = null
	if tab == "lan":
		Net.start_discovery()
	else:
		Net.stop_discovery()
	var row := Ui.hbox(24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(row)
	row.add_child(_host_panel(tab))
	row.add_child(_join_panel(tab))
	if tab == "online":
		_body.add_child(_server_row())
	_update_start()


func _host_panel(tab: String) -> PanelContainer:
	var p := Ui.panel(Vector2.ZERO, true)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v := Ui.vbox(12)
	v.add_child(Ui.title("HÉBERGER", 22, Ui.CYAN))
	var hosting := Net.online and Net.is_host and Net.transport == tab
	if tab == "online" and hosting and Net.room_code != "":
		v.add_child(Ui.label("Code du salon à donner à ton ami :", 20, Ui.MUTED))
		_code_label = Ui.title(Net.room_code, 64, Ui.TEXT)
		_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(_code_label)
	elif hosting:
		var ips := Net.local_ips()
		v.add_child(Ui.label("Partie créée. Ton adresse : %s" % (", ".join(ips) if not ips.is_empty() else "?"), 20, Ui.MUTED))
	else:
		v.add_child(Ui.label("Crée la partie, ton ami la rejoint.", 20, Ui.MUTED))
		var b := Ui.button("CRÉER UN SALON" if tab == "online" else "CRÉER UNE PARTIE", true, Vector2(0, 62))
		b.pressed.connect(func() -> void: _host(tab))
		v.add_child(b)
	v.add_child(Ui.label("Secteur à jouer :", 20))
	_maps_box = Ui.hbox(8)
	v.add_child(_maps_box)
	_build_maps()
	_start_btn = Ui.button("LANCER LA PARTIE", true, Vector2(0, 62))
	_start_btn.pressed.connect(func() -> void: Net.start_game(_chosen_level))
	v.add_child(_start_btn)
	p.add_child(v)
	return p


func _join_panel(tab: String) -> PanelContainer:
	var p := Ui.panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v := Ui.vbox(12)
	v.add_child(Ui.title("REJOINDRE", 22, Ui.MAGENTA))
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(200, 58)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var go := Ui.button("REJOINDRE", false, Vector2(170, 58))
	if tab == "online":
		v.add_child(Ui.label("Entre le code de 4 lettres de ton ami :", 20, Ui.MUTED))
		edit.placeholder_text = "ABCD"
		edit.max_length = 4
		edit.add_theme_font_override("font", Ui.font_title)
		edit.add_theme_font_size_override("font_size", 30)
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		edit.text_changed.connect(func(t: String) -> void:
			var up := t.to_upper()
			if up != t:
				edit.text = up
				edit.caret_column = up.length())
		go.pressed.connect(func() -> void: _join_online(edit.text))
		edit.text_submitted.connect(func(t: String) -> void: _join_online(t))
	else:
		v.add_child(Ui.label("Parties trouvées sur ton réseau :", 20, Ui.MUTED))
		_hosts_box = Ui.vbox(8)
		v.add_child(_hosts_box)
		_refresh_hosts()
		v.add_child(Ui.label("Ou entre l'adresse affichée chez ton ami :", 20, Ui.MUTED))
		edit.placeholder_text = "192.168.1.20"
		edit.add_theme_font_size_override("font_size", 22)
		go.pressed.connect(func() -> void: _join_lan(edit.text.strip_edges()))
	var r := Ui.hbox(10)
	r.add_child(edit)
	r.add_child(go)
	v.add_child(r)
	p.add_child(v)
	return p


func _server_row() -> HBoxContainer:
	var h := Ui.hbox(10)
	h.add_child(Ui.label("Serveur :", 18, Ui.MUTED))
	var e := LineEdit.new()
	e.text = Net.relay_url()
	e.add_theme_font_size_override("font_size", 16)
	e.custom_minimum_size = Vector2(460, 40)
	e.text_submitted.connect(func(t: String) -> void:
		Save.set_setting("relay_url", t.strip_edges())
		Ui.toast("Adresse du serveur enregistrée"))
	h.add_child(e)
	h.add_child(Ui.label("(Entrée pour valider)", 16, Ui.MUTED))
	return h


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


func _update_start() -> void:
	if _start_btn != null:
		_start_btn.disabled = not (Net.is_host and Net.partner_connected)


func _refresh_hosts() -> void:
	if _hosts_box == null or not is_instance_valid(_hosts_box):
		return
	for c in _hosts_box.get_children():
		c.queue_free()
	if Net.hosts.is_empty():
		_hosts_box.add_child(Ui.label("Recherche en cours…", 20, Ui.MUTED))
		return
	for ip in Net.hosts:
		var b := Ui.button("▶  PARTIE DE %s  ·  %s" % [str(Net.hosts[ip].name).to_upper(), ip], false, Vector2(0, 56))
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(func() -> void: _join_lan(ip))
		_hosts_box.add_child(b)


func _host(tab: String) -> void:
	_status.add_theme_color_override("font_color", Ui.CYAN)
	if tab == "online":
		_status.text = "Connexion au serveur…"
		if Net.host_online() != OK:
			_status.text = "Adresse du serveur invalide"
		return
	Net.stop_discovery()
	var err := Net.host_game()
	if err != OK:
		_status.text = "Impossible de créer la partie (erreur %d)" % err
		return
	_status.text = "Partie créée, en attente de ton ami…"
	_show(tab)


func _join_online(code: String) -> void:
	if code.strip_edges().length() != 4:
		_status.text = "Le code fait 4 lettres"
		return
	_status.add_theme_color_override("font_color", Ui.CYAN)
	_status.text = "Connexion au salon %s…" % code.to_upper()
	if Net.join_online(code) != OK:
		_status.text = "Adresse du serveur invalide"


func _join_lan(ip: String) -> void:
	if ip == "":
		_status.text = "Entre une adresse IP"
		return
	Net.stop_discovery()
	_status.add_theme_color_override("font_color", Ui.CYAN)
	_status.text = "Connexion à %s…" % ip
	if Net.join_game(ip) != OK:
		_status.text = "Adresse invalide"


func _on_partner_joined() -> void:
	if Net.is_host:
		Sfx.play("built", -4.0)
		_status.add_theme_color_override("font_color", Ui.GREEN)
		_status.text = "Ton ami est connecté ! Choisis le secteur et lance."
		_update_start()
