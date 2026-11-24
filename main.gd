extends Node2D

# Rebound - Neon Cosmos Edition (Godot 4)

const W = 960.0
const H = 540.0

const GRAV = 1200.0
const SPD = 380.0
const JUMP_VEL = 680.0
const GAP_MIN = 85.0
const GAP_MAX = 115.0

const CHARGE_REQ = 10
const TURBO_VEL = 1500.0
const FRAGILE_RATE = 0.25
const CAMP_LIMIT = 5       # consecutive bounces on one normal tile before it shatters
const ZONE_STEP = 60.0     # score interval per color shift
const DANGER_Y = 190.0
const DEAD_DELAY = 2.0

const CREDITS = "CREATED BY TEAM XP HUNTERS   •   HACK CLUB HAVEN"

const MUSIC_FILES = [
	"res://assets/dance_monkey.mp3",
	"res://assets/dance_monkey.ogg",
	"res://assets/dance_monkey.wav",
	"res://assets/music.mp3",
	"res://assets/music.ogg"
]

const FAAH_FILES = [
	"res://assets/faah.mp3",
	"res://assets/faah.ogg",
	"res://assets/faah.wav"
]

const FONT_FILES = [
	"res://assets/title_font.ttf",
	"res://assets/title_font.otf",
	"res://assets/fonts/title_font.ttf"
]

const BG_COL = Color("#080d20")
const CYAN = Color("#36cfff")
const PURPLE = Color("#a66cff")
const WHITE = Color("#eafaff")
const ULTRA = Color("#2f6bff")
const ULTRA_GLOW = Color("#8fc4ff")
const FRAGILE = Color("#ff7a59")
const DANGER_RED = Color("#ff2a4d")
const WASTED_RED = Color("#d11a2a")

var zone_cols: Array = [
	Color("#36cfff"),
	Color("#3dff9e"),
	Color("#ffe94d"),
	Color("#ff4fd8"),
	Color("#a66cff")
]

var orb_pos = Vector2(480, 420)
var vel = Vector2.ZERO

var plats: Array[Dictionary] = []
var plat_seq = 0
var cam_y = 270.0
var top_y = 420.0

var score = 0
var bounces = 0
var best_score = 0

var turbo_pts = 0
var is_charged = false
var turbo_t = 0.0
var prev_w = false

var fx: Array = []
var trail_pts: Array = []
var hit_squash = 0.0
var cam_shake = 0.0
var shake_vec = Vector2.ZERO

var bgm: AudioStreamPlayer
var muted = false
var sfx: AudioStreamPlayer
var faah_snd: AudioStream

var dead_t = 0.0
var dead_ui_up = false
var state = "menu"

var bg_tex: Texture2D
var menu_bg: ColorRect
var main_font: Font

var ui_layer: CanvasLayer
var menu_root: Control
var menu_vbox: VBoxContainer
var card_panel: Panel
var team_lbl: Label


func _ready():
	randomize()

	if has_node("GameUI/MenuLayer/MainMenu"):
		ui_layer = get_node("GameUI")
		menu_root = get_node("GameUI/MenuLayer")
		menu_vbox = get_node("GameUI/MenuLayer/MainMenu")
	else:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "GameUI"
		add_child(ui_layer)

		menu_root = Control.new()
		menu_root.name = "MenuLayer"
		ui_layer.add_child(menu_root)

		menu_vbox = VBoxContainer.new()
		menu_vbox.name = "MainMenu"
		menu_root.add_child(menu_vbox)

	var cfg = ConfigFile.new()
	if cfg.load("user://rebound.cfg") == OK:
		best_score = cfg.get_value("scores", "best", 0)

	if ResourceLoader.exists("res://assets/space_background.png"):
		bg_tex = load("res://assets/space_background.png")

	init_fonts()
	init_ui()
	init_audio()
	open_main_menu()


func save_best():
	var cfg = ConfigFile.new()
	cfg.set_value("scores", "best", best_score)
	cfg.save("user://rebound.cfg")


func init_fonts():
	for p in FONT_FILES:
		if ResourceLoader.exists(p):
			main_font = load(p)
			return

	var sf = SystemFont.new()
	sf.font_names = PackedStringArray(["Pricedown", "Impact", "Haettenschweiler", "Arial Black", "Bahnschrift", "Anton"])
	sf.font_weight = 800
	main_font = sf


func init_audio():
	bgm = AudioStreamPlayer.new()
	add_child(bgm)
	for p in MUSIC_FILES:
		if ResourceLoader.exists(p):
			var st = load(p)
			if st is AudioStreamWAV:
				st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			else:
				st.set("loop", true)
			bgm.stream = st
			bgm.volume_db = -12.0
			bgm.play()
			break

	sfx = AudioStreamPlayer.new()
	add_child(sfx)
	for p in FAAH_FILES:
		if ResourceLoader.exists(p):
			faah_snd = load(p)
			break

	# procedural fallback if no custom faah clip is bundled
	if faah_snd == null:
		var rate = 22050
		var dur = 0.9
		var samples = int(float(rate) * dur)
		var buf = PackedByteArray()
		buf.resize(samples * 2)

		var ph = 0.0
		for i in range(samples):
			var t = float(i) / float(rate)
			var freq = lerpf(330.0, 150.0, t / dur) * (1.0 + 0.02 * sin(t * 40.0))
			ph += TAU * freq / float(rate)
			var wave = sin(ph) * 0.6 + sin(ph * 2.0) * 0.3 + sin(ph * 3.0) * 0.2 + sin(ph * 5.0) * 0.1
			var env = minf(1.0, t / 0.04) * clampf((dur - t) / 0.3, 0.0, 1.0)
			buf.encode_s16(i * 2, int(clampf(wave * env * 0.45, -1.0, 1.0) * 32767.0))

		var wav = AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = rate
		wav.stereo = false
		wav.data = buf
		faah_snd = wav


