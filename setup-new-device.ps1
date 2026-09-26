# 新设备一键配置：下载语法模型 → 替换 librime 1.17.0 → 重新部署 → 启动小狼毫
# 用法（在本仓库目录里，用管理员 PowerShell 运行）：
#   powershell -ExecutionPolicy Bypass -File .\setup-new-device.ps1
#   只下载语法模型、不替换 rime.dll：加 -SkipRimeDll
param([switch]$SkipRimeDll)
$ErrorActionPreference = 'Stop'

$RimeUser = $PSScriptRoot
$GramUrl  = 'https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram'
$GramSha  = '71BC2EF5BB0D6AF519EDE62CA7E85C6CEFA9B6916A1A09390B6924E39FDD5059'
$LibUrl   = 'https://github.com/rime/librime/releases/download/1.17.0/rime-33e7814-Windows-msvc-x64.7z'
$LibSha   = '7478C7CAA4FF6B37DE86DABA1F7CE4A994A4F5BA24872A820FB2B3A9B01FED15'
$DllSha   = '86B4C7357D4C6D293CE5589B234D8859CA2AC30923A03BEDFA3926EEAF97FB0B'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

if ($RimeUser -ne (Join-Path $env:APPDATA 'Rime')) {
    Write-Warning "本仓库不在 $env:APPDATA\Rime。小狼毫默认只读那里，请把仓库克隆到该目录后再运行。"
}

# 1. 语法模型
$gram = Join-Path $RimeUser 'wanxiang-lts-zh-hans.gram'
Step '检查语法模型 wanxiang-lts-zh-hans.gram（约 400MB）'
if ((Test-Path $gram) -and (Get-FileHash $gram).Hash -eq $GramSha) {
    Write-Host '已存在且校验通过，跳过下载'
} else {
    curl.exe -L --fail -o $gram $GramUrl
    if ((Get-FileHash $gram).Hash -ne $GramSha) { throw '语法模型 SHA256 校验失败，请删除后重试' }
    Write-Host '下载并校验完成'
}

# 2. 找到小狼毫安装目录
$weasel = Get-ChildItem 'C:\Program Files\Rime', 'C:\Program Files (x86)\Rime' -Directory -Filter 'weasel-*' -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
if (-not $weasel) { throw '没找到小狼毫安装目录，请先安装小狼毫（本配置在 0.17.4 上测试）' }
$W = $weasel.FullName
Step "小狼毫目录：$W"
if ($weasel.Name -ne 'weasel-0.17.4') { Write-Warning '本配置在 weasel-0.17.4 上测试，其他版本替换 rime.dll 前请自行确认兼容性' }

# 3. 替换 rime.dll 为 librime 1.17.0（修复 librime-lua 每次调用 Lua translator 都做全量 GC 导致的卡顿）
if (-not $SkipRimeDll) {
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $admin) { throw '替换 rime.dll 需要管理员权限：请用管理员 PowerShell 运行，或加 -SkipRimeDll' }
    if ((Get-FileHash "$W\rime.dll").Hash -eq $DllSha) {
        Step 'rime.dll 已是 librime 1.17.0，跳过替换'
    } else {
        Step '下载 librime 1.17.0 并替换 rime.dll'
        $tmp = Join-Path $env:TEMP 'librime-1.17.0'
        New-Item -ItemType Directory -Force $tmp | Out-Null
        $z = Join-Path $tmp 'rime.7z'
        curl.exe -L --fail -o $z $LibUrl
        if ((Get-FileHash $z).Hash -ne $LibSha) { throw 'librime 压缩包 SHA256 校验失败' }
        & "$W\7z.exe" x $z "-o$tmp" -y | Out-Null
        $newDll = Join-Path $tmp 'dist\lib\rime.dll'
        if ((Get-FileHash $newDll).Hash -ne $DllSha) { throw 'rime.dll SHA256 校验失败' }

        & "$W\WeaselServer.exe" /q
        for ($i = 0; $i -lt 20 -and (Get-Process WeaselServer -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
        if (-not (Test-Path "$W\rime.dll.orig.bak")) { Copy-Item "$W\rime.dll" "$W\rime.dll.orig.bak" }
        Copy-Item $newDll "$W\rime.dll" -Force
        Write-Host "已替换（原文件备份为 $W\rime.dll.orig.bak）"
    }
}

# 4. 重新部署（新旧 librime 的词典索引格式不同，删掉 build 让它完整重建）
Step '重新部署（约 20 秒）'
& "$W\WeaselServer.exe" /q
for ($i = 0; $i -lt 20 -and (Get-Process WeaselServer -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
if (Test-Path "$RimeUser\build") { Remove-Item "$RimeUser\build" -Recurse -Force }
$p = Start-Process "$W\WeaselDeployer.exe" -ArgumentList '/deploy' -PassThru -Wait
if ($p.ExitCode -ne 0) { Write-Warning "部署程序退出码 $($p.ExitCode)，请查看 %TEMP%\rime.weasel 下的日志" }

# 5. 以普通权限启动服务（经 explorer 启动，避免在开启 UAC 的电脑上以管理员身份运行导致普通程序连不上）
Step '启动小狼毫服务'
Start-Process explorer.exe -ArgumentList "`"$W\WeaselServer.exe`""
Write-Host "`n完成。切换到小狼毫打几个字试试；如需还原 rime.dll，把 rime.dll.orig.bak 改回 rime.dll 后重新部署。" -ForegroundColor Green
