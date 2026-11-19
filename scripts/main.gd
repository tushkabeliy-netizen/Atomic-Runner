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

func _ready() -> void:
    rng.randomize()
    token_material = _material(Color(1.0, 0.68, 0.12), true)
    obstacle_material = _material(Color(0.42, 0.22, 0.13))
    _build_world()
    _build_player()
    _build_camera()
    _build_ui()
    _spawn_initial_course()

func _build_world() -> void:
    world_root = Node3D.new()
    world_root.name = "World"
    add_child(world_root)
    _box(world_root, "Road", Vector3(9.0, 0.35, 10000.0), Vector3(0, -0.22, -4900.0), Color(0.13, 0.15, 0.14))
    for side in [-1, 1]:
        _box(world_root, "Gold curb", Vector3(0.22, 0.2, 10000.0), Vector3(side * 4.6, -0.08, -4900.0), Color(0.72, 0.54, 0.2))
        for i in range(30):
            var z := -8.0 - float(i) * 11.0
            var h := 9.0 + float((i * 7) % 12)
            var x := side * (9.0 + float(i % 3) * 3.2)
            _box(world_root, "Soviet city block", Vector3(5.5, h, 7.5), Vector3(x, h * 0.5 - 0.1, z), Color(0.29, 0.32, 0.29))
            _box(world_root, "Facade band", Vector3(5.56, 0.22, 0.12), Vector3(x, h * 0.68, z - 3.82), Color(0.66, 0.22, 0.13))
            if i % 4 == 0:
                _box(world_root, "Monument plinth", Vector3(2.0, 1.0, 2.0), Vector3(side * 6.4, 0.5, z - 2.0), Color(0.42, 0.42, 0.37))
    for i in range(2000):
        _box(world_root, "Lane dash", Vector3(0.055, 0.025, 2.0), Vector3(0, -0.025, -float(i) * 4.8), Color(0.75, 0.69, 0.48))

func _build_player() -> void:
    player = Node3D.new()
    player.name = "Player"
    add_child(player)
    player_body = MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.43
    capsule.height = 1.8
    player_body.mesh = capsule
    player_body.position.y = 0.92
    player_body.material_override = _material(Color(0.68, 0.69, 0.58))
    player.add_child(player_body)
    _box(player, "Armored chest", Vector3(0.62, 0.45, 0.2), Vector3(0, 1.18, -0.34), Color(0.16, 0.23, 0.19))
    _box(player, "Red shoulder marking", Vector3(0.16, 0.18, 0.08), Vector3(0.28, 1.42, -0.42), Color(0.65, 0.13, 0.09))
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
    if game_over:
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
    spawn_distance += FORWARD_SPEED * delta
    if spawn_distance >= 13.0:
        spawn_distance = 0.0
        _spawn_obstacle_row(PLAYER_Z - world_root.position.z - SPAWN_AHEAD)
    _recycle_scenery()
    _check_items()
    _cleanup_items()
    _update_score()

func _recycle_scenery() -> void:
    for item in world_root.get_children():
        if item is MeshInstance3D and (item.name == "Soviet city block" or item.name == "Facade band" or item.name == "Monument plinth"):
            if item.position.z + world_root.position.z > SCENERY_RECYCLE_DISTANCE:
                item.position.z -= SCENERY_RECYCLE_LENGTH

func _check_items() -> void:
    for item in world_root.get_children():
        if not item is MeshInstance3D:
            continue
        if item.name != "Token" and item.name != "Obstacle" and item.name != "LowObstacle":
            continue
        var relative_z := item.position.z + world_root.position.z
        var dx := abs(item.position.x - player.position.x)
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
    status_label.text = "СВАЙП ← →  •  ПРЫЖОК ↑  •  ПОДКАТ ↓"
    _spawn_initial_course()
    _update_score()

func _input(event: InputEvent) -> void:
    if game_over:
        if event is InputEventScreenTouch and event.pressed:
            _restart()
        elif event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
            _restart()
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_start = event.position
            touch_active = true
        elif touch_active:
            _handle_swipe(event.position - touch_start)
            touch_active = false
    elif event is InputEventScreenDrag and touch_active:
        var diff := event.position - touch_start
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
