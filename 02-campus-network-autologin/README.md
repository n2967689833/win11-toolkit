# 02 · 校园网自动认证（Dr.COM 门户自动登录 + 掉线重连）

> 南京邮电大学校园网（Dr.COM / 哆点）**开机自动认证**、掉线自动重连的守护脚本。
> 原理通用，其它使用 Dr.COM Web 门户的高校改几个参数即可复用。

## 功能

- 识别本机**所有网卡**（有线 / 无线 / 多网卡），逐条独立认证
- **先探活再登录**：已在线则跳过 —— 避免「对已登录账号重复发登录请求导致被踢下线」的坑
- 开机自启（计划任务 `NJUPT_AutoLogin`，**每分钟**自检），断线 / 睡眠唤醒后 1 分钟内自动重连
- 密码使用 **Windows DPAPI 加密**存储（只有当前 Windows 账号能解密）
- 纯 Python 标准库，零第三方依赖；带日志 / 诊断 / 一键安装卸载

## 文件

| 文件 | 作用 |
|------|------|
| `njupt_autologin.py` | 主程序：`--setup / --status / --once / --dry-run / --watch / --diag / --logout / --install / --uninstall` |
| `njupt_config.example.json` | 配置模板（复制为 `njupt_config.json` 后由 `--setup` 填写） |
| `1-设置账号密码.cmd` | 双击输入账号 / 运营商 / 密码（输入不回显） |
| `2-安装开机自启.cmd` | 安装计划任务（每分钟自检） |
| `3-立即检查并登录.cmd` | 立刻检查一次 |
| `4-查看认证状态.cmd` | 查看每条网卡是否已认证 |
| `5-测试(注销并自动重连).cmd` | 端到端验证（会断网约 5 秒） |
| `6-卸载开机自启.cmd` | 删除计划任务 |

日志：同目录 `autologin.log`

## 用法

```text
1) 双击 1-设置账号密码.cmd      → 录入账号 / 运营商 / 密码（DPAPI 加密存本地）
2) 双击 2-安装开机自启.cmd      → 注册计划任务，立即生效
3) 双击 4-查看认证状态.cmd      → 确认各网卡在线
（可选）双击 5-测试(注销并自动重连).cmd 做一次端到端验证
```

## 工作原理

1. **探活**：请求 `generate_204` 类探测地址，已联网 → 直接跳过（关键！防止把已登录的账号踢下线）
2. **取参数**：访问门户，从重定向 / 页面中取 `wlan_user_ip` 等参数
3. **登录**：`GET https://<portal>:802/eportal/portal/login?callback=dr1003&login_method=1&user_account=<账号>&user_password=<密码>&wlan_user_ip=<本机IP>`（新版 JSONP 接口）
   - 失败自动回退旧版接口 `POST http://<portal>:801/eportal/?c=ACSetting&a=Login`（`DDDDD`, `upass`）
4. **复核**：查询在线会话接口确认结果
5. **守护**：每次运行绑定源 IP（`source_address` + 自定义 handler），关闭系统代理、忽略自签证书

## 适配其它学校（Dr.COM 门户）

修改 `njupt_config.json` 中：

| 字段 | 说明 |
|------|------|
| `portal_host` | 认证服务器 IP / 域名（可从门户页重定向获取） |
| `portal_https_port` / `portal_http_port` | 新版 802 / 旧版 801（按实际） |
| `wlanacip` / `wlanacname` | 部分学校需要，从门户重定向 URL 的 query 里取 |
| `isp` | 运营商后缀：`""`（校园网）/ `cmcc` / `njxy` 等 |

## 安全说明

- **不会**把密码写进任何脚本；配置里的 `password_dpapi` 是用 Windows DPAPI 加密的密文，换机器/换账号无法解密。
- `njupt_config.json` 已加入 `.gitignore`，**不要**把它提交到仓库（模板见 `njupt_config.example.json`）。

## 已知行为

- 有线 / 无线**各自独立认证**，互不影响。
- 校园网常见「重复登录会把账号踢下线」，所以脚本默认「已在线则不动作」。
