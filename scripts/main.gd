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
    spawn_distance = 0.0

func _build_world() -> void:
    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.025, 0.075, 0.11)
    sky_material.sky_horizon_color = Color(0.92, 0.43, 0.22)
    sky_material.ground_bottom_color = Color(0.055, 0.075, 0.08)
    sky_material.ground_horizon_color = Color(0.28, 0.19, 0.15)
    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_energy = 0.82
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.glow_enabled = true
    environment.glow_intensity = 0.55
    environment.glow_strength = 0.7
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.58, 0.32, 0.22)
    environment.fog_density = 0.006
    environment_node.environment = environment
    add_child(environment_node)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -28, 0)
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    add_child(sun)
    world_root = Node3D.new()
    world_root.name = "World"
    add_child(world_root)
    _box(world_root, "Road", Vector3(9.0, 0.35, 1000000.0), Vector3(0, -0.22, -499900.0), Color(0.13, 0.15, 0.14))
    for side in [-1, 1]:
        _box(world_root, "Gold curb", Vector3(0.22, 0.2, 1000000.0), Vector3(side * 4.6, -0.08, -499900.0), Color(0.72, 0.54, 0.2))
        for i in range(30):
            var z := -8.0 - float(i) * 11.0
            var h := 9.0 + float((i * 7) % 12)
            var x: float = float(side) * (9.0 + float(i % 3) * 3.2)
            _box(world_root, "Soviet city block", Vector3(5.5, h, 7.5), Vector3(x, h * 0.5 - 0.1, z), Color(0.29, 0.32, 0.29))
            _box(world_root, "Facade band", Vector3(5.56, 0.22, 0.12), Vector3(x, h * 0.68, z - 3.82), Color(0.66, 0.22, 0.13))
            if i % 4 == 0:
                _box(world_root, "Monument plinth", Vector3(2.0, 1.0, 2.0), Vector3(side * 6.4, 0.5, z - 2.0), Color(0.42, 0.42, 0.37))
            if i % 2 == 0:
                _box(world_root, "Street lamp", Vector3(0.12, 4.8, 0.12), Vector3(side * 5.25, 2.4, z - 3.0), Color(0.2, 0.24, 0.22))
                _box(world_root, "Street lamp head", Vector3(0.72, 0.16, 0.32), Vector3(side * 5.25, 4.82, z - 3.0), Color(0.85, 0.72, 0.43))
    for i in range(2000):
        _box(world_root, "Lane dash", Vector3(0.055, 0.025, 2.0), Vector3(0, -0.025, -float(i) * 4.8), Color(0.75, 0.69, 0.48))
    _build_city_detail()

