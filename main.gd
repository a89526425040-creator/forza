extends Node3D

# Open Horizon — first playable driving prototype.
# The current car is a procedural blockout; the licensed BMW M4 model will replace it later.

var car: CharacterBody3D
var camera: Camera3D
var speed := 0.0
var steering := 0.0
var road_length := 900.0
var ui_speed: Label
var ui_status: Label
var touch_actions := {}

func _ready() -> void:
    _build_world()
    _build_car()
    _build_hud()
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _build_world() -> void:
    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.10, 0.27, 0.48)
    sky_mat.sky_horizon_color = Color(0.58, 0.75, 0.88)
    sky_mat.ground_bottom_color = Color(0.12, 0.16, 0.12)
    sky_mat.ground_horizon_color = Color(0.42, 0.48, 0.39)
    env.sky.sky_material = sky_mat
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.72, 0.78, 0.86)
    env.ambient_light_energy = 0.8
    world_env.environment = env
    add_child(world_env)

    _box("Ground", Vector3(0, -0.7, -road_length * 0.5), Vector3(260, 1, road_length), Color(0.20, 0.31, 0.19), true)
    _box("Road", Vector3(0, -0.12, -road_length * 0.5), Vector3(13, 0.2, road_length), Color(0.12, 0.13, 0.14), true)
    for side in [-1, 1]:
        _box("Road shoulder", Vector3(side * 7.2, -0.08, -road_length * 0.5), Vector3(1.2, 0.22, road_length), Color(0.55, 0.53, 0.45), true)
        _box("Road edge", Vector3(side * 6.35, 0.015, -road_length * 0.5), Vector3(0.12, 0.03, road_length), Color(0.92, 0.91, 0.82), false)
    for z in range(-20, -900, -16):
        _box("Lane marking", Vector3(0, 0.02, z), Vector3(0.18, 0.035, 7), Color(0.95, 0.91, 0.72), false)
    # Distant Alpine-style mountain silhouettes frame the test road.
    for i in range(18):
        var side := -1.0 if i % 2 == 0 else 1.0
        var x := side * randf_range(35.0, 95.0)
        var z := -randf_range(80.0, 850.0)
        var h := randf_range(24.0, 70.0)
        var mountain := _box("Mountain", Vector3(x, h * 0.35 - 0.5, z), Vector3(randf_range(24.0, 55.0), h, randf_range(35.0, 75.0)), Color(0.30, 0.38, 0.40), false)
        mountain.rotation.y = randf_range(-0.5, 0.5)

func _box(n: String, pos: Vector3, size: Vector3, color: Color, collision: bool) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.name = n
    node.mesh = mesh
    node.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.88
    node.material_override = mat
    add_child(node)
    if collision:
        var body := StaticBody3D.new()
        body.name = n + "Body"
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        shape.shape = box
        body.add_child(shape)
        body.position = pos
        add_child(body)
    return node

func _build_car() -> void:
    car = CharacterBody3D.new()
    car.name = "BMW_M4_Blockout"
    car.position = Vector3(0, 0.65, -8)
    add_child(car)
    var car_collision := CollisionShape3D.new()
    var car_shape := BoxShape3D.new()
    car_shape.size = Vector3(1.85, 0.85, 3.9)
    car_collision.shape = car_shape
    car_collision.position = Vector3(0, 0.18, 0)
    car.add_child(car_collision)
    _car_box("Body", Vector3(0, 0.15, 0), Vector3(2.05, 0.55, 4.35), Color(0.04, 0.20, 0.62))
    _car_box("Cabin", Vector3(0, 0.72, 0.25), Vector3(1.62, 0.72, 1.95), Color(0.035, 0.07, 0.10))
    _car_box("Hood", Vector3(0, 0.40, -1.35), Vector3(1.9, 0.16, 1.15), Color(0.05, 0.24, 0.72))
    _car_box("Front glass", Vector3(0, 1.06, -0.42), Vector3(1.48, 0.08, 0.08), Color(0.16, 0.30, 0.38))
    for x in [-0.98, 0.98]:
        for z in [-1.38, 1.42]:
            var wheel := _car_box("Wheel", Vector3(x, -0.12, z), Vector3(0.34, 0.72, 0.72), Color(0.025, 0.025, 0.03))
            wheel.rotation.z = PI / 2.0
    var cockpit := Camera3D.new()
    cockpit.name = "CockpitCamera"
    cockpit.position = Vector3(0, 1.35, -0.18)
    cockpit.rotation_degrees = Vector3(-3, 0, 0)
    cockpit.fov = 78
    car.add_child(cockpit)
    camera = cockpit
    camera.current = true