func tick_audio(delta):
	if bgm == null or bgm.stream == null:
		return

	var target = -4.0 if state == "playing" else -12.0
	# duck bgm briefly so the game over sfx cuts through
	if state == "lost" and dead_t < 3.0:
		target = -26.0
	if muted:
		target = -80.0

	bgm.volume_db = lerpf(bgm.volume_db, target, minf(1.0, delta * 4.0))
	if not bgm.playing and not muted:
		bgm.play()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		muted = not muted


func zone_color(wy: float) -> Color:
	var h_score = maxf(0.0, (420.0 - wy) / 10.0)
	var t = h_score / ZONE_STEP
	var idx = int(floor(t))
	var c1: Color = zone_cols[idx % zone_cols.size()]
	var c2: Color = zone_cols[(idx + 1) % zone_cols.size()]
	return c1.lerp(c2, smoothstep(0.7, 1.0, t - float(idx)))


func init_ui():
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	menu_bg = ColorRect.new()
	menu_bg.color = BG_COL
	menu_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(menu_bg)
	menu_root.move_child(menu_bg, 0)

	card_panel = Panel.new()
	card_panel.set_anchors_preset(Control.PRESET_CENTER)
	card_panel.offset_left = -260
	card_panel.offset_top = -255
	card_panel.offset_right = 260
	card_panel.offset_bottom = 255
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.10, 0.22, 0.90)
	sb.border_color = Color("#2b6c96")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(0.2, 0.7, 1.0, 0.25)
	sb.shadow_size = 24
	card_panel.add_theme_stylebox_override("panel", sb)

	menu_root.add_child(card_panel)
	menu_root.move_child(card_panel, 1)

	menu_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_vbox.add_theme_constant_override("separation", 15)

	team_lbl = Label.new()
	team_lbl.text = CREDITS
	team_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	team_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	team_lbl.add_theme_font_size_override("font_size", 16)
	team_lbl.add_theme_color_override("font_color", Color("#8aa0d8"))
	if main_font != null:
		team_lbl.add_theme_font_override("font", main_font)
	team_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	menu_root.add_child(team_lbl)
	team_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	team_lbl.offset_top = -52
	team_lbl.offset_bottom = -18


func apply_menu_layout(mode: String):
	card_panel.visible = (mode == "instructions" or mode == "pause")
	team_lbl.visible = (mode == "main")

	if mode == "instructions":
		menu_bg.color = Color(0.02, 0.03, 0.09, 0.35)
		menu_vbox.add_theme_constant_override("separation", 9)
	elif mode == "pause":
		menu_bg.color = Color(0.02, 0.03, 0.08, 0.72)
		menu_vbox.add_theme_constant_override("separation", 15)
	else:
		menu_bg.color = Color(0, 0, 0, 0)
		menu_vbox.add_theme_constant_override("separation", 14)


func wipe_menu():
	for c in menu_vbox.get_children():
		menu_vbox.remove_child(c)
		c.queue_free()


func lbl(txt: String, sz: int, col: Color, stylized: bool = false) -> Label:
	var l = Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if stylized and main_font != null:
		l.add_theme_font_override("font", main_font)
		l.add_theme_constant_override("outline_size", maxi(2, int(float(sz) * 0.10)))
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.12, 0.95))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 4)
	return l


func btn(txt: String, cb: Callable, accent: Color = CYAN) -> Button:
	var b = Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(300, 54)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 22)
	if main_font != null:
		b.add_theme_font_override("font", main_font)
	b.add_theme_color_override("font_color", WHITE)

	var st_norm = StyleBoxFlat.new()
	st_norm.bg_color = Color("#12234a").lerp(accent, 0.14)
	st_norm.border_color = accent
	st_norm.set_border_width_all(2)
	st_norm.set_corner_radius_all(12)
	st_norm.content_margin_left = 20
	st_norm.content_margin_right = 20
	st_norm.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	st_norm.shadow_size = 10

	var st_hov = st_norm.duplicate()
	st_hov.bg_color = Color("#12234a").lerp(accent, 0.34)
	st_hov.border_color = accent.lightened(0.3)
	st_hov.shadow_size = 20
	st_hov.shadow_color = Color(accent.r, accent.g, accent.b, 0.55)

	var st_press = st_norm.duplicate()
	st_press.bg_color = accent.darkened(0.55)
	st_press.shadow_size = 6

	b.add_theme_stylebox_override("normal", st_norm)
	b.add_theme_stylebox_override("hover", st_hov)
	b.add_theme_stylebox_override("pressed", st_press)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	return b


func open_main_menu():
	state = "menu"
	menu_root.visible = true
	menu_bg.color = BG_COL
	wipe_menu()
	apply_menu_layout("main")

	menu_vbox.add_child(lbl("—  NEON COSMOS EDITION  —", 14, PURPLE))
	menu_vbox.add_child(lbl("REBOUND", 96, CYAN, true))
	menu_vbox.add_child(lbl("EVERY FALL IS ANOTHER CHANCE", 15, Color("#aebce9")))
	menu_vbox.add_child(lbl("✦  BEST SCORE: " + str(best_score) + "  ✦", 17, PURPLE))
	menu_vbox.add_child(btn("PLAY", begin_run, CYAN))
	menu_vbox.add_child(btn("HOW TO PLAY", open_help, PURPLE))
	menu_vbox.add_child(lbl("A GAME ABOUT NEVER GIVING UP", 12, Color("#6478a8")))


