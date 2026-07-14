@tool
extends RefCounted

var _last_error := ""


func tokenize_exec_flags(template: String) -> PackedStringArray:
	_last_error = ""
	var arguments := PackedStringArray()
	var current := ""
	var active_quote := ""
	var token_started := false
	var index := 0

	while index < template.length():
		var character := template[index]

		if character == "\\" and index + 1 < template.length():
			var next_character := template[index + 1]
			if _can_escape(next_character, active_quote):
				current += next_character
				token_started = true
				index += 2
				continue

		if character == "'" or character == "\"":
			if active_quote.is_empty():
				active_quote = character
				token_started = true
				index += 1
				continue
			if active_quote == character:
				active_quote = ""
				index += 1
				continue

		if active_quote.is_empty() and _is_whitespace(character):
			if token_started:
				arguments.append(current)
				current = ""
				token_started = false
			index += 1
			continue

		current += character
		token_started = true
		index += 1

	if not active_quote.is_empty():
		_last_error = "Unterminated %s quote in Exec Flags." % active_quote
		return PackedStringArray()

	if token_started:
		arguments.append(current)

	return arguments


func replace_placeholders(argument: String, context: Dictionary) -> String:
	var result := argument
	result = result.replace("{project}", str(context.get("project", "")))
	result = result.replace("{file}", str(context.get("file", "")))
	result = result.replace("{line}", str(context.get("line", 1)))
	result = result.replace("{col}", str(context.get("col", 1)))
	result = result.replace("{column}", str(context.get("column", context.get("col", 1))))
	return result


func build_arguments(template: String, context: Dictionary) -> PackedStringArray:
	var tokens := tokenize_exec_flags(template)
	if not _last_error.is_empty():
		return PackedStringArray()

	var arguments := PackedStringArray()
	for token in tokens:
		arguments.append(replace_placeholders(token, context))
	return arguments


func get_last_error() -> String:
	return _last_error


func _can_escape(character: String, active_quote: String) -> bool:
	if not active_quote.is_empty():
		return character == active_quote or character == "\\"
	return character == "'" or character == "\"" or character == "\\" or _is_whitespace(character)


func _is_whitespace(character: String) -> bool:
	return character == " " or character == "\t" or character == "\n" or character == "\r"
