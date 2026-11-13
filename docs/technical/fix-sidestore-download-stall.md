# 修复 SideStore 下载卡在 3%

> 把这份文档整个复制给你另一个工作区的 AI/协作者，它就能照着改。

## 问题现象

SideStore（或 AltStore）里点更新后，下载**卡在 3%**，一直不动，最后失败。

## 根因（已实测确认）

不是 SideStore 服务器坏了，是 **GitHub 的下载重定向链路被限速**。

SideStore 请求的下载地址会这样跳转：

```
github.com/<owner>/<repo>/releases/download/vX.Y.Z/App.ipa
   ↓ HTTP 302
release-assets.githubusercontent.com/github-production-release-asset/...
   ↑ 这个域名在国内经常被限速或完全不通
```

SideStore 拿到 302 重定向后开始下载，但连不上 `release-assets.githubusercontent.com`，
所以进度条停在个位数不动。

**注意**：`source.json` 本身能正常下载（它是小文件，走的是另一条链路），
所以「源刷新正常、但下载 IPA 卡住」正是这个问题的典型特征。

## 解决方案

让 `source.json` 里的下载链接走**镜像代理**，绕开重定向。

### 已验证的镜像

| 镜像 | 实测结果 |
|---|---|
| `https://gh-proxy.com/` | 903649 字节，2.9 秒，**SHA256 与原件完全一致** |
| `https://ghfast.top/` | 同样成功，约 8 秒（备用） |

用法就是在原始 GitHub 地址前面拼上镜像前缀：

```
https://gh-proxy.com/https://github.com/<owner>/<repo>/releases/download/vX.Y.Z/App.ipa
```

---

## 修改步骤

### 第 1 步：改生成 source.json 的脚本

找到你仓库里生成 `source.json` 的脚本（本仓库是
`scripts/generate_store_source.py`）。找到生成下载地址的函数，
让它改为带镜像前缀。

**改动前**（典型写法）：

```python
REPOSITORY = "你的用户名/你的仓库"
BUNDLE_ID = "你的包名"


def release_url(version: str, asset: str) -> str:
    return f"https://github.com/{REPOSITORY}/releases/download/v{version}/{asset}"
```

**改动后**：

```python
import os

REPOSITORY = "你的用户名/你的仓库"
BUNDLE_ID = "你的包名"

# GitHub redirects release downloads to release-assets.githubusercontent.com,
# which is throttled or unreachable on some networks. SideStore then stalls a
# few percent into the download. Serving links through a proxy avoids that
# redirect entirely; the proxy returns identical bytes, so the app is unchanged.
#
# Set STORE_DOWNLOAD_MIRROR to "" to fall back to direct GitHub links.
MIRROR = os.environ.get("STORE_DOWNLOAD_MIRROR", "https://gh-proxy.com/")
DIRECT_HOST = "https://github.com"


def release_url(version: str, asset: str) -> str:
    direct = f"{DIRECT_HOST}/{REPOSITORY}/releases/download/v{version}/{asset}"
    return MIRROR + direct if MIRROR else direct
```

> **关键**：这个函数通常既用于 `downloadURL`，也用于 `iconURL` / `headerURL`。
> 只要改这一个函数，所有地址就都自动走镜像了。

如果脚本里是 JS/TS 写的，等价改法：

```js
const MIRROR = process.env.STORE_DOWNLOAD_MIRROR ?? "https://gh-proxy.com/";
const DIRECT_HOST = "https://github.com";

function releaseUrl(version, asset) {
  const direct = `${DIRECT_HOST}/${REPOSITORY}/releases/download/v${version}/${asset}`;
  return MIRROR ? MIRROR + direct : direct;
}
```

### 第 2 步：确认 CI 用的是这个脚本

在 `.github/workflows/*.yml` 里找到发布 tag 时生成 source.json 的步骤，
确认它调用的是你刚改的脚本，例如：

```yaml
      - name: Prepare SideStore source
        if: startsWith(github.ref, 'refs/tags/v')
        run: |
          set -euo pipefail
          VERSION="${GITHUB_REF_NAME#v}"
          SIZE=$(stat -f%z unsigned-ipa/YourApp.ipa)
          python3 scripts/generate_store_source.py "$VERSION" "$SIZE" docs/store/source.json
```

（文件名和路径按你自己仓库的实际名字改。）

### 第 3 步：修好线上已经发布的那一版（重要，不用等下次发版）

