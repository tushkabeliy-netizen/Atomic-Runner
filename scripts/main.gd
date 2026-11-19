extends Node3D

const LANE_WIDTH := 2.5
const FORWARD_SPEED := 13.0
const PLAYER_Z := 3.0
const SPAWN_AHEAD := 115.0
const SCENERY_RECYCLE_DISTANCE := 18.0
const SCENERY_RECYCLE_LENGTH := 330.0
const DESPAWN_BEHIND := 12.0
const GRAVITY := 24.0
const JUMP_VELOCITY := 10.0

var lane := 0
var vertical_velocity := 0.0
var jumping := false
var sliding := false
var slide_time := 0.0
var score := 0
var tokens := 0
var distance := 0.0
var game_over := false
var paused := false
var menu_open := false
var menu_layer: CanvasLayer
var pause_label: Label
var touch_start := Vector2.ZERO
var touch_active := false
var spawn_distance := 0.0
var rng := RandomNumberGenerator.new()

var player: Node3D
var player_body: MeshInstance3D
var camera: Camera3D
var score_label: Label
var status_label: Label
var world_root: Node3D
var road_chunks: Array[Node3D] = []
const CHUNK_LENGTH := 80.0
const CHUNK_COUNT := 12
var token_material: StandardMaterial3D
var obstacle_material: StandardMaterial3D
var arm_left: MeshInstance3D
var arm_right: MeshInstance3D
var leg_left: MeshInstance3D
var leg_right: MeshInstance3D

func _ready() -> void:
    rng.randomize()
    token_material = _material(Color(1.0, 0.68, 0.12), true)
    obstacle_material = _material(Color(0.42, 0.22, 0.13))
    _build_world()
    _build_player()
    _build_camera()
    _build_ui()
    _spawn_initial_course()
    _build_menu()
    spawn_distance = 0.0

func _build_world() -> void:
    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.018, 0.055, 0.075)
    sky_material.sky_horizon_color = Color(0.78, 0.34, 0.19)
    sky_material.ground_bottom_color = Color(0.035, 0.045, 0.045)
    sky_material.ground_horizon_color = Color(0.24, 0.15, 0.12)
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.9
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.glow_enabled = true
    environment.glow_intensity = 0.48
    environment.glow_strength = 0.65
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.52, 0.29, 0.2)
    environment.fog_density = 0.004
    environment_node.environment = environment
    add_child(environment_node)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-42, -28, 0)
    sun.light_energy = 1.4
    sun.shadow_enabled = true
    add_child(sun)
    world_root = Node3D.new()
    world_root.name = "World"
    add_child(world_root)
    for i in range(CHUNK_COUNT):
        var chunk := _build_road_chunk(i)
        chunk.position.z = -float(i) * CHUNK_LENGTH
        world_root.add_child(chunk)
        road_chunks.append(chunk)

