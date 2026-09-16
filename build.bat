@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: libmem Windows Build Script
:: Usage:
::   build.bat [Release|Debug] [x64|x86|arm64]
:: Example:
::   build.bat
::   build.bat Release x64
::   build.bat Debug x64
:: ============================================================================

set "BUILD_TYPE=%~1"
if "%BUILD_TYPE%"=="" set "BUILD_TYPE=Release"

set "ARCH=%~2"
if "%ARCH%"=="" set "ARCH=x64"

set "SCRIPT_DIR=%~dp0"
set "BUILD_DIR=%SCRIPT_DIR%build"

echo ============================================================
echo Building libmem (Windows)
echo Configuration : %BUILD_TYPE%
echo Architecture  : %ARCH%
echo Build Dir     : %BUILD_DIR%
echo ============================================================

:: 1. Check if Visual Studio environment is already initialized
where nmake >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [OK] Visual Studio build environment already active.
    goto :find_cmake
)

:: 2. Find Visual Studio using vswhere
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
    echo [ERROR] Failed to initialize MSVC environment.
    exit /b 1
)

:find_cmake
:: 3. Find CMake
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

:: 4. Configure project
echo.
echo [*] Configuring CMake...
cmake -B "%BUILD_DIR%" -DLIBMEM_BUILD_STATIC=ON -DCMAKE_BUILD_TYPE=%BUILD_TYPE%
if %ERRORLEVEL% neq 0 (
    echo [ERROR] CMake configuration failed.
    exit /b %ERRORLEVEL%
)

:: 5. Build project
echo.
echo [*] Building libmem...
cmake --build "%BUILD_DIR%" --config %BUILD_TYPE%
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed.
    exit /b %ERRORLEVEL%
)

:: 6. Locate output library
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
