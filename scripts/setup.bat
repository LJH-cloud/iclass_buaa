@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: Use UTF-8 so Chinese messages display correctly in modern terminals.
chcp 65001 >nul

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%\.." >nul

echo 开始初始化环境...

where node >nul 2>nul
if errorlevel 1 (
    echo 错误: 本机未安装 Node.js，请先安装。
    popd >nul
    pause
    exit /b 1
)

where npm >nul 2>nul
if errorlevel 1 (
    echo 错误: 本机未安装 npm，请先安装 Node.js（含 npm）。
    popd >nul
    pause
    exit /b 1
)

call :ensure_deps "." "root"
if errorlevel 1 goto :failed

call :ensure_deps ".\client" "client"
if errorlevel 1 goto :failed

call :ensure_deps ".\server" "server"
if errorlevel 1 goto :failed

echo 环境已就绪。

set "confirm="
set /p "confirm=是否立即启动应用? (Y/n): "
if not defined confirm set "confirm=y"

if /i "%confirm%"=="y" goto :start_app
if /i "%confirm%"=="yes" goto :start_app

popd >nul
exit /b 0

:start_app
npm run dev
set "APP_EXIT=%ERRORLEVEL%"
popd >nul
exit /b %APP_EXIT%

:failed
echo 初始化失败，请查看上方错误信息。
popd >nul
pause
exit /b 1

:ensure_deps
set "DEPS_DIR=%~1"
set "DEPS_NAME=%~2"
set "MARKER=%DEPS_DIR%\node_modules\.deps-fingerprint"
set "CURRENT="
set "CACHED="

call :deps_fingerprint "%DEPS_DIR%"
if errorlevel 1 exit /b 1
set "CURRENT=%FINGERPRINT%"

if "%FORCE_INSTALL%"=="1" (
    echo [%DEPS_NAME%] 检测到 FORCE_INSTALL=1，执行强制安装...
) else (
    if exist "%DEPS_DIR%\node_modules\" if exist "%MARKER%" (
        set /p "CACHED="<"%MARKER%" 2>nul
        if "!CACHED!"=="!CURRENT!" (
            echo [%DEPS_NAME%] 依赖未变化，跳过安装。
            exit /b 0
        )
    )
)

echo [%DEPS_NAME%] 正在安装/更新依赖，请稍候...
pushd "%DEPS_DIR%" >nul
call npm install --no-audit --no-fund
set "INSTALL_EXIT=%ERRORLEVEL%"
popd >nul
if not "%INSTALL_EXIT%"=="0" exit /b %INSTALL_EXIT%

if not exist "%DEPS_DIR%\node_modules\" mkdir "%DEPS_DIR%\node_modules" >nul 2>nul
> "%MARKER%" <nul set /p "=%CURRENT%"
echo [%DEPS_NAME%] 依赖安装完成。
exit /b 0

:deps_fingerprint
set "FP_DIR=%~1"
set "FINGERPRINT="

if exist "%FP_DIR%\package-lock.json" (
    call :hash_file "%FP_DIR%\package-lock.json"
    if errorlevel 1 exit /b 1
    set "FINGERPRINT=!FINGERPRINT!package-lock.json:!HASH_RESULT!;"
)

if exist "%FP_DIR%\package.json" (
    call :hash_file "%FP_DIR%\package.json"
    if errorlevel 1 exit /b 1
    set "FINGERPRINT=!FINGERPRINT!package.json:!HASH_RESULT!;"
)

exit /b 0

:hash_file
set "HASH_RESULT="
set "HASH_PATH=%~1"

for /f "usebackq delims=" %%H in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $env:HASH_PATH).Hash; $hash.ToLowerInvariant()" 2^>nul`) do (
    set "HASH_RESULT=%%H"
)

if not defined HASH_RESULT (
    for /f "usebackq tokens=1" %%H in (`certutil -hashfile "%~1" SHA256 2^>nul ^| findstr /r "^[0-9A-Fa-f][0-9A-Fa-f]*$"`) do (
        set "HASH_RESULT=%%H"
        goto :hash_file_done
    )
)

:hash_file_done
if not defined HASH_RESULT (
    echo 错误: 无法计算文件哈希：%~1
    exit /b 1
)

exit /b 0
