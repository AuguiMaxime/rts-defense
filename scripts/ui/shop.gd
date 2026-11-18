extends Control
## Boutique : augments (crédits), tourelles et skins (or), packs d'or et pub récompensée.

var _tab := "augments"
var _tabs := {}
var _content: Control


func _ready() -> void:
	var root := Ui.screen_root(self)
	root.add_child(Ui.header("BOUTIQUE"))

	var tabs := Ui.hbox(12)
	for pair in [["augments", "AUGMENTS"], ["arsenal", "TOURELLES & SKINS"], ["gold", "OBTENIR DE L'OR"]]:
		var b := Ui.button(pair[1], false, Vector2(260, 56))
		b.pressed.connect(func() -> void: _show(pair[0]))
		_tabs[pair[0]] = b
		tabs.add_child(b)
	root.add_child(tabs)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_content = Ui.vbox(16)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	_show(_tab)


func _show(tab: String) -> void:
	_tab = tab
	for k in _tabs:
		(_tabs[k] as Button).theme_type_variation = "PrimaryButton" if k == tab else ""
	for c in _content.get_children():
		c.queue_free()
	match tab:
		"augments":
			_content.add_child(Ui.label("Bonus à usage unique, utilisés automatiquement au lancement de la prochaine partie.", 20, Ui.MUTED))
			var row := _row()
			for a in Content.AUGMENTS:
				row.add_child(_augment_card(a))
		"arsenal":
			_content.add_child(Ui.title("TOURELLES SPÉCIALES", 20, Ui.GOLD))
			var row := _row()
			row.add_child(_laser_card())
			_content.add_child(Ui.title("SKINS DE TOURELLES", 20, Ui.GOLD))
			var row2 := _row()
			for s in Content.SKINS:
				row2.add_child(_skin_card(s))
		"gold":
			_content.add_child(Ui.label("L'or sert aux tourelles spéciales et aux skins. Jamais de bonus de puissance à l'achat.", 20, Ui.MUTED))
			var row := _row()
			row.add_child(_ad_card())
			for p in Content.GOLD_PACKS:
				row.add_child(_pack_card(p))


func _row() -> HBoxContainer:
	var r := Ui.hbox(18)
	_content.add_child(r)
	return r


