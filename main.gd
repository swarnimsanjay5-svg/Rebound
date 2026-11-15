extends Node2D

# ==================================================
# REBOUND
# NEON COSMOS EDITION
# Godot 4
# ==================================================

const SCREEN_W = 960.0
const SCREEN_H = 540.0

# Gameplay
const GRAVITY = 1200.0
const MOVE_SPEED = 380.0
const BOUNCE_POWER = 680.0

const PLATFORM_GAP_MIN = 85.0
const PLATFORM_GAP_MAX = 115.0

# Turbo system (yahan se tweak kar sakte ho)
const TURBO_BOUNCES_NEEDED = 10   # kitne tiles ke baad charge hoga
const TURBO_POWER = 1500.0        # ultra jump ki power
const BREAK_CHANCE = 0.25         # kitne % tiles toot-te hain (1.0 = sab)

# Ek hi normal tile pe lagataar itni bounce ke baad tile toot jaayegi
const MAX_SAME_TILE_BOUNCES = 5

# Tile colour zones
const TILE_COLOR_ZONE = 60.0      # kitne score par tile ka colour badlega

# Danger UI
const DANGER_START = 190.0        # screen ke neeche se kitne pixel upar se danger shuru

# WASTED screen: kitne second baad buttons dikhein
const WASTED_MENU_DELAY = 2.0

const CREDITS_TEXT = "CREATED BY TEAM XP HUNTERS   •   HACK CLUB HAVEN"

# Music files (inme se jo pehli mile wahi baje)
const MUSIC_PATHS = [
	"res://assets/dance_monkey.mp3",
	"res://assets/dance_monkey.ogg",
	"res://assets/dance_monkey.wav",
	"res://assets/music.mp3",
	"res://assets/music.ogg"
]

# Faah sound (haarne par)
const FAAH_PATHS = [
	"res://assets/faah.mp3",
	"res://assets/faah.ogg",
	"res://assets/faah.wav"
]

# Title font (optional, bohot better lagta hai)
const FONT_PATHS = [
	"res://assets/title_font.ttf",
	"res://assets/title_font.otf",
	"res://assets/fonts/title_font.ttf"
]

# Colors
const SPACE_COLOR = Color("#080d20")
const CYAN = Color("#36cfff")
const PURPLE = Color("#a66cff")
const WHITE = Color("#eafaff")
const ULTRA = Color("#2f6bff")
const ULTRA_GLOW = Color("#8fc4ff")
const FRAGILE = Color("#ff7a59")
const DANGER_RED = Color("#ff2a4d")
const WASTED_RED = Color("#d11a2a")

# Tile colours jo upar jaate jaate badalte hain
var tile_palette: Array = [
	Color("#36cfff"),
	Color("#3dff9e"),
	Color("#ffe94d"),
	Color("#ff4fd8"),
	Color("#a66cff")
]

# Player
var player_pos = Vector2(480, 420)
var velocity = Vector2.ZERO

# World
var platforms: Array[Dictionary] = []
var next_platform_id = 0

var camera_y = 270.0
var highest_y = 420.0

# Scores
var score = 0
var bounce_count = 0
var high_score = 0

# Turbo / charge
var charge_bounces = 0
var charged = false
var turbo_timer = 0.0
var w_was_down = false

# Effects
var particles: Array = []
var trail: Array = []
var squash = 0.0
var shake = 0.0
var shake_offset = Vector2.ZERO

# Music + sound
var music_player: AudioStreamPlayer
var music_muted = false
var sfx_player: AudioStreamPlayer
var faah_stream: AudioStream

# Wasted screen
var wasted_timer = 0.0
var wasted_menu_shown = false

# Game state
var game_state = "menu"

# Graphics
var background_texture: Texture2D
var menu_background: ColorRect
var title_font: Font

# UI (ab code se automatically ban jayenge)
var game_ui: CanvasLayer
var menu_layer: Control
var main_menu: VBoxContainer
var menu_card: Panel
var credits_label: Label


# ==================================================
# INITIALIZATION
# ==================================================

func build_ui_nodes():

	# Agar scene mein nodes pehle se hain toh wahi use karo
	if has_node("GameUI/MenuLayer/MainMenu"):

		game_ui = get_node("GameUI")
		menu_layer = get_node("GameUI/MenuLayer")
		main_menu = get_node("GameUI/MenuLayer/MainMenu")

		return

	# Warna khud bana lo
	game_ui = CanvasLayer.new()
	game_ui.name = "GameUI"
	add_child(game_ui)

	menu_layer = Control.new()
	menu_layer.name = "MenuLayer"
	game_ui.add_child(menu_layer)

	main_menu = VBoxContainer.new()
	main_menu.name = "MainMenu"
	menu_layer.add_child(main_menu)


func _ready():

	randomize()

	build_ui_nodes()

	load_high_score()

	# Optional background image
	if ResourceLoader.exists("res://assets/space_background.png"):

		background_texture = load(
			"res://assets/space_background.png"
		)

	setup_fonts()

	create_ui()

	setup_music()

	setup_sfx()

	show_main_menu()


func load_high_score():

	var config = ConfigFile.new()

	if config.load("user://rebound.cfg") == OK:

		high_score = config.get_value(
			"scores",
			"best",
			0
		)


func save_high_score():

	var config = ConfigFile.new()

	config.set_value(
		"scores",
		"best",
		high_score
	)

	config.save("user://rebound.cfg")


# ==================================================
# FONTS
# ==================================================

func setup_fonts():

	# Pehle apni font file dhundo (assets/title_font.ttf)
	for path in FONT_PATHS:

		if ResourceLoader.exists(path):

			title_font = load(path)

			return

	# Nahi mili toh system ke bold fonts try karo
	var sf = SystemFont.new()

	sf.font_names = PackedStringArray([
		"Pricedown",
		"Impact",
		"Haettenschweiler",
		"Arial Black",
		"Bahnschrift",
		"Anton"
	])

	sf.font_weight = 800

	title_font = sf


# ==================================================
# MUSIC + SOUND EFFECTS
# ==================================================

func setup_music():

	music_player = AudioStreamPlayer.new()

	add_child(music_player)

	for path in MUSIC_PATHS:

		if ResourceLoader.exists(path):

			var stream = load(path)

			# Loop on (mp3 / ogg best chalte hain)
			if stream is AudioStreamWAV:

				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

			else:

				stream.set("loop", true)

			music_player.stream = stream

			music_player.volume_db = -12.0

			music_player.play()

			break


func setup_sfx():

	sfx_player = AudioStreamPlayer.new()

	add_child(sfx_player)

	for path in FAAH_PATHS:

		if ResourceLoader.exists(path):

			faah_stream = load(path)

			break

	# Agar faah file nahi mili toh khud ek girti hui awaaz bana lo
	if faah_stream == null:

		faah_stream = make_fallback_faah()


