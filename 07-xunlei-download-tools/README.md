# 多线程下载器（纯并发提速）

> 原理：把文件按字节区间切成多段并发下载（和 IDM / aria2 的多连接原理相同）。
> 服务端每连接限速时，多连接能把总带宽跑满 → 提速。
> **不涉及任何破解/绕过会员限制**：能不能提速取决于服务端是否限单连接速度。

## 实测效果（阿里云镜像 48.9MB 文件）
| 方式 | 用时 | 速度 |
|------|------|------|
| 单线程 | 54.9s | 912 KB/s |
| 16 线程 | 5.4s | **9.1 MB/s** |

两者 MD5 完全一致，文件无损。

## 用法

### 方式一：双击 `下载.cmd`（最简单）
按提示粘贴直链，可选填 Cookie / Referer 和线程数。

### 方式二：命令行
```bat
python dl.py "https://example.com/big.zip"
python dl.py "https://example.com/big.zip" -o "D:\Downloads\big.zip" -n 32
python dl.py "直链" -o "D:\out.bin" -n 16 -H "Cookie: a=b" -H "Referer: https://pan.xunlei.com/"
```

参数：
- `-o` 保存路径（默认取 URL 文件名）
- `-n` 并发连接数（默认 16，建议 16~32）
- `-r` 每段重试次数（默认 5）
- `-H` 附加请求头（Cookie/Referer 等，可多次）
- `-A` 自定义 User-Agent

支持**断点续传**：按 Ctrl+C 中断后再运行同一命令即可续传。

## 关于迅雷网盘（pan.xunlei.com）

网盘直链一般需要登录态，做法：
1. 浏览器登录 pan.xunlei.com，打开文件所在目录
2. F12 → Network，点一次下载，找到返回真实下载地址的接口
3. 把返回的直链 + 请求头里的 `Cookie`（有时还要 `Referer`）交给本脚本：
   ```bat
   python dl.py "https://xxx.xunlei.com/...." -n 32 -H "Cookie: 粘贴你的cookie" -H "Referer: https://pan.xunlei.com/"
   ```
> 注意：迅雷直链通常**有时效**（几分钟到几小时），过期需要重新获取。
> 第三方工具访问网盘可能违反其服务条款，请自行判断；账号 Cookie 属于敏感信息，不要外传。

## 免责
仅用于下载你**有权访问**的文件。不提供、不包含任何破解会员/绕过限速的功能。
