@echo off
REM Double-cliquez ce fichier pour generer BdeB-GameAI.sln.
REM Utilise PowerShell 7 (pwsh) si disponible, sinon Windows PowerShell.
setlocal
cd /d "%~dp0"

where pwsh >nul 2>nul
if %errorlevel%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Generate-Solution.ps1"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Generate-Solution.ps1"
)

echo.
echo ============================================================
echo Termine. Appuyez sur une touche pour fermer.
pause >nul