func make_fallback_faah() -> AudioStreamWAV:

	var rate = 22050

	var length = 0.9

	var n = int(float(rate) * length)

	var data = PackedByteArray()

	data.resize(n * 2)

	var phase = 0.0

	for i in range(n):

		var t = float(i) / float(rate)

		var k = t / length

		# Girti hui pitch + halka vibrato
		var freq = lerpf(330.0, 150.0, k) * (1.0 + 0.02 * sin(t * 40.0))

		phase += TAU * freq / float(rate)

		var s = (
			sin(phase) * 0.6
			+ sin(phase * 2.0) * 0.3
			+ sin(phase * 3.0) * 0.2
			+ sin(phase * 5.0) * 0.1
		)

		var env = minf(1.0, t / 0.04) * clampf((length - t) / 0.3, 0.0, 1.0)

		var v = int(clampf(s * env * 0.45, -1.0, 1.0) * 32767.0)

		data.encode_s16(i * 2, v)

	var wav = AudioStreamWAV.new()

	wav.format = AudioStreamWAV.FORMAT_16_BITS

	wav.mix_rate = rate

	wav.stereo = false

	wav.data = data

	return wav


func play_faah():

	if sfx_player == null or faah_stream == null:
		return

	sfx_player.stream = faah_stream

	sfx_player.volume_db = 0.0

	sfx_player.play()


func update_music(delta):

	if music_player == null or music_player.stream == null:
		return

	var target_db = -12.0

	if game_state == "playing":
		target_db = -4.0

	# Haarne par music dheema, taaki faah saaf sunai de
	if game_state == "lost" and wasted_timer < 3.0:
		target_db = -26.0

	if music_muted:
		target_db = -80.0

	music_player.volume_db = lerpf(
		music_player.volume_db,
		target_db,
		minf(1.0, delta * 4.0)
	)

	# Agar track khatam hoke ruk gaya toh dobara chalao
	if not music_player.playing and not music_muted:
		music_player.play()


func _unhandled_input(event):

	# M dabao = music mute / unmute
	if event is InputEventKey and event.pressed and not event.echo:

		if event.keycode == KEY_M:

			music_muted = not music_muted


# ==================================================
# TILE COLOUR (HEIGHT KE HISAAB SE)
# ==================================================

func get_tile_color(world_y: float) -> Color:

	var height_score = maxf(0.0, (420.0 - world_y) / 10.0)

	var t = height_score / TILE_COLOR_ZONE

	var i = int(floor(t))

	var f = t - float(i)

	var c1: Color = tile_palette[i % tile_palette.size()]

	var c2: Color = tile_palette[(i + 1) % tile_palette.size()]

	return c1.lerp(c2, smoothstep(0.7, 1.0, f))


# ==================================================
# UI DESIGN
# ==================================================

func create_ui():

	menu_layer.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	# Background
	menu_background = ColorRect.new()

	menu_background.color = SPACE_COLOR

	menu_background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	menu_layer.add_child(menu_background)

	menu_layer.move_child(menu_background, 0)

	# Menu card
	menu_card = Panel.new()

	menu_card.set_anchors_preset(
		Control.PRESET_CENTER
	)

	menu_card.offset_left = -260
	menu_card.offset_top = -255
	menu_card.offset_right = 260
	menu_card.offset_bottom = 255

	menu_card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var card_style = StyleBoxFlat.new()

	card_style.bg_color = Color(0.06, 0.10, 0.22, 0.90)
	card_style.border_color = Color("#2b6c96")

	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(22)

	card_style.shadow_color = Color(0.2, 0.7, 1.0, 0.25)
	card_style.shadow_size = 24

	menu_card.add_theme_stylebox_override(
		"panel",
		card_style
	)

	menu_layer.add_child(menu_card)

	menu_layer.move_child(menu_card, 1)

	# Menu container
	main_menu.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	main_menu.alignment = BoxContainer.ALIGNMENT_CENTER

	main_menu.add_theme_constant_override(
		"separation",
		15
	)

	# Credits (welcome screen ke bottom mein)
	credits_label = Label.new()

	credits_label.text = CREDITS_TEXT

	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	credits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	credits_label.add_theme_font_size_override("font_size", 16)

	credits_label.add_theme_color_override("font_color", Color("#8aa0d8"))

	if title_font != null:
		credits_label.add_theme_font_override("font", title_font)

	credits_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	menu_layer.add_child(credits_label)

	credits_label.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_WIDE
	)

	credits_label.offset_top = -52
	credits_label.offset_bottom = -18


func set_menu_mode(mode: String):

	# Har screen ka apna look
	menu_card.visible = (mode == "instructions" or mode == "pause")

	credits_label.visible = (mode == "main")

	if mode == "main":

		menu_background.color = Color(0, 0, 0, 0)

		main_menu.add_theme_constant_override("separation", 14)

	elif mode == "instructions":

		menu_background.color = Color(0.02, 0.03, 0.09, 0.35)

		main_menu.add_theme_constant_override("separation", 9)

	elif mode == "pause":

		menu_background.color = Color(0.02, 0.03, 0.08, 0.72)

		main_menu.add_theme_constant_override("separation", 15)

	else:

		menu_background.color = Color(0, 0, 0, 0)

		main_menu.add_theme_constant_override("separation", 14)


# ==================================================
# REUSABLE UI COMPONENTS
# ==================================================

func clear_menu():

	for child in main_menu.get_children():

		main_menu.remove_child(child)

		child.queue_free()


func make_label(
	text_value: String,
	font_size: int,
	color: Color,
	use_title_font: bool = false
) -> Label:

	var label = Label.new()

	label.text = text_value

	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	label.add_theme_font_size_override(
		"font_size",
		font_size
	)

	label.add_theme_color_override(
		"font_color",
		color
	)

	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Premium title look: alag font + outline + shadow
	if use_title_font and title_font != null:

		label.add_theme_font_override("font", title_font)

		label.add_theme_constant_override(
			"outline_size",
			maxi(2, int(float(font_size) * 0.10))
		)

		label.add_theme_color_override(
			"font_outline_color",
			Color(0.02, 0.04, 0.12, 0.95)
		)

		label.add_theme_color_override(
			"font_shadow_color",
			Color(0, 0, 0, 0.55)
		)

		label.add_theme_constant_override("shadow_offset_x", 0)

		label.add_theme_constant_override("shadow_offset_y", 4)

	return label


func make_button(
	text_value: String,
	callback: Callable,
	accent: Color = CYAN
) -> Button:

	var button = Button.new()

	button.text = text_value

	button.custom_minimum_size = Vector2(300, 54)

	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	button.add_theme_font_size_override(
		"font_size",
		22
	)

	if title_font != null:
		button.add_theme_font_override("font", title_font)

	button.add_theme_color_override(
		"font_color",
		WHITE
	)

	# Normal
	var normal = StyleBoxFlat.new()

	normal.bg_color = Color("#12234a").lerp(accent, 0.14)
	normal.border_color = accent

	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)

	normal.content_margin_left = 20
	normal.content_margin_right = 20

	# Neon glow
	normal.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	normal.shadow_size = 10

	# Hover
	var hover = normal.duplicate()

	hover.bg_color = Color("#12234a").lerp(accent, 0.34)
	hover.border_color = accent.lightened(0.3)
	hover.shadow_size = 20
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.55)

	# Pressed
	var pressed = normal.duplicate()

	pressed.bg_color = accent.darkened(0.55)
	pressed.shadow_size = 6

	button.add_theme_stylebox_override(
		"normal",
		normal
	)

	button.add_theme_stylebox_override(
		"hover",
		hover
	)

	button.add_theme_stylebox_override(
		"pressed",
		pressed
	)

	button.add_theme_stylebox_override(
		"focus",
		StyleBoxEmpty.new()
	)

	button.pressed.connect(callback)

	return button


