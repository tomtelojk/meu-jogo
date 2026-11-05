class_name WorldClock
extends Node

signal minute_changed

const MINUTES_PER_SECOND: float = 2.0
var minute: float = 8.5 * 60.0
var day: int = 1
var active: bool = false

func _process(delta: float) -> void:
	if active:
		advance(delta * MINUTES_PER_SECOND)

func advance(minutes: float) -> void:
	if not is_finite(minutes) or minutes < 0:
		return
	var previous := floori(minute)
	minute += minutes
	while minute >= 1440.0:
		minute -= 1440.0
		day += 1
	if floori(minute) != previous or minutes >= 1440:
		minute_changed.emit()

func set_time(hour: float, new_day: int = -1) -> void:
	minute = fposmod(hour * 60.0, 1440.0)
	if new_day > 0:
		day = new_day
	minute_changed.emit()

func label() -> String:
	return "Dia %d · %02d:%02d · %s" % [day, floori(minute / 60.0), floori(minute) % 60, phase()]

func phase() -> String:
	if minute < 6 * 60 or minute >= 21 * 60:
		return "Noite"
	if minute < 12 * 60:
		return "Manhã"
	if minute < 18 * 60:
		return "Tarde"
	return "Entardecer"

func save_data() -> Dictionary:
	return {"minute": minute, "day": day}

func restore(data: Dictionary) -> void:
	var value = data.get("minute", 510.0)
	var saved_day = data.get("day", 1)
	minute = float(value) if (value is float or value is int) and is_finite(float(value)) and float(value) >= 0 and float(value) < 1440 else 510.0
	day = clampi(int(saved_day), 1, 999999) if saved_day is int or saved_day is float else 1
	minute_changed.emit()
