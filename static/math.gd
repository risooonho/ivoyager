# math.gd
# This file is part of I, Voyager (https://ivoyager.dev)
# *****************************************************************************
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
# Call directly using Math, or better, localize in your class header area.
# Issue #37529 prevents localization of global class_name to const. Use:
# const math := preload("res://ivoyager/static/math.gd")

class_name Math

const ECLIPTIC_NORTH := Vector3(0.0, 0.0, 1.0)
const LOG_OF_10 := log(10.0)

static func cartesian2spherical(R: Vector3) -> Vector3:
	var r := R.length()
	var th := acos(R.z / r) # polar angle [0, PI]
	var ph := atan2(R.y, R.x) # azimuthal angle [0, TAU]
	return Vector3(r, th, ph)

static func spherical2cartesian(S: Vector3) -> Vector3:
	var r := S[0]
	var th := S[1]
	var ph := wrapf(S[2], 0.0, TAU)
	assert(th >= 0 and th <= PI)
	var sin_th := sin(th)
	return Vector3(
		r * sin_th * cos(ph), # x
		r * sin_th * sin(ph), # y
		r * cos(th) # z
	)

static func rotate_vector_pole(vector: Vector3, new_pole: Vector3) -> Vector3:
	# Uses Rodrigues Formula to rotate vector from ecliptic (z up) orientation to
	# provided new_pole; new_pole assumed to be a unit vector.
	if vector == ECLIPTIC_NORTH:
		return new_pole
	if new_pole == ECLIPTIC_NORTH:
		return vector
	var cos_th := ECLIPTIC_NORTH.dot(new_pole)
	var X := ECLIPTIC_NORTH.cross(new_pole)
	var sin_th := X.length()
	var k := X / sin_th # normalized cross product
	return vector * cos_th + k.cross(vector) * sin_th + k * k.dot(vector) * (1.0 - cos_th)

static func unrotate_vector_pole(vector: Vector3, old_pole: Vector3) -> Vector3:
	# Uses Rodrigues Formula to rotate vector from ecliptic (z up) orientation to
	# provided new_pole; new_pole assumed to be a unit vector.
#	if vector == ECLIPTIC_NORTH:
#		return old_pole
	if old_pole == ECLIPTIC_NORTH:
		return vector
	var cos_th := ECLIPTIC_NORTH.dot(old_pole)
	var X := -ECLIPTIC_NORTH.cross(old_pole)
	var sin_th := X.length()
	var k := X / sin_th # normalized cross product
	return vector * cos_th + k.cross(vector) * sin_th + k * k.dot(vector) * (1.0 - cos_th)

static func rotate_basis_pole(basis: Basis, new_pole: Vector3) -> Basis:
	if new_pole == ECLIPTIC_NORTH:
		return basis
	var cos_th := ECLIPTIC_NORTH.dot(new_pole)
	var X := ECLIPTIC_NORTH.cross(new_pole)
	var sin_th := X.length()
	var k := X / sin_th # normalized cross product
	var c1 := 1.0 - cos_th
	basis.x = basis.x * cos_th + k.cross(basis.x) * sin_th + k * k.dot(basis.x) * c1
	basis.y = basis.y * cos_th + k.cross(basis.y) * sin_th + k * k.dot(basis.y) * c1
	basis.z = basis.z * cos_th + k.cross(basis.z) * sin_th + k * k.dot(basis.z) * c1
	return basis

static func get_rotation_matrix(keplerian_elements: Array) -> Basis:
	var i: float = keplerian_elements[2]
	var Om: float = keplerian_elements[3]
	var w: float = keplerian_elements[4]
	var sin_i := sin(i)
	var cos_i := cos(i)
	var sin_Om := sin(Om)
	var cos_Om := cos(Om)
	var sin_w := sin(w)
	var cos_w := cos(w)
	return Basis(
		Vector3(
			cos_Om * cos_w - sin_Om * cos_i * sin_w,
			sin_Om * cos_w + cos_Om * cos_i * sin_w,
			sin_i * sin_w
		),
		Vector3(
			-cos_Om * sin_w - sin_Om * cos_i * cos_w,
			-sin_Om * sin_w + cos_Om * cos_i * cos_w,
			sin_i * cos_w
		),
		Vector3(
			sin_i * sin_Om,
			-sin_i * cos_Om,
			cos_i
		)
	)

