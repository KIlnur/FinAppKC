@echo off
REM ============================================================
REM FinAppKC - Startup Script (Windows CMD)
REM ============================================================
REM
REM Usage:
REM   start.bat              - Core services only
REM   start.bat full         - All services (monitoring, mail, etc.)
REM   start.bat monitoring   - With monitoring (Grafana, Prometheus)
REM   start.bat mail         - With MailHog
REM   start.bat stop         - Stop all services
REM   start.bat status       - Show status
REM
REM ============================================================

echo.
echo ============================================
echo   FinAppKC - Enterprise Keycloak IDP
echo ============================================
echo.

set ARG=%1

if "%ARG%"=="full" (
    powershell -ExecutionPolicy Bypass -File "%~dp0start.ps1" -Full
) else if "%ARG%"=="monitoring" (
    powershell -ExecutionPolicy Bypass -File "%~dp0start.ps1" -WithMonitoring
) else if "%ARG%"=="mail" (
    powershell -ExecutionPolicy Bypass -File "%~dp0start.ps1" -WithMail
) else if "%ARG%"=="stop" (
    powershell -ExecutionPolicy Bypass -File "%~dp0start.ps1" -Stop
) else if "%ARG%"=="status" (
    powershell -ExecutionPolicy Bypass -File "%~dp0start.ps1" -Status
) else if "%ARG%"=="logs" (
    powershell -ExecutionPolicy Bypass -File "%~dp0start.ps1" -Logs
) else (
    powershell -ExecutionPolicy Bypass -File "%~dp0start.ps1"
)

pause
