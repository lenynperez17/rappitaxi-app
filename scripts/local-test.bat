@echo off
REM OASIS TAXI - Local Testing Script for Windows
REM Test the complete application locally using Firebase Emulators

setlocal enabledelayedexpansion

echo.
echo 🧪 OASIS TAXI - Local Testing Tool (Windows)
echo =========================================

set PROJECT_ROOT=%~dp0..
cd /d "%PROJECT_ROOT%"

:MENU
echo.
echo Choose testing option:
echo 1) Quick UI Test (Frontend only - RECOMMENDED)
echo 2) Check Prerequisites
echo 3) Install Dependencies
echo 4) Full Test with Emulators (Advanced)
echo 5) Exit
echo.
set /p choice="Enter choice (1-5): "

if "%choice%"=="1" goto :QUICK_TEST
if "%choice%"=="2" goto :CHECK_PREREQ
if "%choice%"=="3" goto :INSTALL_DEPS
if "%choice%"=="4" goto :FULL_TEST
if "%choice%"=="5" goto :EXIT
goto :MENU

:CHECK_PREREQ
echo.
echo ℹ️ Checking prerequisites...

REM Check Flutter
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Flutter not found. Install from: https://flutter.dev/docs/get-started/install
) else (
    echo ✅ Flutter found
)

REM Check Node.js
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js not found. Install from: https://nodejs.org/
) else (
    echo ✅ Node.js found
)

REM Check npm
where npm >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ npm not found. Install Node.js from: https://nodejs.org/
) else (
    echo ✅ npm found
)

pause
goto :MENU

:INSTALL_DEPS
echo.
echo ℹ️ Installing dependencies...

if exist "backend\" (
    echo Installing backend dependencies...
    cd backend
    call npm install
    if %errorlevel% neq 0 (
        echo ❌ Failed to install backend dependencies
        pause
        goto :MENU
    )
    cd ..
    echo ✅ Backend dependencies installed
)

if exist "app\" (
    echo Installing Flutter dependencies...
    cd app
    
    REM Backup original pubspec and use simplified version
    if exist "pubspec.yaml" (
        copy pubspec.yaml pubspec_original.yaml >nul
    )
    copy pubspec_simple.yaml pubspec.yaml >nul
    
    call flutter pub get
    if %errorlevel% neq 0 (
        echo ❌ Failed to install Flutter dependencies
        pause
        goto :MENU
    )
    cd ..
    echo ✅ Flutter dependencies installed
)

echo ✅ All dependencies installed
pause
goto :MENU

:QUICK_TEST
echo.
echo 🚀 Starting Quick UI Test (No Backend)...
echo This will show you the app interface without server functionality

if not exist "app\" (
    echo ❌ App directory not found
    pause
    goto :MENU
)

cd app

echo.
echo Choose platform:
echo 1) Web Browser (Chrome)
echo 2) Windows Desktop App
echo 3) Android (if emulator running)
echo.
set /p platform="Enter choice (1-3): "

echo.
echo 📝 Test Users:
echo - Passenger: passenger@test.com / 123456
echo - Driver: driver@test.com / 123456
echo - Admin: admin@oasistaxiadmin.com / admin123
echo.

if "%platform%"=="1" (
    echo Running on Chrome...
    call flutter run -d chrome
) else if "%platform%"=="2" (
    echo Running as Windows Desktop App...
    call flutter run -d windows
) else if "%platform%"=="3" (
    echo Running on Android...
    call flutter run -d android
) else (
    echo Invalid choice, running on Chrome...
    call flutter run -d chrome
)

cd ..
pause
goto :MENU

:FULL_TEST
echo.
echo 🔥 Full Test with Firebase Emulators (Advanced)
echo This requires Firebase CLI and additional setup

REM Check Firebase CLI
where firebase >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Firebase CLI not found
    echo Install with: npm install -g firebase-tools
    echo Then login with: firebase login
    pause
    goto :MENU
)

echo ℹ️ This will start Firebase emulators and run the full app
echo Make sure you have firebase login completed
echo.
set /p confirm="Continue? (y/N): "
if /i not "%confirm%"=="y" goto :MENU

REM Create local environment if not exists
if not exist ".env.local" (
    echo Creating local environment file...
    (
        echo # Local Testing Environment
        echo NODE_ENV=development
        echo FLUTTER_ENV=development
        echo FIREBASE_PROJECT_ID=oasis-taxi-local
        echo FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
        echo FIREBASE_FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
        echo FIREBASE_FUNCTIONS_EMULATOR_HOST=127.0.0.1:5001
        echo FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199
        echo MERCADOPAGO_ACCESS_TOKEN=TEST-your-test-token
        echo MERCADOPAGO_PUBLIC_KEY=TEST-your-test-key
    ) > .env.local
    echo ✅ Local environment created
)

echo Starting Firebase emulators...
start "Firebase Emulators" cmd /k "firebase emulators:start"

echo Waiting for emulators to start (30 seconds)...
timeout /t 30 /nobreak >nul

echo.
echo 🎉 Emulators should be running now!
echo Firebase UI: http://localhost:4000
echo.
echo Now starting Flutter app...

cd app
call flutter run -d chrome --dart-define=ENV=development --dart-define=USE_EMULATOR=true
cd ..

pause
goto :MENU

:EXIT
echo.
echo 👋 Goodbye!
echo.
exit /b 0

:EOF