func open_help():
	state = "instructions"
	wipe_menu()
	apply_menu_layout("instructions")

	menu_vbox.add_child(lbl("HOW TO PLAY", 44, CYAN, true))
	menu_vbox.add_child(lbl("A / LEFT ARROW - MOVE LEFT", 16, WHITE))
	menu_vbox.add_child(lbl("D / RIGHT ARROW - MOVE RIGHT", 16, WHITE))
	menu_vbox.add_child(lbl("BOUNCE AUTOMATICALLY ON PLATFORMS", 14, PURPLE))
	menu_vbox.add_child(lbl("CLIMB AS HIGH AS POSSIBLE", 15, WHITE))
	menu_vbox.add_child(lbl("BOUNCE ON 10 TILES TO CHARGE THE BALL", 14, ULTRA_GLOW))
	menu_vbox.add_child(lbl("W - TURBO JUMP WHEN BALL IS ULTRA BLUE", 14, ULTRA_GLOW))
	menu_vbox.add_child(lbl("ORANGE TILES BREAK AFTER ONE BOUNCE", 14, FRAGILE))
	menu_vbox.add_child(lbl("5 BOUNCES ON THE SAME TILE BREAKS IT", 14, Color("#ffb38a")))
	menu_vbox.add_child(lbl("DON'T FALL - WATCH THE RED DANGER ZONE", 14, DANGER_RED))
	menu_vbox.add_child(lbl("M - MUTE / UNMUTE MUSIC", 14, WHITE))
	menu_vbox.add_child(lbl("ESC - PAUSE THE GAME", 15, CYAN))
	menu_vbox.add_child(btn("BACK TO MENU", open_main_menu, PURPLE))


func begin_run():
	orb_pos = Vector2(480, 420)
	vel = Vector2.ZERO
	cam_y = 270.0
	top_y = 420.0
	score = 0
	bounces = 0

	turbo_pts = 0
	is_charged = false
	turbo_t = 0.0
	prev_w = false
	hit_squash = 0.0
	cam_shake = 0.0
	shake_vec = Vector2.ZERO
	fx.clear()
	trail_pts.clear()

	dead_t = 0.0
	dead_ui_up = false
	state = "playing"
	plats.clear()

	# wide starter pad so the player doesn't immediately drop
	spawn_plat(350, 470, 260, false)

	var y = 390.0
	while y > -350:
		spawn_plat(randf_range(80, 760), y, randf_range(120, 200), randf() < FRAGILE_RATE)
		y -= randf_range(GAP_MIN, GAP_MAX)

	menu_root.visible = false
	queue_redraw()


func spawn_plat(x: float, y: float, w: float, fragile: bool = false):
	plat_seq += 1
	plats.append({
		"id": plat_seq,
		"rect": Rect2(x, y, w, 18),
		"fragile": fragile,
		"flash": 0.0,
		"hits": 0
	})


func open_pause():
	state = "paused"
	menu_root.visible = true
	menu_bg.color = BG_COL
	wipe_menu()
	apply_menu_layout("pause")

	menu_vbox.add_child(lbl("PAUSED", 52, CYAN, true))
	menu_vbox.add_child(lbl("TAKE A BREATHER", 14, Color("#b8c9ec")))
	menu_vbox.add_child(btn("RESUME", func(): state = "playing"; menu_root.visible = false, CYAN))
	menu_vbox.add_child(btn("RESTART", begin_run, PURPLE))
	menu_vbox.add_child(btn("MAIN MENU", open_main_menu, Color("#ff78b5")))


func trigger_death():
	state = "lost"
	if score > best_score:
		best_score = score
		save_best()

	dead_t = 0.0
	dead_ui_up = false
	menu_root.visible = false

	if sfx != null and faah_snd != null:
		sfx.stream = faah_snd
		sfx.volume_db = 0.0
		sfx.play()


func open_death_menu():
	state = "lost"
	menu_root.visible = true
	menu_bg.color = BG_COL
	wipe_menu()
	apply_menu_layout("gameover")

	var pad = Control.new()
	pad.custom_minimum_size = Vector2(0, 160)
	menu_vbox.add_child(pad)

	menu_vbox.add_child(lbl("GAME OVER", 22, Color("#ff78b5"), true))
	menu_vbox.add_child(lbl("FINAL SCORE: " + str(score), 26, WHITE, true))
	menu_vbox.add_child(lbl("BEST SCORE: " + str(best_score), 17, PURPLE))
	menu_vbox.add_child(btn("PLAY AGAIN", begin_run, Color("#ff3b5c")))
	menu_vbox.add_child(btn("MAIN MENU", open_main_menu, CYAN))


func _process(delta):
	if state == "playing":
		if Input.is_action_just_pressed("ui_cancel"):
			open_pause()
			return
		step_game(delta)
	elif state == "paused":
		if Input.is_action_just_pressed("ui_cancel"):
			state = "playing"
			menu_root.visible = false
	elif state == "lost":
		dead_t += delta
		if not dead_ui_up and dead_t >= DEAD_DELAY:
			dead_ui_up = true
			open_death_menu()

	if state != "playing":
		shake_vec = Vector2.ZERO

	tick_audio(delta)
	queue_redraw()