# ==================================================
# MAIN MENU
# ==================================================

func show_main_menu():

	game_state = "menu"

	menu_layer.visible = true

	menu_background.color = SPACE_COLOR

	clear_menu()

	set_menu_mode("main")

	main_menu.add_child(
		make_label(
			"—  NEON COSMOS EDITION  —",
			14,
			PURPLE
		)
	)

	main_menu.add_child(
		make_label(
			"REBOUND",
			96,
			CYAN,
			true
		)
	)

	main_menu.add_child(
		make_label(
			"EVERY FALL IS ANOTHER CHANCE",
			15,
			Color("#aebce9")
		)
	)

	main_menu.add_child(
		make_label(
			"✦  BEST SCORE: " + str(high_score) + "  ✦",
			17,
			PURPLE
		)
	)

	main_menu.add_child(
		make_button(
			"PLAY",
			start_game,
			CYAN
		)
	)

	main_menu.add_child(
		make_button(
			"HOW TO PLAY",
			show_instructions,
			PURPLE
		)
	)

	main_menu.add_child(
		make_label(
			"A GAME ABOUT NEVER GIVING UP",
			12,
			Color("#6478a8")
		)
	)


# ==================================================
# INSTRUCTIONS
# ==================================================

func show_instructions():

	game_state = "instructions"

	clear_menu()

	set_menu_mode("instructions")

	main_menu.add_child(
		make_label(
			"HOW TO PLAY",
			44,
			CYAN,
			true
		)
	)

	main_menu.add_child(
		make_label(
			"A / LEFT ARROW - MOVE LEFT",
			16,
			WHITE
		)
	)

	main_menu.add_child(
		make_label(
			"D / RIGHT ARROW - MOVE RIGHT",
			16,
			WHITE
		)
	)

	main_menu.add_child(
		make_label(
			"BOUNCE AUTOMATICALLY ON PLATFORMS",
			14,
			PURPLE
		)
	)

	main_menu.add_child(
		make_label(
			"CLIMB AS HIGH AS POSSIBLE",
			15,
			WHITE
		)
	)

	main_menu.add_child(
		make_label(
			"BOUNCE ON 10 TILES TO CHARGE THE BALL",
			14,
			ULTRA_GLOW
		)
	)

	main_menu.add_child(
		make_label(
			"W - TURBO JUMP WHEN BALL IS ULTRA BLUE",
			14,
			ULTRA_GLOW
		)
	)

	main_menu.add_child(
		make_label(
			"ORANGE TILES BREAK AFTER ONE BOUNCE",
			14,
			FRAGILE
		)
	)

	main_menu.add_child(
		make_label(
			"5 BOUNCES ON THE SAME TILE BREAKS IT",
			14,
			Color("#ffb38a")
		)
	)

	main_menu.add_child(
		make_label(
			"DON'T FALL - WATCH THE RED DANGER ZONE",
			14,
			DANGER_RED
		)
	)

	main_menu.add_child(
		make_label(
			"M - MUTE / UNMUTE MUSIC",
			14,
			WHITE
		)
	)

	main_menu.add_child(
		make_label(
			"ESC - PAUSE THE GAME",
			15,
			CYAN
		)
	)

	main_menu.add_child(
		make_button(
			"BACK TO MENU",
			show_main_menu,
			PURPLE
		)
	)


# ==================================================
# START GAME
# ==================================================

func start_game():

	setup_game()

	menu_layer.visible = false


func setup_game():

	player_pos = Vector2(480, 420)

	velocity = Vector2.ZERO

	camera_y = 270.0

	highest_y = 420.0

	score = 0

	bounce_count = 0

	# Turbo + effects reset
	charge_bounces = 0
	charged = false
	turbo_timer = 0.0
	w_was_down = false
	squash = 0.0
	shake = 0.0
	shake_offset = Vector2.ZERO
	particles.clear()
	trail.clear()

	# Wasted reset
	wasted_timer = 0.0
	wasted_menu_shown = false

	game_state = "playing"

	platforms.clear()

	# Starting platform (ye kabhi nahi tootta)
	add_platform(350, 470, 260, false)

	# Initial platforms
	var y = 390.0

	while y > -350:

		add_platform(
			randf_range(80, 760),
			y,
			randf_range(120, 200),
			randf() < BREAK_CHANCE
		)

		y -= randf_range(
			PLATFORM_GAP_MIN,
			PLATFORM_GAP_MAX
		)

	queue_redraw()


func add_platform(x: float, y: float, width: float, fragile: bool = false):

	next_platform_id += 1

	platforms.append({
		"id": next_platform_id,
		"rect": Rect2(x, y, width, 18),
		"fragile": fragile,
		"flash": 0.0,
		"hits": 0
	})


# ==================================================
# PAUSE MENU
# ==================================================

func show_pause_menu():

	game_state = "paused"

	menu_layer.visible = true

	menu_background.color = SPACE_COLOR

	clear_menu()

	set_menu_mode("pause")

	main_menu.add_child(
		make_label(
			"PAUSED",
			52,
			CYAN,
			true
		)
	)

	main_menu.add_child(
		make_label(
			"TAKE A BREATHER",
			14,
			Color("#b8c9ec")
		)
	)

	main_menu.add_child(
		make_button(
			"RESUME",
			resume_game,
			CYAN
		)
	)

	main_menu.add_child(
		make_button(
			"RESTART",
			start_game,
			PURPLE
		)
	)

	main_menu.add_child(
		make_button(
			"MAIN MENU",
			show_main_menu,
			Color("#ff78b5")
		)
	)


func resume_game():

	game_state = "playing"

	menu_layer.visible = false


# ==================================================
# GAME OVER (WASTED)
# ==================================================

func show_game_over():

	game_state = "lost"

	if score > high_score:

		high_score = score

		save_high_score()

	# WASTED animation shuru: pehle sirf screen, buttons baad mein
	wasted_timer = 0.0

	wasted_menu_shown = false

	menu_layer.visible = false

	play_faah()


func show_game_over_menu():

	game_state = "lost"

	menu_layer.visible = true

	menu_background.color = SPACE_COLOR

	clear_menu()

	set_menu_mode("gameover")

	# WASTED text ke neeche jagah
	var spacer = Control.new()

	spacer.custom_minimum_size = Vector2(0, 160)

	main_menu.add_child(spacer)

	main_menu.add_child(
		make_label(
			"GAME OVER",
			22,
			Color("#ff78b5"),
			true
		)
	)

	main_menu.add_child(
		make_label(
			"FINAL SCORE: " + str(score),
			26,
			WHITE,
			true
		)
	)

	main_menu.add_child(
		make_label(
			"BEST SCORE: " + str(high_score),
			17,
			PURPLE
		)
	)

	main_menu.add_child(
		make_button(
			"PLAY AGAIN",
			start_game,
			Color("#ff3b5c")
		)
	)

	main_menu.add_child(
		make_button(
			"MAIN MENU",
			show_main_menu,
			CYAN
		)
	)


