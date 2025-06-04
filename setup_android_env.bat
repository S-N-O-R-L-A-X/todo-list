@echo off
setlocal EnableDelayedExpansion

REM 设置Android SDK路径
set "ANDROID_SDK_ROOT=G:\android\Sdk"
set "ANDROID_HOME=G:\android\Sdk"

REM 确保SDK目录存在
if not exist "!ANDROID_SDK_ROOT!" (
    echo 创建Android SDK目录...
    mkdir "!ANDROID_SDK_ROOT!"
)

echo Android SDK 环境变量已设置：
echo ANDROID_SDK_ROOT=!ANDROID_SDK_ROOT!
echo ANDROID_HOME=!ANDROID_HOME!
echo.

REM 检查 platform-tools 目录是否存在
if not exist "!ANDROID_SDK_ROOT!\platform-tools" (
    echo 错误: platform-tools 目录未找到
    echo 正在尝试自动下载和安装 platform-tools...
    echo.
    
    REM 创建临时目录（使用相对安全的路径）
    set "TEMP_DIR=!TEMP!\android_sdk_download"
    rmdir /s /q "!TEMP_DIR!" 2>nul
    mkdir "!TEMP_DIR!"
    
    REM 下载 platform-tools
    echo 下载 platform-tools...
    powershell -Command "& { $ProgressPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/platform-tools_r34.0.5-windows.zip' -OutFile '!TEMP_DIR!\platform-tools.zip' }"
    
    if !errorlevel! equ 0 (
        echo 下载完成，正在解压...
        powershell -Command "& { $ProgressPreference = 'SilentlyContinue'; Expand-Archive -Path '!TEMP_DIR!\platform-tools.zip' -DestinationPath '!ANDROID_SDK_ROOT!' -Force }"
        
        if !errorlevel! equ 0 (
            echo platform-tools 安装成功！
            set "PATH=!PATH!;!ANDROID_SDK_ROOT!\platform-tools"
        ) else (
            echo 解压 platform-tools 失败
            goto :error_exit
        )
    ) else (
        echo 下载 platform-tools 失败
        goto :error_exit
    )
    
    REM 清理临时文件
    rmdir /s /q "!TEMP_DIR!" 2>nul
)

REM 检查 adb.exe 是否存在
if not exist "!ANDROID_SDK_ROOT!\platform-tools\adb.exe" (
    echo 错误: adb.exe 未在 platform-tools 目录中找到
    echo 请尝试手动下载并解压 platform-tools
    echo 下载地址: https://developer.android.com/studio/releases/platform-tools
    echo.
    goto :check_avdmanager
)

REM 验证adb是否可用
where adb >nul 2>&1
if !errorlevel! equ 0 (
    echo ADB 已找到并添加到系统路径
    echo ADB 版本信息：
    adb version
) else (
    echo 正在将 platform-tools 添加到 PATH...
    set "PATH=!PATH!;!ANDROID_SDK_ROOT!\platform-tools"
    "!ANDROID_SDK_ROOT!\platform-tools\adb.exe" version >nul 2>&1
    if !errorlevel! equ 0 (
        echo ADB 可以通过完整路径使用：!ANDROID_SDK_ROOT!\platform-tools\adb.exe
        echo ADB 版本信息：
        "!ANDROID_SDK_ROOT!\platform-tools\adb.exe" version
    ) else (
        echo 错误: ADB 执行失败，请确保 Android SDK 正确安装
    )
)

:check_avdmanager
REM 验证 avdmanager 是否可用
where avdmanager >nul 2>&1
if !errorlevel! equ 0 (
    echo avdmanager 已找到并添加到系统路径
) else (
    echo 警告: avdmanager 未在系统路径中找到
    echo.
    echo 请按照以下步骤安装 Android Command-line Tools:
    echo 1. 打开 Android Studio
    echo 2. 转到 Tools ^> SDK Manager
    echo 3. 在 SDK Tools 标签页中
    echo 4. 勾选 "Android SDK Command-line Tools ^(latest^)
    echo 5. 点击 "Apply" 进行安装
)

goto :exit

:error_exit
echo.
echo 安装失败。请尝试手动安装 platform-tools：
echo 1. 访问 https://developer.android.com/studio/releases/platform-tools
echo 2. 下载 SDK Platform-Tools for Windows
echo 3. 解压下载的文件到 !ANDROID_SDK_ROOT!

:exit
echo.
echo 请按任意键继续...
pause >nul