func emit_sparks(pos: Vector2, count: int, col: Color, spd: float):
	for i in range(count):
		var ang = randf() * TAU
		var life = randf_range(0.3, 0.7)
		fx.append({
			"pos": pos,
			"vel": Vector2.from_angle(ang) * randf_range(spd * 0.3, spd),
			"life": life,
			"max": life,
			"size": randf_range(2.0, 4.5),
			"color": col,
			"rot": 0.0,
			"spin": 0.0,
			"shard": false,
			"grav": 200.0
		})


func shatter_plat(p: Dictionary, col: Color = FRAGILE):
	var r: Rect2 = p["rect"]
	var chunks = maxi(4, int(r.size.x / 14.0))
	var cw = r.size.x / float(chunks)

	for i in range(chunks):
		var px = r.position.x + (float(i) + 0.5) * cw
		var life = randf_range(0.7, 1.1)
		fx.append({
			"pos": Vector2(px, r.position.y + 9),
			"vel": Vector2(randf_range(-110.0, 110.0) + (px - orb_pos.x) * 1.2, randf_range(-120.0, 140.0)),
			"life": life,
			"max": life,
			"size": Vector2(cw * 0.9, randf_range(8.0, 16.0)),
			"color": col,
			"rot": randf() * TAU,
			"spin": randf_range(-9.0, 9.0),
			"shard": true,
			"grav": 1400.0
		})

	emit_sparks(Vector2(orb_pos.x, r.position.y), 14, col.lightened(0.5), 320.0)
	cam_shake = maxf(cam_shake, 3.0)


func on_plat_bounce(idx: int):
	var p: Dictionary = plats[idx]
	var r: Rect2 = p["rect"]
	hit_squash = 1.0

	var pid: int = p["id"]
	for q in plats:
		if q["id"] != pid:
			q["hits"] = 0
	p["hits"] += 1

	var zcol = zone_color(r.position.y)
	emit_sparks(Vector2(orb_pos.x, r.position.y), 8, FRAGILE if p["fragile"] else zcol, 230.0)

	if not is_charged:
		turbo_pts += 1
		if turbo_pts >= CHARGE_REQ:
			is_charged = true
			emit_sparks(orb_pos, 36, ULTRA_GLOW, 420.0)
			cam_shake = maxf(cam_shake, 4.0)

	if p["fragile"]:
		shatter_plat(p)
		plats.remove_at(idx)
	elif p["hits"] >= CAMP_LIMIT:
		shatter_plat(p, zcol)
		plats.remove_at(idx)
	else:
		p["flash"] = 1.0


func fire_turbo():
	vel.y = -TURBO_VEL
	is_charged = false
	turbo_pts = 0
	turbo_t = 1.1
	cam_shake = 8.0
	hit_squash = 0.0
	emit_sparks(orb_pos, 45, ULTRA_GLOW, 520.0)


func step_fx(delta):
	turbo_t = maxf(0.0, turbo_t - delta)
	hit_squash = maxf(0.0, hit_squash - delta * 5.0)
	cam_shake = maxf(0.0, cam_shake - delta * 30.0)
	shake_vec = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * cam_shake

	trail_pts.push_front(orb_pos)
	if trail_pts.size() > 28:
		trail_pts.pop_back()

	for p in plats:
		p["flash"] = maxf(0.0, p["flash"] - delta * 4.0)

	for i in range(fx.size() - 1, -1, -1):
		var pt: Dictionary = fx[i]
		pt["life"] -= delta
		if pt["life"] <= 0.0:
			fx.remove_at(i)
			continue
		var v: Vector2 = pt["vel"]
		v.y += pt["grav"] * delta
		pt["vel"] = v
		pt["pos"] += v * delta
		pt["rot"] += pt["spin"] * delta


func step_game(delta):
	var move = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move += 1.0
	orb_pos.x += move * SPD * delta

	var w_now = Input.is_key_pressed(KEY_W)
	if w_now and not prev_w and is_charged:
		fire_turbo()
	prev_w = w_now

	if orb_pos.x < -20:
		orb_pos.x = W + 20
	elif orb_pos.x > W + 20:
		orb_pos.x = -20

	var last_y = orb_pos.y
	vel.y += GRAV * delta
	orb_pos.y += vel.y * delta

	# swept check using 17px orb radius so high fall speeds don't tunnel through tiles
	if vel.y > 0:
		var landed = -1
		for i in range(plats.size()):
			var pr: Rect2 = plats[i]["rect"]
			if (
				last_y + 17 <= pr.position.y
				and orb_pos.y + 17 >= pr.position.y
				and orb_pos.x + 15 > pr.position.x
				and orb_pos.x - 15 < pr.end.x
			):
				orb_pos.y = pr.position.y - 17
				bounces += 1
				vel.y = -(JUMP_VEL + minf(float(bounces) * 3.0, 120.0))
				landed = i
				break
		if landed != -1:
			on_plat_bounce(landed)

	if orb_pos.y - 180 < cam_y:
		cam_y = orb_pos.y - 180

	if orb_pos.y < top_y:
		top_y = orb_pos.y
		score = int((420 - top_y) / 10.0)

	var highest_plat = 1000000.0
	for p in plats:
		highest_plat = minf(highest_plat, p["rect"].position.y)

	while highest_plat > cam_y - 650:
		highest_plat -= randf_range(GAP_MIN, GAP_MAX)
		spawn_plat(randf_range(35, 790), highest_plat, randf_range(110, 190), randf() < FRAGILE_RATE)

	for i in range(plats.size() - 1, -1, -1):
		if plats[i]["rect"].position.y > cam_y + 650:
			plats.remove_at(i)

	step_fx(delta)

	if orb_pos.y > cam_y + H + 30:
		trigger_death()


