@echo off
setlocal enabledelayedexpansion

REM === Check if a Gradle path argument is passed ===
if "%~1"=="" (
    REM No argument passed, use default Gradle path
    set GRADLE_PATH=gradlew
) else (
    REM Argument passed, use specified Gradle path
    set GRADLE_PATH=%~1
)

REM === Ensure Gradle wrapper is available ===
if not exist "%GRADLE_PATH%" (
    echo [ERROR] Gradle wrapper not found at "%GRADLE_PATH%". Aborting deployment.
    exit /b 1
)

REM === Change the working directory to where this script is located ===
pushd "%~dp0"

REM === Run Gradle formatting and build ===
echo [INFO] Running Gradle spotlessApply...
call "%GRADLE_PATH%" spotlessApply
if errorlevel 1 (
    echo [ERROR] Gradle spotlessApply failed. Aborting deployment.
    popd
    exit /b 1
)

echo [INFO] Running Gradle build...
call "%GRADLE_PATH%" build
if errorlevel 1 (
    echo [ERROR] Gradle build failed. Aborting deployment.
    popd
    exit /b 1
)

REM === Load .env file ===
if not exist ".env" (
    echo [ERROR] .env file not found in the current directory.
    popd
    exit /b 1
)

for /f "tokens=1,* delims==" %%a in (.env) do (
    set "%%a=%%b"
)

if "!SERVER_PATH!"=="" (
    echo [ERROR] SERVER_PATH not defined in .env
    popd
    exit /b 1
)
if "!RESOURCE_PATH!"=="" (
    echo [ERROR] RESOURCE_PATH not defined in .env
    popd
    exit /b 1
)

set PLUGINS_PATH=!SERVER_PATH!\plugins
set LIBS_PATH=build\libs
set RES_PACK_SRC=src\main\resources\st-respack
set DATA_PACK_SRC=src\main\resources\st-datapack
set WORLD_DATAPACK_PATH=!SERVER_PATH!\world\datapacks
set RES_ZIP=st-respack.zip
set DATA_ZIP=st-datapack.zip

echo [INFO] Starting deployment...
echo [INFO] Server path: !SERVER_PATH!
echo [INFO] Resource path: !RESOURCE_PATH!

REM === Step 1: Create ZIPs before deleting old ===
echo [INFO] Creating !RES_ZIP! from !RES_PACK_SRC!...
powershell -Command "Compress-Archive -Path '!RES_PACK_SRC!\*' -DestinationPath '!RES_ZIP!'"
if not exist "!RES_ZIP!" (
    echo [ERROR] Failed to create !RES_ZIP!. Aborting.
    popd
    exit /b 1
)

echo [INFO] Creating !DATA_ZIP! from !DATA_PACK_SRC!...
powershell -Command "Compress-Archive -Path '!DATA_PACK_SRC!\*' -DestinationPath '!DATA_ZIP!'"
if not exist "!DATA_ZIP!" (
    echo [ERROR] Failed to create !DATA_ZIP!. Aborting.
    popd
    exit /b 1
)

REM === Step 2: Delete old Stweaks jars ===
echo [INFO] Deleting old Stweaks jars in !PLUGINS_PATH!...
for %%f in ("!PLUGINS_PATH!\*Stweaks*.jar") do (
    if exist "%%f" (
        echo [INFO] Deleting %%f
        del /f /q "%%f"
    )
)

REM === Step 3: Move latest JAR to plugins ===
echo [INFO] Searching for most recent jar in !LIBS_PATH!...

set latestJar=
for /f "delims=" %%f in ('dir "!LIBS_PATH!\*.jar" /b /o-d') do (
    set latestJar=%%f
    goto :foundJar
)

:foundJar

REM Now delete all other JAR files except the latest one
echo [INFO] Deleting all JAR files except the latest: !latestJar!
for /f "delims=" %%f in ('dir "!LIBS_PATH!\*.jar" /b') do (
    if "%%f" neq "!latestJar!" del /q "!LIBS_PATH!\%%f"
)

echo [INFO] Finished deleting old JAR files.

if not defined latestJar (
    echo [ERROR] No jar found in !LIBS_PATH!
    popd
    exit /b 1
)

echo [INFO] Moving !latestJar! to !PLUGINS_PATH!...
move /Y "!LIBS_PATH!\!latestJar!" "!PLUGINS_PATH!\" >nul
echo [INFO] Moved: !latestJar!

REM === Step 4: Move or replace st-respack.zip ===
if exist "!RESOURCE_PATH!\!RES_ZIP!" (
    echo [INFO] Replacing existing resource pack...
    move /Y "!RES_ZIP!" "!RESOURCE_PATH!\" >nul
    echo [INFO] Replaced resource pack at !RESOURCE_PATH!\!RES_ZIP!
) else (
    echo [INFO] Moving new resource pack...
    move "!RES_ZIP!" "!RESOURCE_PATH!\" >nul
    echo [INFO] Moved resource pack to !RESOURCE_PATH!\!RES_ZIP!
)

REM === Step 5: Move or replace st-datapack.zip ===
if exist "!WORLD_DATAPACK_PATH!\!DATA_ZIP!" (
    echo [INFO] Replacing existing datapack...
    move /Y "!DATA_ZIP!" "!WORLD_DATAPACK_PATH!\" >nul
    echo [INFO] Replaced datapack at !WORLD_DATAPACK_PATH!\!DATA_ZIP!
) else (
    echo [INFO] Moving new datapack...
    move "!DATA_ZIP!" "!WORLD_DATAPACK_PATH!\" >nul
    echo [INFO] Moved datapack to !WORLD_DATAPACK_PATH!\!DATA_ZIP!
)

echo [SUCCESS] Deployment complete.

REM === Return to the original directory ===
popd