# Obliquity of the ecliptic (=23.439 deg) is rotation around the x-axis
static func get_x_rotation_matrix(th: float) -> Basis:
	return Basis(
		Vector3(1, 0, 0),
		Vector3(0, cos(th), -sin(th)),
		Vector3(0, sin(th), cos(th))
	)

static func get_y_rotation_matrix(th: float) -> Basis:
	return Basis(
		Vector3(cos(th), 0, sin(th)),
		Vector3(0, 1, 0),
		Vector3(-sin(th), 0, cos(th))
	)
static func get_z_rotation_matrix(th: float) -> Basis:
	return Basis(
		Vector3(cos(th), -sin(th), 0),
		Vector3(sin(th), cos(th), 0),
		Vector3(0, 0, 1)
	)

static func get_euler_rotation_matrix(Om: float, i: float, w: float) -> Basis:
	# WIP - I started this and didn't finish. Never tested.
	# Om, i, w are Euler angles alpha, beta, gamma (intrinsic rotations)
	var x1 = cos(Om) * cos(w) - sin(Om) * cos(i) * sin(w)
	var x2 = sin(Om) * cos(w) + cos(w) * cos(i) * sin(w)
	var x3 = sin(i) * sin(w)
	var y1 = -cos(Om) * sin(w) - sin(Om) * cos(i) * cos(w)
	var y2 = -sin(Om) * sin(w) + cos(Om) * cos(i) * cos(w)
	var y3 = sin(i) * cos(w)
	var z1 = sin(i) * sin(Om)
	var z2 = -sin(i) * cos(Om)
	var z3 = cos(i)
	return Basis(
		Vector3(x1, x2, x3),
		Vector3(y1, y2, y3),
		Vector3(z1, z2, z3)
	)

# RA, dec are spherical coordinates except dec is from equator rather than pole
static func get_equatorial_coordinates2(translation: Vector3) -> Vector2:
	# returns Vector2(right_ascension, declination)
	var r := translation.length()
	return Vector2(
		fposmod(atan2(translation.y, translation.x), TAU),
		asin(translation.z / r)
	)

static func convert_equatorial_coordinates2(right_ascension: float,
		declination: float) -> Vector3:
	# returns translation assuming r = 1.0
	var cos_decl := cos(declination)
	return Vector3(
		cos(right_ascension) * cos_decl,
		sin(right_ascension) * cos_decl,
		sin(declination)
	)

static func get_equatorial_coordinates3(translation: Vector3) -> Vector3:
	# returns Vector3(right_ascension, declination, r)
	var r := translation.length()
	return Vector3(
		fposmod(atan2(translation.y, translation.x), TAU),
		asin(translation.z / r),
		r
	)

static func convert_equatorial_coordinates3(equatorial_coord: Vector3) -> Vector3:
	# equatorial_coord is Vector3(right_ascension, declination, r)
	# returns translation
	var right_ascension: float = equatorial_coord[0]
	var declination: float = equatorial_coord[1]
	var r: float = equatorial_coord[2]
	var cos_decl := cos(declination)
	return Vector3(
		cos(right_ascension) * cos_decl,
		sin(right_ascension) * cos_decl,
		sin(declination)
	) * r

# Precision
static func get_str_decimal_precision(x_str: String) -> int:
	# valid float str or table number format (leading underscore, capital E ok)
	var length := x_str.length()
	var sig_digits := 0
	var i := 0
	while i < length:
		var chr: String = x_str[i]
		if chr.is_valid_integer():
			sig_digits += 1
		elif chr == "e" or chr == "E":
			return sig_digits
		i += 1
	return sig_digits