# ==================================================
# MAIN GAME LOOP
# ==================================================

func _process(delta):

	if game_state == "playing":

		if Input.is_action_just_pressed("ui_cancel"):

			show_pause_menu()

			return

		update_game(delta)

	elif game_state == "paused":

		if Input.is_action_just_pressed("ui_cancel"):

			resume_game()

	elif game_state == "lost":

		wasted_timer += delta

		if not wasted_menu_shown and wasted_timer >= WASTED_MENU_DELAY:

			wasted_menu_shown = true

			show_game_over_menu()

	if game_state != "playing":

		shake_offset = Vector2.ZERO

	update_music(delta)

	queue_redraw()


# ==================================================
# TURBO + PARTICLE HELPERS
# ==================================================

func spawn_burst(pos: Vector2, count: int, color: Color, speed: float):

	for i in range(count):

		var angle = randf() * TAU

		var life = randf_range(0.3, 0.7)

		particles.append({
			"pos": pos,
			"vel": Vector2.from_angle(angle) * randf_range(speed * 0.3, speed),
			"life": life,
			"max": life,
			"size": randf_range(2.0, 4.5),
			"color": color,
			"rot": 0.0,
			"spin": 0.0,
			"shard": false,
			"grav": 200.0
		})


func break_platform(p: Dictionary, shard_color: Color = FRAGILE):

	var rect: Rect2 = p["rect"]

	var pieces = maxi(4, int(rect.size.x / 14.0))

	var piece_w = rect.size.x / float(pieces)

	for i in range(pieces):

		var px = rect.position.x + (float(i) + 0.5) * piece_w

		var life = randf_range(0.7, 1.1)

		particles.append({
			"pos": Vector2(px, rect.position.y + 9),
			"vel": Vector2(
				randf_range(-110.0, 110.0) + (px - player_pos.x) * 1.2,
				randf_range(-120.0, 140.0)
			),
			"life": life,
			"max": life,
			"size": Vector2(piece_w * 0.9, randf_range(8.0, 16.0)),
			"color": shard_color,
			"rot": randf() * TAU,
			"spin": randf_range(-9.0, 9.0),
			"shard": true,
			"grav": 1400.0
		})

	spawn_burst(
		Vector2(player_pos.x, rect.position.y),
		14,
		shard_color.lightened(0.5),
		320.0
	)

	shake = maxf(shake, 3.0)


func handle_tile_hit(index: int):

	var p: Dictionary = platforms[index]

	var rect: Rect2 = p["rect"]

	squash = 1.0

	# Lagataar bounce counter: dusri tile pe jaate hi reset
	var pid: int = p["id"]

	for q in platforms:

		if q["id"] != pid:

			q["hits"] = 0

	p["hits"] = p["hits"] + 1

	# Bounce sparks (tile ke colour ke)
	var tile_color = get_tile_color(rect.position.y)

	var spark_color = tile_color

	if p["fragile"]:
		spark_color = FRAGILE

	spawn_burst(
		Vector2(player_pos.x, rect.position.y),
		8,
		spark_color,
		230.0
	)

	# Charge counting
	if not charged:

		charge_bounces += 1

		if charge_bounces >= TURBO_BOUNCES_NEEDED:

			charged = true

			spawn_burst(player_pos, 36, ULTRA_GLOW, 420.0)

			shake = maxf(shake, 4.0)

	# Tile reaction
	if p["fragile"]:

		break_platform(p)

		platforms.remove_at(index)

	elif p["hits"] >= MAX_SAME_TILE_BOUNCES:

		# Ek hi tile pe 5 baar bounce = tile toot gayi
		break_platform(p, tile_color)

		platforms.remove_at(index)

	else:

		p["flash"] = 1.0


func activate_turbo():

	velocity.y = -TURBO_POWER

	charged = false

	charge_bounces = 0

	turbo_timer = 1.1

	shake = 8.0

	squash = 0.0

	spawn_burst(player_pos, 45, ULTRA_GLOW, 520.0)


func update_effects(delta):

	# Timers
	turbo_timer = maxf(0.0, turbo_timer - delta)

	squash = maxf(0.0, squash - delta * 5.0)

	shake = maxf(0.0, shake - delta * 30.0)

	shake_offset = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	) * shake

	# Trail
	trail.push_front(player_pos)

	if trail.size() > 28:
		trail.pop_back()

	# Tile flash
	for p in platforms:

		p["flash"] = maxf(0.0, p["flash"] - delta * 4.0)

	# Particles
	for i in range(particles.size() - 1, -1, -1):

		var pt: Dictionary = particles[i]

		pt["life"] = pt["life"] - delta

		if pt["life"] <= 0.0:

			particles.remove_at(i)

			continue

		var v: Vector2 = pt["vel"]

		v.y += pt["grav"] * delta

		pt["vel"] = v

		var pos: Vector2 = pt["pos"]

		pos += v * delta

		pt["pos"] = pos

		pt["rot"] = pt["rot"] + pt["spin"] * delta


# ==================================================
# GAME PHYSICS
# ==================================================

func update_game(delta):

	# Movement
	var direction = 0.0

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0

	player_pos.x += direction * MOVE_SPEED * delta

	# Turbo activate (W)
	var w_down = Input.is_key_pressed(KEY_W)

	if w_down and not w_was_down and charged:

		activate_turbo()

	w_was_down = w_down

	# Screen wrapping
	if player_pos.x < -20:
		player_pos.x = SCREEN_W + 20

	if player_pos.x > SCREEN_W + 20:
		player_pos.x = -20

	# Gravity
	var previous_y = player_pos.y

	velocity.y += GRAVITY * delta

	player_pos.y += velocity.y * delta

	# Automatic bouncing
	if velocity.y > 0:

		var hit_index = -1

		for i in range(platforms.size()):

			var platform: Rect2 = platforms[i]["rect"]

			var old_bottom = previous_y + 17

			var new_bottom = player_pos.y + 17

			var overlaps_x = (
				player_pos.x + 15 > platform.position.x
				and player_pos.x - 15 < platform.end.x
			)

			if (
				old_bottom <= platform.position.y
				and new_bottom >= platform.position.y
				and overlaps_x
			):

				player_pos.y = platform.position.y - 17

				bounce_count += 1

				var power = BOUNCE_POWER + minf(
					float(bounce_count) * 3.0,
					120.0
				)

				velocity.y = -power

				hit_index = i

				break

		if hit_index != -1:

			handle_tile_hit(hit_index)

	# Camera
	var target_camera = player_pos.y - 180

	if target_camera < camera_y:

		camera_y = target_camera

	# Score
	if player_pos.y < highest_y:

		highest_y = player_pos.y

		score = int(
			(420 - highest_y) / 10.0
		)

	# Generate infinite platforms
	var highest_platform = 1000000.0

	for p in platforms:

		var rect: Rect2 = p["rect"]

		highest_platform = minf(
			highest_platform,
			rect.position.y
		)

	while highest_platform > camera_y - 650:

		highest_platform -= randf_range(
			PLATFORM_GAP_MIN,
			PLATFORM_GAP_MAX
		)

		add_platform(
			randf_range(35, 790),
			highest_platform,
			randf_range(110, 190),
			randf() < BREAK_CHANCE
		)

	# Remove old platforms
	for i in range(platforms.size() - 1, -1, -1):

		var rect: Rect2 = platforms[i]["rect"]

		if rect.position.y > camera_y + 650:

			platforms.remove_at(i)

	# Effects (particles, trail, shake)
	update_effects(delta)

	# Game over
	if player_pos.y > camera_y + SCREEN_H + 30:

		show_game_over()


