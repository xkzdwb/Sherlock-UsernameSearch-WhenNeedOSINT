# 一条命令装好：拉上游 tag → 建 venv → 自举 pip → 装依赖 → editable 装本体
#
#   cd <clone 下来的目录>
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
#
# 可选参数：
#   -Python  <解释器路径>   默认 py -3，退回 python
#   -Tag     <上游 tag>     默认 v0.16.2
#   -SkipFetch              已有 upstream/ 时不重新下载

param(
  [string]$Python = '',
  [string]$Tag = 'v0.16.2',
  [switch]$SkipFetch
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$upstream = Join-Path $PSScriptRoot 'upstream'
$slug = $Tag.TrimStart('v')
$src = Join-Path $upstream "sherlock-$slug"
$venv = Join-Path $PSScriptRoot '.venv'
if ($IsWindows -or $env:OS -eq 'Windows_NT') {
  $vp = Join-Path $venv 'Scripts\python.exe'
} else {
  $vp = Join-Path $venv 'bin/python'
}

# ---------- 找解释器 ----------
if (-not $Python) {
  foreach ($candidate in @('py -3', 'python3', 'python')) {
    $parts = $candidate -split ' '
    try {
      & $parts[0] @($parts[1..($parts.Length - 1)] | Where-Object { $_ }) -c 'import sys; assert sys.version_info >= (3, 9)' 2>$null
      if ($LASTEXITCODE -eq 0) { $Python = $candidate; break }
    } catch { }
  }
}
if (-not $Python) { throw '找不到 Python 3.9+。用 -Python 指定解释器路径。' }
$pyParts = $Python -split ' '
$pyExe = (Get-Command $pyParts[0] -ErrorAction SilentlyContinue).Source
$pyArgs = @($pyParts[1..($pyParts.Length - 1)] | Where-Object { $_ })
Write-Host "== [1/6] 解释器：$Python" -ForegroundColor Cyan

# ---------- 拉上游源码 ----------
if (-not $SkipFetch -or -not (Test-Path $src)) {
  Write-Host "== [2/6] 下载上游 $Tag" -ForegroundColor Cyan
  New-Item -ItemType Directory -Force -Path $upstream | Out-Null
  & $pyExe @pyArgs (Join-Path $PSScriptRoot 'tools\fetch-upstream.py') $upstream $Tag
  if ($LASTEXITCODE -ne 0) { throw '下载上游源码失败（检查网络或换镜像）' }
} else {
  Write-Host "== [2/6] 复用已有 upstream/" -ForegroundColor Cyan
}
if (-not (Test-Path $src)) { throw "找不到上游源码目录：$src" }

# ---------- 建 venv ----------
Write-Host '== [3/6] 建 venv' -ForegroundColor Cyan
if (-not (Test-Path $vp)) {
  # 部分精简 Python 缺 ensurepip 数据，先试常规建法，失败再退回 --without-pip
  & $pyExe @pyArgs -m venv $venv
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $vp)) {
    Write-Host '      常规 venv 失败，改用 --without-pip' -ForegroundColor Yellow
    & $pyExe @pyArgs -m venv --without-pip $venv
  }
}
if (-not (Test-Path $vp)) { throw 'venv 创建失败' }

# ---------- 自举 pip ----------
Write-Host '== [4/6] 自举 pip' -ForegroundColor Cyan
& $vp -c 'import pip' 2>$null
if ($LASTEXITCODE -ne 0) {
  $pipWhl = Get-ChildItem $PSScriptRoot -Filter 'pip-*.whl' -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $pipWhl) {
    # wheel 文件名必须保留 pip-x.y.z-py3-none-any.whl 的标准格式，
    # 否则 pip 会报 Invalid wheel filename (wrong number of parts)
    & $pyExe @pyArgs (Join-Path $PSScriptRoot 'tools\fetch-pip-wheel.py') $PSScriptRoot
    if ($LASTEXITCODE -ne 0) { throw '下载 pip wheel 失败' }
    $pipWhl = Get-ChildItem $PSScriptRoot -Filter 'pip-*.whl' | Select-Object -First 1
  }
  $env:PYTHONPATH = $pipWhl.FullName
  & $vp -m pip install --no-index --no-deps $pipWhl.FullName
  Remove-Item Env:\PYTHONPATH
  Remove-Item $pipWhl.FullName -Force
}

# ---------- 装依赖 ----------
Write-Host '== [5/6] 装依赖（requirements.txt）' -ForegroundColor Cyan
& $vp -m pip install --no-cache-dir --progress-bar off --timeout 60 --retries 2 -r (Join-Path $PSScriptRoot 'requirements.txt')
if ($LASTEXITCODE -ne 0) { throw '依赖安装失败' }

# ---------- 装本体 ----------
Write-Host '== [6/6] 装 sherlock 本体（editable）' -ForegroundColor Cyan
Push-Location $src
try {
  # 上游构建后端是 poetry-core，需要 build isolation 才能拉到
  & $vp -m pip install --no-cache-dir --no-deps --progress-bar off -e .
  if ($LASTEXITCODE -ne 0) { throw 'sherlock 本体安装失败' }
} finally {
  Pop-Location
}

& $vp -m sherlock_project --version
Write-Host "`n完成。查询：`n  .\run.cmd <用户名>" -ForegroundColor Green
