@echo off
rem 日常查询入口（.cmd 版，不受 PowerShell 执行策略影响）
rem
rem   run.cmd github
rem   run.cmd github --print-all
rem   run.cmd github --csv --txt
rem
rem 自动补 --local：让 sherlock 用 upstream 自带的 data.json，而不是联网拉清单。
rem 你的机器能访问 data.sherlockproject.xyz 时，直接调用 python 加不加都可以。
rem
rem 注意：本文件必须是 CRLF 换行，LF 会让 cmd 把参数切碎。

cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
  echo 找不到虚拟环境 .venv
  echo 先装环境：powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
  exit /b 1
)

if not exist "results" mkdir "results"
cd /d "%~dp0results"

"..\.venv\Scripts\python.exe" -m sherlock_project %* --local
exit /b %ERRORLEVEL%