# ==================================================
# GRAPHICS - BACKGROUND
# ==================================================

func draw_background():

	if background_texture != null:

		draw_texture_rect(
			background_texture,
			Rect2(0, 0, SCREEN_W, SCREEN_H),
			false,
			Color.WHITE
		)

		# Dark tint for readability
		draw_rect(
			Rect2(0, 0, SCREEN_W, SCREEN_H),
			Color(0.02, 0.04, 0.12, 0.24)
		)

	else:

		draw_rect(
			Rect2(0, 0, SCREEN_W, SCREEN_H),
			SPACE_COLOR
		)

	# Procedural stars
	for i in range(120):

		var x = fposmod(
			float(i * 137 + 31),
			SCREEN_W
		)

		var world_y = fposmod(
			float(i * 83 + 19),
			1000.0
		)

		var y = fposmod(
			world_y - camera_y * 0.25,
			SCREEN_H
		)

		var star_color = Color(
			0.55,
			0.75,
			1.0,
			0.35 + 0.25 * sin(
				Time.get_ticks_msec() * 0.002 + i
			)
		)

		draw_circle(
			Vector2(x, y),
			1.3,
			star_color
		)


# ==================================================
# GRAPHICS - PREMIUM WELCOME SCENE
# ==================================================

func draw_tile_visual(rect: Rect2, edge: Color, alpha: float):

	# Glow
	for g in range(3):

		var e = 3.0 + float(g) * 4.0

		draw_rect(
			Rect2(
				rect.position - Vector2(e, e),
				rect.size + Vector2(e * 2.0, e * 2.0)
			),
			Color(edge.r, edge.g, edge.b, (0.14 - float(g) * 0.04) * alpha)
		)

	# Body
	var body = Color("#172449").lerp(edge, 0.12)

	draw_rect(rect, Color(body.r, body.g, body.b, alpha))

	# Top line
	draw_rect(
		Rect2(rect.position.x, rect.position.y, rect.size.x, 3),
		Color(edge.r, edge.g, edge.b, alpha)
	)

	# Border
	var bright = edge.lightened(0.25)

	draw_rect(
		rect,
		Color(bright.r, bright.g, bright.b, alpha),
		false,
		2.0
	)


func draw_orb_at(pos: Vector2):

	# Welcome screen ki demo ball: poora charge cycle dikhati hai
	var tsec = Time.get_ticks_msec() * 0.001

	var cycle = fposmod(tsec, 8.0)

	var ratio = clampf(cycle / 5.0, 0.0, 1.0)

	var demo_charged = cycle > 5.0

	# Tile ke paas pahunchte hi halka squash
	var near_floor = clampf(1.0 - (413.0 - pos.y) / 24.0, 0.0, 1.0)

	draw_orb(
		pos,
		1.0 + near_floor * 0.22,
		1.0 - near_floor * 0.22,
		ratio,
		demo_charged,
		0.0,
		near_floor * 0.8
	)


func demo_ball_y(tt: float) -> float:

	return 413.0 - absf(sin(tt * 2.6)) * 190.0


func draw_menu_scene():

	var t = Time.get_ticks_msec() * 0.001

	# Purple gradient neeche ki taraf
	for i in range(10):

		var f = float(i) / 9.0

		draw_rect(
			Rect2(0, float(i) * SCREEN_H / 10.0, SCREEN_W, SCREEN_H / 10.0 + 1.0),
			Color(0.35 * f, 0.12 * f, 0.55 * f, 0.20 * f)
		)

	# Chaand / planet
	var pc = Vector2(845, 135) + Vector2(0, sin(t * 0.5) * 6.0)

	draw_circle(pc, 128, Color(0.55, 0.35, 1.0, 0.05))

	draw_circle(pc, 108, Color(0.55, 0.35, 1.0, 0.08))

	draw_circle(pc, 84, Color("#1b1f55"))

	draw_circle(pc + Vector2(-10, -8), 77, Color("#262c75"))

	draw_circle(pc + Vector2(-24, 12), 13, Color("#1d2260"))

	draw_circle(pc + Vector2(20, -22), 9, Color("#1d2260"))

	draw_circle(pc + Vector2(24, 26), 6, Color("#1d2260"))

	draw_arc(pc, 84, 0.0, TAU, 80, Color(0.55, 0.5, 1.0, 0.55), 2.0)

	# Upar tairte neon tiles
	for i in range(8):

		var speed = 14.0 + float(i % 3) * 9.0

		var w = 100.0 + float((i * 37) % 70)

		var x = fposmod(float(i * 131 + 40), SCREEN_W - 120.0)

		var y = fposmod(float(i * 83 + 500) - t * speed, 620.0) - 40.0

		var col: Color = tile_palette[i % tile_palette.size()]

		draw_tile_visual(Rect2(x, y, w, 16), col, 0.45)

	# Demo ball jo tile par uchalti rehti hai
	draw_tile_visual(Rect2(55, 430, 150, 16), CYAN, 1.0)

	for k in range(6, 0, -1):

		var yy = demo_ball_y(t - float(k) * 0.025)

		draw_circle(
			Vector2(130, yy),
			16.0 - float(k) * 1.5,
			Color(0.2, 0.8, 1.0, 0.22 - float(k) * 0.03)
		)

	draw_orb_at(Vector2(130, demo_ball_y(t)))

	# Credits ke upar patli glowing line
	if game_state == "menu":

		draw_line(
			Vector2(280, 486),
			Vector2(680, 486),
			Color(0.2, 0.75, 1.0, 0.35),
			1.5
		)


# ==================================================
# GRAPHICS - PLATFORMS (BRIGHT NEON BORDER)
# ==================================================

