@echo off
REM ===================================================
REM   子墨记账 — Windows 桌面快捷方式创建脚本
REM   双击运行即可在桌面创建快捷方式
REM ===================================================
setlocal

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."
set "EXE_PATH=%PROJECT_ROOT%\build\windows\x64\runner\Release\zimo_jizhang.exe"

REM 检查 exe 是否存在
if not exist "%EXE_PATH%" (
    echo [错误] 未找到 zimo_jizhang.exe
    echo 路径: %EXE_PATH%
    echo 请先执行: flutter build windows
    pause
    exit /b 1
)

REM 获取桌面路径
for /f "tokens=2,*" %%a in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v Desktop 2^>nul') do set "DESKTOP=%%b"
if not defined DESKTOP set "DESKTOP=%USERPROFILE%\Desktop"

set "SHORTCUT=%DESKTOP%\子墨记账.lnk"

echo [信息] 正在创建桌面快捷方式...
echo 目标: %EXE_PATH%
echo 位置: %SHORTCUT%

REM 使用 PowerShell 创建 .lnk 快捷方式 (带有正确图标)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$WshShell = New-Object -ComObject WScript.Shell; " ^
    + ^"$Shortcut = $WshShell.CreateShortcut('%SHORTCUT%'); " ^
    + ^"$Shortcut.TargetPath = '%EXE_PATH%'; " ^
    + ^"$Shortcut.WorkingDirectory = '%PROJECT_ROOT:\=/%/build/windows/x64/runner/Release'; " ^
    + ^"$Shortcut.WindowStyle = 1; " ^
    + ^"$Shortcut.IconLocation = '%EXE_PATH%,0'; " ^
    + ^"$Shortcut.Description = '子墨记账 - 本地优先的个人记账应用'; " ^
    + ^"$Shortcut.Save();"

if %ERRORLEVEL% EQU 0 (
    echo [成功] 桌面快捷方式已创建！
) else (
    echo [失败] 快捷方式创建失败，请检查权限
)

pause
exit /b 0
