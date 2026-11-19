extends Node3D

const LANE_WIDTH := 2.5
const FORWARD_SPEED := 13.0
const TRACK_LENGTH := 180.0

var player_z := 0.0
var lane := 0
var target_x := 0.0
var vertical_velocity := 0.0
var jumping := false
var sliding := false
var slide_time := 0.0
var score := 0
var distance_accumulator := 0.0
var game_over := false
var touch_start := Vector2.ZERO
var touch_active := false

var player: Node3D
var player_body: MeshInstance3D
var camera: Camera3D
var score_label: Label
var hint_label: Label
var world_root: Node3D

func _ready() -> void:
    _build_world()
    _build_player()
    _build_ui()
    _build_camera()

func _build_world() -> void:
    world_root = Node3D.new()
    world_root.name = "World"
    add_child(world_root)
    var ground := _box("Ground", Vector3(9.0, 0.4, TRACK_LENGTH), Vector3(0, -0.35, -TRACK_LENGTH * 0.42), Color(0.18, 0.20, 0.18))
    world_root.add_child(ground)
    for side in [-1, 1]:
        var curb := _box("Curb", Vector3(0.22, 0.22, TRACK_LENGTH), Vector3(side * 4.6, -0.12, -TRACK_LENGTH * 0.42), Color(0.72, 0.58, 0.25))
        world_root.add_child(curb)
        for i in range(12):
            var z := -8.0 - float(i) * 14.0
            var h := 7.0 + float((i * 7) % 9)
            var building := _box("DistantBlock", Vector3(5.0, h, 7.0), Vector3(side * (9.0 + float(i % 3) * 2.0), h * 0.5 - 0.2, z), Color(0.34, 0.36, 0.32))
            world_root.add_child(building)
            var stripe := _box("FacadeStripe", Vector3(5.05, 0.18, 0.16), Vector3(side * (9.0 + float(i % 3) * 2.0), h * 0.65, z - 3.58), Color(0.72, 0.23, 0.12))
            world_root.add_child(stripe)
    for i in range(35):
        var z := -12.0 - float(i) * 4.6
        var line := _box("LaneMark", Vector3(0.055, 0.018, 2.0), Vector3(0, -0.13, z), Color(0.78, 0.72, 0.48))
        world_root.add_child(line)
    for i in range(16):
        var z := -18.0 - float(i) * 10.0
        var lane_index := (i * 7 + 1) % 3 - 1
        if i % 3 == 0:
            var token := _cylinder("Token", 0.42, 0.12, Vector3(lane_index * LANE_WIDTH, 1.15, z), Color(0.95, 0.68, 0.16))
            world_root.add_child(token)
        else:
            var obstacle := _box("Obstacle", Vector3(1.35, 1.25, 1.0), Vector3(lane_index * LANE_WIDTH, 0.45, z), Color(0.42, 0.24, 0.15))
            world_root.add_child(obstacle)

func _build_player() -> void:
    player = Node3D.new()
    player.name = "Player"
    add_child(player)
    player_body = MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.48
    mesh.height = 1.9
    player_body.mesh = mesh
    player_body.position.y = 1.0
    player_body.material_override = _material(Color(0.72, 0.70, 0.58))
    player.add_child(player_body)
    var chest := _box("ChestPlate", Vector3(0.62, 0.48, 0.18), Vector3(0, 1.25, -0.37), Color(0.18, 0.24, 0.20))
    player.add_child(chest)
    player.position = Vector3(0, 0, 3)

func _build_camera() -> void:
    camera = Camera3D.new()
    camera.position = Vector3(0, 5.0, 10.5)
    camera.rotation_degrees = Vector3(-17, 0, 0)
    camera.current = true
    add_child(camera)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := ColorRect.new()
    panel.color = Color(0.035, 0.045, 0.04, 0.78)
    panel.position = Vector2(18, 18)
    panel.size = Vector2(280, 86)
    layer.add_child(panel)
    score_label = Label.new()
    score_label.position = Vector2(34, 28)
    score_label.add_theme_font_size_override("font_size", 30)
    score_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
    layer.add_child(score_label)
    hint_label = Label.new()
    hint_label.text = "СВАЙПЫ: ← →   ПРЫЖОК: ↑   ПОДКАТ: ↓"
    hint_label.position = Vector2(18, 1160)
    hint_label.add_theme_font_size_override("font_size", 17)
    hint_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.72))
    layer.add_child(hint_label)
    _update_score()

func _process(delta: float) -> void:
    if game_over:
        return
    player_z -= FORWARD_SPEED * delta
    target_x = float(lane) * LANE_WIDTH
    player.position.x = lerp(player.position.x, target_x, min(delta * 12.0, 1.0))
    player.position.z = 3.0
    if jumping:
        vertical_velocity -= 22.0 * delta
        player.position.y += vertical_velocity * delta
        if player.position.y <= 0.0:
            player.position.y = 0.0
            jumping = false
            vertical_velocity = 0.0
    if sliding:
        slide_time -= delta
        if slide_time <= 0.0:
            sliding = false
            player_body.scale = Vector3.ONE
    world_root.position.z = -player_z
    camera.position.x = lerp(camera.position.x, player.position.x * 0.35, delta * 3.0)
    distance_accumulator += FORWARD_SPEED * delta
    score = int(distance_accumulator)
    _check_pickups_and_obstacles()
    _update_score()
    if abs(player_z) > TRACK_LENGTH - 20.0:
        player_z = 0.0

func _check_pickups_and_obstacles() -> void:
    for item in world_root.get_children():
        if not item is MeshInstance3D:
            continue
        if item.name != "Token" and item.name != "Obstacle":
            continue
        var dz := abs(item.global_position.z - player.global_position.z)
        var dx := abs(item.global_position.x - player.global_position.x)
        if dz < 1.0 and dx < 0.95:
            if item.name == "Token":
                score += 25
                distance_accumulator = float(score)
                item.queue_free()
            elif player.position.y < 0.45 and not sliding:
                _end_run()
            elif player.position.y < 0.45 and not jumping:
                _end_run()

func _end_run() -> void:
    game_over = true
    hint_label.text = "ЗАБЕГ ОКОНЧЕН  •  ЖЕТОНЫ: %06d" % score

func _input(event: InputEvent) -> void:
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
        if delta.x > 0:
            lane = min(lane + 1, 1)
        else:
            lane = max(lane - 1, -1)
    elif delta.y < 0:
        _jump()
    else:
        _slide()

func _jump() -> void:
    if not jumping:
        jumping = true
        vertical_velocity = 9.0
        player_body.scale = Vector3(0.9, 1.08, 0.9)

func _slide() -> void:
    if not jumping:
        sliding = true
        slide_time = 0.75
        player_body.scale = Vector3(1.15, 0.48, 1.0)

func _update_score() -> void:
    if is_instance_valid(score_label):
        score_label.text = "ЖЕТОНЫ  ₽  %06d" % score

func _box(label: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = pos
    node.material_override = _material(color)
    return node

func _cylinder(label: String, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    node.mesh = mesh
    node.position = pos
    node.material_override = _material(color)
    return node

func _material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.82
    return mat