func render_bg():
	if bg_tex != null:
		draw_texture_rect(bg_tex, Rect2(0, 0, W, H), false, Color.WHITE)
		draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.04, 0.12, 0.24))
	else:
		draw_rect(Rect2(0, 0, W, H), BG_COL)

	var ms = Time.get_ticks_msec()
	for i in range(120):
		var sx = fposmod(float(i * 137 + 31), W)
		var sy = fposmod(fposmod(float(i * 83 + 19), 1000.0) - cam_y * 0.25, H)
		draw_circle(Vector2(sx, sy), 1.3, Color(0.55, 0.75, 1.0, 0.35 + 0.25 * sin(ms * 0.002 + i)))


func render_plat_box(r: Rect2, edge: Color, alpha: float):
	for g in range(3):
		var e = 3.0 + float(g) * 4.0
		draw_rect(
			Rect2(r.position - Vector2(e, e), r.size + Vector2(e * 2.0, e * 2.0)),
			Color(edge.r, edge.g, edge.b, (0.14 - float(g) * 0.04) * alpha)
		)

	var body = Color("#172449").lerp(edge, 0.12)
	draw_rect(r, Color(body.r, body.g, body.b, alpha))
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 3), Color(edge.r, edge.g, edge.b, alpha))
	var hi = edge.lightened(0.25)
	draw_rect(r, Color(hi.r, hi.g, hi.b, alpha), false, 2.0)


func render_menu_bg():
	var t = Time.get_ticks_msec() * 0.001

	for i in range(10):
		var f = float(i) / 9.0
		draw_rect(Rect2(0, float(i) * H / 10.0, W, H / 10.0 + 1.0), Color(0.35 * f, 0.12 * f, 0.55 * f, 0.20 * f))

	var pc = Vector2(845, 135) + Vector2(0, sin(t * 0.5) * 6.0)
	draw_circle(pc, 128, Color(0.55, 0.35, 1.0, 0.05))
	draw_circle(pc, 108, Color(0.55, 0.35, 1.0, 0.08))
	draw_circle(pc, 84, Color("#1b1f55"))
	draw_circle(pc + Vector2(-10, -8), 77, Color("#262c75"))
	draw_circle(pc + Vector2(-24, 12), 13, Color("#1d2260"))
	draw_circle(pc + Vector2(20, -22), 9, Color("#1d2260"))
	draw_circle(pc + Vector2(24, 26), 6, Color("#1d2260"))
	draw_arc(pc, 84, 0.0, TAU, 80, Color(0.55, 0.5, 1.0, 0.55), 2.0)

	for i in range(8):
		var spd = 14.0 + float(i % 3) * 9.0
		var pw = 100.0 + float((i * 37) % 70)
		var px = fposmod(float(i * 131 + 40), W - 120.0)
		var py = fposmod(float(i * 83 + 500) - t * spd, 620.0) - 40.0
		render_plat_box(Rect2(px, py, pw, 16), zone_cols[i % zone_cols.size()], 0.45)

	# live demo orb bouncing on the left pad
	render_plat_box(Rect2(55, 430, 150, 16), CYAN, 1.0)
	for k in range(6, 0, -1):
		var ty = 413.0 - absf(sin((t - float(k) * 0.025) * 2.6)) * 190.0
		draw_circle(Vector2(130, ty), 16.0 - float(k) * 1.5, Color(0.2, 0.8, 1.0, 0.22 - float(k) * 0.03))

	var demo_y = 413.0 - absf(sin(t * 2.6)) * 190.0
	var cyc = fposmod(t, 8.0)
	var floor_prox = clampf(1.0 - (413.0 - demo_y) / 24.0, 0.0, 1.0)
	render_orb(
		Vector2(130, demo_y),
		1.0 + floor_prox * 0.22,
		1.0 - floor_prox * 0.22,
		clampf(cyc / 5.0, 0.0, 1.0),
		cyc > 5.0,
		0.0,
		floor_prox * 0.8
	)

	if state == "menu":
		draw_line(Vector2(280, 486), Vector2(680, 486), Color(0.2, 0.75, 1.0, 0.35), 1.5)