func draw_platforms():

	for p in platforms:

		var world_rect: Rect2 = p["rect"]

		var screen_rect = Rect2(
			world_rect.position.x + shake_offset.x,
			world_rect.position.y - camera_y + shake_offset.y,
			world_rect.size.x,
			world_rect.size.y
		)

		if screen_rect.end.y < 0 or screen_rect.position.y > SCREEN_H:
			continue

		var fragile: bool = p["fragile"]

		var flash: float = p["flash"]

		# Height ke hisaab se tile ka colour
		var edge = get_tile_color(world_rect.position.y)

		if fragile:
			edge = FRAGILE

		var pulse = 0.75 + 0.25 * sin(
			Time.get_ticks_msec() * 0.004 + world_rect.position.x * 0.05
		)

		# Outer glow (layered)
		for g in range(4):

			var e = 3.0 + float(g) * 4.0

			var a = (0.16 - float(g) * 0.035) * pulse + flash * 0.10

			draw_rect(
				Rect2(
					screen_rect.position - Vector2(e, e),
					screen_rect.size + Vector2(e * 2.0, e * 2.0)
				),
				Color(edge.r, edge.g, edge.b, a)
			)

		# Platform body
		var body_color = Color("#172449").lerp(edge, 0.12)

		if fragile:
			body_color = Color("#2b1a33")

		draw_rect(
			screen_rect,
			body_color
		)

		# Top neon line
		draw_rect(
			Rect2(
				screen_rect.position.x,
				screen_rect.position.y,
				screen_rect.size.x,
				4
			),
			edge.lightened(flash * 0.6)
		)

		# Bright glowing border
		draw_rect(
			screen_rect,
			edge.lightened(0.25 + flash * 0.5),
			false,
			2.5
		)

		# Small decorative detail
		draw_rect(
			Rect2(
				screen_rect.position.x + 12,
				screen_rect.position.y + 9,
				20,
				2
			),
			Color("#a66cff")
		)

		# Cracks on fragile tiles
		if fragile:

			var top = screen_rect.position.y + 4

			for k in range(3):

				var cx = screen_rect.position.x + screen_rect.size.x * (0.25 + 0.25 * float(k))

				draw_line(Vector2(cx, top), Vector2(cx + 6, top + 6), edge, 1.5)
				draw_line(Vector2(cx + 6, top + 6), Vector2(cx + 1, top + 10), edge, 1.5)
				draw_line(Vector2(cx + 1, top + 10), Vector2(cx + 7, top + 14), edge, 1.5)

		# Normal tile par lagataar bounce ka warning crack
		if not fragile:

			var hits: int = p["hits"]

			if hits >= 2:

				var crack_col = Color(1, 1, 1, 0.85)

				if hits >= MAX_SAME_TILE_BOUNCES - 1:
					crack_col = Color(1.0, 0.5, 0.3, 0.95)

				var crack_top = screen_rect.position.y + 4

				for k in range(hits - 1):

					var cx2 = screen_rect.position.x + screen_rect.size.x * (0.30 + 0.20 * float(k))

					draw_line(Vector2(cx2, crack_top), Vector2(cx2 + 6, crack_top + 6), crack_col, 1.5)
					draw_line(Vector2(cx2 + 6, crack_top + 6), Vector2(cx2 + 1, crack_top + 10), crack_col, 1.5)
					draw_line(Vector2(cx2 + 1, crack_top + 10), Vector2(cx2 + 7, crack_top + 14), crack_col, 1.5)


# ==================================================
# GRAPHICS - PARTICLES + TRAIL
# ==================================================

func draw_particles():

	for pt in particles:

		var t: float = pt["life"] / pt["max"]

		var c: Color = pt["color"]

		c.a = minf(1.0, t * 2.0)

		var world_pos: Vector2 = pt["pos"]

		var pos = Vector2(
			world_pos.x,
			world_pos.y - camera_y
		) + shake_offset

		if pt["shard"]:

			var sz: Vector2 = pt["size"]

			draw_set_transform(pos, pt["rot"], Vector2.ONE)

			draw_rect(
				Rect2(-sz.x * 0.5, -sz.y * 0.5, sz.x, sz.y),
				Color(c.r * 0.35, c.g * 0.25, c.b * 0.3, c.a)
			)

			draw_rect(
				Rect2(-sz.x * 0.5, -sz.y * 0.5, sz.x, sz.y),
				c,
				false,
				1.5
			)

			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		else:

			var r: float = pt["size"]

			draw_circle(pos, r * 2.2 * t, Color(c.r, c.g, c.b, c.a * 0.25))

			draw_circle(pos, r * t + 0.5, c)


func draw_trail():

	var n = trail.size()

	if n < 2:
		return

	var turbo_on = turbo_timer > 0.0

	var col = CYAN

	if charged or turbo_on:
		col = ULTRA

	for i in range(n):

		var t = 1.0 - float(i) / float(n)

		var wp: Vector2 = trail[i]

		var pos = Vector2(wp.x, wp.y - camera_y) + shake_offset

		var alpha = t * 0.30

		var radius = 16.0 * t

		var core_alpha = t * 0.18

		if turbo_on:

			alpha = t * 0.65

			radius = 24.0 * t

			core_alpha = t * 0.55

		# Soft outer glow
		draw_circle(pos, radius * 1.5, Color(col.r, col.g, col.b, alpha * 0.35))

		# Main trail
		draw_circle(pos, radius, Color(col.r, col.g, col.b, alpha))

		# Bright white-hot core
		draw_circle(pos, radius * 0.45, Color(1, 1, 1, core_alpha))


# ==================================================
# GRAPHICS - ENERGY ORB (PREMIUM BALL)
# ==================================================

func hash01(x: float) -> float:

	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0)


