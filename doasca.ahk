; YouTube: @game_play267
; Twitch: RR_357000
; X: @relliK_2048
; Discord:
#Include %A_ScriptDir%\doa_tools\Gdip.ahk
#SingleInstance force
#Persistent
#NoEnv

SendMode Input
DetectHiddenWindows On
SetWorkingDir %A_ScriptDir%
SetBatchLines, -1
SetTitleMatchMode, 2


FileInstall, doa_media\DOA_GOOD_MORNING.wav, %A_Temp%\DOA_GOOD_MORNING.wav, 1
FileInstall, doa_media\DOA_GAME_OVER.wav, %A_Temp%\DOA_GAME_OVER.wav, 1
FileInstall, doa.ini, %A_Temp%\doa.ini, 1

; === Dedicated tools folder ===
dest := A_ScriptDir . "\tools"

FileRemoveDir, %dest%, 1
FileCreateDir, %dest%

; === Install each file (must be literal for FileInstall in AHK v1) ===
FileInstall, doa_tools\Gdip.ahk, %dest%\Gdip.ahk, 1
FileInstall, doa_tools\nircmd.exe, %dest%\nircmd.exe, 1
FileInstall, doa_tools\vgmstream-cli.exe, %dest%\vgmstream-cli.exe, 1
FileInstall, doa_tools\avcodec-vgmstream-59.dll, %dest%\avcodec-vgmstream-59.dll, 1
FileInstall, doa_tools\avformat-vgmstream-59.dll, %dest%\avformat-vgmstream-59.dll, 1
FileInstall, doa_tools\avutil-vgmstream-57.dll, %dest%\avutil-vgmstream-57.dll, 1
FileInstall, doa_tools\libatrac9.dll, %dest%\libatrac9.dll, 1
FileInstall, doa_tools\libcelt-0061.dll, %dest%\libcelt-0061.dll, 1
FileInstall, doa_tools\libcelt-0110.dll, %dest%\libcelt-0110.dll, 1
FileInstall, doa_tools\libg719_decode.dll, %dest%\libg719_decode.dll, 1
FileInstall, doa_tools\libmpg123-0.dll, %dest%\libmpg123-0.dll, 1
FileInstall, doa_tools\libspeex-1.dll, %dest%\libspeex-1.dll, 1
FileInstall, doa_tools\libvorbis.dll, %dest%\libvorbis.dll, 1
FileInstall, doa_tools\swresample-vgmstream-4.dll, %dest%\swresample-vgmstream-4.dll, 1

; === Unzip function ===
Unzip(zipFile, destFolder) {
    sh := ComObjCreate("Shell.Application")
    sh.NameSpace(destFolder).CopyHere(sh.NameSpace(zipFile).Items, (4|16))
}

ExtractZip(tempZip, finalDest) {
    Unzip(tempZip, finalDest)
    Sleep, 200
    FileDelete, %tempZip%
}

; === ffmpeg zip extraction ===
tempZip := A_Temp . "\ffmpeg.zip"
FileInstall, doa_tools\ffmpeg.zip, %tempZip%, 1
ExtractZip(tempZip, dest)
MsgBox, Tools extracted to %dest%


; ─── global config variables. ────────────────────────────────────────────────────────────────────
Global audioPrepared    := false
iniFile                 := A_Temp      . "\doa.ini"
fallbackLog             := A_ScriptDir . "\doa_fallback.log"
FFmpegFolder            := A_ScriptDir . "\tools\"
ffmpegExe               := A_ScriptDir . "\tools\ffmpeg.exe"
nircmd                  := A_ScriptDir . "\tools\nircmd.exe"
logFile                 := A_ScriptDir . "\doa.log"
baseDir                 := A_ScriptDir
recording               := false
ffmpegPID               := 0
lastPlayed              := ""
ffplayPID               := 0
Global muteSound        := 0
DoaGameExe              := "\DOA5A.exe"


; ─── Conditionally set default priority if it's not already set. ──────────────────────────────────────────────────────
IniRead, priorityValue, %iniFile%, PRIORITY, Priority
if (priorityValue = "")
    IniWrite, Normal, %iniFile%, PRIORITY, Priority


; ─── read DOA Game path and extract executable name if found. ────────────────────────────────────────────────────────────
IniRead, DOAGamePath, %iniFile%, DOA_GAME, Path
if (doaPath != "") {
    Global DOAGameExe
    SplitPath, DOAGamePath, DOAGameExe
}


; ─── load last played game id and title with safe defaultS. ────────────────────────────────────────────────────────────
IniRead, lastGameExe, %iniFile%, LAST_PLAYED, GameExe, UnknownID


; ─── save screen size. ────────────────────────────────────────────────────────────────────
IniRead, SavedSize, %iniFile%, SIZE_SETTINGS, SizeChoice, FULLSCREEN
SizeChoice := SavedSize
selectedControl := sizeToControl[SavedSize]
for key, val in sizeToControl {
    label := (val = selectedControl) ? "[" . key . "]" : key
    GuiControl,, %val%, %label%
}
DefaultSize := "FULLSCREEN"


; ─── load window settings from ini. ────────────────────────────────────────────────────────────────────
IniRead, SizeChoice, %iniFile%, SIZE_SETTINGS, SizeChoice, %DefaultSize%


GetCommandOutput(cmd) {
    tmpFile := A_Temp "\cmd_output.txt"
    ; Wrap the entire cmd in double-quotes to preserve quoted paths inside
    fullCmd := ComSpec . " /c """ . cmd . " > """ . tmpFile . """ 2>&1"""
    Log("DEBUG", "Running full command: " . fullCmd)
    RunWait, %fullCmd%,,
    ; RunWait, %fullCmd%,, Hide
    FileRead, output, %tmpFile%
    FileDelete, %tmpFile%
    Log("DEBUG", "Raw output from cmd: " . output)
    return Trim(output)
}


; ─── set as admin. ────────────────────────────────────────────────────────────
if not A_IsAdmin
{
    try
    {
        Run *RunAs "%A_ScriptFullPath%"
    }
    catch
    {
        setText("Error: This script needs to be run as Administrator.")
    }
    ExitApp
}


; ─── Monitor info. ────────────────────────────────────────────────────────────
monitorIndex := 1  ; Change this to 2 for your second monitor

SysGet, MonitorCount, MonitorCount
if (monitorIndex > MonitorCount) {
    setText("Invalid monitor index:" .  monitorIndex)
    ExitApp
}

SysGet, monLeft, Monitor, %monitorIndex%
SysGet, monTop, Monitor, %monitorIndex%
SysGet, monRight, Monitor, %monitorIndex%
SysGet, monBottom, Monitor, %monitorIndex%

; ─── Get real screen dimensions. ────────────────────────────────────────────────────────────
SysGet, Monitor, Monitor, %monitorIndex%
monLeft := MonitorLeft
monTop := MonitorTop
monRight := MonitorRight
monBottom := MonitorBottom

monWidth := monRight - monLeft
monHeight := monBottom - monTop

msg := "Monitor Count: " . MonitorCount . "`n`n"
    . "Monitor  " . monitorIndex    . ":" . "`n"
    . "Left:    " . monLeft         . "`n"
    . "Top:     " . monTop          . "`n"
    . "Right:   " . monRight        . "`n"
    . "Bottom:  " . monBottom       . "`n"
    . "Width:   " . monWidth        . "`n"
    . "Height:  " . monHeight


; ───────────────────────────────────────────────────────────────
;Unique window class name
#WinActivateForce
scriptTitle := "DOA Screen Capture Advanced"
if WinExist("ahk_class AutoHotkey ahk_exe " A_ScriptName) && !A_IsCompiled {
    ;Re-run if script is not compiled
    ExitApp
}

;Try to send a message to existing instance
if A_Args[1] = "activate" {
    PostMessage, 0x5555,,,, ahk_class AutoHotkey
    ExitApp
}

OnMessage(0x5555, "BringToFront")
BringToFront(wParam, lParam, msg, hwnd) {
    Gui, Show
    WinActivate
}

; ─── Sound settings at startup. ───────────────────────────────────────────────────────────────────────────────────────
IniRead, muteSound, %iniFile%, MUTE_SOUND, Mute, 0


; ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
title := "DOA Screen Capture Advanced - " . Chr(169) . " " . A_YYYY . " - Philip"
Gui, Show, w780 h470, %title%
Gui, +LastFound
Gui, Font, s10 q5, Segoe UI
Gui, Margin, 15, 15
GuiHwnd := WinExist()


; ─── DOA Game section. ────────────────────────────────────────────────────────────
Gui, Add, Button, gRunDOAGame         x10 y25 w100 h50, RUN DOA
Gui, Add, Button, gExitDOAGame       x120 y25 w100 h50, EXIT DOA
Gui, Add, Button, gRefreshPath          x230 y25 w100 h50, REFRESH PATH
Gui, Add, Button, gSetDOAGamePath    x340 y25 w100 h50, SET PATH
Gui, Add, Button, gToggleMute vMuteBtn  x450 y25 w100 h50, % (muteSound ? "UNMUTE" : "MUTE")
Gui, Add, Button,                       x560 y25 w100 h50,
Gui, Add, Button,                       x670 y25 w100 h50,


; ─── Priority section. ───────────────────────────────────────────────────────────
Gui, Add, Text,                             x10 y85, Process Priority:
Gui, Add, DropDownList, vPriorityChoice     x10 y110 w100 r6, Idle|Below Normal|Normal|Above Normal|High|Realtime
LoadSettings()
Gui, Add, Text, x12 y5, Run this program from inside the Win64 folder. Use the escape button for a sound test or to quit DOA.
Gui, Add, Button, gSetPriority              x10 y145 w100 h50, SET PROCESS PRIORITY
Gui, Add, Button,                           x120 y145 w100 h50,
Gui, Add, Button,                           x230 y145 w100 h50,
Gui, Add, Button,                           x340 y145 w100 h50,
Gui, Add, Button,                           x450 y145 w100 h50,
Gui, Add, Button,                           x560 y145 w100 h50,
Gui, Add, Button,                           x670 y145 w100 h50,


; ─── Screen manager. ────────────────────────────────────────────────────────────
Gui, Add, Button, vSizeFull gSetSizeChoice          x120 y85 w100 h50, FULLSCREEN
Gui, Add, Button, vSizeWindowed gSetSizeChoice      x230 y85 w100 h50, WINDOWED
Gui, Add, Button, vSizeHidden                       x340 y85 w100 h50, HIDDEN
Gui, Add, Button, gMoveToMonitor                    x450 y85 w100 h50, SWITCH MONITOR 1/2
Gui, Add, Button, gResetScreen                      x560 y85 w100 h50, RESET SCREEN
Gui, Add, Button,                                   x670 y85 w100 h50,


; ─── media. ────────────────────────────────────────────────────────────
Gui, Add, Button, gScreenshot            x10 y205 w100 h50, TAKE SCREENSHOT
Gui, Add, Button, gSetAudiorecord       x120 y205 w100 h50, SET AUDIO DEVICES
Gui, Add, Button, gSetAudioDefault      x230 y205 w100 h50, RESET AUDIO DEVICES
Gui, Add, Button, gAudioCapture         x340 y205 w100 h50, RECORD  AUDIO
Gui, Add, Button, gVideoCapture         x450 y205 w100 h50, CAPTURE VIDEO
Gui, Add, Button,                       x560 y205 w100 h50,
Gui, Add, Button,                       x670 y205 w100 h50,


; ─── other. ────────────────────────────────────────────────────────────
Gui, Add, Button, gViewLog          x10 y265 w100 h50, VIEW LOGS
Gui, Add, Button, gClearLog         x120 y265 w100 h50, CLEAR LOGS
Gui, Add, Button, gOpenScriptDir    x230 y265 w100 h50, BROWSE
Gui, Add, Button, gViewConfig       x340 y265 w100 h50, VIEW  SETTINGS
Gui, Add, Button,                   x450 y265 w100 h50,
Gui, Add, Button,                   x560 y265 w100 h50,
Gui, Add, Button,                   x670 y265 w100 h50,


; ─── text. ────────────────────────────────────────────────────────────
Gui, Add, Text, x5 y325, CONTROLS: Screenshot = F1 | Videocapture = F2 | Audiorecording = F3. Press q inside the ffmpeg window to quit recording


; ─── status bar 1 ────────────────────────────────────────────────────────────
Gui, Add, GroupBox,                 x0 y345 w780 h33
Gui, Add, Text, vVariableTextA      x5 y355 w765, [PATH]
pathText := "PATH: " . (DOAGameExe != "" ? DOAGameExe : "NoData")
GuiControl,, VariableTextA, %pathText%
Log("DEBUG", "Updated VariableTextA with: " . pathText)


; ─── status bar 3. ────────────────────────────────────────────────────────────
Gui, Add, GroupBox,                   x0 y380 w780 h33
Gui, Add, Text, vCurrentPriority      x5 y390 w770,


; ─── status bar 2 ────────────────────────────────────────────────────────────
Gui, Add, GroupBox,                 x0 y415 w780 h33
Gui, Add, Text, vSetText            x5 y425 w770,


; ─── Bottom statusbar, 1 is reserved for process priority status ──────────────────────────────────────────────
Gui, Add, StatusBar, vStatusBar1 hWndhStatusBar
SB_SetParts(355, 445)
UpdateStatusBar(msg, segment := 1) {
    SB_SetText(msg, segment)
}

; ─── Start timers for cpu/memory every x second(s). ───────────────────────────────────────────────────────────────────
SetTimer, UpdateCPUMem, 1000

; ─── Force one immediate priority update. ─────────────────────────────────────────────────────────────────────────────
Gosub, UpdatePriority

; ─── Start priority timer after a delay (3s between updates), runs every 3 seconds. ───────────────────────────────────
SetTimer, UpdatePriority, 3000

; ─── Record timestamp of last update. ─────────────────────────────────────────────────────────────────────────────────
FormatTime, timeStamp, , yyyy-MM-dd HH:mm:ss
Log("DEBUG", "Writing Timestamp " . timeStamp . " to " . iniFile)
IniWrite, %timeStamp%, %iniFile%, LAST_UPDATE, LastUpdated


; ─── System tray. ────────────────────────────────────────────────────────────
Menu, Tray, Add, Show GUI, ShowGui                      ;Add a custom "Show GUI" option
Menu, Tray, Add                                         ;Add a separator line
Menu, Tray, Add, About DOA..., ShowAboutDialog
Menu, Tray, Default, Show GUI                           ;Make "Show GUI" the default double-click action
Menu, Tray, Tip, DOA Screen Capture Tool              ;Tooltip when hovering

; ─── this return ends all updates to the gui. ───────────────────────────────────
return
; ─── END GUI. ───────────────────────────────────────────────────────────────────


setText(newText) {
    GuiControl,, SetText, %newText%
}

; ─── Toggle sound in app. ─────────────────────────────────────────────────────────────────────────────────────────────
ToggleMute:
    muteSound := !muteSound
    IniWrite, %muteSound%, %iniFile%, MUTE_SOUND, Mute
    GuiControl,, MuteBtn, % (muteSound ? "UNMUTE" : "MUTE")
    SoundBeep, 750, 150
return


; ─── Refresh path. ────────────────────────────────────────────────────────────────────────────────────────────────────
RefreshdoaPath()


; ─── DOA path function. ─────────────────────────────────────────────────────────────────────────────────────────────
doaPath:
    FileSelectFile, selectedPath,, 3, Select DOA executable, Executable Files (*.exe)
    if (selectedPath != "")
    {
        doaPath := selectedPath
        IniWrite, %doaPath%, %iniFile%, DOA_GAME, Path
        Log("INFO", "Path saved: " . selectedPath)
    }
Return


; ─── Show GUI. ───────────────────────────────────────────────────────────────────
ShowGui:
    Gui, Show
    setText("Screen Capture Advanced.")
return

CreateGui:
    Gui, New
    Gui, Add, Text,, The GUI was Refreshed, Right Click in the Tray Bar to Reload.
    Gui, Show
Return

ExitScript:
    Log("INFO", "Exiting script via tray menu.")
    ExitApp
return

RefreshGui:
    Gui, Destroy
    Gosub, CreateGui
return


; ─── refresh path to game. ────────────────────────────────────────────────────────────
RefreshPath:
    RefreshDOAGamePath()
    CustomTrayTip("Path refreshed: " DOAGamePath, 1)
    Log("DEBUG", "Path refreshed: " . DOAGamePath)
