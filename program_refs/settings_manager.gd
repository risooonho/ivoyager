# settings_manager.gd
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
#
# Settings are persisted in <cache_dir>/<cache_file_name> (specified below).
#
# TODO: We could have some settings cached in a user ProjectSettings override
# for restart engine settings (screen size, rendering, etc.).

extends CachedItemsManager
class_name SettingsManager

enum GUISizes {
	GUI_SMALL,
	GUI_MEDIUM,
	GUI_LARGE,
	}

func _on_init():
	# project vars - modify on ProjectBuilder signal "project_objects_instantiated"
	cache_file_name = "settings.vbinary"
	defaults = {
		# save/load
		save_base_name = "I Voyager",
		append_date_to_save = true,
		loaded_game_is_paused = false,
	#	autosave = false,
	#	autosave_number = 5,
	#	autosave_minutes = 30,
	
		# camera
		camera_transition_time = 1.0,
		camera_mouse_in_out_rate = 1.0,
		camera_mouse_move_rate = 1.0,
		camera_mouse_pitch_yaw_rate = 1.0,
		camera_mouse_roll_rate = 1.0,
		camera_key_in_out_rate = 1.0,
		camera_key_move_rate = 1.0,
		camera_key_pitch_yaw_rate = 1.0,
		camera_key_roll_rate = 1.0,

		# UI & HUD display
		gui_size = GUISizes.GUI_MEDIUM,
		viewport_label_size = 12,
		viewport_icon_size = 100,
		hide_hud_when_close = true, # restart or load required
	
		# graphics
		planet_orbit_color =  Color(0.5,0.5,0.1),
		dwarf_planet_orbit_color = Color(0.1,0.8,0.2),
		moon_orbit_color = Color(0.3,0.3,0.9),
		minor_moon_orbit_color = Color(0.35,0.1,0.35),
		default_orbit_color = Color(0.4,0.4,0.8),
		asteroid_point_color = Color("008800"),
	
		# misc
		mouse_action_releases_gui_focus = true,

		# cached but not in base OptionsPopup
		save_dir = "",
		pbd_splash_caption_open = false,
		
		# TODO:
#		planet_icon_color = Color(0.5, 0.7, 0.4), # green w/ yellow
#		moon_icon_color = Color(0.5, 0.7, 0.4), # green w/ yellow
#		minor_orbit_color = Color(0.8, 0.0, 0.0),
		}
	
	# read-only
	current = Global.settings

func _on_change_current(setting: String) -> void:
	Global.emit_signal("setting_changed", setting, current[setting])
