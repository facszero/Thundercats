extends Node2D

const HEROES = ["Lion-O", "Cheetara", "Panthro", "Tygra"]
const ROUTES = ["Salida del Cubil", "Paso de los Mutantes"]
const ATLAS = preload("res://thundercats/heroes.webp")
const TANK = preload("res://thundercats/tank.webp")
const CANYON = preload("res://thundercats/canyon.webp")
const SKYCUTTER = preload("res://thundercats/monkian-skycutter.webp")
const HEIGHT = 160.0 # Standing height of Garbin in Gordian.
const DECK = 431.0
const FINISH = 5400.0
var hero := 0
var route := 0
var mode := "select"
var distance := 0.0
var altitude := 0.0
var vertical_speed := 0.0
var rider_x := 300.0
var hits := 0
var skycutters: Array[float] = []
var mines: Array[float] = []
var fingers := {}
var swing := 0.0
var recovery := 0.0
var controls := Control.new()
var left: Button
var right: Button

func _ready():
	add_child(controls)
	show_selector()

func driver() -> int:
	return 0 if hero == 2 else 2

func clear_controls():
	fingers.clear()
	for child in controls.get_children():
		controls.remove_child(child)
		child.queue_free()

func button(title: String, pos: Vector2, extent: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.text = title
	b.position = pos
	b.size = extent
	b.add_theme_font_size_override("font_size", 23)
	if action.is_valid(): b.pressed.connect(action)
	controls.add_child(b)
	return b

func show_selector():
	mode = "select"
	clear_controls()
	for i in HEROES.size():
		var b := button(HEROES[i], Vector2(78+i*288,464), Vector2(256,68), start_run.bind(i,0))
		if i == 0: b.grab_focus()
	queue_redraw()

func start_run(index: int, stage: int):
	hero = index
	route = stage
	mode = "ride"
	distance = 0
	hits = 0
	altitude = 0
	vertical_speed = 0
	swing = 0
	recovery = 0
	rider_x = 300
	mines.clear()
	skycutters.clear()
	for i in range(8 + route*2):
		var marker := 1100.0 + i*(540.0-route*80.0)
		if i % 2 == route:
			skycutters.append(marker)
		else:
			mines.append(marker)
	clear_controls()
	left = button("◀", Vector2(30,633), Vector2(85,68), Callable())
	right = button("▶", Vector2(128,633), Vector2(85,68), Callable())
	var jump_button := button("Saltar", Vector2(926,633), Vector2(146,68), Callable())
	var attack_button := button("Atacar", Vector2(1090,633), Vector2(160,68), Callable())
	jump_button.button_down.connect(jump)
	attack_button.button_down.connect(attack)
	for b in controls.get_children(): b.focus_mode = Control.FOCUS_NONE
	queue_redraw()

func jump():
	if mode == "ride" and altitude <= 0:
		vertical_speed = 740.0 * sqrt(HEIGHT / 90.0)

func attack():
	if mode == "ride" and recovery <= 0:
		swing = 0.23
		recovery = 0.48

func _input(event):
	if mode != "ride": return
	if event is InputEventScreenTouch:
		if not event.pressed:
			fingers.erase(event.index)
		else:
			for b in controls.get_children():
				if b.get_global_rect().has_point(event.position):
					if b == left: fingers[event.index] = -1
					elif b == right: fingers[event.index] = 1
					elif b.text == "Saltar": jump()
					elif b.text == "Atacar": attack()
					break
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE, KEY_Z, KEY_UP: jump()
			KEY_X, KEY_J: attack()
			KEY_ESCAPE: show_selector()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A: jump()
			JOY_BUTTON_X: attack()

func finish_run(success: bool):
	mode = "won" if success else "lost"
	clear_controls()
	var primary: Button
	if success and route == 0:
		primary = button("Seguir al paso", Vector2(420,375), Vector2(440,66), start_run.bind(hero,1))
	else:
		primary = button("Repetir recorrido", Vector2(420,375), Vector2(440,66), start_run.bind(hero,route))
	primary.grab_focus()
	button("Elegir héroe",Vector2(420,457),Vector2(440,66),show_selector)

func _physics_process(dt):
	if mode != "ride": return
	var axis := Input.get_axis("ui_left","ui_right") + float(right.button_pressed) - float(left.button_pressed)
	for direction in fingers.values(): axis += float(direction)
	rider_x = clampf(rider_x + clampf(axis,-1,1)*190*dt, 210, 375)
	distance += (240.0+route*55)*dt
	altitude = maxf(0,altitude+vertical_speed*dt)
	vertical_speed = vertical_speed-1800*dt if altitude>0 else 0
	swing = maxf(0,swing-dt)
	recovery = maxf(0,recovery-dt)
	for i in range(mines.size()-1,-1,-1):
		var gap := mines[i]-distance-rider_x
		if altitude < 90 and swing > 0 and gap >= -18 and gap < 132:
			mines.remove_at(i)
		elif altitude < 54 and absf(gap)<36:
			mines.remove_at(i)
			hits += 1
		elif gap < -120:
			mines.remove_at(i)
	for i in range(skycutters.size()-1,-1,-1):
		var center := cutter_position(skycutters[i])
		var player_offset := center - Vector2(rider_x,DECK-altitude)
		var can_strike := player_offset.x >= -16 and player_offset.x < 164 and absf(player_offset.y+75)<68
		if swing>0 and can_strike:
			skycutters.remove_at(i)
		elif absf(player_offset.x)<55 and player_offset.y > -HEIGHT-16 and player_offset.y < 18:
			hits += 1
			skycutters.remove_at(i)
		elif center.x < -120:
			skycutters.remove_at(i)
	if hits >= 3 or distance >= FINISH:
		finish_run(hits<3)
	queue_redraw()

func cutter_position(marker: float) -> Vector2:
	var x := 320.0 + (marker-distance-320.0)*1.24
	var dive := 1.0-smoothstep(480,900,x)
	return Vector2(x,lerpf(205,DECK-67,dive)+sin(x/100)*7)

func caption(at: Vector2, words: String, font_size: int):
	draw_string(ThemeDB.fallback_font,at+Vector2(2,3),words,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("#141420"))
	draw_string(ThemeDB.fallback_font,at,words,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("#fff1d3"))

func _draw():
	var scroll := fmod(distance*0.26,1280.0)
	draw_texture_rect(CANYON,Rect2(-scroll,0,1280,720),false)
	draw_texture_rect(CANYON,Rect2(1280-scroll,0,1280,720),false)
	if mode == "select":
		draw_rect(Rect2(0,0,1280,720),Color(0.04,0.03,0.1,0.69))
		caption(Vector2(78,120),"THUNDERCATS",68)
		caption(Vector2(80,190),"Elegí quién defenderá el Thundertank",30)
		for i in HEROES.size():
			draw_texture_rect_region(ATLAS,Rect2(78+i*288,300,256,158),Rect2(i*256,0,256,158))
		return
	var bob := sin(distance/19)*0.65
	draw_rect(Rect2(0,619,1280,101),Color("#352d39"))
	for i in range(14):
		var x := i*102-fmod(distance,102)
		draw_line(Vector2(x,624),Vector2(x-36,632),Color("#745043"),3)
	draw_set_transform(Vector2(310,624),0,Vector2(1,0.055))
	draw_circle(Vector2.ZERO,147,Color("#241f25"))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	draw_texture_rect(TANK,Rect2(150,DECK+bob,480,198-bob),false)
	# Crop the seated driver's upper body to the open front cockpit.
	draw_texture_rect_region(ATLAS,Rect2(413,DECK-14+bob,76,62),Rect2(driver()*256+57,170,142,116))
	var foot := Vector2(rider_x,DECK-altitude+bob)
	draw_texture_rect_region(ATLAS,Rect2(foot-Vector2(82,HEIGHT),Vector2(164,HEIGHT)),Rect2(hero*256,170,256,250))
	if swing>0: draw_arc(foot+Vector2(27,-68),86,-1.3,0.72,20,Color("#ffe57b"),7,true)
	for marker in skycutters:
		var center := cutter_position(marker)
		if center.x >= -110 and center.x <= 1390:
			draw_texture_rect(SKYCUTTER,Rect2(center-Vector2(93,47),Vector2(186,94)),false)
	for mark in mines:
		var p := Vector2(mark-distance,DECK-26)
		if p.x < -35 or p.x > 1315: continue
		draw_line(p-Vector2(57,0),p,Color("#f0793b"),5)
		draw_circle(p,20,Color("#351d3e"))
		draw_circle(p,12,Color("#ff763c"))
		draw_circle(p,5,Color("#fff49d"))
	draw_rect(Rect2(0,0,1280,88),Color(0.05,0.06,0.12,0.9))
	caption(Vector2(30,36),ROUTES[route]+"   /   "+HEROES[hero],27)
	caption(Vector2(30,68),"Conduce "+HEROES[driver()]+"   ·   Saltá o atacá cuando baje el Skycutter",20)
	caption(Vector2(950,54),"%d%%     Escudo %d/3" % [mini(100,int(100*distance/FINISH)),3-hits],25)
	if mode in ["won","lost"]:
		draw_rect(Rect2(290,230,700,320),Color("#231d30"))
		caption(Vector2(405,328),"¡Llegaste al destino!" if mode=="won" else "El tanque perdió el escudo",34)
