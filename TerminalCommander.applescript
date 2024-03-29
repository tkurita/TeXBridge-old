global TerminalCommanderBase
global NSUserDefaults
global NSRunningApplication
global appController

on buildup()
	script TerminalCommanderExtend
		property parent : TerminalCommanderBase
		
		on send_command for a_command
			tell NSUserDefaults's standardUserDefaults()
				set activate_flag to boolForKey_("ActivateTerminal") as boolean
			end tell
			do_command for a_command given activation:activate_flag
		end send_command
		
		on activate_terminal()
			NSRunningApplication's activateAppOfIdentifier_("com.apple.Terminal")
			return true
		end activate_terminal
		
		on execution_string()
			--log "start execution_string"
			tell NSUserDefaults's standardUserDefaults()
				set exec_string to stringForKey_("ExecutionString") as text
			end tell
			if exec_string is "" then
				set exec_string to missing value
			end if
			return exec_string
		end execution_string
		
		on settings_name()
			--log "start settings_name"
			set a_name to missing value
			if my _delegate is not missing value then
				set a_name to my _delegate's settings_name()
			end if
			if a_name is missing value then
				tell NSUserDefaults's standardUserDefaults()
					set a_name to stringForKey_("SettingsSetName")
				end tell
			end if
			if a_name is not missing value then
				set a_name to a_name as text
			end if
			return a_name
		end settings_name
	end script

	tell TerminalCommanderExtend
        set_use_osax_for_customtitle(false)
        set_custom_title(appController's factoryDefaultForKey_("CustomTitle") as text)
        return it
    end tell
end buildup