func draw_orb(
	pos: Vector2,
	sx: float,
	sy: float,
	ratio: float,
	is_charged: bool,
	turbo_left: float,
	squash_amt: float
):

	var time = Time.get_ticks_msec() * 0.005

	var tsec = Time.get_ticks_msec() * 0.001

	var pulse = 1.0 + sin(time) * 0.06

	# Colours (charge badhne par ball dheere dheere blue hoti hai)
	var glow_col = Color(0.05, 0.75, 1.0).lerp(ULTRA, ratio * 0.5)
	var rim = Color("#9af3ff").lerp(ULTRA_GLOW, ratio * 0.5)
	var body_outer = Color("#0070c8").lerp(Color("#1a3fd0"), ratio * 0.6)
	var body_mid = CYAN.lerp(Color("#4f8dff"), ratio * 0.5)
	var core_col = Color("#e8feff")
	var ring_a = CYAN
	var ring_b = PURPLE
	var bloom_boost = 1.0

	if is_charged:

		pulse = 1.0 + sin(time * 3.0) * 0.10

		glow_col = ULTRA
		rim = Color("#cfe4ff")
		body_outer = Color("#0f2fb8")
		body_mid = ULTRA
		core_col = Color("#ffffff")
		ring_a = ULTRA_GLOW
		ring_b = WHITE
		bloom_boost = 1.7

	draw_set_transform(pos, 0.0, Vector2(sx, sy))

	# ---------- 1. Soft bloom (bahut halka glow) ----------
	for i in range(9):

		var r = (70.0 - float(i) * 5.5) * pulse

		var a = (0.012 + float(i) * 0.006) * bloom_boost

		draw_circle(
			Vector2.ZERO,
			r,
			Color(glow_col.r, glow_col.g, glow_col.b, a)
		)

	if is_charged:

		for i in range(4):

			draw_circle(
				Vector2.ZERO,
				(96.0 - float(i) * 6.0) * pulse,
				Color(glow_col.r, glow_col.g, glow_col.b, 0.02 + float(i) * 0.01)
			)

	# ---------- 2. Turbo flame ----------
	if turbo_left > 0.0:

		var inten = clampf(turbo_left / 1.1, 0.0, 1.0)

		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-15, 8),
				Vector2(15, 8),
				Vector2(0, 8.0 + 120.0 * inten)
			]),
			Color(ULTRA_GLOW.r, ULTRA_GLOW.g, ULTRA_GLOW.b, 0.35 * inten)
		)

		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-7, 8),
				Vector2(7, 8),
				Vector2(0, 8.0 + 70.0 * inten)
			]),
			Color(1, 1, 1, 0.55 * inten)
		)

	# ---------- 3. Bounce shockwave ----------
	if squash_amt > 0.05:

		draw_arc(
			Vector2.ZERO,
			20.0 + (1.0 - squash_amt) * 38.0,
			0.0,
			TAU,
			48,
			Color(rim.r, rim.g, rim.b, squash_amt * 0.45),
			2.0
		)

	# ---------- 4. Charged shockwave ring ----------
	if is_charged:

		var phase = fposmod(tsec * 1.2, 1.0)

		draw_arc(
			Vector2.ZERO,
			30.0 + phase * 45.0,
			0.0,
			TAU,
			64,
			Color(glow_col.r, glow_col.g, glow_col.b, (1.0 - phase) * 0.5),
			2.5
		)

	# ---------- 5. Charge segments (10 dots ring) ----------
	if not is_charged:

		var filled = int(round(ratio * float(TURBO_BOUNCES_NEEDED)))

		var seg = TAU / float(TURBO_BOUNCES_NEEDED)

		for i in range(TURBO_BOUNCES_NEEDED):

			var a0 = -PI * 0.5 + float(i) * seg + 0.09

			var a1 = a0 + seg - 0.18

			if i < filled:

				draw_arc(
					Vector2.ZERO,
					34.0,
					a0,
					a1,
					8,
					Color(ULTRA_GLOW.r, ULTRA_GLOW.g, ULTRA_GLOW.b, 0.25),
					6.0
				)

				draw_arc(
					Vector2.ZERO,
					34.0,
					a0,
					a1,
					8,
					Color(ULTRA_GLOW.r, ULTRA_GLOW.g, ULTRA_GLOW.b, 0.95),
					3.0
				)

			else:

				draw_arc(
					Vector2.ZERO,
					34.0,
					a0,
					a1,
					8,
					Color(0.4, 0.55, 0.9, 0.18),
					2.0
				)

	# ---------- 6. Rotating energy rings ----------
	draw_arc(
		Vector2.ZERO,
		26.0 * pulse,
		0.0,
		TAU,
		64,
		Color(ring_a.r, ring_a.g, ring_a.b, 0.15),
		1.5
	)

	draw_arc(
		Vector2.ZERO,
		26.0 * pulse,
		time,
		time + PI * 1.65,
		64,
		ring_a,
		2.5
	)

	draw_arc(
		Vector2.ZERO,
		22.0 * pulse,
		-time * 1.3,
		-time * 1.3 + PI * 1.5,
		64,
		ring_b,
		1.8
	)

	# ---------- 7. Electric bolts (sirf charged ball par) ----------
	if is_charged:

		var bucket = floor(tsec * 16.0)

		for b in range(6):

			var base_a = time * 0.5 + float(b) * TAU / 6.0

			var pts = PackedVector2Array()

			for s in range(5):

				var f = float(s) / 4.0

				var r = lerpf(23.0, 46.0, f)

				var jitter = (
					hash01(float(b) * 7.13 + float(s) * 3.7 + bucket * 1.91) - 0.5
				) * 0.55

				if s == 0:
					jitter = 0.0

				pts.append(Vector2.from_angle(base_a + jitter) * r)

			draw_polyline(
				pts,
				Color(ULTRA_GLOW.r, ULTRA_GLOW.g, ULTRA_GLOW.b, 0.9),
				2.2
			)

			draw_polyline(
				pts,
				Color(1, 1, 1, 0.85),
				0.9
			)

	# ---------- 8. Ball body (gradient shading) ----------
	draw_circle(
		Vector2.ZERO,
		20.0 * pulse,
		Color(rim.r, rim.g, rim.b, 0.35)
	)

	for i in range(6):

		var t = float(i) / 5.0

		var r = (18.0 - float(i) * 2.2) * pulse

		draw_circle(
			Vector2.ZERO,
			r,
			body_outer.lerp(body_mid, t)
		)

	# Bright core
	draw_circle(Vector2.ZERO, 8.0 * pulse, core_col)

	draw_circle(Vector2.ZERO, 5.0 * pulse, Color(1, 1, 1, 0.9))

	# ---------- 9. BRIGHT EDGE (rim light) ----------
	var rim_alpha = 0.9

	if is_charged:
		rim_alpha = 0.75 + 0.25 * sin(time * 4.0)

	draw_arc(
		Vector2.ZERO,
		17.5 * pulse,
		0.0,
		TAU,
		64,
		Color(rim.r, rim.g, rim.b, rim_alpha),
		2.5
	)

	# Edge ke bahar halka glow rings
	for g in range(3):

		draw_arc(
			Vector2.ZERO,
			(19.5 + float(g) * 2.0) * pulse,
			0.0,
			TAU,
			64,
			Color(rim.r, rim.g, rim.b, 0.28 - float(g) * 0.08),
			2.0
		)

	# Edge pe ghoomti hui chamak
	draw_arc(
		Vector2.ZERO,
		17.5 * pulse,
		time * 0.8,
		time * 0.8 + PI * 0.5,
		24,
		Color(1, 1, 1, 0.95),
		3.5
	)

	draw_arc(
		Vector2.ZERO,
		17.5 * pulse,
		time * 0.8 + PI,
		time * 0.8 + PI * 1.25,
		16,
		Color(1, 1, 1, 0.5),
		2.5
	)

	# ---------- 10. Glossy highlights ----------
	draw_arc(
		Vector2.ZERO,
		12.0,
		PI * 1.05,
		PI * 1.45,
		16,
		Color(1, 1, 1, 0.55),
		3.0
	)

	draw_circle(Vector2(-6, -7), 4, WHITE)

	draw_circle(Vector2(5, 6), 2, Color(1, 1, 1, 0.45))

	# ---------- 11. Orbiting sparkles ----------
	for k in range(3):

		var sp = Vector2.from_angle(time * (1.2 + float(k) * 0.5) + float(k) * 2.1) * (31.0 + float(k) * 3.0)

		draw_circle(sp, 3.2, Color(ring_a.r, ring_a.g, ring_a.b, 0.25))

		draw_circle(sp, 1.6, WHITE)

	# Transform reset
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_player():

	var screen_player = Vector2(
		player_pos.x,
		player_pos.y - camera_y
	) + shake_offset

	var ratio = float(charge_bounces) / float(TURBO_BOUNCES_NEEDED)

	# Squash & stretch
	var stretch = clampf(absf(velocity.y) / 2600.0, 0.0, 0.22)

	if turbo_timer > 0.0:

		stretch += 0.12 * minf(1.0, turbo_timer / 0.5)

	var sx = 1.0 - stretch * 0.5 + squash * 0.30

	var sy = 1.0 + stretch - squash * 0.30

	draw_orb(
		screen_player,
		sx,
		sy,
		ratio,
		charged,
		turbo_timer,
		squash
	)


# ==================================================
# GRAPHICS - DANGER UI
# ==================================================

