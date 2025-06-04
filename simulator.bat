@echo off
setlocal EnableDelayedExpansion

REM 设置 ADB 路径
set "NOX_PATH=G:\android\Nox\bin"
set "SDK_PATH=G:\android\Sdk\platform-tools"

REM 优先使用 Android SDK 的 ADB
if exist "%SDK_PATH%\adb.exe" (
    set "ADB_PATH=%SDK_PATH%\adb.exe"
    set "PATH=%PATH%;%SDK_PATH%"
) else if exist "%NOX_PATH%\adb.exe" (
    set "ADB_PATH=%NOX_PATH%\adb.exe"
    set "PATH=%PATH%;%NOX_PATH%"
) else (
    echo 错误: 未找到 ADB 程序
    echo 请确保以下路径之一存在：
    echo 1. Android SDK: %SDK_PATH%\adb.exe
    echo 2. 夜神模拟器: %NOX_PATH%\adb.exe
    echo.
    echo 您可以运行 setup_android_env.bat 来安装 Android SDK 和 ADB
    pause
    exit /b 1
)

set "NOX_ADB_PATH=%NOX_PATH%\nox_adb.exe"

echo 使用的 ADB 路径: !ADB_PATH!
echo.

REM 关闭之前的 ADB 服务器
"!ADB_PATH!" kill-server
timeout /t 2 /nobreak > nul

REM 启动 ADB 服务器
"!ADB_PATH!" start-server
timeout /t 2 /nobreak > nul

REM 尝试连接模拟器
echo 正在尝试连接模拟器...
"!ADB_PATH!" connect 127.0.0.1:62001

REM 如果存在 NOX ADB，也尝试使用它连接
if exist "!NOX_ADB_PATH!" (
    echo 尝试使用 NOX ADB 连接...
    "!NOX_ADB_PATH!" connect 127.0.0.1:62001
)

REM 检查设备连接状态
echo.
echo 正在检查设备连接状态...
"!ADB_PATH!" devices

REM 检查连接结果
"!ADB_PATH!" devices | find "127.0.0.1:62001" > nul
if !errorlevel! equ 0 (
    echo.
    echo 设备连接成功！
    
    echo.
    echo 正在配置 Gradle 优化设置...
    set GRADLE_OPTS=-Dorg.gradle.daemon=true -Dorg.gradle.parallel=true -Dorg.gradle.jvmargs=-Xmx2048m
    
    echo.
    echo 正在预编译 Android 项目...
    cd android
    call gradlew assembleDebug --daemon
    cd ..
    
    echo.
    echo 正在启动 Flutter 应用...
    flutter run --no-build
) else (
    echo.
    echo 警告: 未检测到已连接的设备
    echo 请确保：
    echo 1. 夜神模拟器已经启动
    echo 2. 模拟器设置中 ADB 调试已启用
    echo 3. 模拟器端口设置为 62001
)

echo.
echo 按任意键继续...
pause > nul