改完脚本只对**未来**的版本生效。要让用户**立刻**能下载，
需要把最近那版的 `source.json` 资产替换掉。

**方法 A：手动改并重传（不改代码也能做）**

1. 下载当前 Release 里的 `source.json`
2. 用文本编辑器，把所有 `https://github.com/` 开头的下载地址
   前面加上 `https://gh-proxy.com/`
   - 改 `iconURL`
   - 改 `headerURL`
   - 改每个 `apps[].iconURL`
   - 改每个 `apps[].versions[].downloadURL`
3. 保存后在 GitHub Release 页面**删掉旧的 source.json**，再上传新的

**方法 B：用 GitHub API 替换（自动）**

```js
// 1. 取 release 和 source.json 资产的 id
const rel = await fetch(
  "https://api.github.com/repos/<owner>/<repo>/releases/tags/vX.Y.Z",
  { headers: { Authorization: "token <你的token>" } }
).then(r => r.json());
const asset = rel.assets.find(a => a.name === "source.json");

// 2. 下载它
const text = await fetch(
  `https://api.github.com/repos/<owner>/<repo>/releases/assets/${asset.id}`,
  { headers: { Authorization: "token <你的token>", Accept: "application/octet-stream" } }
).then(r => r.text());

// 3. 所有 URL 加镜像前缀
const MIRROR = "https://gh-proxy.com/";
const j = JSON.parse(text);
const wrap = u => u.startsWith("https://github.com/") ? MIRROR + u : u;
j.iconURL = wrap(j.iconURL);
j.headerURL = wrap(j.headerURL);
for (const app of j.apps) {
  app.iconURL = wrap(app.iconURL);
  for (const v of app.versions) v.downloadURL = wrap(v.downloadURL);
}

// 4. 删旧资产
await fetch(
  `https://api.github.com/repos/<owner>/<repo>/releases/assets/${asset.id}`,
  { method: "DELETE", headers: { Authorization: "token <你的token>" } }
);

// 5. 上传新资产
await fetch(
  `https://uploads.github.com/repos/<owner>/<repo>/releases/${rel.id}/assets?name=source.json`,
  { method: "POST",
    headers: { Authorization: "token <你的token>", "Content-Type": "application/json" },
    body: JSON.stringify(j, null, 2) + "\n" }
);
```

### 第 4 步：在手机上验证

1. SideStore → Sources（源）
2. 找到你的源，**下拉刷新**
3. 如果还是旧地址，**删掉源再重新添加**（最彻底）
4. 重新点更新/安装

---

## 验证镜像是否真的可用（可选，建议做）

在电脑上跑一下，确认镜像返回的字节数和原件一致：

```powershell
$u = "https://github.com/<owner>/<repo>/releases/download/vX.Y.Z/App.ipa"
Invoke-WebRequest -Uri $u -OutFile direct.bin -UseBasicParsing
Invoke-WebRequest -Uri "https://gh-proxy.com/$u" -OutFile mirror.bin -UseBasicParsing
(Get-FileHash direct.bin -Algorithm SHA256).Hash
(Get-FileHash mirror.bin  -Algorithm SHA256).Hash
# 两行必须相同
```

## 常见误区

- ❌ **以为 SideStore 服务器坏了** —— 不是，是 GitHub 的 CDN 域名被限速
- ❌ **以为 source.json 打不开** —— 它能打开，问题在它里面的 downloadURL
- ❌ **只改代码不改线上资产** —— 用户还是下不了，必须替换已发布的 source.json
- ❌ **改完不刷新源** —— SideStore 会缓存 source.json，删源重加最保险

## 备用镜像

如果 `gh-proxy.com` 哪天也不通了，换成：

```
https://ghfast.top/
```

改一行 `MIRROR` 常量即可，其他都不用动。

---

## 给 AI 的一句话说明（可直接粘贴）

> 我的 iOS 应用用 SideStore 分发，下载卡在 3%。原因是 GitHub 的 release 下载会
> 302 重定向到 release-assets.githubusercontent.com，这个域名在国内被限速。
> 请帮我修改生成 source.json 的脚本，让所有下载/图标地址都加上
> `https://gh-proxy.com/` 前缀（保留原始 https://github.com/ 路径在后面），
> 然后指导我替换已发布 Release 里的 source.json 资产。另外请顺手确认
> iconURL、headerURL 和每个版本的 downloadURL 都改到了。
