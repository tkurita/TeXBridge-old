property TeXBridgeProxy : module
property EditorClient : module "miClient"

property _env_command : missing value --"flushleft"
property _line_command : missing value --"leftline"
property _declarative_command : missing value --"raggedright"
property _declarative_for_line : missing value

property _beginText : missing value
property _endText : missing value
property _backslash : missing value

on debug()
	set_env_command("center")
	set_line_command("centerline")
	set_declarative_command("centering")
	do()
end debug

on run
	--return debug()
	try
		do()
	on error errMsg
		display alert errMsg
	end try
end run

on initialize()
	TeXBridgeProxy's initialize()
end initialize

on toolserver()
	return TeXBridgeProxy's shared_instance()
end toolserver

on set_env_command(a_command)
	set my _env_command to a_command
end set_env_command

on set_line_command(a_command, is_declarative)
	set my _line_command to a_command
	set my _declarative_for_line to is_declarative
end set_line_command

on set_declarative_command(a_command)
	set my _declarative_command to a_command
end set_declarative_command

on do()
	setup_string_constants()
	set a_text to selection_contents() of EditorClient
	set nPar to count paragraph of a_text
	set selinfo to missing value
	if a_text is "" then
		if my _declarative_command is not missing value then
			set a_text to my _backslash & my _declarative_command & space
		else
			set a_text to my _backslash & my _line_command & "{}"
		end if
	else
		set selinfo to EditorClient's selection_info()
		set nchar to length of a_text
		if nPar > 1 then
			if my _env_command is not missing value then
				set {a_text, shiftlen} to wrap_with_env(a_text, my _env_command)
			else
				if my _line_command is not missing value then
					set {a_text, shiftlen} to wrap_with_command(a_text, my _line_command)
				else
					set {a_text, shiftlen} to wrap_with_declalative(a_text, my _declarative_command)
				end if
			end if
		else
			if my _declarative_for_line then
				set {a_text, shiftlen} to wrap_with_declalative(a_text, my _line_command)
			else
				set {a_text, shiftlen} to wrap_with_command(a_text, my _line_command)
			end if
		end if
	end if
	EditorClient's insert_text(a_text)
	if selinfo is not missing value then
		EditorClient's select_in_range(shiftlen + (selinfo's cursorPosition), nchar)
	end if
end do

on wrap_with_declalative(a_text, a_command)
	set pretext to "{" & my _backslash & a_command & space
	return {pretext & a_text & "}", length of pretext}
end wrap_with_declalative

on wrap_with_command(a_text, a_command)
	set pretext to my _backslash & a_command & "{"
	return {pretext & a_text & "}", length of pretext}
end wrap_with_command

on setup_string_constants()
	tell TeXBridgeProxy's shared_instance()
		resolve_support_plist()
		set my _beginText to plist_value("beginText")
		set my _endText to plist_value("endText")
		set my _backslash to plist_value("backslash")
	end tell
end setup_string_constants

on wrap_with_env(a_text, an_env)
	if a_text does not end with return then
		set a_text to a_text & return
	end if
	set pretext to build_begin_text(an_env) & return
	return {pretext & a_text & build_end_text(an_env) & return, length of pretext}
end wrap_with_env

on build_begin_text(an_env)
	return my _beginText & "{" & an_env & "}"
end build_begin_text

on build_end_text(an_env)
	return my _endText & "{" & an_env & "}"
end build_end_text
