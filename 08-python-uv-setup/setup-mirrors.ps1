<#
    setup-mirrors.ps1 —— Python / npm / uv 国内镜像一键配置（幂等，可重复运行）
    用法：
      powershell -ExecutionPolicy Bypass -File setup-mirrors.ps1
      powershell -ExecutionPolicy Bypass -File setup-mirrors.ps1 -CheckOnly
      powershell -ExecutionPolicy Bypass -File setup-mirrors.ps1 -PipIndex https://mirrors.aliyun.com/pypi/simple
#>
param(
    [switch]$CheckOnly,
    [string]$PipIndex = "https://pypi.tuna.tsinghua.edu.cn/simple",
    [string]$PipTrustedHost = "pypi.tuna.tsinghua.edu.cn",
    [string]$NpmRegistry = "https://registry.npmmirror.com",
    [string]$UvPythonMirror = "https://ghfast.top/https://github.com/astral-sh/python-build-standalone/releases/download"
)

$ErrorActionPreference = "Continue"
function Say($m, $c = "Gray") { Write-Host $m -ForegroundColor $c }

Say "`n=== 1) 环境检测 ===" "Cyan"
foreach ($c in @(
    @{ n = "py";      a = @("-3.12","-V") },
    @{ n = "python";  a = @("-V") },
    @{ n = "pip";     a = @("-V") },
    @{ n = "uv";      a = @("--version") },
    @{ n = "node";    a = @("-v") },
    @{ n = "npm";     a = @("-v") }
)) {
    $exe = Get-Command $c.n -ErrorAction SilentlyContinue
    if ($exe) {
        $v = (& $c.n @($c.a) 2>&1 | Select-Object -First 1) -join ""
        Say ("  [OK]   {0,-6} {1}" -f $c.n, $v) "Green"
        Say ("         -> {0}" -f $exe.Source) "DarkGray"
    } else {
        Say ("  [MISS] {0}" -f $c.n) "DarkYellow"
    }
}

if ($CheckOnly) { Say "`n(仅检测模式，未做任何修改)" "Yellow"; return }

Say "`n=== 2) 配置 pip 镜像 ===" "Cyan"
$pipDir = Join-Path $env:APPDATA "pip"
New-Item -ItemType Directory -Force -Path $pipDir | Out-Null
$pipIni = Join-Path $pipDir "pip.ini"
@"
[global]
index-url = $PipIndex
trusted-host = $PipTrustedHost
timeout = 60
"@ | Out-File -FilePath $pipIni -Encoding ASCII
Say "  已写入: $pipIni" "Green"

Say "`n=== 3) 配置 npm 镜像 ===" "Cyan"
if (Get-Command npm -ErrorAction SilentlyContinue) {
    & npm config set registry $NpmRegistry 2>&1 | Out-Null
    Say ("  npm registry = " + (& npm config get registry)) "Green"
} else { Say "  跳过（未安装 npm）" "DarkYellow" }

Say "`n=== 4) 配置 uv 环境变量（用户级） ===" "Cyan"
[Environment]::SetEnvironmentVariable("UV_DEFAULT_INDEX", $PipIndex, "User")
[Environment]::SetEnvironmentVariable("UV_PYTHON_INSTALL_MIRROR", $UvPythonMirror, "User")
$env:UV_DEFAULT_INDEX = $PipIndex
$env:UV_PYTHON_INSTALL_MIRROR = $UvPythonMirror
Say "  UV_DEFAULT_INDEX         = $PipIndex" "Green"
Say "  UV_PYTHON_INSTALL_MIRROR = $UvPythonMirror" "Green"
Say "  （新开终端生效）" "DarkGray"

Say "`n=== 5) 冒烟测试 ===" "Cyan"
if (Get-Command uv -ErrorAction SilentlyContinue) {
    $tmp = Join-Path $env:TEMP ("uv_smoke_" + [guid]::NewGuid().ToString("N").Substring(0,8))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    Push-Location $tmp
    try {
        & uv venv --python 3.12 2>&1 | Out-Null
        $r = & uv pip install six 2>&1 | Select-Object -Last 1
        Say ("  uv 安装测试: " + $r) "Green"
    } catch { Say ("  测试失败: " + $_.Exception.Message) "Red" }
    Pop-Location
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
} else { Say "  跳过（未安装 uv）" "DarkYellow" }

Say "`n=== 完成 ===" "Cyan"
Say "常用命令: py -3.12 -m venv .venv | uv venv --python 3.12 | uv pip install <pkg> | uv run x.py | uv tool install <cli>" "DarkGray"