return


; ─── Set path to DOA5A.exe function. ────────────────────────────────────────────────────────────────────
SetDOAGamePath:
    Global DOAGamePath, DOAGameExe
    FileSelectFile, selectedPath,, , Select DOAGame executable, Executable Files (*.exe)
    if (selectedPath != "" && FileExist(selectedPath)) {
        SaveDOAGamePath(selectedPath)
        IniWrite, %selectedPath%, %iniFile%, DOA_GAME, Path
        ; Also update Global DOAGamePath and DOAGameExe
        ; Global DOAGamePath, DOAGameExe
        DOAGamePath := selectedPath
        SplitPath, DOAGamePath, DOAGameExe

        setText("Path: " . selectedPath)
        Log("INFO", "Path saved: " . selectedPath)
    } else {
        CustomTrayTip("Path not selected or invalid.", 3)
        setText("ERROR: No valid DOAGame executable selected.")
        Log("ERROR", "No valid DOAGame executable selected.")
    }
Return

; ─── Get path to DOA5A.exe function. ────────────────────────────────────────────────────────────────────
GetDOAGamePath() {
    static iniFile := A_ScriptDir . "doa.ini"
    local path

    if !FileExist(iniFile) {
        CustomTrayTip("Missing doa.ini.", 3)
        setText("ERROR: Missing doa.ini when calling GetDOAGamePath.")
        Log("ERROR", "Missing doa.ini when calling GetDOAGamePath()")
        return ""
    }

    IniRead, path, %iniFile%, DOA_GAME, Path
    if (ErrorLevel) {
        CustomTrayTip("Could not read [DOAGame] path from doa.ini.", 3)
        setText("ERROR: Could not read [DOAGame] path from doa.ini.")
        Log("ERROR", "Could not read [DOAGame] path from doa.ini")
        return ""
    }

    path := Trim(path, "`" " ")  ; trim surrounding quotes and spaces

    Log("DEBUG", "GetDOAGamePath, Path is: " . path)

    if (path != "" && FileExist(path) && SubStr(path, -3) = ".exe")
        return path

    CustomTrayTip("Could not read [DOAGame] path from: " . path, 3)
    setText("ERROR: Invalid or non-existent path in doa.ini: " . path)
    Log("ERROR", "Invalid or non-existent path in doa.ini: " . path)
    return ""
}

SaveDOAGamePath(path) {
    static iniFile := A_ScriptDir . "doa.ini"
    IniWrite, %path%, %iniFile%, DOA_GAME, Path
    Log("DEBUG", "Saved path to config: " . DOAGamePath)
    CustomTrayTip("Saved Path to config: " . DOAGamePath, 1)
}

DOAGamePath := GetDOAGamePath()
Log("DEBUG", "Saved path to config: " . DOAGamePath)

if (DOAGamePath = "") {
    setText("Warning, Path not set or invalid. Please select it now.")
    FileSelectFile, selectedPath,, , Select DOAGame executable, Executable Files (*.exe)
    if (selectedPath != "" && FileExist(selectedPath)) {
        SaveDOAGamePath(selectedPath)
        DOAGamePath := selectedPath
        setText("Info, Saved Path:" . DOAGamePath)
    } else {
        setText("Error, No valid path selected. Exiting.")
        ExitApp
    }
} else {
setText("Info, Using Path:" . DOAGamePath)
}


; ─── DOAGame path function. ────────────────────────────────────────────────────────────────────
DOAGamePath:
    FileSelectFile, selectedPath,, 3, Select DOAGame executable, Executable Files (*.exe)
    if (selectedPath != "")
    {
        DOAGamePath := selectedPath
        IniWrite, %DOAGamePath%, %iniFile%, DOA_GAME, Path
        setText("Saved: Path saved: " . selectedPath)
        Log("INFO", "Path saved: " . selectedPath)
    }
Return


; ─── Load settings function. ────────────────────────────────────────────────────────────────────
LoadSettings() {
    Global PriorityChoice, iniFile, DOAGameExe

    Process, Exist, %DOAGameExe%
    if (!ErrorLevel) {
        defaultPriority := "Normal"
        ; IniWrite, %defaultPriority%, %iniFile%, PRIORITY, Priority

        ; Extract just the filename for display
        SplitPath, iniFile, iniFileName

        ; Status bar message with clean formatting
        setText("Process Not Found. Priority [" defaultPriority "] Saved to " iniFileName ".")
        ; CustomTrayTip("Initial Priority Set to " defaultPriority, 1)

        ; Update GUI
        GuiControl, ChooseString, PriorityChoice, %defaultPriority%
        PriorityChoice := defaultPriority

        Log("INFO", "Set default priority to " defaultPriority " in " iniFile)
    }
    else {
        ; Load saved priority if process exists
        IniRead, savedPriority, %iniFile%, PRIORITY, Priority, Normal
        GuiControl, ChooseString, PriorityChoice, %savedPriority%
        PriorityChoice := savedPriority
    }
}

; ─── Save current settings function. ────────────────────────────────────────────────────────────────────
SaveSettings() {
    Global PriorityChoice, iniFile

    ; Get current selection from GUI (important!)
    GuiControlGet, currentPriority,, PriorityChoice
    Log("DEBUG", "Attempting to save priority: "currentPriority)

    ; Save to INI
    ; IniWrite, %currentPriority%, %iniFile%, PRIORITY, Priority
    Log("INFO", "TrayTip shown: Priority set to "currentPriority)
}


; ─── Kill DOAGame with button function. ────────────────────────────────────────────────────────────────────
ExitDOAGame:
    if (!muteSound)
        SoundPlay, %A_Temp%\DOA_GAME_OVER.wav, 1

    ; Confirm what we're checking for
    Log("DEBUG", "Checking for process: " . DOAGameExe)
    Process, Exist, %DOAGameExe%

    pid := ErrorLevel
    if (pid) {
        KillAllProcesses(pid)  ; Pass PID to function
        ; CustomTrayTip("Killed all DOAGame processes.")
        Log("INFO", "Killed all DOAGame processes (PID: " . pid . ")")
        setText("Killed all DOAGame processes.")
    } else {
        ; CustomTrayTip("No DOAGame processes running.")
        Log("INFO", "No DOAGame processes running.")
        setText("No DOAGame processes running")
    }

;    Gui, Show ; Show or hide GUI but keep script alive
;    Menu, Tray, Show  ; Ensure tray icon stays visible
return


; ─── kill all processes for DOAGame. ────────────────────────────────────────────────────────────────────
KillAllProcesses(pid := "") {
    ahkPid := DllCall("GetCurrentProcessId")

    if (pid) {
        if (pid = ahkPid) {
            Log("WARN", "KillAllProcesses: Tried to kill AHK itself (PID " . pid . "). Skipping.")
            return
        }

        ; Run, "%A_ScriptFullPath%" activate
        RunWait, taskkill /im %DOAGameExe% /F,, Hide
        RunWait, taskkill /im powershell.exe /F,, Hide
        RunWait, %ComSpec% /c taskkill /PID %pid% /F,, Hide
        ; Optional: Kill any potential child processes
        RunWait, %ComSpec% /c taskkill /im powershell.exe /F,, Hide

        Log("INFO", "KillAllProcesses: Killed PID " . pid)
    } else {
        Log("WARN", "KillAllProcesses: No PID provided.")
    }
}


; ─── exit  the app. ────────────────────────────────────────────────────────────────────
Exitdoa:
    if (!muteSound) {
        SoundPlay, %A_Temp%\DOA_GAME_OVER.wav
        Sleep, 3500
    }
    Log("INFO", "Exiting AHK using the Exit button.")
    ExitApp
return


