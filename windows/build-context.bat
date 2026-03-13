@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ===================== CONFIG =====================
REM Extension to gather (include the dot). Examples: .kt  .java  .js
set "EXT=.kt"
REM ==================================================

REM Switch to UTF-8 (optional but nice for code)
chcp 65001 >nul

REM Get current folder name (root)
for %%I in (.) do set "ROOT=%%~nxI"

REM Output file path
set "OUT=%ROOT%-context.txt"

REM Clear old output if it exists
if exist "%OUT%" del "%OUT%"

REM Count matching files (non-recursive)
set "COUNT=0"
for %%F in (*%EXT%) do set /a COUNT+=1

if "%COUNT%"=="0" (
    echo No files with extension "%EXT%" found in "%CD%".
    goto :eof
)

echo Building "%OUT%" from %COUNT% file(s) with extension "%EXT%"...
echo.

REM Write a tiny preamble
>>"%OUT%" echo ===== Context dump for folder: %ROOT% =====
>>"%OUT%" echo Extension: %EXT%
>>"%OUT%" echo Generated on: %DATE% %TIME%
>>"%OUT%" echo.

REM Iterate alphabetically (dir /b is sorted by default)
for /f "delims=" %%F in ('dir /b /a-d "*%EXT%"') do (
    echo Adding %%F

    >>"%OUT%" echo.
    >>"%OUT%" echo ===== FILE: %%F =====
    >>"%OUT%" echo.

    REM Concatenate file contents
    type "%%F" >>"%OUT%"

    >>"%OUT%" echo.
    >>"%OUT%" echo ===== END FILE: %%F =====
    >>"%OUT%" echo.
)

echo.
echo Done. Output: "%OUT%"
endlocal