static func get_least_str_decimal_precision(str_array: Array) -> int:
	var least_sig_digits := 999
	for x_str in str_array:
		var sig_digits := get_str_decimal_precision(x_str)
		if least_sig_digits > sig_digits:
			least_sig_digits = sig_digits
	return least_sig_digits

static func get_decimal_precision(x: float) -> int:
	# Use with caution! 100.0 will return 1, which could happen by chance even
	# if this is a precise measurement. Intended for GUI display only; data
	# import should use function above. Max return is 10.
	# It's a bit odd converting to String. Is there a faster way...?
	if x == 0.0:
		return 1
	var exp10 := floor(log(abs(x)) / LOG_OF_10)
	var str1000 := String(x / pow(10.0, exp10 - 3.0)) # (10000, 1000] as text
	if str1000.find(".") != -1: # has decimal, so no trailing 0's
		return str1000.length() - 1
	if str1000.ends_with("000"):
		return 1
	if str1000.ends_with("00"):
		return 2
	if str1000.ends_with("0"):
		return 3
	return 4

static func set_decimal_precision(x: float, sig_digits: int) -> float:
	# Ensures that String(x) will be displayed with sig_digits or less.
	if x == 0.0:
		return 0.0
	var exp10 := floor(log(abs(x)) / LOG_OF_10)
	var decimal_factor := pow(10.0, exp10 - sig_digits + 1)
	x /= decimal_factor
	return round(x) * decimal_factor







# Misc
static func acosh(x: float) -> float:
	# from https://en.wikipedia.org/wiki/Hyperbolic_function
	assert(x >= 1.0)
	return log(x + sqrt(x * x - 1.0))

# Camera
static func get_view_position(translation: Vector3, north: Vector3,
		ref_longitude := 0.0) -> Vector3:
	# view_position is [right_ascension, declination, range] sometimes relative
	# to a moving ref_longitude
	translation = unrotate_vector_pole(translation, north)
	var view_position := get_equatorial_coordinates3(translation)
	view_position[0] -= ref_longitude
	return view_position

static func convert_view_position(view_position: Vector3, north: Vector3,
		ref_longitude := 0.0) -> Vector3:
	# see comment above
	view_position[0] += ref_longitude
	var translation := convert_equatorial_coordinates3(view_position)
	translation = rotate_vector_pole(translation, north)
	return translation

static func get_fov_from_focal_length(focal_length: float) -> float:
	# This is for photography buffs who think in focal lengths (of full-frame
	# sensor) rather than fov. Godot sets fov to fit horizonal screen height by
	# default, so we use horizonal height of a full-frame sensor (11.67mm)
	# to calculate: fov = 2 * arctan(sensor_size / focal_length).
	return rad2deg(2.0 * atan(11.67 / focal_length))
	
static func get_focal_length_from_fov(fov: float) -> float:
	return 11.67 / tan(deg2rad(fov) / 2.0)

static func get_fov_scaling_factor(fov: float) -> float:
	# This polynomial was empirically determined (with a tape measure!) to
	# correct icon size on the screen for fov changes (more or less). Icons
	# werer depreciated, but it may be more generally useful for scale
	# corrections after fov change.
	return 0.00005 * fov * fov + 0.0001 * fov + 0.0816

# Conversions (use UnitDefs for most conversions!)
static func srgb2linear(color: Color) -> Color:
	if color.r <= 0.04045:
		color.r /= 12.92
	else:
		color.r = pow((color.r + 0.055) / 1.055, 2.4)
	if color.g <= 0.04045:
		color.g /= 12.92
	else:
		color.g = pow((color.g + 0.055) / 1.055, 2.4)
	if color.b <= 0.04045:
		color.b /= 12.92
	else:
		color.b = pow((color.b + 0.055) / 1.055, 2.4)
	return color
		
static func linear2srgb(x: float) -> float:
	if x <= 0.0031308:
		return x * 12.92
	else:
		return pow(x, 1.0 / 2.4) * 1.055 - 0.055

