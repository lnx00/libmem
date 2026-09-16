@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: libmem Windows Build Script
:: Usage:
::   build.bat [Release|Debug] [x64|x86|arm64]
:: Examples:
::   build.bat
::   build.bat Release x86
::   build.bat Debug x64
:: ============================================================================

set "BUILD_TYPE=%~1"
if "%BUILD_TYPE%"=="" set "BUILD_TYPE=Release"

set "RAW_ARCH=%~2"
if "%RAW_ARCH%"=="" set "RAW_ARCH=x64"

:: Normalize architecture
if /i "%RAW_ARCH%"=="x86" (
    set "ARCH=x86"
    set "LIBMEM_ARCH=i686"
    set "RUST_TARGET=i686-pc-windows-msvc"
) else if /i "%RAW_ARCH%"=="i686" (
    set "ARCH=x86"
    set "LIBMEM_ARCH=i686"
    set "RUST_TARGET=i686-pc-windows-msvc"
) else if /i "%RAW_ARCH%"=="x64" (
    set "ARCH=x64"
    set "LIBMEM_ARCH=x86_64"
    set "RUST_TARGET=x86_64-pc-windows-msvc"
) else if /i "%RAW_ARCH%"=="x86_64" (
    set "ARCH=x64"
    set "LIBMEM_ARCH=x86_64"
    set "RUST_TARGET=x86_64-pc-windows-msvc"
) else if /i "%RAW_ARCH%"=="amd64" (
    set "ARCH=x64"
    set "LIBMEM_ARCH=x86_64"
    set "RUST_TARGET=x86_64-pc-windows-msvc"
) else if /i "%RAW_ARCH%"=="arm64" (
    set "ARCH=arm64"
    set "LIBMEM_ARCH=aarch64"
    set "RUST_TARGET=aarch64-pc-windows-msvc"
) else (
    echo [ERROR] Unsupported architecture: %RAW_ARCH%
    echo Supported: x64, x86, arm64
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "BUILD_DIR=%SCRIPT_DIR%build\%ARCH%"

echo ============================================================
echo Building libmem (Windows)
echo Configuration : %BUILD_TYPE%
echo Architecture  : %ARCH% (LIBMEM_ARCH=%LIBMEM_ARCH%)
echo Build Dir     : %BUILD_DIR%
echo ============================================================

:: Find Visual Studio using vswhere
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" set "VSWHERE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"

if not exist "%VSWHERE%" (
    echo [ERROR] Could not find vswhere.exe.
    echo Please make sure Visual Studio is installed with C++ development tools.
    exit /b 1
)

for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -property installationPath`) do (
    set "VS_PATH=%%i"
)

if "%VS_PATH%"=="" (
    echo [ERROR] No Visual Studio installation found.
    exit /b 1
)

set "VCVARSALL=%VS_PATH%\VC\Auxiliary\Build\vcvarsall.bat"
if not exist "%VCVARSALL%" (
    echo [ERROR] Could not find vcvarsall.bat at:
    echo "%VCVARSALL%"
    exit /b 1
)

echo [*] Initializing MSVC environment (%ARCH%)...
call "%VCVARSALL%" %ARCH%
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to initialize MSVC environment for %ARCH%.
    exit /b 1
)

:: Find CMake
where cmake >nul 2>&1
if %ERRORLEVEL% neq 0 (
    if defined VS_PATH (
        set "VS_CMAKE=%VS_PATH%\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
        if exist "!VS_CMAKE!" (
            set "PATH=%VS_PATH%\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;!PATH!"
        )
    )
)

where cmake >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] CMake could not be found.
    echo Please ensure CMake or the Visual Studio 'C++ CMake tools for Windows' component is installed.
    exit /b 1
)

:: Configure project
echo.
echo [*] Configuring CMake...
cmake -B "%BUILD_DIR%" -DLIBMEM_BUILD_STATIC=ON -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DLIBMEM_ARCH=%LIBMEM_ARCH%
if %ERRORLEVEL% neq 0 (
    echo [ERROR] CMake configuration failed.
    exit /b %ERRORLEVEL%
)

:: Build project
echo.
echo [*] Building libmem...
cmake --build "%BUILD_DIR%" --config %BUILD_TYPE%
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed.
    exit /b %ERRORLEVEL%
)

:: Locate output library
set "LIB_FILE=%BUILD_DIR%\libmem.lib"
if not exist "%LIB_FILE%" (
    if exist "%BUILD_DIR%\%BUILD_TYPE%\libmem.lib" (
        set "LIB_FILE=%BUILD_DIR%\%BUILD_TYPE%\libmem.lib"
    )
)

echo.
echo ============================================================
echo [SUCCESS] libmem built successfully!
if exist "%LIB_FILE%" (
    echo Library path: %LIB_FILE%
)
echo.
echo ============================================================

exit /b 0