func _build_city_detail() -> void:
    # Add visible facade detail to the camera-facing sides of every avenue block.
    var glass_dark := Color(0.035, 0.095, 0.12)
    var glass_lit := Color(0.95, 0.57, 0.25)
    var concrete := Color(0.56, 0.48, 0.36)
    var red := Color(0.66, 0.13, 0.075)
    for side in [-1, 1]:
        for i in range(30):
            var z := -8.0 - float(i) * 11.0
            var h := 9.0 + float((i * 7) % 12)
            var x: float = float(side) * (9.0 + float(i % 3) * 3.2)
            var front := z + 3.83
            _box(world_root, "Facade cornice", Vector3(5.72, 0.32, 0.24), Vector3(x, h - 0.18, front), concrete)
            _box(world_root, "Facade plinth", Vector3(5.65, 0.48, 0.22), Vector3(x, 0.38, front), Color(0.25, 0.24, 0.2))
            for edge in [-1, 1]:
                _box(world_root, "Facade pilaster", Vector3(0.18, h - 0.9, 0.18), Vector3(x + float(edge) * 2.58, h * 0.5, front + 0.08), concrete)
            var rows := int((h - 2.6) / 2.25)
            for row in range(rows):
                var wy := 1.75 + float(row) * 2.25
                for col in range(3):
                    var wx := x + float(col - 1) * 1.68
                    var pane_color := glass_lit if ((i * 13 + row * 7 + col * 3) % 6 == 0) else glass_dark
                    _box(world_root, "Window frame", Vector3(0.91, 1.38, 0.13), Vector3(wx, wy, front + 0.11), Color(0.17, 0.19, 0.17))
                    _box(world_root, "Window glass", Vector3(0.69, 1.12, 0.055), Vector3(wx, wy + 0.015, front + 0.19), pane_color)
                    _box(world_root, "Window sill", Vector3(1.02, 0.12, 0.25), Vector3(wx, wy - 0.72, front + 0.2), concrete)
                    _box(world_root, "Window mullion", Vector3(0.055, 1.12, 0.07), Vector3(wx, wy, front + 0.235), concrete)
            if i % 5 == 0:
                _box(world_root, "Art deco sign", Vector3(2.25, 0.62, 0.18), Vector3(x, 2.0, front + 0.32), red)
                _box(world_root, "Sign lettering", Vector3(1.62, 0.075, 0.08), Vector3(x, 2.0, front + 0.44), Color(1.0, 0.75, 0.38))
                _box(world_root, "Entrance canopy", Vector3(2.8, 0.16, 1.15), Vector3(x, 3.0, front + 0.55), Color(0.16, 0.2, 0.18))
                for post_x in [-1.1, 1.1]:
                    _box(world_root, "Entrance column", Vector3(0.18, 2.45, 0.18), Vector3(x + post_x, 1.55, front + 0.92), concrete)
        # A layered skyline creates depth and a visible horizon behind the avenue.
        for i in range(18):
            var far_x: float = float(side) * (27.0 + float(i % 4) * 5.5)
            var far_h := 13.0 + float((i * 11) % 25)
            var far_z := -18.0 - float(i) * 18.0
            _box(world_root, "Distant skyline", Vector3(8.0 + float(i % 3) * 2.0, far_h, 10.0), Vector3(far_x, far_h * 0.5, far_z), Color(0.17, 0.22, 0.22))
            _box(world_root, "Distant rooftop", Vector3(8.2 + float(i % 3) * 2.0, 0.28, 10.2), Vector3(far_x, far_h + 0.14, far_z), Color(0.3, 0.26, 0.2))
    # A boulevard rhythm of lanterns, benches and warm pools of light.
    for i in range(24):
        var z := -12.0 - float(i) * 14.0
        var side := -1 if i % 2 == 0 else 1
        var x := float(side) * 5.45
        _box(world_root, "Lantern post", Vector3(0.13, 5.3, 0.13), Vector3(x, 2.65, z), Color(0.12, 0.17, 0.16))
        _box(world_root, "Lantern housing", Vector3(0.78, 0.52, 0.78), Vector3(x, 5.2, z), Color(0.95, 0.61, 0.27))
        _box(world_root, "Lantern cap", Vector3(1.02, 0.13, 1.02), Vector3(x, 5.53, z), Color(0.18, 0.22, 0.19))
        _box(world_root, "Boulevard bench", Vector3(1.65, 0.16, 0.48), Vector3(float(side) * 6.25, 0.58, z - 2.5), Color(0.32, 0.18, 0.11))
        _box(world_root, "Bench leg", Vector3(0.12, 0.52, 0.12), Vector3(float(side) * 5.7, 0.28, z - 2.5), Color(0.16, 0.19, 0.17))
        _box(world_root, "Bench leg", Vector3(0.12, 0.52, 0.12), Vector3(float(side) * 6.8, 0.28, z - 2.5), Color(0.16, 0.19, 0.17))

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
    _box(player, "Helmet", Vector3(0.62, 0.16, 0.62), Vector3(0, 2.22, 0), Color(0.22, 0.29, 0.24))
    _box(player, "Armored chest", Vector3(0.62, 0.48, 0.2), Vector3(0, 1.25, -0.34), Color(0.16, 0.23, 0.19))
    _box(player, "Chest insignia", Vector3(0.22, 0.12, 0.07), Vector3(0, 1.38, -0.46), Color(0.72, 0.16, 0.1))
    _box(player, "Red shoulder marking", Vector3(0.16, 0.18, 0.08), Vector3(0.28, 1.48, -0.42), Color(0.65, 0.13, 0.09))
    arm_left = _box(player, "Left arm", Vector3(0.22, 0.72, 0.24), Vector3(-0.49, 1.16, 0), Color(0.57, 0.59, 0.5))
    arm_right = _box(player, "Right arm", Vector3(0.22, 0.72, 0.24), Vector3(0.49, 1.16, 0), Color(0.57, 0.59, 0.5))
    leg_left = _box(player, "Left leg", Vector3(0.27, 0.72, 0.31), Vector3(-0.19, 0.38, 0.02), Color(0.23, 0.29, 0.25))
    leg_right = _box(player, "Right leg", Vector3(0.27, 0.72, 0.31), Vector3(0.19, 0.38, 0.02), Color(0.23, 0.29, 0.25))
    _box(player, "Backpack", Vector3(0.52, 0.62, 0.28), Vector3(0, 1.2, 0.34), Color(0.19, 0.25, 0.21))
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
    for item in world_root.get_children():
        if not item is MeshInstance3D:
            continue
        var world_z: float = item.position.z + world_root.position.z
        if item.name == "Lane dash":
            if world_z > SCENERY_RECYCLE_DISTANCE:
                item.position.z -= 9600.0
        elif item.name == "Soviet city block" or item.name == "Facade band" or item.name == "Monument plinth" or item.name == "Street lamp" or item.name == "Street lamp head":
            if world_z > SCENERY_RECYCLE_DISTANCE:
                item.position.z -= SCENERY_RECYCLE_LENGTH

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
