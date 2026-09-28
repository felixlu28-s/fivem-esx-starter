@echo off
setlocal
cd /d "%~dp0"
set "TXHOST_DATA_PATH=%~dp0server-data\txData"
"server\FXServer.exe"
