extends "res://scripts/ui/overlay_screen.gd"
## A two-choice question. Cancel is focused first, so a stray Enter or tap
## never confirms something destructive. Set the fields before adding it.

signal confirmed

const Loc := preload("res://scripts/core/loc.gd")

var title_key: String = ""
## A Loc entry (key or [key, args...]).
var body: Variant = ""
var confirm_key: String = "CONFIRM_NEW_YES"
var _body_label: Label


func _build() -> void:
	panel_width = 600.0
	name = "ConfirmDialog"
	add_title(title_key)
	_body_label = add_paragraph(Loc.resolve(body), false)
	add_spacer(8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var cancel := add_button("UI_CANCEL", close, HORIZONTAL_ALIGNMENT_CENTER, row)
	cancel.name = "Cancel"
	var ok := add_button(confirm_key, _on_confirm, HORIZONTAL_ALIGNMENT_CENTER, row)
	ok.name = "Confirm"
	for b in [cancel, ok]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _focus_first() -> void:
	var cancel := box.find_child("Cancel", true, false)
	if cancel != null:
		cancel.grab_focus()


func _on_confirm() -> void:
	if _closing:
		return
	confirmed.emit()
	close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _body_label != null:
		_body_label.text = Loc.resolve(body)