func render_plats():
	var ms = Time.get_ticks_msec()
	for p in plats:
		var wr: Rect2 = p["rect"]
		var sr = Rect2(wr.position.x + shake_vec.x, wr.position.y - cam_y + shake_vec.y, wr.size.x, wr.size.y)
		if sr.end.y < 0 or sr.position.y > H:
			continue

		var fragile: bool = p["fragile"]
		var flash: float = p["flash"]
		var edge = FRAGILE if fragile else zone_color(wr.position.y)
		var pulse = 0.75 + 0.25 * sin(ms * 0.004 + wr.position.x * 0.05)

		for g in range(4):
			var e = 3.0 + float(g) * 4.0
			var a = (0.16 - float(g) * 0.035) * pulse + flash * 0.10
			draw_rect(Rect2(sr.position - Vector2(e, e), sr.size + Vector2(e * 2.0, e * 2.0)), Color(edge.r, edge.g, edge.b, a))

		draw_rect(sr, Color("#2b1a33") if fragile else Color("#172449").lerp(edge, 0.12))
		draw_rect(Rect2(sr.position.x, sr.position.y, sr.size.x, 4), edge.lightened(flash * 0.6))
		draw_rect(sr, edge.lightened(0.25 + flash * 0.5), false, 2.5)
		draw_rect(Rect2(sr.position.x + 12, sr.position.y + 9, 20, 2), Color("#a66cff"))

		if fragile:
			var top = sr.position.y + 4
			for k in range(3):
				var cx = sr.position.x + sr.size.x * (0.25 + 0.25 * float(k))
				draw_line(Vector2(cx, top), Vector2(cx + 6, top + 6), edge, 1.5)
				draw_line(Vector2(cx + 6, top + 6), Vector2(cx + 1, top + 10), edge, 1.5)
				draw_line(Vector2(cx + 1, top + 10), Vector2(cx + 7, top + 14), edge, 1.5)
		else:
			var hits: int = p["hits"]
			if hits >= 2:
				var c_col = Color(1.0, 0.5, 0.3, 0.95) if hits >= CAMP_LIMIT - 1 else Color(1, 1, 1, 0.85)
				var c_top = sr.position.y + 4
				for k in range(hits - 1):
					var cx2 = sr.position.x + sr.size.x * (0.30 + 0.20 * float(k))
					draw_line(Vector2(cx2, c_top), Vector2(cx2 + 6, c_top + 6), c_col, 1.5)
					draw_line(Vector2(cx2 + 6, c_top + 6), Vector2(cx2 + 1, c_top + 10), c_col, 1.5)
					draw_line(Vector2(cx2 + 1, c_top + 10), Vector2(cx2 + 7, c_top + 14), c_col, 1.5)