func _build_road_chunk(index: int) -> Node3D:
    var chunk := Node3D.new()
    chunk.name = "RoadChunk"
    var road_mat := _material(Color(0.105, 0.125, 0.12))
    var curb_mat := _material(Color(0.68, 0.43, 0.19))
    var concrete := Color(0.34, 0.34, 0.29)
    var glass := Color(0.035, 0.105, 0.12)
    var lit_glass := Color(0.92, 0.49, 0.22)
    _box(chunk, "Road surface", Vector3(9.0, 0.36, CHUNK_LENGTH + 0.2), Vector3(0, -0.22, -CHUNK_LENGTH * 0.5), Color(0.105, 0.125, 0.12))
    for side in [-1, 1]:
        _box(chunk, "Gold curb", Vector3(0.22, 0.22, CHUNK_LENGTH), Vector3(float(side) * 4.62, -0.08, -CHUNK_LENGTH * 0.5), Color(0.68, 0.43, 0.19))
        for dash in range(10):
            _box(chunk, "Lane dash", Vector3(0.055, 0.026, 2.5), Vector3(float(side) * 1.25, -0.015, -4.0 - float(dash) * 8.0), Color(0.78, 0.7, 0.51))
        var building_x := float(side) * 8.2
        var height := 13.0 + float((index * 7 + side * 3) % 8)
        _box(chunk, "Art deco building", Vector3(6.4, height, 18.0), Vector3(building_x, height * 0.5 - 0.1, -CHUNK_LENGTH * 0.5), concrete)
        _box(chunk, "Building cornice", Vector3(6.7, 0.42, 18.3), Vector3(building_x, height - 0.05, -CHUNK_LENGTH * 0.5), Color(0.61, 0.48, 0.31))
        _box(chunk, "Building base", Vector3(6.55, 0.7, 18.2), Vector3(building_x, 0.35, -CHUNK_LENGTH * 0.5), Color(0.22, 0.24, 0.21))
        for row in range(4):
            for col in range(3):
                var wx := building_x + float(col - 1) * 1.85
                var wy := 2.1 + float(row) * 2.55
                var wz := -CHUNK_LENGTH * 0.5 + 9.08
                _box(chunk, "Window recess", Vector3(1.12, 1.62, 0.16), Vector3(wx, wy, wz), Color(0.12, 0.14, 0.13))
                var pane := lit_glass if ((index * 5 + row * 3 + col) % 7 == 0) else glass
                _box(chunk, "Illuminated window", Vector3(0.86, 1.34, 0.07), Vector3(wx, wy, wz + 0.1), pane)
                _box(chunk, "Window divider", Vector3(0.07, 1.34, 0.08), Vector3(wx, wy, wz + 0.15), Color(0.53, 0.45, 0.31))
        if index % 3 == 0:
            _box(chunk, "Red propaganda banner", Vector3(1.4, 3.4, 0.22), Vector3(building_x - float(side) * 2.2, height * 0.56, -CHUNK_LENGTH * 0.5 + 9.2), Color(0.55, 0.105, 0.055))
            _box(chunk, "Banner emblem", Vector3(0.65, 0.65, 0.08), Vector3(building_x - float(side) * 2.2, height * 0.56, -CHUNK_LENGTH * 0.5 + 9.35), Color(0.93, 0.66, 0.3))
        var lamp_x := float(side) * 5.25
        _box(chunk, "Street lamp", Vector3(0.13, 5.2, 0.13), Vector3(lamp_x, 2.6, -12.0), Color(0.13, 0.17, 0.15))
        _box(chunk, "Lamp housing", Vector3(0.85, 0.5, 0.72), Vector3(lamp_x, 5.1, -12.0), Color(0.92, 0.58, 0.25))
        _box(chunk, "Lamp cap", Vector3(1.05, 0.13, 0.92), Vector3(lamp_x, 5.4, -12.0), Color(0.16, 0.19, 0.17))
        _box(chunk, "Pipe", Vector3(0.16, 4.5, 0.16), Vector3(float(side) * 5.0, 2.25, -48.0), Color(0.34, 0.25, 0.17))
    # A distant industrial silhouette keeps the avenue broad rather than corridor-like.
    _box(chunk, "Distant factory", Vector3(17.0, 20.0, 9.0), Vector3(-22.0, 10.0, -CHUNK_LENGTH * 0.5), Color(0.19, 0.23, 0.22))
    _box(chunk, "Factory chimney", Vector3(2.2, 28.0, 2.2), Vector3(23.0, 14.0, -CHUNK_LENGTH * 0.5 - 3.0), Color(0.29, 0.25, 0.2))
    return chunk

func _build_city_detail() -> void:
    # City scenery is generated as reusable road chunks in _build_road_chunk().