func _card(title_text: String, desc: String, accent := Ui.CYAN) -> Array:
	var card := Ui.panel(Vector2(280, 250))
	card.add_theme_stylebox_override("panel", Ui.box(Color(Ui.PANEL, 0.92), Color(accent, 0.5), 2, 10))
	var v := Ui.vbox(10)
	card.add_child(v)
	v.add_child(Ui.title(title_text.to_upper(), 18, accent))
	var d := Ui.label(desc, 20, Ui.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(236, 60)
	v.add_child(d)
	return [card, v]


func _augment_card(a: Dictionary) -> PanelContainer:
	var parts := _card(a.name, a.desc, Ui.GREEN)
	var v: VBoxContainer = parts[1]
	v.add_child(Ui.spacer())
	v.add_child(Ui.label("En stock : %d" % Save.augment_count(a.id), 20, Ui.TEXT, true))
	var b := Ui.button("ACHETER  ◆ %d" % a.cost, false, Vector2(0, 54))
	b.pressed.connect(func() -> void:
		if Save.spend("credits", a.cost):
			Save.change_augment(a.id, 1)
			Ui.toast("%s ajouté" % a.name, Ui.GREEN)
			_show(_tab)
		else:
			Ui.toast("Pas assez de crédits", Ui.RED))
	v.add_child(b)
	return parts[0]


func _laser_card() -> PanelContainer:
	var t: Dictionary = Content.TOWERS.laser
	var parts := _card(t.name, "%s\n%d M · %d E" % [t.desc, t.metal, t.essence], Ui.GOLD)
	var v: VBoxContainer = parts[1]
	var img := TextureRect.new()
	img.texture = Sprites.TURRET_LIGHT
	img.modulate = Sprites.TOWER_LOOK.laser.tint
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(0, 64)
	v.add_child(img)
	if Save.owns("tower_laser"):
		var b := Ui.button("DÉBLOQUÉE", false, Vector2(0, 54))
		b.disabled = true
		v.add_child(b)
	else:
		v.add_child(_gold_buy_button(t.price_gold, func() -> void: Save.give("tower_laser")))
	return parts[0]


func _skin_card(s: Dictionary) -> PanelContainer:
	var parts := _card(s.name, "Teinte de toutes tes tourelles.", Ui.GOLD)
	var v: VBoxContainer = parts[1]
	var preview := Ui.hbox(4)
	preview.alignment = BoxContainer.ALIGNMENT_CENTER
	for tex in [Sprites.TURRET_GUN, Sprites.TURRET_DOUBLE, Sprites.TURRET_MISSILE]:
		var img := TextureRect.new()
		img.texture = tex
		img.modulate = s.tint
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(56, 56)
		preview.add_child(img)
	v.add_child(preview)
	if Save.data.skin == s.id:
		var b := Ui.button("ÉQUIPÉ", false, Vector2(0, 54))
		b.disabled = true
		v.add_child(b)
	elif Save.owns(s.id):
		var b := Ui.button("ÉQUIPER", true, Vector2(0, 54))
		b.pressed.connect(func() -> void:
			Save.data.skin = s.id
			Save.save_data()
			_show(_tab))
		v.add_child(b)
	else:
		v.add_child(_gold_buy_button(s.price_gold, func() -> void:
			Save.give(s.id)
			Save.data.skin = s.id
			Save.save_data()))
	return parts[0]


func _gold_buy_button(price: int, on_buy: Callable) -> Button:
	var b := Ui.button("● %d OR" % price, false, Vector2(0, 54))
	b.theme_type_variation = "GoldButton"
	b.pressed.connect(func() -> void:
		if Save.spend("gold", price):
			on_buy.call()
			Ui.toast("Achat effectué", Ui.GOLD)
			_show(_tab)
		else:
			Ui.toast("Pas assez d'or", Ui.RED)
			_show("gold"))
	return b


func _ad_card() -> PanelContainer:
	var parts := _card("Pub récompensée", "Regarde une courte vidéo pour gagner de l'or gratuitement.", Ui.GREEN)
	var v: VBoxContainer = parts[1]
	v.add_child(Ui.spacer())
	var reward := Ui.hbox(8)
	var ic := CurrencyIcon.new()
	ic.kind = "gold"
	reward.add_child(ic)
	reward.add_child(Ui.label("+%d" % Content.AD_REWARD_GOLD, 30, Ui.GOLD, true))
	v.add_child(reward)
	var b := Ui.button("▶  REGARDER", true, Vector2(0, 54))
	b.pressed.connect(func() -> void: _play_ad(b))
	v.add_child(b)
	return parts[0]


## Pub simulée. À remplacer par le plugin AdMob (annonce avec récompense) au moment de publier.
func _play_ad(b: Button) -> void:
	b.disabled = true
	for i in range(3, 0, -1):
		b.text = "PUB…  %d" % i
		await get_tree().create_timer(1.0).timeout
	Save.add("gold", Content.AD_REWARD_GOLD)
	Ui.toast("+%d or" % Content.AD_REWARD_GOLD, Ui.GOLD)
	if is_inside_tree():
		_show(_tab)


func _pack_card(p: Dictionary) -> PanelContainer:
	var parts := _card("%d or" % p.gold, "Pack d'or", Ui.GOLD)
	var v: VBoxContainer = parts[1]
	var coins := Ui.hbox(6)
	coins.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in clampi(p.gold / 300 + 1, 1, 5):
		var ic := CurrencyIcon.new()
		ic.kind = "gold"
		ic.custom_minimum_size = Vector2(40, 40)
		coins.add_child(ic)
	v.add_child(coins)
	v.add_child(Ui.spacer())
	var b := Ui.button(p.price, false, Vector2(0, 54))
	b.theme_type_variation = "GoldButton"
	b.pressed.connect(func() -> void: Ui.toast("Paiements bientôt disponibles (Google Play)", Ui.GOLD))
	v.add_child(b)
	return parts[0]