func render_fx():
	for pt in fx:
		var t: float = pt["life"] / pt["max"]
		var c: Color = pt["color"]
		c.a = minf(1.0, t * 2.0)

		var wp: Vector2 = pt["pos"]
		var sp = Vector2(wp.x, wp.y - cam_y) + shake_vec

		if pt["shard"]:
			var sz: Vector2 = pt["size"]
			draw_set_transform(sp, pt["rot"], Vector2.ONE)
			draw_rect(Rect2(-sz.x * 0.5, -sz.y * 0.5, sz.x, sz.y), Color(c.r * 0.35, c.g * 0.25, c.b * 0.3, c.a))
			draw_rect(Rect2(-sz.x * 0.5, -sz.y * 0.5, sz.x, sz.y), c, false, 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var r: float = pt["size"]
			draw_circle(sp, r * 2.2 * t, Color(c.r, c.g, c.b, c.a * 0.25))
			draw_circle(sp, r * t + 0.5, c)


func render_trail():
	var n = trail_pts.size()
	if n < 2:
		return

	var boosting = turbo_t > 0.0
	var col = ULTRA if (is_charged or boosting) else CYAN

	for i in range(n):
		var t = 1.0 - float(i) / float(n)
		var wp: Vector2 = trail_pts[i]
		var sp = Vector2(wp.x, wp.y - cam_y) + shake_vec

		var alpha = t * (0.65 if boosting else 0.30)
		var rad = (24.0 if boosting else 16.0) * t
		var core_a = t * (0.55 if boosting else 0.18)

		draw_circle(sp, rad * 1.5, Color(col.r, col.g, col.b, alpha * 0.35))
		draw_circle(sp, rad, Color(col.r, col.g, col.b, alpha))
		draw_circle(sp, rad * 0.45, Color(1, 1, 1, core_a))


func noise01(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0)


func render_orb(pos: Vector2, sx: float, sy: float, ratio: float, charged_flag: bool, turbo_left: float, sq: float):
	var tsec = Time.get_ticks_msec() * 0.001
	var time = tsec * 5.0
	var pulse = 1.0 + sin(time) * 0.06

	var glow_col = Color(0.05, 0.75, 1.0).lerp(ULTRA, ratio * 0.5)
	var rim = Color("#9af3ff").lerp(ULTRA_GLOW, ratio * 0.5)
	var body_out = Color("#0070c8").lerp(Color("#1a3fd0"), ratio * 0.6)
	var body_mid = CYAN.lerp(Color("#4f8dff"), ratio * 0.5)
	var core_col = Color("#e8feff")
	var ring_a = CYAN
	var ring_b = PURPLE
	var bloom = 1.0

	if charged_flag:
		pulse = 1.0 + sin(time * 3.0) * 0.10
		glow_col = ULTRA
		rim = Color("#cfe4ff")
		body_out = Color("#0f2fb8")
		body_mid = ULTRA
		core_col = Color("#ffffff")
		ring_a = ULTRA_GLOW
		ring_b = WHITE
		bloom = 1.7

	draw_set_transform(pos, 0.0, Vector2(sx, sy))

	for i in range(9):
		draw_circle(Vector2.ZERO, (70.0 - float(i) * 5.5) * pulse, Color(glow_col.r, glow_col.g, glow_col.b, (0.012 + float(i) * 0.006) * bloom))

	if charged_flag:
		for i in range(4):
			draw_circle(Vector2.ZERO, (96.0 - float(i) * 6.0) * pulse, Color(glow_col.r, glow_col.g, glow_col.b, 0.02 + float(i) * 0.01))

	if turbo_left > 0.0:
		var inten = clampf(turbo_left / 1.1, 0.0, 1.0)
		draw_colored_polygon(
			PackedVector2Array([Vector2(-15, 8), Vector2(15, 8), Vector2(0, 8.0 + 120.0 * inten)]),
			Color(ULTRA_GLOW.r, ULTRA_GLOW.g, ULTRA_GLOW.b, 0.35 * inten)
		)
		draw_colored_polygon(
			PackedVector2Array([Vector2(-7, 8), Vector2(7, 8), Vector2(0, 8.0 + 70.0 * inten)]),
			Color(1, 1, 1, 0.55 * inten)
		)

	if sq > 0.05:
		draw_arc(Vector2.ZERO, 20.0 + (1.0 - sq) * 38.0, 0.0, TAU, 48, Color(rim.r, rim.g, rim.b, sq * 0.45), 2.0)

	if charged_flag:
		var ph = fposmod(tsec * 1.2, 1.0)
		draw_arc(Vector2.ZERO, 30.0 + ph * 45.0, 0.0, TAU, 64, Color(glow_col.r, glow_col.g, glow_col.b, (1.0 - ph) * 0.5), 2.5)
	else:
		var filled = int(round(ratio * float(CHARGE_REQ)))
		var seg = TAU / float(CHARGE_REQ)
		for i in range(CHARGE_REQ):
			var a0 = -PI * 0.5 + float(i) * seg + 0.09
			var a1 = a0 + seg - 0.18
			if i < filled:
				draw_arc(Vector2.ZERO, 34.0, a0, a1, 8, Color(ULTRA_GLOW.r, ULTRA_GLOW.g, ULTRA_GLOW.b, 0.25), 6.0)
				draw_arc(Vector2.ZERO, 34.0, a0, a1, 8, Color(ULTRA_GLOW.r, ULTRA_GLOW.g, ULTRA_GLOW.b, 0.95), 3.0)
			else:
				draw_arc(Vector2.ZERO, 34.0, a0, a1, 8, Color(0.4, 0.55, 0.9, 0.18), 2.0)

	draw_arc(Vector2.ZERO, 26.0 * pulse, 0.0, TAU, 64, Color(ring_a.r, ring_a.g, ring_a.b, 0.15), 1.5)
	draw_arc(Vector2.ZERO, 26.0 * pulse, time, time + PI * 1.65, 64, ring_a, 2.5)
	draw_arc(Vector2.ZERO, 22.0 * pulse, -time * 1.3, -time * 1.3 + PI * 1.5, 64, ring_b, 1.8)

	if charged_flag:
		var step = floor(tsec * 16.0)
		for b in range(6):
			var base_a = time * 0.5 + float(b) * TAU / 6.0
			var pts = PackedVector2Array()
			for s in range(5):
				var f = float(s) / 4.0
				var jit = 0.0 if s == 0 else (noise01(float(b) * 7.13 + float(s) * 3.7 + step * 1.91) - 0.5) * 0.55
				pts.append(Vector2.from_angle(base_a + jit) * lerpf(23.0, 46.0, f))
			draw_polyline(pts, Color(ULTRA_GLOW.r, ULTRA_GLOW.g, ULTRA_GLOW.b, 0.9), 2.2)
			draw_polyline(pts, Color(1, 1, 1, 0.85), 0.9)

	draw_circle(Vector2.ZERO, 20.0 * pulse, Color(rim.r, rim.g, rim.b, 0.35))
	for i in range(6):
		draw_circle(Vector2.ZERO, (18.0 - float(i) * 2.2) * pulse, body_out.lerp(body_mid, float(i) / 5.0))

	draw_circle(Vector2.ZERO, 8.0 * pulse, core_col)
	draw_circle(Vector2.ZERO, 5.0 * pulse, Color(1, 1, 1, 0.9))

	var rim_a = (0.75 + 0.25 * sin(time * 4.0)) if charged_flag else 0.9
	draw_arc(Vector2.ZERO, 17.5 * pulse, 0.0, TAU, 64, Color(rim.r, rim.g, rim.b, rim_a), 2.5)
	for g in range(3):
		draw_arc(Vector2.ZERO, (19.5 + float(g) * 2.0) * pulse, 0.0, TAU, 64, Color(rim.r, rim.g, rim.b, 0.28 - float(g) * 0.08), 2.0)

	draw_arc(Vector2.ZERO, 17.5 * pulse, time * 0.8, time * 0.8 + PI * 0.5, 24, Color(1, 1, 1, 0.95), 3.5)
	draw_arc(Vector2.ZERO, 17.5 * pulse, time * 0.8 + PI, time * 0.8 + PI * 1.25, 16, Color(1, 1, 1, 0.5), 2.5)

	draw_arc(Vector2.ZERO, 12.0, PI * 1.05, PI * 1.45, 16, Color(1, 1, 1, 0.55), 3.0)
	draw_circle(Vector2(-6, -7), 4, WHITE)
	draw_circle(Vector2(5, 6), 2, Color(1, 1, 1, 0.45))

	for k in range(3):
		var sp = Vector2.from_angle(time * (1.2 + float(k) * 0.5) + float(k) * 2.1) * (31.0 + float(k) * 3.0)
		draw_circle(sp, 3.2, Color(ring_a.r, ring_a.g, ring_a.b, 0.25))
		draw_circle(sp, 1.6, WHITE)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func render_danger():
	if state != "playing":
		return

	var sy = orb_pos.y - cam_y
	var lvl = clampf((sy - (H - DANGER_Y)) / DANGER_Y, 0.0, 1.0)
	if lvl <= 0.0:
		return

	var blink = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.015 * (1.0 + lvl * 1.5))
	var a = lvl * (0.25 + 0.35 * blink)

	for i in range(6):
		var thick = 14.0 + float(i) * 18.0
		var col = Color(DANGER_RED.r, DANGER_RED.g, DANGER_RED.b, a * 0.22 * (1.0 - float(i) / 6.0))
		draw_rect(Rect2(0, 0, thick, H), col)
		draw_rect(Rect2(W - thick, 0, thick, H), col)
		draw_rect(Rect2(0, H - thick * 1.6, W, thick * 1.6), col)

	if lvl > 0.25:
		var fnt = ThemeDB.fallback_font
		var ta = 0.55 + 0.45 * blink
		var tcol = Color(DANGER_RED.r, DANGER_RED.g, DANGER_RED.b, ta)
		draw_string(fnt, Vector2(0, 112), "DANGER!", HORIZONTAL_ALIGNMENT_CENTER, W, 34, tcol)

		for side in [-1.0, 1.0]:
			var cx = W * 0.5 + side * 135.0
			draw_colored_polygon(PackedVector2Array([Vector2(cx, 84), Vector2(cx - 19, 118), Vector2(cx + 19, 118)]), tcol)
			draw_string(fnt, Vector2(cx - 20, 113), "!", HORIZONTAL_ALIGNMENT_CENTER, 40, 22, Color(1, 1, 1, ta))


