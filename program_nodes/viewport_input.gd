# viewport_input.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# Copyright (c) 2017-2020 Charlie Whitfield
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# *****************************************************************************
# Handles input for camera movements and click selection. This node expects
# specific members and functions present in BCamera! Modify, remove or replace
# this node if these don't apply.

extends Node
class_name ViewportInput

enum {
	DRAG_MOVE,
	DRAG_PITCH_YAW,
	DRAG_ROLL,
	DRAG_PITCH_YAW_ROLL_HYBRID
}

const MOUSE_WHEEL_ADJ := 2.5 # adjust so default setting can be ~1.0
const MOUSE_MOVE_ADJ := 0.4
const MOUSE_PITCH_YAW_ADJ := 0.2
const MOUSE_ROLL_ADJ := 0.5
const KEY_IN_OUT_ADJ := 1.0
const KEY_MOVE_ADJ := 1.0
const KEY_PITCH_YAW_ADJ := 3.0
const KEY_ROLL_ADJ := 3.0

const VIEW_ZOOM = Enums.VIEW_ZOOM
const VIEW_45 = Enums.VIEW_45
const VIEW_TOP = Enums.VIEW_TOP
const VIEW_CENTERED = Enums.VIEW_CENTERED
const VIEW_UNCENTERED = Enums.VIEW_UNCENTERED
const VECTOR2_ZERO := Vector2.ZERO
const VECTOR3_ZERO := Vector3.ZERO

# project vars
var l_button_drag := DRAG_MOVE
var r_button_drag := DRAG_PITCH_YAW_ROLL_HYBRID
var cntr_drag := DRAG_PITCH_YAW_ROLL_HYBRID # keep same as above for Mac!
var shift_drag := DRAG_PITCH_YAW
var alt_drag := DRAG_ROLL
var hybrid_drag_center_zone := 0.2 # for _drag_mode = DRAG_PITCH_YAW_ROLL_HYBRID
var hybrid_drag_outside_zone := 0.7 # for _drag_mode = DRAG_PITCH_YAW_ROLL_HYBRID

# private
var _camera: Camera
onready var _tree := get_tree()
onready var _viewport := get_viewport()

var _settings: Dictionary = Global.settings
onready var _mouse_in_out_rate: float = _settings.camera_mouse_in_out_rate * MOUSE_WHEEL_ADJ
onready var _mouse_move_rate: float = _settings.camera_mouse_move_rate * MOUSE_MOVE_ADJ
onready var _mouse_pitch_yaw_rate: float = _settings.camera_mouse_pitch_yaw_rate * MOUSE_PITCH_YAW_ADJ
onready var _mouse_roll_rate: float = _settings.camera_mouse_roll_rate * MOUSE_ROLL_ADJ
onready var _key_in_out_rate: float = _settings.camera_key_in_out_rate * KEY_IN_OUT_ADJ
onready var _key_move_rate: float = _settings.camera_key_move_rate * KEY_MOVE_ADJ
onready var _key_pitch_yaw_rate: float = _settings.camera_key_pitch_yaw_rate * KEY_PITCH_YAW_ADJ
onready var _key_roll_rate: float = _settings.camera_key_roll_rate * KEY_ROLL_ADJ

var _drag_mode := -1 # one of DRAG_ enums when active
var _drag_start := VECTOR2_ZERO
var _drag_segment_start := VECTOR2_ZERO
var _drag_vector := VECTOR2_ZERO
var _mwheel_turning := 0.0
var _move_pressed := VECTOR3_ZERO
var _rotate_pressed := VECTOR3_ZERO


func project_init() -> void:
	Global.connect("run_state_changed", self, "_on_run_state_changed")
	Global.connect("about_to_free_procedural_nodes", self, "_restore_init_state")
	Global.connect("camera_ready", self, "_connect_camera")

func _restore_init_state() -> void:
	_camera = null

func _connect_camera(camera: Camera) -> void:
	_camera = camera

func _ready():
	set_process(false)

func _on_run_state_changed(is_running: bool) -> void:
	set_process(is_running)
	set_process_unhandled_input(is_running)

