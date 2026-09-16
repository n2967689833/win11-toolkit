# 08 · Python / uv 环境与国内镜像一键配置

> 国内网络环境下配置 Python 工具链的标准动作：**装 uv、配镜像、验证**。

## 功能

`setup-mirrors.ps1`：

1. 检测环境：`py` / `python` / `pip` / `uv` / `node` / `npm` 是否可用及版本
2. 配置 **pip** 清华源 → `%APPDATA%\pip\pip.ini`
3. 配置 **npm** → `registry.npmmirror.com`
4. 配置 **uv** 用户环境变量：`UV_DEFAULT_INDEX`（清华源）、`UV_PYTHON_INSTALL_MIRROR`（GitHub 代理镜像）
5. 打印结果与常用命令速查

## 用法

```powershell
powershell -ExecutionPolicy Bypass -File setup-mirrors.ps1            # 配置全部
powershell -ExecutionPolicy Bypass -File setup-mirrors.ps1 -CheckOnly # 只检测不改动
```

## 安装 uv（如未安装）

```powershell
# 官方脚本（国内可直连 releases.astral.sh）
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
# 或走镜像
$env:UV_INSTALLER_GITHUB_BASE_URL="https://ghfast.top/https://github.com"
```

## 国内镜像速查

| 包管理器 | 镜像 |
|---------|------|
| pip | `https://pypi.tuna.tsinghua.edu.cn/simple` |
| npm | `https://registry.npmmirror.com` |
| uv（包索引） | `UV_DEFAULT_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple` |
| uv（Python 解释器下载） | `UV_PYTHON_INSTALL_MIRROR=https://ghfast.top/https://github.com/astral-sh/python-build-standalone/releases/download` |

## 常用命令

```powershell
py -3.12 -m venv .venv          # 建虚拟环境
uv venv --python 3.12           # uv 建环境（秒级）
uv pip install requests         # 装包（走镜像）
uv run script.py                # 直接跑脚本
uv tool install ruff            # 装全局 CLI 工具
uv python install 3.13          # 装一个新版本 Python
```

## 注意

- 本机系统 PATH 中的 `python` 可能被某些 IDE / 宿主程序内置的解释器抢占（例如宿主自带的 `resources\python`）→ 需要确定性版本时用 **`py -3.12`**。
- uv 安装到 `%USERPROFILE%\.local\bin`，该目录需在 PATH 中（安装脚本会自动追加）。