func _build_player() -> void:
    player = Node3D.new()
    player.name = "Player"
    add_child(player)
    player_body = MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.36
    capsule.height = 1.42
    player_body.mesh = capsule
    player_body.position.y = 1.05
    player_body.material_override = _material(Color(0.68, 0.69, 0.58))
    player.add_child(player_body)
    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.29
    head_mesh.height = 0.58
    head.mesh = head_mesh
    head.position = Vector3(0, 1.98, 0)
    head.material_override = _material(Color(0.72, 0.7, 0.58))
    player.add_child(head)
    _sphere_part(player, "Helmet shell", Vector3(0.35, 0.27, 0.35), Vector3(0, 2.22, 0.01), Color(0.19, 0.27, 0.23))
    _sphere_part(player, "Helmet brow", Vector3(0.34, 0.07, 0.31), Vector3(0, 2.12, -0.08), Color(0.42, 0.39, 0.28))
    _sphere_part(player, "Helmet visor", Vector3(0.22, 0.105, 0.075), Vector3(0, 2.03, -0.265), Color(0.07, 0.19, 0.22))
    _sphere_part(player, "Armored chest", Vector3(0.43, 0.43, 0.17), Vector3(0, 1.31, -0.31), Color(0.15, 0.23, 0.19))
    _sphere_part(player, "Chest insignia", Vector3(0.13, 0.13, 0.045), Vector3(0, 1.42, -0.47), Color(0.78, 0.18, 0.1))
    _sphere_part(player, "Left shoulder armor", Vector3(0.24, 0.23, 0.25), Vector3(-0.48, 1.48, -0.01), Color(0.25, 0.31, 0.26))
    _sphere_part(player, "Right shoulder armor", Vector3(0.24, 0.23, 0.25), Vector3(0.48, 1.48, -0.01), Color(0.25, 0.31, 0.26))
    arm_left = _capsule_part(player, "Left arm", 0.145, 0.82, Vector3(-0.5, 1.12, 0.0), Color(0.48, 0.53, 0.45))
    arm_right = _capsule_part(player, "Right arm", 0.145, 0.82, Vector3(0.5, 1.12, 0.0), Color(0.48, 0.53, 0.45))
    _sphere_part(player, "Left glove", Vector3(0.15, 0.15, 0.15), Vector3(-0.5, 0.66, -0.015), Color(0.12, 0.16, 0.14))
    _sphere_part(player, "Right glove", Vector3(0.15, 0.15, 0.15), Vector3(0.5, 0.66, -0.015), Color(0.12, 0.16, 0.14))
    leg_left = _capsule_part(player, "Left leg", 0.17, 0.82, Vector3(-0.19, 0.39, 0.02), Color(0.21, 0.28, 0.24))
    leg_right = _capsule_part(player, "Right leg", 0.17, 0.82, Vector3(0.19, 0.39, 0.02), Color(0.21, 0.28, 0.24))
    _sphere_part(player, "Left knee plate", Vector3(0.16, 0.14, 0.09), Vector3(-0.19, 0.48, -0.16), Color(0.46, 0.42, 0.31))
    _sphere_part(player, "Right knee plate", Vector3(0.16, 0.14, 0.09), Vector3(0.19, 0.48, -0.16), Color(0.46, 0.42, 0.31))
    _box(player, "Left boot", Vector3(0.31, 0.18, 0.48), Vector3(-0.19, 0.09, -0.09), Color(0.12, 0.15, 0.13))
    _box(player, "Right boot", Vector3(0.31, 0.18, 0.48), Vector3(0.19, 0.09, -0.09), Color(0.12, 0.15, 0.13))
    _box(player, "Backpack", Vector3(0.52, 0.62, 0.28), Vector3(0, 1.2, 0.34), Color(0.19, 0.25, 0.21))
    _box(player, "Backpack canister", Vector3(0.16, 0.48, 0.17), Vector3(0.31, 1.2, 0.38), Color(0.48, 0.35, 0.18))
    _box(player, "Utility belt", Vector3(0.62, 0.12, 0.3), Vector3(0, 0.82, -0.015), Color(0.12, 0.16, 0.14))
    player.position = Vector3(0, 0, PLAYER_Z)

func _build_camera() -> void:
    camera = Camera3D.new()
    camera.position = Vector3(0, 5.2, 10.8)
    camera.rotation_degrees = Vector3(-18, 0, 0)
    camera.current = true
    add_child(camera)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := ColorRect.new()
    panel.color = Color(0.025, 0.04, 0.035, 0.82)
    panel.position = Vector2(16, 16)
    panel.size = Vector2(310, 92)
    layer.add_child(panel)
    score_label = Label.new()
    score_label.position = Vector2(30, 25)
    score_label.add_theme_font_size_override("font_size", 28)
    score_label.add_theme_color_override("font_color", Color(0.98, 0.76, 0.3))
    layer.add_child(score_label)
    status_label = Label.new()
    status_label.position = Vector2(20, 1110)
    status_label.size = Vector2(680, 140)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 19)
    status_label.add_theme_color_override("font_color", Color(0.94, 0.88, 0.72))
    status_label.text = "СВАЙП ← →  •  ПРЫЖОК ↑  •  ПОДКАТ ↓"
    layer.add_child(status_label)
    pause_label = Label.new()
    pause_label.position = Vector2(610, 24)
    pause_label.size = Vector2(90, 54)
    pause_label.text = "Ⅱ"
    pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_label.add_theme_font_size_override("font_size", 36)
    pause_label.add_theme_color_override("font_color", Color(0.98, 0.76, 0.3))
    layer.add_child(pause_label)
    _update_score()

