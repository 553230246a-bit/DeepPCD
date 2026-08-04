@echo off
setlocal
if "%~1"=="" goto :usage
if "%~2"=="" goto :usage
set "FOLDX_EXE=%~1"
set "PDB_PATH=%~2"
set "RUNS=%~3"
set "OUTPUT_NAME=%~4"
if "%RUNS%"=="" set "RUNS=3"
if "%OUTPUT_NAME%"=="" set "OUTPUT_NAME=BhNIT_22_single"
powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%~dp0run_foldx.ps1" ^
  -FoldXPath "%FOLDX_EXE%" ^
  -PdbPath "%PDB_PATH%" ^
  -Runs %RUNS% ^
  -OutputName "%OUTPUT_NAME%"
exit /b %ERRORLEVEL%
:usage
echo Usage:
echo   run_foldx.cmd "D:\FoldX\foldx.exe" "data\input\BhNIT.pdb" [runs] [output_name]
exit /b 2