; ─── Run DOAGame standalone function. ────────────────────────────────────────────────────────────────────
RunDOAGame:
    Global iniFile
    if (!FileExist(IniFile)) {
        SplitPath, IniFile, iniFileName
        CustomTrayTip("Missing " . IniFile . " Set DOAGame Path first.", 3)
        setText("Missing " . IniFile . " Set DOAGame Path first.")
        Return
    }

    setText("Reading from: " . IniFile)

    IniRead, DOAGamePath, %IniFile%, DOA_GAME, Path
    if (DOAGamePath != "") {
        Global DOAGameExe
        SplitPath, DOAGamePath, DOAGameExe
    }
    setText("Path read: " . DOAGamePath)

    if (ErrorLevel) {
        CustomTrayTip("Could not read path from " . IniFile, 3)
        setText("Could not read the path from " . IniFile)
        Log("ERROR", "Could not read the path from section [DOAGame] in`n" . IniFile)
        Return
    }

    if !FileExist(DOAGamePath) {
        CustomTrayTip("File not found: " . DOAGamePath, 3)
        setText("File not found: " . DOAGamePath)
        Log("ERROR", "The file does not exist:`n" . DOAGamePath)
    Return
    }

    ; Extract the EXE name only
    SplitPath, DOAGamePath, DOAGameExe

    ; Kill any existing DOAGame process by exe name
    RunWait, taskkill /im %DOAGameExe% /F,, Hide
    Sleep, 1000

    ; Launch DOAGame
    Run, %DOAGamePath%

    Sleep, 2000
    Process, Exist, %DOAGameExe%
    if (!ErrorLevel)
    {
    setText("Error, Failed to launch DOAGame:" . DOAGamePath)
    Log("ERROR", "DOAGame failed to launch.")
    setText("ERROR: DOAGame did not launch.")
    CustomTrayTip("ERROR: DOAGame did not launch!", 3)
    return
    }
    if (!muteSound)
    SoundPlay, %A_Temp%\DOA_GOOD_MORNING.wav
    Log("INFO", "Game Started.")
    setText("Good Morning! Game Started.")
    CustomTrayTip("Good Morning! Game Started.", 1)
Return


