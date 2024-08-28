@echo off
setlocal enabledelayedexpansion

rem Get all profiles
for /f "tokens=*" %%i in ('netsh wlan show profiles ^| findstr "All User Profile"') do (
    set "profile=%%i"
    rem Extract the profile name
    for /f "tokens=2 delims=:" %%j in ("!profile!") do (
        set "name=%%j"
        rem Trim leading spaces
        set "name=!name:~1!"
        echo Profile: !name!
        rem Show the profile with key
        netsh wlan show profile name="!name!" key=clear | findstr "Key Content"
        echo.
    )
)

pause
endlocal
