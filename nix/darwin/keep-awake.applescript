set helper to "/etc/keep-awake/helper"
try
    set timerStatus to do shell script (quoted form of helper & " status")
    if timerStatus starts with "active " then
        do shell script (quoted form of helper & " stop")
        display dialog "Keep Awake stopped. Normal sleep is enabled." with title "Keep Awake" buttons {"OK"} default button "OK"
    else
        set answer to display dialog "Keep awake for how many minutes?" with title "Keep Awake" default answer "" buttons {"Cancel", "Start"} default button "Start" cancel button "Cancel"
        set minutes to text returned of answer
        set timerStatus to do shell script (quoted form of helper & " start " & quoted form of minutes)
        display dialog "Keep Awake is on until " & text 8 thru -1 of timerStatus & ". Click Keep Awake again to stop." with title "Keep Awake" buttons {"OK"} default button "OK"
    end if
on error messageText number errorNumber
    if errorNumber is not -128 then
        display dialog messageText with title "Keep Awake — Error" buttons {"OK"} default button "OK" with icon stop
    end if
end try
