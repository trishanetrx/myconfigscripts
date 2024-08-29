@echo off
setlocal enabledelayedexpansion

rem Get all profiles
for /f "tokens=*" %%i in ('netsh wlan show profiles ^| findstr /i "All User Profile"') do (
    set "profile=%%i"
    rem Extract the profile name and trim leading/trailing spaces
    for /f "tokens=2* delims=:" %%j in ("!profile!") do (
        set "name=%%j"
        set "name=!name:~1!"
        setlocal enabledelayedexpansion
        rem Show the profile with key, suppress errors
        for /f "tokens=*" %%k in ('netsh wlan show profile name^="!name!" key^=clear 2^>nul ^| findstr /i "Key Content"') do (
            echo Profile: !name!
            echo %%k
            echo.
        )
        endlocal
    )
)

pause
endlocal