func _build_menu() -> void:
    menu_open = true
    paused = true
    menu_layer = CanvasLayer.new()
    menu_layer.layer = 10
    add_child(menu_layer)
    var shade := ColorRect.new()
    shade.anchor_right = 1.0
    shade.anchor_bottom = 1.0
    shade.color = Color(0.012, 0.025, 0.026, 0.88)
    menu_layer.add_child(shade)
    var top_line := ColorRect.new()
    top_line.position = Vector2(76, 292)
    top_line.size = Vector2(568, 3)
    top_line.color = Color(0.78, 0.34, 0.13)
    menu_layer.add_child(top_line)
    var title := Label.new()
    title.position = Vector2(42, 330)
    title.size = Vector2(636, 100)
    title.text = "ATOMIC RUNNER"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 54)
    title.add_theme_color_override("font_color", Color(0.94, 0.77, 0.49))
    menu_layer.add_child(title)
    var subtitle := Label.new()
    subtitle.position = Vector2(60, 430)
    subtitle.size = Vector2(600, 60)
    subtitle.text = "ПРОТОКОЛ «БЕСКОНЕЧНЫЙ МАРШРУТ»"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 19)
    subtitle.add_theme_color_override("font_color", Color(0.72, 0.65, 0.5))
    menu_layer.add_child(subtitle)
    var divider := ColorRect.new()
    divider.position = Vector2(170, 520)
    divider.size = Vector2(380, 2)
    divider.color = Color(0.48, 0.31, 0.19, 0.9)
    menu_layer.add_child(divider)
    var description := Label.new()
    description.position = Vector2(90, 555)
    description.size = Vector2(540, 110)
    description.text = "ПРОБЕГИ ЧЕРЕЗ ГОРОД\nСОБИРАЙ ЖЕТОНЫ  •  ИЗБЕГАЙ ПРЕПЯТСТВИЙ"
    description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    description.add_theme_font_size_override("font_size", 18)
    description.add_theme_color_override("font_color", Color(0.82, 0.81, 0.72))
    menu_layer.add_child(description)
    var start_button := Button.new()
    start_button.position = Vector2(115, 730)
    start_button.size = Vector2(490, 88)
    start_button.text = "НАЧАТЬ ЗАБЕГ"
    start_button.add_theme_font_size_override("font_size", 27)
    start_button.add_theme_color_override("font_color", Color(0.98, 0.9, 0.72))
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.42, 0.13, 0.075, 0.98)
    normal.border_color = Color(0.91, 0.54, 0.25)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(5)
    start_button.add_theme_stylebox_override("normal", normal)
    var hover := StyleBoxFlat.new()
    hover.bg_color = Color(0.58, 0.2, 0.09, 1.0)
    hover.border_color = Color(1.0, 0.72, 0.36)
    hover.set_border_width_all(2)
    hover.set_corner_radius_all(5)
    start_button.add_theme_stylebox_override("hover", hover)
    start_button.pressed.connect(_start_run)
    menu_layer.add_child(start_button)
    var footer := Label.new()
    footer.position = Vector2(70, 930)
    footer.size = Vector2(580, 60)
    footer.text = "СОВЕТСКИЙ РЕТРОФУТУРИЗМ  •  1955"
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_font_size_override("font_size", 15)
    footer.add_theme_color_override("font_color", Color(0.52, 0.49, 0.4))
    menu_layer.add_child(footer)

func _start_run() -> void:
    if is_instance_valid(menu_layer):
        menu_layer.queue_free()
    menu_open = false
    paused = false
    status_label.text = "СВАЙП ← →  •  ПРЫЖОК ↑  •  ПОДКАТ ↓"

