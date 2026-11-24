@echo off
rem Starts Komikku with a console window so that errors are visible (debugging).
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "PYTHONHOME=%ROOT%"
set "PATH=%ROOT%\bin;%PATH%"
"%ROOT%\bin\python.exe" "%ROOT%\komikku-launcher.pyw" %*
pause