; ─── View logs function. ────────────────────────────────────────────────────────────────────
ViewLog:
Global logFile
    Run, % "notepad.exe """ logFile """"
    Log("DEBUG", "Opened " . logFile . " in Notepad.")
return


; ─── Clear logs function. ────────────────────────────────────────────────────────────────────
ClearLog:
Global logFile
    FileDelete, %logFile%
    CustomTrayTip(logFile . " cleared successfully", 1)
return


; ─── View configuration function. ────────────────────────────────────────────────────────────────────
ViewConfig:
    Global iniFile
    Run, notepad.exe "%iniFile%"
    SplitPath, iniFile, iniFileName
    Log("DEBUG", "Opened: " iniFile)
    UpdateStatusBar(iniFile . " opened.",2)
return


; ─── browse script dir. ────────────────────────────────────────────────────────────────────
OpenScriptDir:
    Run, %A_ScriptDir%
return


; ─── Show "about" dialog function. ────────────────────────────────────────────────────────────────────
ShowAboutDialog() {
    ; Extract embedded version.dat resource to temp file
    tempFile := A_Temp "\version.dat"
    hRes := DllCall("FindResource", "Ptr", 0, "VERSION_FILE", "Ptr", 10) ;RT_RCDATA = 10
    if (hRes) {
        hData := DllCall("LoadResource", "Ptr", 0, "Ptr", hRes)
        pData := DllCall("LockResource", "Ptr", hData)
        size := DllCall("SizeofResource", "Ptr", 0, "Ptr", hRes)
        if (pData && size) {
            File := FileOpen(tempFile, "w")
            if IsObject(File) {
                File.RawWrite(pData + 0, size)
                File.Close()
            }
        }
    }

    ; Read version string
    FileRead, verContent, %tempFile%
    version := "Unknown"
    if (verContent != "") {
        version := verContent
    }

aboutText := "DOA Screen Capture Advanced`n"
           . "Version: " . version . "`n"
           . Chr(169) . " " . A_YYYY . " Philip" . "`n"
           . "YouTube: @game_play267" . "`n"
           . "Twitch: RR_357000" . "`n"
           . "X: @relliK_2048" . "`n"
           . "Discord:"

MsgBox, 64, About DOA, %aboutText%
}


; ─── Update CPU status function. ──────────────────────────────────────────────────────────────────────────────────────
UpdateCPUMem() {
    try {
        ComObjError(false)
        objWMIService := ComObjGet("winmgmts:\\.\root\cimv2")
        colCompSys := objWMIService.ExecQuery("Select * from Win32_OperatingSystem")
        for obj in colCompSys {
            totalMem := Round(obj.TotalVisibleMemorySize / 1024, 1)
            freeMem := Round(obj.FreePhysicalMemory / 1024, 1)
        }

        colProc := objWMIService.ExecQuery("Select * from Win32_Processor")
        for objItem in colProc {
            cpuLoad := objItem.LoadPercentage
        }

        SB_SetText(" CPU: " . cpuLoad . "% | Free RAM: " . freeMem . " MB / " . totalMem . " MB")

        Global lastResourceLog := 0  ; Global variable to track last log time
        Global logInterval := logInterval   ; 5 seconds in milliseconds

    } catch e {
        setText("Error fetching CPU/memory: " . e.Message)
    }
}


; ─── DOA refresh path function. ─────────────────────────────────────────────────────────────────────────────────────
RefreshdoaPath() {
    Global doaPath
    Global iniFile

    IniRead, path, %iniFile%, DOA_GAME, Path
    path := Trim(path, "`" " ")

    if (path = "" || !FileExist(path) || SubStr(path, -3) != ".exe") {
        MsgBox, 48, Path, Invalid path in INI file. Please select DOA5A.exe manually.

        FileSelectFile, userPath, 3, , Select DOA Executable, Executable (*.exe)
        if (userPath = "") {
            MsgBox, 48, Cancelled, No file selected. Path unchanged.
            return
        }

        userPath := Trim(userPath, "`" " ")
        IniWrite, %userPath%, %iniFile%, DOA_GAME, Path
        doaPath := userPath
        Log("INFO", "User manually selected Path: " . userPath)
        MsgBox, 64, Path Updated, Path successfully updated to:`n%userPath%
        return
    }

    doaPath := path
    Log("INFO", "Path refreshed: " . path)
    CustomTrayTip("Path refreshed: " . path, 1)
}


; ─── DOA check if running function. ─────────────────────────────────────────────────────────────────────────────────
GetDOAWindowID(ByRef hwnd) {
    WinGet, hwnd, ID, ahk_exe DOA5A.exe
    if !hwnd {
        MsgBox, DOA5A.exe is not running.
        return false
    }
    return true
}


; ─── Process exists. ──────────────────────────────────────────────────────────────────────────────────────────────────
ProcessExist(name) {
    Process, Exist, %name%
    return ErrorLevel
}


; ─── Raw ini valuer. ──────────────────────────────────────────────────────────────────────────────────────────────────
GetIniValueRaw(file, section, key) {
    sectionFound := false
    Loop, Read, %file%
    {
        line := A_LoopReadLine
        if (RegExMatch(line, "^\s*\[" . section . "\]\s*$")) {
            sectionFound := true
            continue
        }
        if (sectionFound && RegExMatch(line, "^\s*\[.*\]\s*$")) {
            break
        }
        if (sectionFound && RegExMatch(line, "^\s*" . key . "\s*=\s*(.*)$", m)) {
            return m1
        }
    }
    return ""
}


; ─── Kill DOAGame process with escape button function. ────────────────────────────────────────────────────────────────────
Esc::
    wav := A_Temp . "\DOA_GAME_OVER.wav"
    if FileExist(wav)
    SoundPlay, %wav%
    else
    MsgBox, WAV not found at: %wav%

    Process, Exist, DOA5A.exe
    if (ErrorLevel) {
        CustomTrayTip("ESC pressed. Killing DOA processes.")
        Log("WARN", "ESC pressed. Killing all DOA processes.")
        KillAllProcessesEsc()
    } else {
        CustomTrayTip("No DOA processes found.", 1)
        Log("INFO", "Pressed escape key but no DOA processes found.")
    }
return


KillAllProcessesEsc() {
    RunWait, taskkill /im DOA5A.exe /F,, Hide
    RunWait, taskkill /im powershell.exe /F,, Hide
    ;RunWait, taskkill /im autohotkey.exe /F,, Hide
    Log("INFO", "ESC pressed. Killing all DOA processes.")
}


;; ─── set window size handler. ───────────────────────────────────────────────────────────────────
       ;;SetSizeChoice:
       ;;clicked := A_GuiControl
       ;;Global SizeChoice, iniFile
       ;;
       ;;; map control names to size values
       ;;sizes := { "SizeFull": "FULLSCREEN", "SizeWindowed":  "WINDOWED", "SizeHidden": "HIDDEN" }
       ;;
       ;;; save selected size
       ;;SizeChoice := sizes[clicked]
       ;;IniWrite, %SizeChoice%, %iniFile%, SIZE_SETTINGS, SizeChoice
       ;;
       ;;; update visuals (bracket the selected one)
       ;;for key, val in sizes {
       ;;    label := (key = clicked) ? "[" . val . "]" : val
       ;;    GuiControl,, %key%, %label%
       ;;}
       ;;; immediately apply the size
       ;;GoSub, ResizeWindow
       ;;return
       ;;
       ;;
       ;;ResizeWindow:
       ;;    Global iniFile
       ;;    Gui, Submit, NoHide
       ;;    setText("Current SizeChoice: " . SizeChoice)
       ;;
       ;;    ;-----------------------------------------------------------------
       ;;    ;  1. make sure DOA is running, get HWND
       ;;    ;-----------------------------------------------------------------
       ;;    WinGet, hwnd, ID, ahk_exe DOA5A.exe
       ;;    if !hwnd {
       ;;        MsgBox, DOAGame is not running.
       ;;        return
       ;;    }
       ;;    WinID := "ahk_id " hwnd
       ;;
       ;;    ;-----------------------------------------------------------------
       ;;    ; 2. helper to turn any fixed-size choice into “fake-fullscreen”
       ;;    ;-----------------------------------------------------------------
       ;;    FakeFullscreen(width, height)
       ;;    {
       ;;        ; remove borders / title bar
       ;;        Global WinID
       ;;        WinSet, Style, -0xC00000, %WinID%  ; WS_CAPTION
       ;;        WinSet, Style, -0x800000, %WinID%  ; WS_BORDER
       ;;        WinSet, ExStyle, -0x00040000, %WinID%  ; WS_EX_DLGMODALFRAME
       ;;        WinShow, %WinID%
       ;;
       ;;        ; which monitor is the window on?
       ;;        WinGetPos, winX, winY, , , %WinID%
       ;;        SysGet, MonitorCount, MonitorCount
       ;;        Loop, %MonitorCount% {
       ;;            SysGet, Mon, Monitor, %A_Index%
       ;;            if (winX >= MonLeft && winX < MonRight
       ;;             && winY >= MonTop  && winY < MonBottom) {
       ;;                monLeft   := MonLeft
       ;;                monTop    := MonTop
       ;;                monWidth  := MonRight  - MonLeft
       ;;                monHeight := MonBottom - MonTop
       ;;                break
       ;;            }
       ;;        }
       ;;
       ;;        ; centre the custom-sized window
       ;;        newX := monLeft + (monWidth  - width)  // 2
       ;;        newY := monTop  + (monHeight - height) // 2
       ;;        WinMove, %WinID%, , %newX%, %newY%, %width%, %height%
       ;;    }
       ;;
       ;;    ;-----------------------------------------------------------------
       ;;    ; 3. act on the user’s SizeChoice
       ;;    ;-----------------------------------------------------------------
       ;;    ; native maximised / true fullscreen
       ;;    if (SizeChoice = "FULLSCREEN") {
       ;;        WinRestore, %WinID%
       ;;        WinMaximize, %WinID%
       ;;    }
       ;;    ; windowed mode you already had (keeps borders, uses INI size)
       ;;    else if (SizeChoice = "Windowed") {
       ;;    ; Restore normal window styles
       ;;    WinSet, Style, +0xC00000, %WinID%       ; WS_CAPTION (title bar)
       ;;    WinSet, Style, +0x800000, %WinID%       ; WS_BORDER
       ;;    WinSet, Style, +0x20000,  %WinID%       ; WS_MINIMIZEBOX
       ;;    WinSet, Style, +0x10000,  %WinID%       ; WS_MAXIMIZEBOX
       ;;    WinSet, Style, +0x40000,  %WinID%       ; WS_SYSMENU (close button)
       ;;    WinSet, ExStyle, +0x00040000, %WinID%   ; WS_EX_DLGMODALFRAME
       ;;
       ;;    WinShow, %WinID%
       ;;    WinRestore, %WinID%
       ;;    WinMaximize, %WinID%
       ;;    }
       ;;    else if (SizeChoice = "Hidden")
       ;;        WinHide, %WinID%
       ;;return
       ;;
       ;;
       ;;; ─── switch between monitors handler. ───────────────────────────────────────────────────────────────────
       ;;Run, DOA5A.exe,,, pid
       ;;WinWait, ahk_exe DOA5A.exe
       ;;
       ;;
       ;;; ─── monitor switch logic. ───────────────────────────────────────────────────────────────────
       ;;MoveToMonitor:
       ;;    MoveWindowToOtherMonitor("DOA5A.exe")
       ;;return
       ;;
       ;;
       ;;; ─── window functions. ───────────────────────────────────────────────────────────────────
       ;;exeName := "DOA5A.exe"
       ;;MoveWindowToOtherMonitor(exeName) {
       ;;    WinGet, hwnd, ID, ahk_exe %exeName%
       ;;    if !hwnd {
       ;;        MsgBox, %exeName% is not running.
       ;;        return
       ;;    }
       ;;
       ;;    WinGetPos, winX, winY,,, ahk_id %hwnd%
       ;;    SysGet, Mon1, Monitor, 1
       ;;    SysGet, Mon2, Monitor, 2
       ;;
       ;;    if (winX >= Mon1Left && winX < Mon1Right)
       ;;        currentMon := 1
       ;;    else
       ;;        currentMon := 2
       ;;
       ;;    if (currentMon = 1) {
       ;;        targetLeft := Mon2Left
       ;;        targetTop := Mon2Top
       ;;        targetW := Mon2Right - Mon2Left
       ;;        targetH := Mon2Bottom - Mon2Top
       ;;    } else {
       ;;        targetLeft := Mon1Left
       ;;        targetTop := Mon1Top
       ;;        targetW := Mon1Right - Mon1Left
       ;;        targetH := Mon1Bottom - Mon1Top
       ;;    }
       ;;
       ;;    WinRestore, ahk_id %hwnd%
       ;;    WinSet, Style, -0xC00000, ahk_id %hwnd%
       ;;    WinSet, Style, -0x800000, ahk_id %hwnd%
       ;;    WinMove, ahk_id %hwnd%, , targetLeft, targetTop, targetW, targetH
       ;;}
       ;;
       ;;; ─── reset to defaults for window positions. ───────────────────────────────────────────────────────────────────
       ;;ResetScreen:
       ;;Global SizeChoice, DefaultSize, iniFile
       ;;; Restore defaults
       ;;SizeChoice := DefaultSize
       ;;
       ;;; Update size buttons
       ;;sizeToControl := { "FULLSCREEN": "SizeFull", "WINDOWED": "SizeWindowed", "HIDDEN": "SizeHidden" }
       ;;
       ;;for key, val in sizeToControl {
       ;;    label := (key = SizeChoice) ? "[" . key . "]" : key
       ;;    GuiControl,, %val%, %label%
       ;;}
       ;;IniWrite, %SizeChoice%, %iniFile%, SIZE_SETTINGS, SizeChoice
       ;;
       ;;return


; ─── set window size handler ─────────────────────────────────────────────────────────────
SetSizeChoice:
clicked := A_GuiControl
Global SizeChoice, iniFile

; map control names to size values
sizes := { "SizeFull": "FULLSCREEN", "SizeWindowed": "WINDOWED", "SizeBorderless": "BORDERLESS", "SizeHidden": "HIDDEN" }

; save selected size
SizeChoice := sizes[clicked]
IniWrite, %SizeChoice%, %iniFile%, SIZE_SETTINGS, SizeChoice

; update visuals
for key, val in sizes {
    label := (key = clicked) ? "[" . val . "]" : val
    GuiControl,, %key%, %label%
}

; immediately apply the size
GoSub, ResizeWindow
return


; ─── resize window ─────────────────────────────────────────────────────────────
ResizeWindow:
Global iniFile
Gui, Submit, NoHide
setText("Current Screen Size Choice: " . SizeChoice)

WinGet, hwnd, ID, ahk_exe DOA5A.exe
if !hwnd {
    MsgBox, Dead Or Alive is not running.
    return
}
WinID := "ahk_id " hwnd

; make borderless fullscreen safely
MakeBorderlessFullscreenSafe(hwnd)
return


; ─── helper: borderless fullscreen function ─────────────────────────────────────────────
MakeBorderlessFullscreenSafe(hwnd) {
    if !hwnd
        return

    WinShow, ahk_id %hwnd%
    WinRestore, ahk_id %hwnd%
    Sleep, 120

    ; get monitor for window
    WinGetPos, winX, winY, winW, winH, ahk_id %hwnd%
    centerX := winX + winW // 2
    centerY := winY + winH // 2

    SysGet, MonCount, MonitorCount
    Loop, %MonCount% {
        SysGet, Mon, Monitor, %A_Index%
        if (centerX >= MonLeft && centerX < MonRight && centerY >= MonTop && centerY < MonBottom) {
            targetX := MonLeft
            targetY := MonTop
            targetW := MonRight - MonLeft
            targetH := MonBottom - MonTop
            break
        }
    }

    ; fallback to primary
    if (!targetW) {
        SysGet, Mon, Monitor, 1
        targetX := MonLeft
        targetY := MonTop
        targetW := MonRight - MonLeft
        targetH := MonBottom - MonTop
    }

    ; remove borders
    WinSet, Style, -0xC00000, ahk_id %hwnd%
    WinSet, Style, -0x800000, ahk_id %hwnd%
    WinSet, ExStyle, -0x00040000, ahk_id %hwnd%
    WinMove, ahk_id %hwnd%, , targetX, targetY, targetW, targetH
    DllCall("RedrawWindow", "ptr", hwnd, "ptr", 0, "ptr", 0, "uint", 0x85)
    Sleep, 50
}


; ─── move to next monitor ─────────────────────────────────────────────────────────────
exeName := "DOA5A.exe"
MoveWindowToOtherMonitor(exeName) {
    WinGet, hwnd, ID, ahk_exe %exeName%
    if !hwnd {
        MsgBox, %exeName% is not running.
        return
    }

    WinGetPos, winX, winY, winW, winH, ahk_id %hwnd%
    centerX := winX + winW // 2
    centerY := winY + winH // 2

    SysGet, MonCount, MonitorCount
    if (MonCount < 2)
        return

    currentMon := 1
    Loop, %MonCount% {
        SysGet, Mon, Monitor, %A_Index%
        if (centerX >= MonLeft && centerX < MonRight && centerY >= MonTop && centerY < MonBottom) {
            currentMon := A_Index
            break
        }
    }

    targetMon := (currentMon < MonCount) ? currentMon + 1 : 1
    SysGet, MonT, Monitor, %targetMon%
    targetLeft := MonTLeft
    targetTop  := MonTTop
    targetW := MonTRight - MonTLeft
    targetH := MonTBottom - MonTTop

    WinShow, ahk_id %hwnd%
    WinRestore, ahk_id %hwnd%
    Sleep, 80

    WinMove, ahk_id %hwnd%, , targetLeft, targetTop, targetW, targetH
    MakeBorderlessFullscreenSafe(hwnd)
    return
}


; ─── hotkey or button handler for monitor switch ─────────────────────────────────────────────
MoveToMonitor:
MoveWindowToOtherMonitor("DOA5A.exe")
return


; ─── reset screen settings ─────────────────────────────────────────────────────────────
ResetScreen:
Global SizeChoice, DefaultSize, iniFile
SizeChoice := DefaultSize

sizeToControl := { "FULLSCREEN": "SizeFull", "WINDOWED": "SizeWindowed", "BORDERLESS": "SizeBorderless", "HIDDEN": "SizeHidden" }
for key, val in sizeToControl {
    label := (key = SizeChoice) ? "[" . key . "]" : key
    GuiControl,, %val%, %label%
}
IniWrite, %SizeChoice%, %iniFile%, SIZE_SETTINGS, SizeChoice
return

; ─── Log function. ────────────────────────────────────────────────────────────────────
Log(level, msg) {
Global logFile
    static needsRotation := true
    static inLog := false  ;recursion guard

    if (inLog)
        return  ; Already logging, avoid recursion

    inLog := true

    if (needsRotation && FileExist( logfile)) {
        FileGetSize, logSize, %logfile%
        if (logSize > 1024000) {  ;>1MB
            FormatTime, timestamp,, yyyyMMdd_HHmmss
            FileMove, %logfile%, %A_ScriptDir%\doa_%timestamp%.log
        }
        needsRotation := false
    }

    try {
        FormatTime, timestamp,, yyyy-MM-dd HH:mm:ss
        logEntry := "[" timestamp "] [" level "] " msg "`n"
        FileAppend, %logEntry%, %logfile%
    }
    catch e {
        FormatTime, timestamp,, yyyy-MM-dd HH:mm:ss
        FileAppend, [%timestamp%] [MAIN-LOG-FAILED] %e%`n, %fallbackLog%
        FileAppend, %logEntry%, %fallbackLog%

        ; User notifications
        setText("LOG ERROR: Check fallback.log.")
    }

    inLog := false
}


; ─── Custom tray tip function ────────────────────────────────────────────────────────────────────
CustomTrayTip(Text, Icon := 1) {
    ; Parameters:
    ; Text  - Message to display
    ; Icon  - 0=None, 1=Info, 2=Warning, 3=Error (default=1)
    static Title := "DOA Screen Capture Advanced"
    ; Validate icon input (clamp to 0-3 range)
    Icon := (Icon >= 0 && Icon <= 3) ? Icon : 1
    ; 16 = No sound (bitwise OR with icon value)
    TrayTip, %Title%, %Text%, , % Icon|16
}


; ─── DOAGame refresh path function. ────────────────────────────────────────────────────────────────────
RefreshDOAGamePath() {
    Global DOAGamePath
    Global iniFile

    IniRead, path, %iniFile%, DOA_GAME, Path
    path := Trim(path, "`" " ")

    if (path = "" || !FileExist(path) || SubStr(path, -3) != ".exe") {
        MsgBox, 48, Path, Invalid path in INI file. Please select DOA5A.exe manually.

        FileSelectFile, userPath, 3, , Select DOAGame Executable, Executable (*.exe)
        if (userPath = "") {
            MsgBox, 48, Cancelled, No file selected. Path unchanged.
            return
        }

        userPath := Trim(userPath, "`" " ")
        IniWrite, %userPath%, %iniFile%, DOA_GAME, Path
        DOAGamePath := userPath
        Log("INFO", "User manually selected Path: " . userPath)
        MsgBox, 64, Path Updated, Path successfully updated to:`n%userPath%
        return
    }

    DOAGamePath := path
    Log("INFO", "Path refreshed: " . path)
    CustomTrayTip("Path refreshed: " . path, 1)
    setText("PATH: " . path)
}


; ─── DOAGame check if running function. ────────────────────────────────────────────────────────────────────
GetDOAGameWindowID(ByRef hwnd) {
    WinGet, hwnd, ID, ahk_exe DOA5A.exe
    if !hwnd {
        MsgBox, DOA5A.exe is not running.
        return false
    }
    return true
}


; ─── Install 7-zip function. ────────────────────────────────────────────────────────────────────
Extract7z(filePath, extractTo) {
    sevenZipPath := A_ScriptDir "\doa_tools\7z.exe"

    if !FileExist(sevenZipPath) {
        MsgBox, 16, Error, Missing 7z.exe in script folder.`n%sevenZipPath%
        return false
    }

    ; Run 7-Zip to extract the file
    RunWait, %ComSpec% /c ""%sevenZipPath%" x "%filePath%" -o"%extractTo%" -y",, Hide

    if ErrorLevel {
        MsgBox, 16, Error, Extraction failed.
        return false
    }

    return true
}

; ─── Hotkey for screenshot ─────────────────────────
F1::
    Gosub, Screenshot
return


; ─── Take screenshot function. ────────────────────────────────────────────────────────────────────
Screenshot:
{
    ; 2 Ensure DOAGame exists
    if !WinExist("ahk_exe DOA5A.exe") {
        ; CustomTrayTip("DOAGame Window Not Found.",2)
        Log("ERROR", "DOAGame Window Not Found.")
        setText("DOAGame Window Not Found.")
        return
    }

    ; 3 Get HWND, bring to front (optional)
    WinGet, hwnd, ID, ahk_exe DOA5A.exe
    WinActivate, ahk_id %hwnd%
    WinWaitActive, ahk_id %hwnd%,, 2

    ; 4 Window metrics
    WinGetPos, X, Y, W, H, ahk_id %hwnd%
    WinGet, winStyle, Style, ahk_id %hwnd%
    WinGet, winExStyle, ExStyle, ahk_id %hwnd%

    ; ── log Debug Info exactly as requested ──
    info := "Debug Info:`n`n"
    info .= "Window Handle: " hwnd "`n`n"
    info .= "Position: X" X " Y" Y "`n`n"
    info .= "Size: " W "x" H "`n`n"
    info .= "Style: " winStyle "`n`n"
    info .= "ExStyle: " winExStyle "`n`n"
    Log("DEBUG", info)

    ; 5 Adjust for negatives (multi-monitor)
    if (X < 0 || Y < 0) {
        SysGet, mCount, MonitorCount
        Loop, %mCount% {
            SysGet, Mon, Monitor, %A_Index%
            if (X >= MonLeft && X < MonRight && Y >= MonTop && Y < MonBottom) {
                ; nothing to fix – coords already absolute
                break
            }
        }
    }

    ; 6 Start GDI+
    if !(pToken := Gdip_Startup()) {
        ; CustomTrayTip("GDI+ init failed.",2)
        Log("ERROR", "GDI+ failed to initialise.")
        setText("GDI+ init failed.")
        return
    }

    ; 7 Capture DOAGame window
    pBitmap := Gdip_BitmapFromScreen(X "|" Y "|" W "|" H)
    if !pBitmap {
        Log("ERROR", "Screen capture failed. hwnd=" . hwnd)
        ; CustomTrayTip("Screen capture failed (see log).",2)
        setText("Screen capture failed.")
        Gdip_Shutdown(pToken)
        return
    }

    ; 8 Screenshot format from INI
    IniRead, ShotFormat, %iniFile%, Settings, ScreenshotFormat, png
    ShotFormat := (ShotFormat = "jpg") ? "jpg" : "png"

    ; 9 Ensure screenshots folder exists
    ScreenshotDir := A_ScriptDir "\doa_screenshots"
    FileCreateDir, %ScreenshotDir%

    ; 10 File name  GameID_YYYY-MM-DD_HH-MM-SS.ext
    FormatTime, ts,, yyyy-MM-dd_HH-mm-ss
    filePath := ScreenshotDir "\" GameID "_" ts "." ShotFormat

    ; 11 Save bitmap
    result := Gdip_SaveBitmapToFile(pBitmap, filePath)
    Gdip_DisposeImage(pBitmap)
    Gdip_Shutdown(pToken)

    if (result) {                     ; non-zero = error
        Log("ERROR", "Save failed. Code=" . result . " Path=" . filePath)
        ; CustomTrayTip("Failed to save screenshot! Code " . result,2)
        setText("Screenshot save failed.")
    } else {
        Log("DEBUG", "Screenshot taken: " . filePath)
        setText("Screenshot saved: " . filePath)
        Run, %ScreenshotDir%
    }
    return
}


; ─── Hotkey to toggle recording ─────────────────────────
F2::
    Gosub, VideoCapture
return


; ─── Toggle Video Capture ───────────────────────────────
VideoCapture:
nircmd := A_ScriptDir . "\tools\nircmd.exe"
ffmpegExe := A_ScriptDir . "\tools\ffmpeg.exe"

; Ensure NirCmd exists
if !FileExist(nircmd) {
    MsgBox, 16, Error, nircmd.exe not found at:`n%nircmd%
    return
}

; Ensure ffmpeg exists
if !FileExist(ffmpegExe) {
    MsgBox, 16, Error, ffmpeg.exe not found at:`n%ffmpegExe%
    return
}

; ─── Detect if FFmpeg is running ────────────────────────
Process, Exist, ffmpeg.exe
ffmpegPIDRunning := ErrorLevel

; ─── STOP recording if FFmpeg is found ──────────────────
if (ffmpegPIDRunning) {
    Process, Close, %ffmpegPIDRunning%
    ControlSend,, q, ahk_pid %ffmpegPIDRunning%.
    recording := false
    GuiControl, +c808080, VideoCapture
    CustomTrayTip("Recording stopped.", 1)

    ; Reset audio devices
    RunWait, "%nircmd%" setdefaultsounddevice "Speakers" 1 /nosplash,, Hide
    RunWait, "%nircmd%" setdefaultsounddevice "Microphone" 1 /nosplash,, Hide
    CustomTrayTip("Audio input/output set to default", 1)
    return
}

; ─── START recording if FFmpeg is not found ─────────────
if !ProcessExist("DOA5A.exe") {
    CustomTrayTip("Cannot Record, DOA is not running.", 3)
    return
}

MsgBox, 52, Warning, Did you SET AUDIO DEVICES?
IfMsgBox No
{
    MsgBox, 48, Info, click SET AUDIO DEVICES.
    return
}

if !ProcessExist("DOA5A.exe") {
    CustomTrayTip("Cannot Record, DOA is not running.", 1)
    return
}

; Output paths
FormatTime, ts,, yyyy-MM-dd_HH-mm-ss
FileCreateDir, %A_ScriptDir%\doa_captures
outFile  := A_ScriptDir "\doa_captures\doa_video_" ts ".mp4"
;audioDev := "CABLE Output (VB-Audio Virtual Cable)"
audioDev := "Voicemeeter Out B1 (VB-Audio Voicemeeter VAIO)"

if (fps = "") {
    CustomTrayTip("Missing Framerate, defaulting to 60.")
    fps := 60
}

monLeft := 0
monTop := 0
monWidth := 1920
monHeight := 1080

RotateFfmpegLog(5, 1024*1024)
logfile := A_ScriptDir . "\tools\doa_ffmpeg.log"

ffArgs := " -f gdigrab -framerate " fps
         . " -offset_x " monLeft
         . " -offset_y " monTop
         . " -video_size " monWidth "x" monHeight
         . " -i desktop"
         . " -f dshow -i audio=""" audioDev """"
         . " -c:v libx264 -preset ultrafast -crf 18"
         . " -c:a aac -b:a 192k"
         . " -pix_fmt yuv420p"
         . " -async 1 -bufsize 512k"
         . " -movflags +faststart"
         . " """ . outFile . """"

Run, % ffmpegExe . ffArgs, , , ffmpegPID

; Wait for FFmpeg console and keep on top
Loop {
    if WinExist("ahk_pid " ffmpegPID) {
        WinSet, AlwaysOnTop, On, ahk_pid %ffmpegPID%
        WinActivate, ahk_pid %ffmpegPID%
        break
    }
    Sleep, 100
}

recording := true
GuiControl, +cFFCC66, VideoCapture
CustomTrayTip("Recording started.", 1)
return


; ─── Hotkey to toggle audio capture ─────────────────────
F3::
    Gosub, AudioCapture
return


; ─── Toggle Audio Capture ───────────────────────────────
AudioCapture:
nircmd      := A_ScriptDir . "\tools\nircmd.exe"
ffmpegExe   := A_ScriptDir . "\tools\ffmpeg.exe"

; Ensure NirCmd exists
if !FileExist(nircmd) {
    MsgBox, 16, Error, nircmd.exe not found at:`n%nircmd%
    return
}

; Ensure ffmpeg exists
if !FileExist(ffmpegExe) {
    MsgBox, 16, Error, ffmpeg.exe not found at:`n%ffmpegExe%
    return
}

; ─── START recording if FFmpeg is not found ─────────────
if !ProcessExist("DOA5A.exe") {
    CustomTrayTip("Cannot Record, DOA is not running.", 3)
    return
}

; ─── Detect if FFmpeg is already recording audio ─────────
Process, Exist, ffmpeg.exe
ffmpegPIDRunning := ErrorLevel

; ─── STOP recording if found ────────────────────────────
if (ffmpegPIDRunning) {
    Process, Close, %ffmpegPIDRunning%
    ControlSend,, q, ahk_pid %ffmpegPIDRunning%.
    recording := false
    GuiControl, +c808080, AudioCapture
    CustomTrayTip("Audio recording stopped.", 1)

    ; Reset audio devices
    RunWait, "%nircmd%" setdefaultsounddevice "Speakers" 1 /nosplash,, Hide
    RunWait, "%nircmd%" setdefaultsounddevice "Microphone" 1 /nosplash,, Hide
    CustomTrayTip("Audio input/output set to default", 1)
    return
}

; ─── START recording ────────────────────────────────────
MsgBox, 52, Warning, Did you SET AUDIO DEVICES?
IfMsgBox No
{
    MsgBox, 48, Info, click SET AUDIO DEVICES.
    return
}

if !ProcessExist("DOA5A.exe") {
    CustomTrayTip("Cannot Record, DOA is not running.", 1)
    return
}

; Output paths
FormatTime, ts,, yyyy-MM-dd_HH-mm-ss
FileCreateDir, %A_ScriptDir%\doa_recordings
outFile := A_ScriptDir "\doa_recordings\doa_audio_" ts ".wav"
audioDevice := "Voicemeeter Out B1 (VB-Audio Voicemeeter VAIO)"

ffArgs := "-f dshow -i audio=""" audioDevice """ -acodec pcm_s16le -ar 48000 -ac 2 """ outFile """"

Run, % ffmpegExe " " ffArgs, , , ffmpegPID

; Wait for FFmpeg console and keep on top
Loop {
    if WinExist("ahk_pid " ffmpegPID) {
        WinSet, AlwaysOnTop, On, ahk_pid %ffmpegPID%
        WinActivate, ahk_pid %ffmpegPID%
        break
    }
    Sleep, 100
}

recording := true
GuiControl, +cFFCC66, AudioCapture
CustomTrayTip("Audio recording started.", 1)
return


; ─── set audio for record. ────────────────────────────────────────────────────────────────────
SetAudioRecord:
nircmd := A_ScriptDir . "\tools\nircmd.exe"


; Ensure NirCmd exists
if !FileExist(nircmd) {
    MsgBox, 16, Error, nircmd.exe not found at:`n%nircmd%
    return
}

RunWait, "%nircmd%" setdefaultsounddevice "VoiceMeeter Input" 1 /nosplash,, Hide
Sleep, 200
RunWait, "%nircmd%" setdefaultsounddevice "Voicemeeter Out B3" 1 /nosplash,, Hide
Sleep, 200

; Refresh audio system
DllCall("winmm.dll\waveOutMessage", "UInt", -1, "UInt", 0x3CD, "UPtr", 0, "UPtr", 0)

CustomTrayTip("Recording devices set. Launch DOA and start recording.", 1)
Log("INFO", "Audio devices switched: Output = " . audioDevOut . ", Input = " . audioDevIn)
return


; ─── set audio to default. ────────────────────────────────────────────────────────────────────
SetAudioDefault:
nircmd := A_ScriptDir . "\tools\nircmd.exe"

; Ensure NirCmd exists
if !FileExist(nircmd) {
    MsgBox, 16, Error, nircmd.exe not found at:`n%nircmd%
    return
}

    RunWait, "%nircmd%" setdefaultsounddevice "Speakers" 1 /nosplash,, Hide
    Sleep, 200
    RunWait, "%nircmd%" setdefaultsounddevice "Microphone" 1 /nosplash,, Hide
    Sleep, 200

    DllCall("winmm.dll\waveOutMessage", "UInt", -1, "UInt", 0x3CD, "UPtr", 0, "UPtr", 0)

    CustomTrayTip("Audio output/input set to default.", 1)
    Log("INFO", "Audio devices reverted to default.")
return


; ─── Set process priority function. ───────────────────────────────────────────────────────────────────────────────────
SetPriority:
    Gui, Submit, NoHide
    if PriorityChoice =  ;empty or not selected
    {
        CustomTrayTip("Please select a priority before setting.")
        return
    }

    priorityCode := ""
    if (PriorityChoice = "Idle")
        priorityCode := "L"
    else if (PriorityChoice = "Below Normal")
        priorityCode := "B"
    else if (PriorityChoice = "Normal")
        priorityCode := "N"
    else if (PriorityChoice = "Above Normal")
        priorityCode := "A"
    else if (PriorityChoice = "High")
        priorityCode := "H"
    else if (PriorityChoice = "Realtime")
        priorityCode := "R"

    Process, Exist, DOA5A.exe
    if (ErrorLevel) {
        Process, Priority, %ErrorLevel%, %priorityCode%
        CustomTrayTip("Set to: " PriorityChoice, 1)
        Log("INFO", "Set DOA priority to " . PriorityChoice)
        IniWrite, %PriorityChoice%, %iniFile%, PRIORITY, Priority
    } else {
        CustomTrayTip("exe is not running.", 1)
        Log("WARN", "Attempted to set priority, but DOA5A.exe is not running.")
    }
return


; ─── Update process priority function. ────────────────────────────────────────────────────────────────────────────────
UpdatePriority:
    Process, Exist, DOA5A.exe
    if (!ErrorLevel) {
        GuiControl,, CurrentPriority, DOA is not running.
        GuiControl, Disable, PriorityChoice
        GuiControl, Disable, Set Priority
        UpdateCPUMem()
        return
    }

    pid := ErrorLevel
    current := GetPriority(pid)

    GuiControl,, CurrentPriority, Priority: %current%

    Global lastPriority
    if (current != lastPriority) {
        GuiControl,, PriorityChoice, %current%
        lastPriority := current
    }

    GuiControl, Enable, PriorityChoice
    GuiControl, Enable, Set Priority
    UpdateCPUMem()
return


; ─── Get currrent process priority function. ──────────────────────────────────────────────────────────────────────────
GetPriority(pid) {
    try {
        wmi := ComObjGet("winmgmts:")
        query := "Select Priority from Win32_Process where ProcessId=" pid
        for proc in wmi.ExecQuery(query)
            return MapPriority(proc.Priority)
        return "Unknown"
    } catch e {
        CustomTrayTip("Failed to get priority.", 3)
        return "Error"
    }
}

MapPriority(val) {
    if (val = 4)
        return "Idle"
    if (val = 6)
        return "Below Normal"
    if (val = 8)
        return "Normal"
    if (val = 10)
        return "Above Normal"
    if (val = 13)
        return "High"
    if (val = 24)
        return "Realtime"
    if (val = 32)
        return "Normal"
    if (val = 64)
        return "Idle"
    if (val = 128)
        return "High"
    if (val = 256)
        return "Realtime"
    if (val = 16384)
        return "Below Normal"
    if (val = 32768)
        return "Above Normal"
    return "Unknown (" val ")"
}


; ─── rotate logs function. ────────────────────────────────────────────────────────────────────
RotateFfmpegLog(maxLogs = "", maxSize = "") {
    if (maxLogs = "")
        maxLogs := 5
    if (maxSize = "")
        maxSize := 1024 * 1024  ; 1 MB

    logDir := A_ScriptDir
    logFile := logDir . "\doa_ffmpeg.log"

    ; Step 1: Rotate if file is too big
    if FileExist(logFile) {
        FileGetSize, logSize, %logFile%
        if (logSize > maxSize) {
            FormatTime, timestamp,, yyyyMMdd_HHmmss
            FileMove, %logFile%, %logDir%\doa_ffmpeg_%timestamp%.log
        }
    }

    ; Step 2: Delete old logs if more than maxLogs
    logPattern := logDir . "\doa_ffmpeg_*.log"
    logs := []

    Loop, Files, %logPattern%, F
        logs.push(A_LoopFileFullPath)

    if (logs.MaxIndex() > maxLogs) {
        SortLogsByDate(logs)
        Loop, % logs.MaxIndex() - maxLogs
            FileDelete, % logs[A_Index]
    }
}


SortLogsByDate(ByRef arr) {
    Loop, % arr.MaxIndex()
        Loop, % arr.MaxIndex() - A_Index
    if (FileExist(arr[A_Index]) && FileExist(arr[A_Index + 1])) {
        FileGetTime, time1, % arr[A_Index], M
        FileGetTime, time2, % arr[A_Index + 1], M
        if (time1 > time2) {
            temp := arr[A_Index]
            arr[A_Index] := arr[A_Index + 1]
            arr[A_Index + 1] := temp
        }
    }
}


GuiClose:
    ExitApp
return
