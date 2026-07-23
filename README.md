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

当前配置只保留 Google CSE 和 Bing，并关闭 HTTP/2，以避免 Clash 与旧版异步
连接池组合中出现的 `anyio.EndOfStream` 问题。

Google 在 2026 年 7 月停止向旧的无 JavaScript HTML/GSA 请求返回搜索结果，
因此 SearXNG 上游已将旧 `google` 引擎标记为 `inactive`。本便携版改用当前
SearXNG 新增的 `google_cse` 实现，通过 Google Custom Search 的公开端点获取
结果，不再强行启用已失效的旧抓取器；界面上的引擎名称仍显示为简洁的
`google`。该公开端点仍可能受 Google 限流或策略变化影响；Bing 结果会继续
明确标记为 Bing，不会伪装成 Google 结果。

## 主题颜色

页面右上角提供“自动、浅色、深色”三种主题。自动模式跟随浏览器所在系统
的外观；手动选择会保存在当前浏览器中，刷新页面后仍然生效。配色参考
`D:\AI\Term\index.html`，采用雾灰/炭黑底色、暖琥珀强调色和冷蓝链接。

## 端口和反向代理

SearXNG 默认只监听本机 `127.0.0.1:3001`。公网访问应由 IIS、Nginx 或其他
反向代理转发到这个地址，不要直接把 Flask 开发服务器暴露到公网。

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
3. 安装当前依赖；
4. 应用最小 Windows 兼容补丁；
5. 生成可直接复制到服务器的便携目录。

指定其他上游提交：

```powershell
.\tools\build-portable.ps1 -UpstreamRef "<commit-or-tag>"
```

建议使用固定提交，而不是直接使用不断变化的 `master`，这样构建结果可以复现。