func draw_danger():

	if game_state != "playing":
		return

	var screen_y = player_pos.y - camera_y

	# 0 = safe, 1 = bilkul girne wala hai
	var level = clampf(
		(screen_y - (SCREEN_H - DANGER_START)) / DANGER_START,
		0.0,
		1.0
	)

	if level <= 0.0:
		return

	# Jitna neeche, utna tez blink
	var blink = 0.5 + 0.5 * sin(
		Time.get_ticks_msec() * 0.015 * (1.0 + level * 1.5)
	)

	var a = level * (0.25 + 0.35 * blink)

	# Red vignette (left, right, bottom)
	for i in range(6):

		var fade = 1.0 - float(i) / 6.0

		var thick = 14.0 + float(i) * 18.0

		var col = Color(
			DANGER_RED.r,
			DANGER_RED.g,
			DANGER_RED.b,
			a * 0.22 * fade
		)

		draw_rect(Rect2(0, 0, thick, SCREEN_H), col)

		draw_rect(Rect2(SCREEN_W - thick, 0, thick, SCREEN_H), col)

		draw_rect(
			Rect2(0, SCREEN_H - thick * 1.6, SCREEN_W, thick * 1.6),
			col
		)

	# Warning text + triangles
	if level > 0.25:

		var font = ThemeDB.fallback_font

		var text_alpha = 0.55 + 0.45 * blink

		var text_col = Color(
			DANGER_RED.r,
			DANGER_RED.g,
			DANGER_RED.b,
			text_alpha
		)

		draw_string(
			font,
			Vector2(0, 112),
			"DANGER!",
			HORIZONTAL_ALIGNMENT_CENTER,
			SCREEN_W,
			34,
			text_col
		)

		for side in [-1.0, 1.0]:

			var cx = SCREEN_W * 0.5 + side * 135.0

			draw_colored_polygon(
				PackedVector2Array([
					Vector2(cx, 84),
					Vector2(cx - 19, 118),
					Vector2(cx + 19, 118)
				]),
				text_col
			)

			draw_string(
				font,
				Vector2(cx - 20, 113),
				"!",
				HORIZONTAL_ALIGNMENT_CENTER,
				40,
				22,
				Color(1, 1, 1, text_alpha)
			)


# ==================================================
# GRAPHICS - WASTED (GTA STYLE)
# ==================================================

func draw_wasted():

	if game_state != "lost":
		return

	# Screen dhundhli + dark hoti hai
	var k = clampf(wasted_timer / 0.8, 0.0, 1.0)

	draw_rect(
		Rect2(0, 0, SCREEN_W, SCREEN_H),
		Color(0.50, 0.52, 0.56, 0.42 * k)
	)

	draw_rect(
		Rect2(0, 0, SCREEN_W, SCREEN_H),
		Color(0.02, 0.02, 0.05, 0.50 * k)
	)

	# Side vignette
	for i in range(6):

		var thick = 20.0 + float(i) * 26.0

		var col = Color(0, 0, 0, 0.10 * k)

		draw_rect(Rect2(0, 0, thick, SCREEN_H), col)

		draw_rect(Rect2(SCREEN_W - thick, 0, thick, SCREEN_H), col)

	# Cinematic black bars
	var bar = 54.0 * clampf(wasted_timer / 0.6, 0.0, 1.0)

	draw_rect(Rect2(0, 0, SCREEN_W, bar), Color.BLACK)

	draw_rect(Rect2(0, SCREEN_H - bar, SCREEN_W, bar), Color.BLACK)

	# WASTED text: zoom-in + fade-in
	var ta = clampf((wasted_timer - 0.25) / 0.5, 0.0, 1.0)

	if ta <= 0.0:
		return

	var s = 1.0 + 0.5 * (1.0 - ta) * (1.0 - ta)

	var font: Font = ThemeDB.fallback_font

	if title_font != null:
		font = title_font

	var center = Vector2(SCREEN_W * 0.5, 200.0)

	draw_set_transform(center, 0.0, Vector2(s, s))

	var left = -SCREEN_W * 0.5

	# Shadow
	draw_string(
		font,
		Vector2(left + 6, 6),
		"WASTED",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_W,
		130,
		Color(0, 0, 0, 0.7 * ta)
	)

	# Outline
	draw_string_outline(
		font,
		Vector2(left, 0),
		"WASTED",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_W,
		130,
		14,
		Color(0, 0, 0, ta)
	)

	# Red fill
	draw_string(
		font,
		Vector2(left, 0),
		"WASTED",
		HORIZONTAL_ALIGNMENT_CENTER,
		SCREEN_W,
		130,
		Color(WASTED_RED.r, WASTED_RED.g, WASTED_RED.b, ta)
	)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ==================================================
# GRAPHICS - HUD
# ==================================================

func draw_hud():

	if game_state != "playing" and game_state != "paused":
		return

	# Top panel
	draw_rect(
		Rect2(0, 0, SCREEN_W, 65),
		Color("#10182f")
	)

	# Bottom border
	draw_rect(
		Rect2(0, 63, SCREEN_W, 2),
		Color(0.2, 0.75, 1.0, 0.5)
	)

	var font = ThemeDB.fallback_font

	# Game name
	draw_string(
		font,
		Vector2(25, 40),
		"REBOUND",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		25,
		CYAN
	)

	# Score
	draw_string(
		font,
		Vector2(400, 40),
		"SCORE: " + str(score),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		22,
		WHITE
	)

	# Bounce counter
	draw_string(
		font,
		Vector2(700, 40),
		"BOUNCES: " + str(bounce_count),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		19,
		PURPLE
	)

	# Turbo bar (bottom center)
	var bar_x = 330.0
	var bar_y = 508.0
	var bar_w = 300.0
	var bar_h = 12.0

	var fill = float(charge_bounces) / float(TURBO_BOUNCES_NEEDED)

	if charged:
		fill = 1.0

	draw_rect(
		Rect2(bar_x, bar_y, bar_w, bar_h),
		Color(0.05, 0.1, 0.25, 0.85)
	)

	draw_rect(
		Rect2(bar_x, bar_y, bar_w * fill, bar_h),
		ULTRA if charged else CYAN
	)

	draw_rect(
		Rect2(bar_x, bar_y, bar_w, bar_h),
		ULTRA_GLOW if charged else Color("#245477"),
		false,
		2.0
	)

	if charged:

		var blink = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012)

		draw_string(
			font,
			Vector2(bar_x, bar_y - 8),
			"PRESS W - TURBO READY!",
			HORIZONTAL_ALIGNMENT_CENTER,
			bar_w,
			18,
			Color(ULTRA_GLOW.r, ULTRA_GLOW.g, ULTRA_GLOW.b, blink)
		)

	else:

		draw_string(
			font,
			Vector2(bar_x, bar_y - 8),
			"TURBO  " + str(charge_bounces) + "/" + str(TURBO_BOUNCES_NEEDED),
			HORIZONTAL_ALIGNMENT_CENTER,
			bar_w,
			15,
			Color("#8aa4d6")
		)


# ==================================================
# FINAL DRAW FUNCTION
# ==================================================

func _draw():

	draw_background()

	if game_state == "menu" or game_state == "instructions":

		draw_menu_scene()

	if game_state == "playing" or game_state == "paused" or game_state == "lost":

		draw_platforms()

		draw_particles()

		draw_trail()

		draw_player()

	draw_danger()

	draw_hud()

	draw_wasted()