func _process(delta: float) -> void:
	if _drag_vector:
		match _drag_mode:
			DRAG_MOVE:
				var multiplier := delta * _mouse_move_rate
				_camera.move_action.x -= _drag_vector.x * multiplier
				_camera.move_action.y += _drag_vector.y * multiplier
			DRAG_PITCH_YAW:
				var multiplier := delta * _mouse_pitch_yaw_rate
				_camera.rotate_action.x += _drag_vector.y * multiplier
				_camera.rotate_action.y += _drag_vector.x * multiplier
			DRAG_ROLL:
				var multiplier := delta * _mouse_roll_rate
				var mouse_position := _drag_segment_start + _drag_vector
				var center_to_mouse := (mouse_position - _viewport.size / 2.0).normalized()
				_camera.rotate_action.z += center_to_mouse.cross(_drag_vector) * multiplier
			DRAG_PITCH_YAW_ROLL_HYBRID:
				# one or a mix of two above based on mouse position
				var mouse_rotate := _drag_vector * delta
				var z_proportion := (2.0 * _drag_start - _viewport.size).length() / _viewport.size.x
				z_proportion -= hybrid_drag_center_zone
				z_proportion /= hybrid_drag_outside_zone - hybrid_drag_center_zone
				z_proportion = clamp(z_proportion, 0.0, 1.0)
				var mouse_position := _drag_segment_start + _drag_vector
				var center_to_mouse := (mouse_position - _viewport.size / 2.0).normalized()
				_camera.rotate_action.z += center_to_mouse.cross(mouse_rotate) \
						* z_proportion * _mouse_roll_rate
				mouse_rotate *= (1.0 - z_proportion) * _mouse_pitch_yaw_rate
				_camera.rotate_action.x += mouse_rotate.y
				_camera.rotate_action.y += mouse_rotate.x
		_drag_vector = VECTOR2_ZERO
	if _mwheel_turning:
		_camera.move_action.z += _mwheel_turning * delta
		_mwheel_turning = 0.0
	if _move_pressed:
		_camera.move_action += _move_pressed * delta
	if _rotate_pressed:
		_camera.rotate_action += _rotate_pressed * delta