func _car_box(n: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.name = n
    node.mesh = mesh
    node.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.55
    mat.roughness = 0.32
    node.material_override = mat
    car.add_child(node)
    return node

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(20, 18)
    panel.add_theme_stylebox_override("panel", _panel_style())
    layer.add_child(panel)
    var labels := VBoxContainer.new()
    panel.add_child(labels)
    ui_speed = Label.new()
    ui_speed.add_theme_font_size_override("font_size", 30)
    ui_speed.text = "0 km/h"
    labels.add_child(ui_speed)
    ui_status = Label.new()
    ui_status.text = "OPEN HORIZON  •  ALPINE ROAD TEST"
    labels.add_child(ui_status)

    _make_touch_button(layer, "◀", "steer_left", Vector2(34, -112), Vector2(82, 82))
    _make_touch_button(layer, "▶", "steer_right", Vector2(128, -112), Vector2(82, 82))
    _make_touch_button(layer, "BRAKE", "brake", Vector2(-208, -112), Vector2(92, 82))
    _make_touch_button(layer, "GAS", "accelerate", Vector2(-108, -112), Vector2(92, 82))

func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.04, 0.07, 0.78)
    style.set_corner_radius_all(12)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    return style

func _make_touch_button(layer: CanvasLayer, caption: String, action: String, offset: Vector2, size: Vector2) -> void:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = size
    button.position = offset
    button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if offset.x >= 0 else Control.PRESET_BOTTOM_RIGHT)
    button.position = Vector2(offset.x, offset.y)
    button.add_theme_font_size_override("font_size", 22)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_stylebox_override("normal", _panel_style())
    button.add_theme_stylebox_override("hover", _panel_style())
    button.add_theme_stylebox_override("pressed", _panel_style())
    button.button_down.connect(func(): Input.action_press(action))
    button.button_up.connect(func(): Input.action_release(action))
    layer.add_child(button)

func _physics_process(delta: float) -> void:
    if car == null:
        return
    var throttle := Input.get_action_strength("accelerate")
    var braking := Input.get_action_strength("brake")
    var steer_input := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
    var target_steer := steer_input
    steering = move_toward(steering, target_steer, delta * 3.0)
    speed += throttle * 24.0 * delta
    speed -= braking * 42.0 * delta
    if throttle < 0.05 and braking < 0.05:
        speed = move_toward(speed, 0.0, 2.0 * delta)
    speed = clamp(speed, -12.0, 62.0)
    var steer_factor: float = clampf(absf(speed) / 18.0, 0.12, 1.0)
    car.rotation.y -= steering * steer_factor * delta * (1.25 if speed >= 0.0 else -1.0)
    var forward := -car.global_basis.z
    car.velocity.x = forward.x * speed
    car.velocity.z = forward.z * speed
    car.velocity.y -= 18.0 * delta
    car.move_and_slide()
    if car.global_position.y < -10:
        car.global_position = Vector3(0, 1, -8)
        speed = 0
    if ui_speed:
        ui_speed.text = str(int(absf(speed) * 3.6)) + " km/h"

func _exit_tree() -> void:
    for action in ["accelerate", "brake", "steer_left", "steer_right"]:
        Input.action_release(action)
