# SearXNG for Windows

这是一个可直接运行的 Windows 便携版 SearXNG，目标系统为 Windows Server
2012 R2 及之后的 64 位 Windows。

当前重建基线：

- SearXNG：`2026.07.22+ef8f6470`
- Python：`3.11.9` 64 位嵌入版
- httpx：`0.28.1`

## 启动

1. 先启动 Clash，并确认 HTTP 代理监听 `127.0.0.1:7897`。
2. 双击 `SearXNG for Windows.bat`。
3. 打开 `http://127.0.0.1:3001/`。

启动脚本会在第一次运行时生成 `config/.secret`。不要把这个文件提交到
Git，也不要在多台服务器之间共用。

## 代理范围

代理只配置在 `config/settings.yml` 的 `outgoing` 部分：

```yaml
outgoing:
  proxies: "http://127.0.0.1:7897"
```

它只影响 SearXNG 向 Google、Bing 等搜索引擎发出的请求。启动脚本不会修改
Windows 系统代理、WinHTTP 代理或其他软件的代理设置。

当前配置保留 Google 和 Bing 的网页、新闻及图片搜索，并启用 Bing 自动补全。
图片请求通过 SearXNG 图片代理返回。HTTP/2 保持关闭，以避免 Clash 与旧版
异步连接池组合中出现的 `anyio.EndOfStream` 问题。

Google News 在数据中心或代理出口上容易触发验证码，因此新闻分类中的 Google
来源使用 Google CSE 兼容实现。Bing 最新站点已停止旧的新闻无限滚动和图片
异步入口，本项目在构建时改用仍可解析的标准新闻、图片搜索入口。

Google 在 2026 年 7 月停止向旧的无 JavaScript HTML/GSA 请求返回搜索结果，
因此 SearXNG 上游已将旧 `google` 引擎标记为 `inactive`。本便携版改用当前
SearXNG 新增的 `google_cse` 实现，通过 Google Custom Search 的公开端点获取
结果，不再强行启用已失效的旧抓取器；界面上的引擎名称仍显示为简洁的
`google`。该公开端点仍可能受 Google 限流或策略变化影响；Bing 结果会继续
明确标记为 Bing，不会伪装成 Google 结果。

最新版 SearXNG 已删除不可靠且占用较高内存的 fastText 输入语言识别。
“自动检测”不再把浏览器首选语言当作引擎限制，而是使用中立的 `all`
locale；本便携版在 Google CSE 上仍默认偏向大陆简体（`hl=zh-CN`、`gl=cn`），
并避免上游把 `zh-CN` 映射成香港地区带来的繁体结果偏好。需要繁体或其他语言
时，可在界面中手动选择，或使用 `:zh-TW`、`:en`、`:fr` 等查询前缀。

## 主题颜色

页面右上角提供“自动、浅色、深色”三种主题。自动模式跟随浏览器所在系统
的外观；手动选择会保存在当前浏览器中，刷新页面后仍然生效。配色参考
`D:\AI\Term\index.html`，采用雾灰/炭黑底色、暖琥珀强调色和冷蓝链接。

## 端口和反向代理

SearXNG 默认只监听本机 `127.0.0.1:3001`。启动脚本优先使用最新版上游采用
的 Granian WSGI 服务器；如果旧版 Windows 无法加载 Granian，则回退到 Flask
兼容服务器。公网访问仍应由 IIS、Nginx 或其他反向代理转发到这个地址。

如需改端口，编辑：

```yaml
server:
  port: 3001
  bind_address: "127.0.0.1"
```

## 重新构建便携版

在仓库根目录运行：

```powershell
.\tools\build-portable.ps1
```

默认输出到 `.build\portable`。脚本会：

1. 下载 Python 3.11.9 嵌入版；
2. 获取固定的 SearXNG 上游提交；
3. 安装当前运行依赖和 Granian 服务器依赖；
4. 应用最小 Windows 兼容补丁；
5. 生成可直接复制到服务器的便携目录。

生成发布 ZIP 时使用带根文件校验的打包脚本：

```powershell
.\tools\package-portable.ps1 `
  -SourceDirectory ".\.build\portable" `
  -DestinationZip ".\dist\SearXNGforWindows-2026.07.22.zip"
```

指定其他上游提交：

```powershell
.\tools\build-portable.ps1 -UpstreamRef "<commit-or-tag>"
```

建议使用固定提交，而不是直接使用不断变化的 `master`，这样构建结果可以复现。
