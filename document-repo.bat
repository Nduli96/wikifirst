@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Documents the current git repository into docs\wiki, after its owner agrees.
rem Usage: document-repo.bat [spending limit in US dollars, default 5]
rem System tools use full paths: in Git Bash, the Unix find comes first on PATH and would scan the whole disk.

set "CODE=2"

set "BUDGET=%~1"
if not defined BUDGET set "BUDGET=5"
for /f "delims=0123456789." %%X in ("%BUDGET%") do goto bad_budget

if defined CLAUDE_CMD goto check_custom
"%SystemRoot%\System32\where.exe" claude >nul 2>nul
if errorlevel 1 goto no_claude
rem Unquoted on purpose: a quoted name found through PATH breaks %~dp0 inside the npm claude.cmd.
set RUN=claude
goto find_repo
:check_custom
if not exist "%CLAUDE_CMD%" goto no_claude
set RUN="%CLAUDE_CMD%"

:find_repo
set "ROOT="
for /f "usebackq delims=" %%R in (`git rev-parse --show-toplevel 2^>nul`) do set "ROOT=%%R"
if not defined ROOT goto no_repo
set "ROOT=%ROOT:/=\%"
if /i "%ROOT%\"=="%~dp0" goto own_clone

set "COUNT=0"
for /f %%N in ('git ls-files ^| "%SystemRoot%\System32\find.exe" /c /v ""') do set "COUNT=%%N"
if "%COUNT%"=="0" goto no_files

echo.
echo wikifirst: document this repository
echo.
echo   Repository:     "%ROOT%"
echo   Tracked files:  %COUNT%
echo   Spending limit: %BUDGET% US dollars
echo.
echo What will happen:
echo   - Claude Code reads source files tracked by git. Their content goes to the
echo     model provider, as in any Claude Code session.
echo   - It writes only to docs\wiki. It changes no code and commits nothing.
echo   - Files that look like secrets are blocked, but the block works by file name.
echo     Read the notes before you publish them.
echo.
echo Only continue if this is your repository, or you have permission to document it.
echo.
set "ANSWER="
set /p "ANSWER=Type YES to continue: "
if /i not "%ANSWER%"=="YES" goto declined

cd /d "%ROOT%"
set "BEFORE=%TEMP%\wikifirst_before_%RANDOM%.txt"
set "AFTER=%TEMP%\wikifirst_after_%RANDOM%.txt"
git status --porcelain -- . ":(exclude)docs/wiki" > "%BEFORE%"

echo.
echo Working. This can take a long time and prints nothing until it ends.
echo Notes appear in docs\wiki as they are written.
echo.
type "%~dp0document-repo.md" | %RUN% -p --model sonnet --permission-mode dontAsk --max-budget-usd %BUDGET% --allowedTools "Read,Glob,Grep,Agent,Edit(docs/wiki/**),Write(docs/wiki/**),Bash(git ls-files*),Bash(git rev-parse*),PowerShell(git ls-files*),PowerShell(git rev-parse*)" --disallowedTools "Read(**/.env*),Read(**/*.pem),Read(**/*.key),Read(**/*credential*),Read(**/*secret*)"
set "CODE=%errorlevel%"

git status --porcelain -- . ":(exclude)docs/wiki" > "%AFTER%"
"%SystemRoot%\System32\fc.exe" /b "%BEFORE%" "%AFTER%" >nul
if errorlevel 1 goto outside_changes
goto report

:outside_changes
echo.
echo WARNING: files outside docs\wiki changed during this run. Check them:
type "%AFTER%"

:report
del "%BEFORE%" "%AFTER%" >nul 2>nul
echo.
"%SystemRoot%\System32\where.exe" python >nul 2>nul
if errorlevel 1 goto report_done
python "%~dp0check_wiki.py"
:report_done
echo.
echo Finished. Nothing was committed. Run this again to continue if the limit stopped it.
goto finish

:bad_budget
echo Usage: document-repo.bat [spending limit in US dollars, default 5]
goto finish
:no_claude
echo Claude Code was not found. Install its command line tool, or set CLAUDE_CMD to the full path of claude.exe.
goto finish
:no_repo
echo Run this from inside the git repository you want to document.
goto finish
:own_clone
echo This is wikifirst's own folder. Run this from inside the repository you want to document.
goto finish
:no_files
echo This repository has no tracked files.
goto finish
:declined
echo Nothing was done.
set "CODE=1"

:finish
echo(%cmdcmdline%| "%SystemRoot%\System32\find.exe" /i "/c" >nul && pause
exit /b %CODE%