func render_wasted():
	if state != "lost":
		return

	var k = clampf(dead_t / 0.8, 0.0, 1.0)
	draw_rect(Rect2(0, 0, W, H), Color(0.50, 0.52, 0.56, 0.42 * k))
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.02, 0.05, 0.50 * k))

	for i in range(6):
		var thick = 20.0 + float(i) * 26.0
		var col = Color(0, 0, 0, 0.10 * k)
		draw_rect(Rect2(0, 0, thick, H), col)
		draw_rect(Rect2(W - thick, 0, thick, H), col)

	var bar = 54.0 * clampf(dead_t / 0.6, 0.0, 1.0)
	draw_rect(Rect2(0, 0, W, bar), Color.BLACK)
	draw_rect(Rect2(0, H - bar, W, bar), Color.BLACK)

	var ta = clampf((dead_t - 0.25) / 0.5, 0.0, 1.0)
	if ta <= 0.0:
		return

	var sc = 1.0 + 0.5 * (1.0 - ta) * (1.0 - ta)
	var fnt: Font = main_font if main_font != null else ThemeDB.fallback_font

	draw_set_transform(Vector2(W * 0.5, 200.0), 0.0, Vector2(sc, sc))
	var left = -W * 0.5
	draw_string(fnt, Vector2(left + 6, 6), "WASTED", HORIZONTAL_ALIGNMENT_CENTER, W, 130, Color(0, 0, 0, 0.7 * ta))
	draw_string_outline(fnt, Vector2(left, 0), "WASTED", HORIZONTAL_ALIGNMENT_CENTER, W, 130, 14, Color(0, 0, 0, ta))
	draw_string(fnt, Vector2(left, 0), "WASTED", HORIZONTAL_ALIGNMENT_CENTER, W, 130, Color(WASTED_RED.r, WASTED_RED.g, WASTED_RED.b, ta))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func render_hud():
	if state != "playing" and state != "paused":
		return

	draw_rect(Rect2(0, 0, W, 65), Color("#10182f"))
	draw_rect(Rect2(0, 63, W, 2), Color(0.2, 0.75, 1.0, 0.5))

	var fnt = ThemeDB.fallback_font
	draw_string(fnt, Vector2(25, 40), "REBOUND", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, CYAN)
	draw_string(fnt, Vector2(400, 40), "SCORE: " + str(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, WHITE)
	draw_string(fnt, Vector2(700, 40), "BOUNCES: " + str(bounces), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, PURPLE)

	var bx = 330.0
	var by = 508.0
	var bw = 300.0
	var bh = 12.0
	var fill = 1.0 if is_charged else float(turbo_pts) / float(CHARGE_REQ)

	draw_rect(Rect2(bx, by, bw, bh), Color(0.05, 0.1, 0.25, 0.85))
	draw_rect(Rect2(bx, by, bw * fill, bh), ULTRA if is_charged else CYAN)
	draw_rect(Rect2(bx, by, bw, bh), ULTRA_GLOW if is_charged else Color("#245477"), false, 2.0)

	if is_charged:
		var blink = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
		draw_string(fnt, Vector2(bx, by - 8), "PRESS W - TURBO READY!", HORIZONTAL_ALIGNMENT_CENTER, bw, 18, Color(ULTRA_GLOW.r, ULTRA_GLOW.g, ULTRA_GLOW.b, blink))
	else:
		draw_string(fnt, Vector2(bx, by - 8), "TURBO  " + str(turbo_pts) + "/" + str(CHARGE_REQ), HORIZONTAL_ALIGNMENT_CENTER, bw, 15, Color("#8aa4d6"))


func _draw():
	render_bg()

	if state == "menu" or state == "instructions":
		render_menu_bg()

	if state == "playing" or state == "paused" or state == "lost":
		render_plats()
		render_fx()
		render_trail()
		var sp = Vector2(orb_pos.x, orb_pos.y - cam_y) + shake_vec
		var stretch = clampf(absf(vel.y) / 2600.0, 0.0, 0.22) + (0.12 * minf(1.0, turbo_t / 0.5) if turbo_t > 0.0 else 0.0)
		render_orb(
			sp,
			1.0 - stretch * 0.5 + hit_squash * 0.30,
			1.0 + stretch - hit_squash * 0.30,
			float(turbo_pts) / float(CHARGE_REQ),
			is_charged,
			turbo_t,
			hit_squash
		)

	render_danger()
	render_hud()
	render_wasted()