func _unhandled_input(event: InputEvent) -> void:
	if !_camera:
		return
	var is_handled := false
	if event is InputEventMouseButton:
		var button_index: int = event.button_index
		# BUTTON_WHEEL_UP & _DOWN always fire twice (pressed then not pressed)
		if button_index == BUTTON_WHEEL_UP:
			_mwheel_turning = _mouse_in_out_rate
			is_handled = true
		elif button_index == BUTTON_WHEEL_DOWN:
			_mwheel_turning = -_mouse_in_out_rate
			is_handled = true
		# start/stop mouse drag or process a mouse click
		elif button_index == BUTTON_LEFT or button_index == BUTTON_RIGHT:
			if event.pressed: # possible drag start (but may be a click selection!)
				_drag_start = event.position
				_drag_segment_start = _drag_start
				if event.control:
					_drag_mode = cntr_drag
				elif event.shift:
					_drag_mode = shift_drag
				elif event.alt:
					_drag_mode = alt_drag
				elif button_index == BUTTON_RIGHT:
					_drag_mode = r_button_drag
				else:
					_drag_mode = l_button_drag
			else: # end of drag, or button-up after a mouse click selection
				if _drag_start == event.position: # was a mouse click!
					Global.emit_signal("mouse_clicked_viewport_at", event.position, _camera, true)
				_drag_start = VECTOR2_ZERO
				_drag_segment_start = VECTOR2_ZERO
				_drag_mode = -1
			is_handled = true
	elif event is InputEventMouseMotion:
		if _drag_segment_start: # accumulate mouse drag motion
			var current_mouse_pos: Vector2 = event.position
			_drag_vector += current_mouse_pos - _drag_segment_start
			_drag_segment_start = current_mouse_pos
			is_handled = true
	elif event.is_action_type():
		if event.is_pressed():
			if event.is_action_pressed("camera_zoom_view"):
				_camera.move(null, VIEW_ZOOM, Vector3.ZERO, Vector3.ZERO, false)
			elif event.is_action_pressed("camera_45_view"):
				_camera.move(null, VIEW_45, Vector3.ZERO, Vector3.ZERO, false)
			elif event.is_action_pressed("camera_top_view"):
				_camera.move(null, VIEW_TOP, Vector3.ZERO, Vector3.ZERO, false)
			elif event.is_action_pressed("recenter"):
				_camera.move(null, -1, Vector3.ZERO, Vector3.ZERO, false)
			elif event.is_action_pressed("camera_left"):
				_move_pressed.x = -_key_move_rate
			elif event.is_action_pressed("camera_right"):
				_move_pressed.x = _key_move_rate
			elif event.is_action_pressed("camera_up"):
				_move_pressed.y = _key_move_rate
			elif event.is_action_pressed("camera_down"):
				_move_pressed.y = -_key_move_rate
			elif event.is_action_pressed("camera_in"):
				_move_pressed.z = -_key_in_out_rate
			elif event.is_action_pressed("camera_out"):
				_move_pressed.z = _key_in_out_rate
			elif event.is_action_pressed("pitch_up"):
				_rotate_pressed.x = _key_pitch_yaw_rate
			elif event.is_action_pressed("pitch_down"):
				_rotate_pressed.x = -_key_pitch_yaw_rate
			elif event.is_action_pressed("yaw_left"):
				_rotate_pressed.y = _key_pitch_yaw_rate
			elif event.is_action_pressed("yaw_right"):
				_rotate_pressed.y = -_key_pitch_yaw_rate
			elif event.is_action_pressed("roll_left"):
				_rotate_pressed.z = -_key_roll_rate
			elif event.is_action_pressed("roll_right"):
				_rotate_pressed.z = _key_roll_rate
			else:
				return  # no input handled
		else: # key release
			if event.is_action_released("camera_left"):
				_move_pressed.x = 0.0
			elif event.is_action_released("camera_right"):
				_move_pressed.x = 0.0
			elif event.is_action_released("camera_up"):
				_move_pressed.y = 0.0
			elif event.is_action_released("camera_down"):
				_move_pressed.y = 0.0
			elif event.is_action_released("camera_in"):
				_move_pressed.z = 0.0
			elif event.is_action_released("camera_out"):
				_move_pressed.z = 0.0
			elif event.is_action_released("pitch_up"):
				_rotate_pressed.x = 0.0
			elif event.is_action_released("pitch_down"):
				_rotate_pressed.x = 0.0
			elif event.is_action_released("yaw_left"):
				_rotate_pressed.y = 0.0
			elif event.is_action_released("yaw_right"):
				_rotate_pressed.y = 0.0
			elif event.is_action_released("roll_left"):
				_rotate_pressed.z = 0.0
			elif event.is_action_released("roll_right"):
				_rotate_pressed.z = 0.0
			else:
				return  # no input handled
		is_handled = true
	if is_handled:
		_tree.set_input_as_handled()

func _settings_listener(setting: String, value) -> void:
	match setting:
		"camera_mouse_in_out_rate":
			_mouse_in_out_rate = value * MOUSE_WHEEL_ADJ
		"camera_mouse_move_rate":
			_mouse_move_rate = value * MOUSE_MOVE_ADJ
		"camera_mouse_pitch_yaw_rate":
			_mouse_pitch_yaw_rate = value * MOUSE_PITCH_YAW_ADJ
		"camera_mouse_roll_rate":
			_mouse_roll_rate = value * MOUSE_ROLL_ADJ
		"camera_key_in_out_rate":
			_key_in_out_rate = value * KEY_IN_OUT_ADJ
		"camera_key_move_rate":
			_key_move_rate = value * KEY_MOVE_ADJ
		"camera_key_pitch_yaw_rate":
			_key_pitch_yaw_rate = value * KEY_PITCH_YAW_ADJ
		"camera_key_roll_rate":
			_key_roll_rate = value * KEY_ROLL_ADJ
