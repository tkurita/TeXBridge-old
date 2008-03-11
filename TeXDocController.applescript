global PathConverter
global PathAnalyzer
global XFile
global XText

global UtilityHandlers
global TerminalCommander
global MessageUtility
global DVIController
global ToolPaletteController

property name : "TeXDocController"
property _log_suffix : ".log"

global _com_delim

(*== Private Methods *)
on doc_position()
	return my _doc_position
end doc_position

on set_doc_position(an_index)
	set my _doc_position to an_index
end set_doc_position

on resolve_parent(a_paragraph)
	--log "start resolveParentFile"
	set parent_file to XText's make_with(a_paragraph)'s text_in_range(13, -2)
	--log parent_file
	if parent_file's starts_with(":") then
		set pathconv to PathConverter's make_with(my _targetFileRef's hfs_path())
		set tex_file to absolute_path of pathconv for parent_file's as_unicode()
	else
		set tex_file to parent_file's as_unicode()
	end if
	--tell me to log "tex_file : " & tex_file
	if tex_file ends with ":" then
		set a_msg to UtilityHandlers's localized_string("ParentFIleIsInvalid", parent_file)
		error a_msg number 1230
	end if
	
	try
		set tex_file to tex_file as alias
	on error
		set a_msg to UtilityHandlers's localized_string("ParentFileIsNotFound", tex_file)
		error a_msg number 1220
	end try
	
	--log "end resolveParentFile"
	return tex_file
end resolve_parent

(*== accessors *)
on has_file()
	return my _file_ref is not missing value
end has_file

on has_parent()
	return my _hasParentFile
end has_parent

on log_contents()
	return my _logContents
end log_contents

on set_use_term(a_flag)
	set my _use_term to a_flag
end set_use_term

on is_use_term()
	return my _use_term
end is_use_term

on set_typeset_command(a_command)
	set my _typeset_command to a_command
end set_typeset_command

on dvips_command()
	if my _dvips_command is missing value then
		return contents of default entry "dvipsCommand" of user defaults
	end if
	return my _dvipos_command
end dvips_command

on dvipdf_command()
	if (my _dvipdf_command is missing value) then
		return contents of default entry "dvipdfCommand" of user defaults
	end if
	
	return my _dvipdf_command
end dvipdf_command

on typeset_command()
	if my _typeset_command is missing value then
		return contents of default entry "typesetCommand" of user defaults
	end if
	return my _typeset_command
end typeset_command

on logfile()
	return my _logFileRef
end logfile

on text_encoding()
	return my _text_encoding
end text_encoding

on tex_file()
	return my _file_ref
end tex_file

on file_ref()
	return my _file_ref
end file_ref

on update_with_parent(a_parent_file)
	set my _hasParentFile to true
	set my _file_ref to XFile's make_with(a_parent_file)
	--set pathRecord to do(tex_file) of PathAnalyzer
	--set my _workingDirectory to folderReference of pathRecord
	set my _workingDirectory to my _file_ref's parent_folder()
	--set my _texFileName to name of pathRecord
	set my _texFileName to my _file_ref's item_name()
end update_with_parent

on set_filename(a_name)
	set my _texFileName to a_name
end set_filename

on filename()
	return my _texFileName
end filename

on no_suffix_posix_path()
	return my _file_ref's change_path_extension("")'s posix_path()
end no_suffix_posix_path

on no_suffix_target_path()
	return my _targetFileRef's change_path_extension("")'s posix_path()
end no_suffix_target_path

on basename()
	return my _file_ref's basename()
end basename

on target_file()
	return my _targetFileRef
end target_file

on cwd()
	return my _workingDirectory
end cwd

on working_directory()
	return my _workingDirectory
end working_directory