func _spawn_initial_course() -> void:
    for i in range(18):
        _spawn_obstacle_row(-22.0 - float(i) * 13.0)

func _spawn_obstacle_row(z: float) -> void:
    var chosen_lane := rng.randi_range(-1, 1)
    var kind := rng.randi_range(0, 4)
    if kind == 0:
        _spawn_token_line(chosen_lane, z)
    elif kind == 1:
        _spawn_barrier(chosen_lane, z)
    elif kind == 2:
        _spawn_token_line(chosen_lane, z)
        _spawn_barrier(-chosen_lane if chosen_lane != 0 else 1, z - 1.0)
    elif kind == 3:
        _spawn_low_barrier(chosen_lane, z)
    else:
        _spawn_token_line(chosen_lane, z)
        _spawn_token_line(chosen_lane, z - 2.5)

func _spawn_token_line(lane_index: int, z: float) -> void:
    for i in range(3):
        var token := MeshInstance3D.new()
        token.name = "Token"
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.36
        mesh.bottom_radius = 0.36
        mesh.height = 0.12
        token.mesh = mesh
        token.material_override = token_material
        token.position = Vector3(float(lane_index) * LANE_WIDTH, 1.15, z - float(i) * 2.0)
        world_root.add_child(token)

func _spawn_barrier(lane_index: int, z: float) -> void:
    _box(world_root, "Obstacle", Vector3(1.35, 1.35, 1.0), Vector3(float(lane_index) * LANE_WIDTH, 0.62, z), Color(0.42, 0.22, 0.13))

func _spawn_low_barrier(lane_index: int, z: float) -> void:
    _box(world_root, "LowObstacle", Vector3(1.55, 0.65, 1.0), Vector3(float(lane_index) * LANE_WIDTH, 1.35, z), Color(0.34, 0.37, 0.34))

func _process(delta: float) -> void:
    if game_over or paused:
        return
    distance += FORWARD_SPEED * delta
    score = int(distance) + tokens * 25
    world_root.position.z = distance
    player.position.x = lerp(player.position.x, float(lane) * LANE_WIDTH, min(delta * 13.0, 1.0))
    if jumping:
        vertical_velocity -= GRAVITY * delta
        player.position.y += vertical_velocity * delta
        if player.position.y <= 0.0:
            player.position.y = 0.0
            vertical_velocity = 0.0
            jumping = false
            player_body.scale = Vector3.ONE
    if sliding:
        slide_time -= delta
        if slide_time <= 0.0:
            sliding = false
            player_body.scale = Vector3.ONE
    camera.position.x = lerp(camera.position.x, player.position.x * 0.28, delta * 3.0)
    if not jumping and not sliding:
        var run_swing := sin(distance * 0.72) * 0.42
        arm_left.rotation.x = run_swing
        arm_right.rotation.x = -run_swing
        leg_left.rotation.x = -run_swing * 0.8
        leg_right.rotation.x = run_swing * 0.8
    else:
        arm_left.rotation.x = 0.0
        arm_right.rotation.x = 0.0
        leg_left.rotation.x = 0.0
        leg_right.rotation.x = 0.0
    spawn_distance += FORWARD_SPEED * delta
    if distance >= 243.0 and spawn_distance >= 13.0:
        spawn_distance = 0.0
        _spawn_obstacle_row(PLAYER_Z - world_root.position.z - SPAWN_AHEAD)
    _recycle_scenery()
    _check_items()
    _cleanup_items()
    _update_score()

func _recycle_scenery() -> void:
    for chunk in road_chunks:
        var world_z := chunk.position.z + world_root.position.z
        if world_z > CHUNK_LENGTH:
            chunk.position.z -= CHUNK_LENGTH * float(CHUNK_COUNT)

func _check_items() -> void:
    for item in world_root.get_children():
        if not item is MeshInstance3D:
            continue
        if item.name != "Token" and item.name != "Obstacle" and item.name != "LowObstacle":
            continue
        var relative_z: float = item.position.z + world_root.position.z
        var dx: float = absf(item.position.x - player.position.x)
        if abs(relative_z - PLAYER_Z) < 1.0 and dx < 0.95:
            if item.name == "Token":
                tokens += 1
                score = int(distance) + tokens * 25
                item.queue_free()
            elif item.name == "Obstacle" and player.position.y < 0.55 and not sliding:
                _end_run()
                return
            elif item.name == "LowObstacle" and not sliding:
                _end_run()
                return

