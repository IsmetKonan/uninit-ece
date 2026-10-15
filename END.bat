@echo off
color 0A
title init_ece

echo MAKE SURE TO RUN THE PROGRAMM AS ADMINISTRATOR!
echo trying to start main as Administrator ...
timeout /t 2
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0UninstallWizard.ps1""'"

echo init_ece started as Administrator
exit /b