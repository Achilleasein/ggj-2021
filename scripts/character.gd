extends KinematicBody

const CAMERA_MOUSE_ROTATION_SPEED = 0.001
const CAMERA_CONTROLLER_ROTATION_SPEED = 3.0
const CAMERA_X_ROT_MIN = -40
const CAMERA_X_ROT_MAX = 30

const DIRECTION_INTERPOLATE_SPEED = 1
const MOTION_INTERPOLATE_SPEED = 10
const ROTATION_INTERPOLATE_SPEED = 10

const MIN_AIRBORNE_TIME = 0.1
const JUMP_SPEED = 5

var airborne_time = 100

var orientation = Transform()
var root_motion = Transform()
var motion = Vector2()
var velocity = Vector3()

var aiming = false
var camera_x_rot = 0.0

onready var initial_position = transform.origin
onready var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * ProjectSettings.get_setting("physics/3d/default_gravity_vector")

onready var player_model = $PlayerModel
onready var animation_tree = $"PlayerModel/AnimationTree"
onready var state_machine = animation_tree["parameters/playback"]

onready var camera_base = $CameraBase
onready var camera_rot = camera_base.get_node(@"CameraRot")
onready var camera_spring_arm = camera_rot.get_node(@"SpringArm")
onready var camera_camera = camera_spring_arm.get_node(@"Camera")

func _ready():
	orientation = player_model.global_transform
	orientation.origin = Vector3()
	state_machine.start("char05_Idle")

func _physics_process(delta):
	var camera_move = Vector2(
		Input.get_action_strength("view_right") - Input.get_action_strength("view_left"),
		Input.get_action_strength("view_up") - Input.get_action_strength("view_down")
	)
	var camera_speed_this_frame = delta * CAMERA_CONTROLLER_ROTATION_SPEED
	rotate_camera(camera_move * camera_speed_this_frame)
	var motion_target = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	motion = motion.linear_interpolate(motion_target, MOTION_INTERPOLATE_SPEED * delta)

	var camera_basis = camera_rot.global_transform.basis
	var camera_z = camera_basis.z
	var camera_x = camera_basis.x

	camera_z.y = 0
	camera_z = camera_z.normalized()
	camera_x.y = 0
	camera_x = camera_x.normalized()

	airborne_time += delta
	if is_on_floor():
		airborne_time = 0

	var on_air = airborne_time > MIN_AIRBORNE_TIME

	if not on_air and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_SPEED
		on_air = true
		airborne_time = MIN_AIRBORNE_TIME

	var target = camera_x * motion.x + camera_z * motion.y
	if target.length() > 0.001:
		var q_from = orientation.basis.get_rotation_quat()
		var q_to = Transform().looking_at(target, Vector3.UP).basis.get_rotation_quat()
		orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))

	root_motion = animation_tree.get_root_motion_transform()
	orientation *= root_motion

	var h_velocity = orientation.origin / delta
	velocity.x = -target.x * 2 # h_velocity.x
	velocity.z = -target.z * 2 # h_velocity.z
	velocity += gravity * delta
	velocity = move_and_slide(velocity, Vector3.UP)

	orientation.origin = Vector3()
	orientation = orientation.orthonormalized()

	player_model.global_transform.basis = orientation.basis
	
	if on_air:
		state_machine.travel("char05_Jump")
	elif abs(h_velocity.x) >= 0.005 or abs(h_velocity.z) >= 0.005:
		state_machine.travel("char05_Running")
	else:
		state_machine.travel("char05_Idle")

func _input(event):
	if event is InputEventMouseMotion:
		rotate_camera(event.relative * CAMERA_MOUSE_ROTATION_SPEED)

func rotate_camera(move):
	camera_base.rotate_y(-move.x)
	camera_base.orthonormalize()
	camera_x_rot += move.y
	camera_x_rot = clamp(camera_x_rot, deg2rad(CAMERA_X_ROT_MIN), deg2rad(CAMERA_X_ROT_MAX))
	camera_rot.rotation.x = camera_x_rot