func _cleanup_items() -> void:
    for item in world_root.get_children():
        if item is MeshInstance3D and (item.name == "Token" or item.name == "Obstacle" or item.name == "LowObstacle"):
            if item.position.z + world_root.position.z > PLAYER_Z + DESPAWN_BEHIND:
                item.queue_free()

func _end_run() -> void:
    game_over = true
    status_label.text = "ЗАБЕГ ОКОНЧЕН  •  ЖЕТОНЫ: %06d\nНажми, чтобы начать заново" % score

func _restart() -> void:
    for item in world_root.get_children():
        if item.name == "Token" or item.name == "Obstacle" or item.name == "LowObstacle":
            item.queue_free()
    lane = 0
    player.position = Vector3(0, 0, PLAYER_Z)
    player_body.scale = Vector3.ONE
    jumping = false
    sliding = false
    vertical_velocity = 0.0
    slide_time = 0.0
    score = 0
    tokens = 0
    distance = 0.0
    spawn_distance = 0.0
    world_root.position.z = 0.0
    game_over = false
    paused = false
    pause_label.text = "Ⅱ"
    status_label.text = "СВАЙП ← →  •  ПРЫЖОК ↑  •  ПОДКАТ ↓"
    _spawn_initial_course()
    _update_score()

func _input(event: InputEvent) -> void:
    if menu_open:
        return
    if event is InputEventScreenTouch and event.pressed and event.position.x > 590.0 and event.position.y < 100.0 and not game_over:
        _toggle_pause()
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not game_over:
        _toggle_pause()
        return
    if game_over:
        if event is InputEventScreenTouch and event.pressed:
            _restart()
        elif event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
            _restart()
        return
    if paused:
        if event is InputEventScreenTouch and event.pressed:
            _toggle_pause()
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_start = event.position
            touch_active = true
        elif touch_active:
            _handle_swipe(event.position - touch_start)
            touch_active = false
    elif event is InputEventScreenDrag and touch_active:
        var diff: Vector2 = event.position - touch_start
        if diff.length() > 75.0:
            _handle_swipe(diff)
            touch_active = false
    elif event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_LEFT: lane = max(lane - 1, -1)
            KEY_RIGHT: lane = min(lane + 1, 1)
            KEY_UP: _jump()
            KEY_DOWN: _slide()

func _handle_swipe(delta: Vector2) -> void:
    if abs(delta.x) > abs(delta.y):
        lane = clampi(lane + (1 if delta.x > 0 else -1), -1, 1)
    elif delta.y < 0:
        _jump()
    else:
        _slide()

func _toggle_pause() -> void:
    paused = not paused
    pause_label.text = "▶" if paused else "Ⅱ"
    status_label.text = "ПАУЗА  •  НАЖМИ ▶ ДЛЯ ПРОДОЛЖЕНИЯ" if paused else "СВАЙП ← →  •  ПРЫЖОК ↑  •  ПОДКАТ ↓"

func _jump() -> void:
    if not jumping and not sliding:
        jumping = true
        vertical_velocity = JUMP_VELOCITY
        player_body.scale = Vector3(0.9, 1.08, 0.9)

func _slide() -> void:
    if not jumping:
        sliding = true
        slide_time = 0.8
        player_body.scale = Vector3(1.12, 0.48, 1.0)

func _update_score() -> void:
    if is_instance_valid(score_label):
        score_label.text = "ЖЕТОНЫ  ₽  %06d" % score

func _sphere_part(parent: Node, label: String, dimensions: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    var mesh := SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    node.mesh = mesh
    node.scale = dimensions
    node.position = pos
    node.material_override = _material(color)
    parent.add_child(node)
    return node

func _capsule_part(parent: Node, label: String, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    node.mesh = mesh
    node.position = pos
    node.material_override = _material(color)
    parent.add_child(node)
    return node

func _box(parent: Node, label: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = pos
    node.material_override = _material(color)
    parent.add_child(node)
    return node

func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.78
    if glow:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 0.7
    return mat