(*== Instance methods *)
on typeset()
	--log "start typeset"
	set beforeCompileTime to current date
	set cd_command to "cd " & (quoted form of (my _workingDirectory's posix_path()))
	
	set tex_command to typeset_command()
	
	if my _use_term then
		set all_command to cd_command & _com_delim & tex_command & space & "'" & my _texFileName & "'"
		send_command of TerminalCommander for all_command
		
		set a_term to make TerminalCommander
		delay 1
		wait_termination(300) of a_term
	else
		set tex_command to XText's make_with(tex_command)
		set command_elems to tex_command's as_xlist_with(space)
		if tex_command's include("-interaction=") then
			script ChangeInteractionMode
				on do(an_elem)
					if an_elem starts with "-interaction=" then
						set contents of an_elem to "-interaction=nonstopmode"
						return false
					end if
					return true
				end do
			end script
			command_elems's each(ChangeInteractionMode)
		else
			set new_command to command_elems's item_at(1) & space & "-interaction=nonstopmode"
			set_item of command_elems for new_command at 1
		end if
		set tex_command to command_elems's as_unicode_with(space)
		--set pathCommand to "export PATH=/usr/local/bin:$PATH"
		--set all_command to pathCommand & "; " & cd_command & "; " & theTexCommand & space & "'" & my _texFileName & "' 2>&1"
		set shell_path to TerminalCommander's shell_path()
		set all_command to cd_command & ";exec " & shell_path & " -lc " & quote & tex_command & space & (quoted form of my _texFileName) & " 2>&1" & quote
		try
			set my _logContents to do shell script all_command
		on error msg number errno
			if errno is 1 then
				-- 1:general tex error
				set my _logContents to msg
			else if errno is 127 then
				-- maybe comannd name or path setting is not correct
				show_error(errno, "texCompile", msg) of MessageUtility
				error "Typeset is not executed." number 1250
			else
				error msg number errno
			end if
		end try
	end if
	--log "after Typeset"
	set a_dvi to lookup_dvi()
	--log "after lookup_dvi"
	if a_dvi is not missing value then
		set_src_special_flag() of a_dvi
	end if
	--log "end typeset"
	return a_dvi
end typeset

on check_logfile()
	set textALogfile to localized string "aLogfile"
	set textHasBeenOpend to localized string "hasBeenOpend"
	set textShouldClose to localized string "shouldClose"
	set textCancel to localized string "Cancel"
	set textClose to localized string "Close"
	
	set a_logfile to XFile's make_with(path_for_suffix(my _log_suffix))
	set logFileReady to false
	if a_logfile's item_exists() then
		if busy status of (a_logfile's info()) then
			set logfile_path to a_logfile's hfs_path()
			tell application "mi"
				set nDoc to count document
				repeat with ith from 1 to nDoc
					set theFilePath to file of document ith as Unicode text
					if theFilePath is logfile_path then
						try
							set a_result to display dialog textALogfile & return & logfile_path & return & textHasBeenOpend & return & textShouldClose buttons {textCancel, textClose} default button textClose with icon note
						on error msg number -128 --if canceld, error number -128
							set logFileReady to false
							exit repeat
						end try
						
						if button returned of a_result is textClose then
							close document ith without saving
							set logFileReady to true
							exit repeat
						end if
					end if
				end repeat
			end tell
		else
			set logFileReady to true
		end if
	else
		set logFileReady to true
	end if
	
	if logFileReady then
		set my _logFileRef to a_logfile
	end if
	return logFileReady
end check_logfile

on build_command(a_command, a_suffix)
	-- replace %s in a_command with texBaseName. if %s is not in a_command, texBaseName+a_suffix is added end of a_command
	if "%s" is in a_command then
		set a_basename to basename()
		set a_command to XText's make_with(a_command)'s replace("%s", a_basename)'s as_unicode()
		return a_command
	else
		set a_filename to name_for_suffix(a_suffix)
		return (a_command & space & "'" & a_filename & "'")
	end if
end build_command

on lookup_header_command(a_paragraph)
	ignoring case
		if a_paragraph starts with "%ParentFile" then
			set a_parentfile to resolve_parent(a_paragraph)
			update_with_parent(a_parentfile)
		else if a_paragraph starts with "%Typeset-Command" then
			set_typeset_command(XText's make_with(text 18 thru -1 of a_paragraph)'s strip()'s as_unicode())
		else if a_paragraph starts with "%DviToPdf-Command" then
			set my _dvipdf_command to XText's make_with(text 19 thru -1 of a_paragraph)'s strip()'s as_unicode()
		else if a_paragraph starts with "%DviToPs-Command" then
			set my _dvips_command to XText's make_with(text 18 thru -1 of a_paragraph)'s strip()'s as_unicode()
		end if
	end ignoring
end lookup_header_command

on lookup_header_commands_from_file()
	--log "start getHearderCommandFromFile"
	set lineFeed to ASCII character 10
	set inputFile to open for access (my _file_ref's as_alias())
	set a_paragraph to read inputFile before lineFeed
	repeat while (a_paragraph starts with "%")
		lookup_header_command(a_paragraph)
		try
			set a_paragraph to read inputFile before lineFeed
		on error
			exit repeat
		end try
	end repeat
	close access inputFile
end lookup_header_commands_from_file

on path_for_suffix(an_extension)
	return my _file_ref's change_path_extension(an_extension)'s hfs_path()
end path_for_suffix

on name_for_suffix(a_suffix)
	return (basename()) & a_suffix
end name_for_suffix

on open_outfile(an_extension)
	set file_path to path_for_suffix(an_extension)
	try
		tell application "Finder"
			open (file_path as alias)
		end tell
	on error msg number errno
		activate
		display alert msg message "Error Number : " & errno
	end try
end open_outfile

on lookup_dvi()
	--log "start lookup_dvi"
	--set dvi_path to path_for_suffix(".dvi")
	set a_dvifile to my _file_ref's change_path_extension(".dvi")
	if a_dvifile's item_exists() then
		--log "dviFilePath exists"
		set a_dvi to make_with(me) of DVIController
		a_dvi's set_dvifile(a_dvifile)
		set_file_type() of a_dvi
		return a_dvi
	else
		return missing value
	end if
end lookup_dvi

(*== Constructors *)
on make_with_dvifile(dvi_file_ref)
	--log "start makeObjFromDVIFile"
	local basepath
	set dvi_path to dvi_file_ref as Unicode text
	if dvi_path ends with ".dvi" then
		set basepath to text 1 thru -5 of dvi_path
	else
		set basepath to dvi_path
	end if
	set tex_path to basepath & ".tex"
	
	--if isExists(POSIX file tex_path) of UtilityHandlers then
	if XFile's make_with(POSIX file tex_path)'s item_exists() then
		set tex_doc_obj to make_with(POSIX file tex_path, missing value)
		tex_doc_obj's lookup_header_commands_from_file()
	else
		set tex_doc_obj to make_with(POSIX file basepath, missing value)
	end if
	
	return tex_doc_obj
end make_with_dvifile

on make_with(a_xfile, an_encoding)
	--log "start make_with in TeXDocController"
	--set pathRecord to do(theTargetFile) of PathAnalyzer
	
	script TeXDocController
		property _file_ref : missing value -- targetFileRef's ParentFile. if ParentFile does not exists, it's same to targeFileRef
		property _typeset_command : missing value
		property _dvipdf_command : missing value
		property _dvips_command : missing value
		property _text_encoding : an_encoding
		
		property _texFileName : missing value
		property _texBasePath : missing value
		property _texBaseName : missing value
		
		property _targetFileRef : missing value -- a document applied tools. alias class
		property _doc_position : missing value
		
		property _logFileRef : missing value
		property _logContents : missing value
		property _workingDirectory : missing value -- if ParentFile exists, it's directory of ParentFile
		property _hasParentFile : false
		--property _isSrcSpecial : missing value
		property _use_term : true
		
	end script
	
	if a_xfile is missing value then
		return TeXDocController
	end if
	
	if class of a_xfile is not script then
		set a_xfile to XFile's make_with(a_xfile)
	end if
	
	set TeXDocController's _file_ref to a_xfile
	set TeXDocController's _targetFileRef to a_xfile
	set TeXDocController's _texFileName to a_xfile's item_name()
	set TeXDocController's _workingDirectory to a_xfile's parent_folder()
	return TeXDocController
end make_with
