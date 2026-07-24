[CmdletBinding()]
param(
    [string]$UpstreamRef = "ef8f6470e0473a1548f175217aaa7b9346ce6973",
    [string]$PythonVersion = "3.11.9",
    [string]$OutputDirectory = "",
    [switch]$KeepWorkDirectory
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$RepositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $RepositoryRoot ".build\portable"
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$WorkDirectory = Join-Path $RepositoryRoot ".build\work"
$DownloadDirectory = Join-Path $RepositoryRoot ".build\downloads"
$PythonDirectory = Join-Path $OutputDirectory "python"
$SitePackages = Join-Path $PythonDirectory "Lib\site-packages"
$UpstreamBare = Join-Path $WorkDirectory "searxng.git"
$UpstreamArchive = Join-Path $WorkDirectory "searxng-source.zip"
$UpstreamSource = Join-Path $WorkDirectory "source"

function Remove-DirectoryIfPresent {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        $resolved = [IO.Path]::GetFullPath($Path)
        $allowedRoot = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot ".build"))
        if (-not $resolved.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove a directory outside .build: $resolved"
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

function Download-File {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    if (Test-Path -LiteralPath $Destination) {
        return
    }
    Write-Host "Downloading $Uri"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $Destination
}

function Expand-Zip {
    param(
        [Parameter(Mandatory = $true)][string]$Archive,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($Archive, $Destination)
}

New-Item -ItemType Directory -Force -Path $DownloadDirectory, $WorkDirectory | Out-Null
Remove-DirectoryIfPresent -Path $OutputDirectory
Remove-DirectoryIfPresent -Path $UpstreamSource
New-Item -ItemType Directory -Force -Path $OutputDirectory, $PythonDirectory, $UpstreamSource | Out-Null

$PythonZip = Join-Path $DownloadDirectory "python-$PythonVersion-embed-amd64.zip"
$GetPip = Join-Path $DownloadDirectory "get-pip.py"
Download-File -Uri "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip" -Destination $PythonZip
Download-File -Uri "https://bootstrap.pypa.io/get-pip.py" -Destination $GetPip

Write-Host "Extracting Python $PythonVersion"
Expand-Zip -Archive $PythonZip -Destination $PythonDirectory

$PythonMinor = ($PythonVersion.Split(".")[0..1] -join "")
$PthFile = Join-Path $PythonDirectory "python$PythonMinor._pth"
$PthContent = [IO.File]::ReadAllText($PthFile)
$PthContent = $PthContent.Replace("#import site", "import site")
if ($PthContent -notmatch "(?m)^Lib\\site-packages$") {
    $PthContent = $PthContent.TrimEnd() + [Environment]::NewLine + "Lib\site-packages" + [Environment]::NewLine
}
[IO.File]::WriteAllText($PthFile, $PthContent, (New-Object Text.UTF8Encoding($false)))

$PythonExe = Join-Path $PythonDirectory "python.exe"
Write-Host "Bootstrapping pip"
& $PythonExe $GetPip --disable-pip-version-check --no-warn-script-location
if ($LASTEXITCODE -ne 0) {
    throw "get-pip.py failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $UpstreamBare)) {
    git init --bare $UpstreamBare | Out-Null
}
git -C $UpstreamBare config core.protectNTFS false
Write-Host "Fetching SearXNG $UpstreamRef"
git -C $UpstreamBare fetch --depth 1 https://github.com/searxng/searxng.git $UpstreamRef
if ($LASTEXITCODE -ne 0) {
    throw "Unable to fetch SearXNG ref $UpstreamRef"
}
$ResolvedCommit = (git -C $UpstreamBare rev-parse FETCH_HEAD).Trim()

if (Test-Path -LiteralPath $UpstreamArchive) {
    Remove-Item -LiteralPath $UpstreamArchive -Force
}
git -C $UpstreamBare archive --format=zip --output=$UpstreamArchive FETCH_HEAD searx searxng_extra requirements.txt requirements-server.txt
if ($LASTEXITCODE -ne 0) {
    throw "Unable to create the SearXNG source archive"
}
Expand-Zip -Archive $UpstreamArchive -Destination $UpstreamSource

$Requirements = Join-Path $UpstreamSource "requirements.txt"
$ServerRequirements = Join-Path $UpstreamSource "requirements-server.txt"
Write-Host "Installing current SearXNG dependencies"
& $PythonExe -m pip install `
    --disable-pip-version-check `
    --no-warn-script-location `
    --no-cache-dir `
    --target $SitePackages `
    -r $Requirements `
    -r $ServerRequirements
if ($LASTEXITCODE -ne 0) {
    throw "Dependency installation failed with exit code $LASTEXITCODE"
}

Copy-Item -LiteralPath (Join-Path $UpstreamSource "searx") -Destination $SitePackages -Recurse
Copy-Item -LiteralPath (Join-Path $UpstreamSource "searxng_extra") -Destination $SitePackages -Recurse

# Install the operator theme assets separately from the generated upstream bundle.
$ThemeDirectory = Join-Path $SitePackages "searx\static\themes\simple"
New-Item -ItemType Directory -Force -Path $ThemeDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $RepositoryRoot "custom\theme.css") -Destination (Join-Path $ThemeDirectory "wowtran-theme.css")
Copy-Item -LiteralPath (Join-Path $RepositoryRoot "custom\theme.js") -Destination (Join-Path $ThemeDirectory "wowtran-theme.js")

# pwd and os.getuid do not exist on Windows. Keep upstream behavior on POSIX.
$ValkeyDb = Join-Path $SitePackages "searx\valkeydb.py"
$ValkeyText = [IO.File]::ReadAllText($ValkeyDb)
$ValkeyText = [regex]::Replace(
    $ValkeyText,
    "import os\r?\nimport pwd\r?\nimport logging",
    "import os`nimport logging`n`ntry:`n    import pwd`nexcept ImportError:  # Windows`n    pwd = None"
)
$ValkeyText = [regex]::Replace(
    $ValkeyText,
    "        _pw = pwd\.getpwuid\(os\.getuid\(\)\)\r?\n        logger\.exception\(`"\[%s \(%s\)\] can't connect valkey DB \.\.\.`", _pw\.pw_name, _pw\.pw_uid\)",
    "        if pwd is not None and hasattr(os, 'getuid'):`n            _pw = pwd.getpwuid(os.getuid())`n            logger.exception(`"[%s (%s)] can't connect valkey DB ...`", _pw.pw_name, _pw.pw_uid)`n        else:`n            logger.exception(`"can't connect valkey DB ...`")"
)
if ($ValkeyText -match "(?m)^import pwd$") {
    throw "Windows compatibility patch for searx/valkeydb.py did not apply"
}
[IO.File]::WriteAllText($ValkeyDb, $ValkeyText, (New-Object Text.UTF8Encoding($false)))

# Jinja template names always use forward slashes, including on Windows.
$WebUtils = Join-Path $SitePackages "searx\webutils.py"
$WebUtilsText = [IO.File]::ReadAllText($WebUtils)
$WebUtilsText = $WebUtilsText.Replace(
    "                file_list.append(str(f.relative_to(static_path)))",
    "                file_list.append(f.relative_to(static_path).as_posix())"
)
$WebUtilsText = $WebUtilsText.Replace(
    "                f = os.path.join(directory[templates_path_length:], filename)",
    "                f = os.path.join(directory[templates_path_length:], filename).replace(os.sep, '/')"
)
if ($WebUtilsText -match "file_list\.append\(str\(f\.relative_to\(static_path\)\)\)") {
    throw "Windows static-path patch for searx/webutils.py did not apply"
}
[IO.File]::WriteAllText($WebUtils, $WebUtilsText, (New-Object Text.UTF8Encoding($false)))

# Bing retired the HTML payload from its infinitescrollajax endpoint while the
# normal news search endpoint still returns the markup parsed by bing_news.
$BingNews = Join-Path $SitePackages "searx\engines\bing_news.py"
$BingNewsText = [IO.File]::ReadAllText($BingNews)
$BingNewsText = $BingNewsText.Replace(
    '    params["url"] = base_url + "/news/infinitescrollajax?" + urlencode(query_params)',
    '    params["url"] = base_url + "/news/search?" + urlencode(query_params)'
)
$BingNewsText = $BingNewsText.Replace(
    '    # - example: https://www.bing.com/news/infinitescrollajax?q=london&first=1',
    "    # Bing's infinitescrollajax endpoint currently returns an empty HTTP 200.`n    # The normal endpoint serves the ``newsitem`` markup parsed below."
)
$BingNewsText = [regex]::Replace(
    $BingNewsText,
    '(?m)^\s*"InfiniteScroll": 1,\r?\n',
    ''
)
$BingNewsText = $BingNewsText.Replace('paging = True', 'paging = False')
$BingNewsText = [regex]::Replace(
    $BingNewsText,
    '(?m)^\s*page = int\(params\.get\("pageno", 1\)\) - 1\r?\n',
    ''
)
$BingNewsText = [regex]::Replace(
    $BingNewsText,
    '(?m)^\s*# to simplify the page count lets use the default of 10 images per page\r?\n\s*"first": page \* 10 \+ 1,\r?\n\s*"SFX": page,\r?\n',
    ''
)
$BingNewsText = $BingNewsText.Replace(
    '    engine_traits.regions["zh-CN"] = "en-hk"',
    '    engine_traits.regions["zh-CN"] = "en-US"'
)
if (
    $BingNewsText -match 'params\["url"\].*/news/infinitescrollajax\?' -or
    $BingNewsText -notmatch '/news/search\?' -or
    $BingNewsText -match '"InfiniteScroll": 1' -or
    $BingNewsText -match '"first": page' -or
    $BingNewsText -match '(?m)^paging = True$' -or
    $BingNewsText -match 'regions\["zh-CN"\] = "en-hk"'
) {
    throw "Bing News endpoint compatibility patch did not apply"
}
[IO.File]::WriteAllText($BingNews, $BingNewsText, (New-Object Text.UTF8Encoding($false)))

$BingImages = Join-Path $SitePackages "searx\engines\bing_images.py"
$BingImagesText = [IO.File]::ReadAllText($BingImages)
$BingImagesText = [regex]::Replace(
    $BingImagesText,
    '(?m)^\s*"async": "1",\r?\n',
    ''
)
$BingImagesText = $BingImagesText.Replace(
    '    params["url"] = base_url + "/images/async?" + urlencode(query_params)',
    '    params["url"] = base_url + "/images/search?" + urlencode(query_params)'
)
if (
    $BingImagesText -match '"async": "1"' -or
    $BingImagesText -match 'params\["url"\].*/images/async\?' -or
    $BingImagesText -notmatch '/images/search\?'
) {
    throw "Bing Images endpoint compatibility patch did not apply"
}
[IO.File]::WriteAllText($BingImages, $BingImagesText, (New-Object Text.UTF8Encoding($false)))

$EngineTraits = Join-Path $SitePackages "searx\data\engine_traits.json"
$EngineTraitsText = [IO.File]::ReadAllText($EngineTraits)
$EngineTraitsText = [regex]::Replace(
    $EngineTraitsText,
    '(?s)("bing images":\s*\{.*?"regions":\s*\{.*?)"zh-CN": "zh-cn"',
    '$1"zh-CN": "en-US"',
    1
)
$EngineTraitsText = $EngineTraitsText.Replace(
    '      "zh-CN": "en-hk",',
    '      "zh-CN": "en-US",'
)
$EngineTraitsObject = $EngineTraitsText | ConvertFrom-Json
if (
    $EngineTraitsText -match '"zh-CN": "en-hk"' -or
    $EngineTraitsObject.'bing images'.regions.'zh-CN' -ne 'en-US' -or
    $EngineTraitsObject.'bing news'.regions.'zh-CN' -ne 'en-US'
) {
    throw "Bing zh-CN region compatibility patch did not apply"
}
[IO.File]::WriteAllText($EngineTraits, $EngineTraitsText, (New-Object Text.UTF8Encoding($false)))

# Relative redirects remain valid behind reverse proxies that do not forward a
# usable Host header.  Absolute redirects otherwise become "http:///".
$WebApp = Join-Path $SitePackages "searx\webapp.py"
$WebAppText = [IO.File]::ReadAllText($WebApp)
$PreferencesStart = $WebAppText.IndexOf("@app.route('/preferences', methods=['GET', 'POST'])")
$PreferencesEnd = $WebAppText.IndexOf("app.add_url_rule('/favicon_proxy'", $PreferencesStart)
if ($PreferencesStart -lt 0 -or $PreferencesEnd -lt 0) {
    throw "Unable to locate the preferences route in searx/webapp.py"
}
$PreferencesBlock = $WebAppText.Substring($PreferencesStart, $PreferencesEnd - $PreferencesStart)
$PreferencesBlock = $PreferencesBlock.Replace(
    "redirect(url_for('index', _external=True))",
    "redirect(url_for('index'))"
)
if ($PreferencesBlock -match "url_for\('index', _external=True\)") {
    throw "Reverse-proxy preferences redirect patch did not apply"
}
$WebAppText = $WebAppText.Substring(0, $PreferencesStart) + $PreferencesBlock + $WebAppText.Substring($PreferencesEnd)
[IO.File]::WriteAllText($WebApp, $WebAppText, (New-Object Text.UTF8Encoding($false)))

# Replace upstream project links with the operator's legal footer.
$BaseTemplate = Join-Path $SitePackages "searx\templates\simple\base.html"
$BaseTemplateText = [IO.File]::ReadAllText($BaseTemplate)
$ThemeBootScript = @"
  <script>
    (function () {
      try {
        var mode = localStorage.getItem("wowtranSearchTheme");
        if (["auto", "light", "dark"].indexOf(mode) === -1) mode = "auto";
        var root = document.documentElement;
        root.classList.remove("theme-auto", "theme-light", "theme-dark", "theme-black");
        root.classList.add("theme-" + mode);
        root.setAttribute("data-theme-mode", mode);
      } catch (error) {
        // Keep the server-rendered automatic theme when storage is unavailable.
      }
    })();
  </script>
"@
$BaseTemplateText = $BaseTemplateText.Replace(
    '  <meta name="viewport" content="width=device-width, initial-scale=1">',
    '  <meta name="viewport" content="width=device-width, initial-scale=1">' + [Environment]::NewLine + $ThemeBootScript.TrimEnd()
)
$BaseTemplateText = $BaseTemplateText.Replace(
    '  <script type="module" src="{{ url_for(''static'', filename=''sxng-core.min.js'') }}" client_settings="{{ client_settings }}"></script>',
    '  <script type="module" src="{{ url_for(''static'', filename=''sxng-core.min.js'') }}" client_settings="{{ client_settings }}"></script>' + [Environment]::NewLine +
    '  <script defer src="{{ url_for(''static'', filename=''themes/simple/wowtran-theme.js'') }}?v=20260724-10"></script>'
)
$BaseTemplateText = [regex]::Replace(
    $BaseTemplateText,
    '  \{% endif %\}\r?\n  \{% if get_setting\(''server\.limiter''\) or get_setting\(''server\.public_instance''\) %\}',
    '  {% endif %}' + [Environment]::NewLine +
    '  <link rel="stylesheet" href="{{ url_for(''static'', filename=''themes/simple/wowtran-theme.css'') }}?v=20260724-10" type="text/css" media="screen">' + [Environment]::NewLine +
    '  {% if get_setting(''server.limiter'') or get_setting(''server.public_instance'') %}',
    1
)
$ThemeSwitcher = @"
      <div class="sxng-theme-switcher">
        <button type="button" id="sxng-theme-trigger" class="sxng-theme-trigger" onclick="return window.wowtranThemeToggle(event)" aria-haspopup="listbox" aria-expanded="false" aria-controls="sxng-theme-menu" aria-label="主题颜色：自动" title="主题颜色：自动">
          <span class="sxng-theme-symbol" aria-hidden="true">◐</span>
          <span class="sxng-theme-label">自动</span>
        </button>
        <div id="sxng-theme-menu" class="sxng-theme-menu" role="listbox" aria-label="主题颜色" hidden>
          <button type="button" class="sxng-theme-option" onclick="return window.wowtranThemeSelect('auto', event)" role="option" data-theme-mode-option="auto" aria-label="自动：跟随系统外观" aria-selected="true">
            <span class="sxng-theme-option-icon" aria-hidden="true">◐</span>
            <span class="sxng-theme-option-copy"><strong>自动</strong><small>跟随系统外观</small></span>
          </button>
          <button type="button" class="sxng-theme-option" onclick="return window.wowtranThemeSelect('light', event)" role="option" data-theme-mode-option="light" aria-label="浅色：雾灰与暖琥珀" aria-selected="false">
            <span class="sxng-theme-option-icon" aria-hidden="true">☀</span>
            <span class="sxng-theme-option-copy"><strong>浅色</strong><small>雾灰与暖琥珀</small></span>
          </button>
          <button type="button" class="sxng-theme-option" onclick="return window.wowtranThemeSelect('dark', event)" role="option" data-theme-mode-option="dark" aria-label="深色：炭黑与暖琥珀" aria-selected="false">
            <span class="sxng-theme-option-icon" aria-hidden="true">☾</span>
            <span class="sxng-theme-option-copy"><strong>深色</strong><small>炭黑与暖琥珀</small></span>
          </button>
        </div>
      </div>
"@
$BaseTemplateText = $BaseTemplateText.Replace(
    '      {%- block linkto_preferences -%}',
    $ThemeSwitcher.TrimEnd() + [Environment]::NewLine + '      {%- block linkto_preferences -%}'
)
if (
    $BaseTemplateText -notmatch 'wowtran-theme\.css' -or
    $BaseTemplateText -notmatch 'wowtran-theme\.js' -or
    $BaseTemplateText -notmatch 'id="sxng-theme-trigger"' -or
    $BaseTemplateText -notmatch 'wowtranSearchTheme'
) {
    throw "Theme patch for searx/templates/simple/base.html did not apply"
}
$LegalFooter = @"
  <footer>
    <p>
      © 2022-2032 版权归南京领域翻译有限公司所有<br>
      <a href="https://beian.miit.gov.cn/" target="_blank" rel="noopener noreferrer">苏ICP备08111928号</a>
    </p>
  </footer>
"@
$PatchedBaseTemplate = [regex]::Replace(
    $BaseTemplateText,
    "(?s)  <footer>\s*<p>.*?</p>\s*</footer>",
    $LegalFooter,
    1
)
if ($PatchedBaseTemplate -eq $BaseTemplateText) {
    throw "Legal footer patch for searx/templates/simple/base.html did not apply"
}
[IO.File]::WriteAllText($BaseTemplate, $PatchedBaseTemplate, (New-Object Text.UTF8Encoding($false)))

$CommitDate = (git -C $UpstreamBare show -s --date=format:"%Y.%m.%d" --format="%cd" FETCH_HEAD).Trim()
$ShortCommit = (git -C $UpstreamBare rev-parse --short=8 FETCH_HEAD).Trim()
$VersionString = "$CommitDate+$ShortCommit"
$VersionFrozen = @"
# SPDX-License-Identifier: AGPL-3.0-or-later
# This file is generated by tools/build-portable.ps1.
VERSION_STRING = "$VersionString"
VERSION_TAG = "$VersionString"
DOCKER_TAG = "$CommitDate-$ShortCommit"
GIT_URL = "https://github.com/searxng/searxng"
GIT_BRANCH = "$UpstreamRef"
"@
[IO.File]::WriteAllText(
    (Join-Path $SitePackages "searx\version_frozen.py"),
    $VersionFrozen,
    (New-Object Text.UTF8Encoding($false))
)

New-Item -ItemType Directory -Force -Path (Join-Path $OutputDirectory "config") | Out-Null
Copy-Item -LiteralPath (Join-Path $RepositoryRoot "config\settings.yml") -Destination (Join-Path $OutputDirectory "config\settings.yml")
Copy-Item -LiteralPath (Join-Path $RepositoryRoot "config\limiter.toml") -Destination (Join-Path $OutputDirectory "config\limiter.toml")
Copy-Item -LiteralPath (Join-Path $RepositoryRoot "SearXNG for Windows.bat") -Destination $OutputDirectory
Copy-Item -LiteralPath (Join-Path $RepositoryRoot "README.md") -Destination $OutputDirectory
Copy-Item -LiteralPath (Join-Path $RepositoryRoot "LICENSE") -Destination $OutputDirectory
Copy-Item -LiteralPath $Requirements -Destination (Join-Path $OutputDirectory "config\requirements.txt")
Copy-Item -LiteralPath $ServerRequirements -Destination (Join-Path $OutputDirectory "config\requirements-server.txt")

$BuildInfo = @"
SearXNG commit: $ResolvedCommit
SearXNG version: $VersionString
Python version: $PythonVersion
Built at: $([DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"))
"@
[IO.File]::WriteAllText(
    (Join-Path $OutputDirectory "BUILD-INFO.txt"),
    $BuildInfo,
    (New-Object Text.UTF8Encoding($false))
)

Write-Host "Validating imports"
& $PythonExe -c "import httpx, anyio, searx, searx.valkeydb; from searx.version import VERSION_STRING; print('SearXNG', VERSION_STRING); print('httpx', httpx.__version__); print('anyio', anyio.__version__ if hasattr(anyio, '__version__') else 'installed')"
if ($LASTEXITCODE -ne 0) {
    throw "Portable runtime import validation failed"
}

if (-not $KeepWorkDirectory) {
    Remove-DirectoryIfPresent -Path $UpstreamSource
    if (Test-Path -LiteralPath $UpstreamArchive) {
        Remove-Item -LiteralPath $UpstreamArchive -Force
    }
}

Write-Host ""
Write-Host "Portable build completed:"
Write-Host "  $OutputDirectory"
