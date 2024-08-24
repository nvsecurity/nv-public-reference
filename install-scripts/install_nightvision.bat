@echo off
setlocal

:: Check if running as administrator
net session >nul 2>&1
if %errorLevel%==0 (
    echo Running as Administrator...
) else (
    echo Please run this script as Administrator.
    echo Press any key to continue . . .
    pause >nul
    exit
)

:: Detect processor architecture and run appropriate commands
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo AMD64 architecture detected
    call :amd_commands
) else if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
    echo ARM64 architecture detected
    call :arm_commands
) else (
    echo Unsupported architecture: %PROCESSOR_ARCHITECTURE%
    exit
)

goto :eof

:amd_commands
@echo off
:: Check if running as administrator
net session >nul 2>&1
if %errorLevel%==0 (
    goto :run_commands
) else (
    echo Please run this script as Administrator.
    pause
    exit
)

:run_commands
:: Create the folder and add the new location into the PATH for the first time only
mkdir "C:\Program Files\Nightvision\bin" 2>nul
if not exist "C:\Program Files\Nightvision\bin" (
    echo Failed to create the directory.
    pause
    exit
)
setx PATH "%PATH%;C:\Program Files\Nightvision\bin" /M

:: Download and install the app
curl.exe -o nightvision_latest_windows_amd64.tar.gz https://downloads.nightvision.net/binaries/latest/nightvision_latest_windows_amd64.tar.gz
tar xf nightvision_latest_windows_amd64.tar.gz -C "C:\Program Files\Nightvision\bin"
del nightvision_latest_windows_amd64.tar.gz

echo Nightvision has been installed or updated successfully.
pause
exit

goto :eof

:arm_commands
@echo off
:: Check if running as administrator
net session >nul 2>&1
if %errorLevel%==0 (
    goto :run_commands
) else (
    echo Please run this script as Administrator.
    pause
    exit
)

:run_commands
:: Create the folder and add the new location into the PATH for the first time only
mkdir "C:\Program Files\Nightvision\bin" 2>nul
if not exist "C:\Program Files\Nightvision\bin" (
    echo Failed to create the directory.
    pause
    exit
)
setx PATH "%PATH%;C:\Program Files\Nightvision\bin" /M

:: Download and install the app
curl.exe -o nightvision_latest_windows_arm64.tar.gz https://downloads.nightvision.net/binaries/latest/nightvision_latest_windows_arm64.tar.gz
tar xf nightvision_latest_windows_arm64.tar.gz -C "C:\Program Files\Nightvision\bin"
del nightvision_latest_windows_arm64.tar.gz

echo Nightvision has been installed or updated successfully.
pause
exit

goto :eof

:end
echo Script execution completed.
pause
exit

