# 我的 Rime 配置（小狼毫 + 万象拼音）

多设备共用的一份配置：万象拼音 + 个人定制（胭脂主题、9 候选、闲鱼快捷短语、FF14 词库、emoji 候选）。

## 新设备安装

1. 安装 [小狼毫 0.17.4](https://github.com/rime/weasel/releases/tag/0.17.4)，安装时用户目录保持默认（`%APPDATA%\Rime`）。
2. 如果 `%APPDATA%\Rime` 里已有文件（安装时生成的默认配置），先把它改名备份，再克隆本仓库：

   ```powershell
   Rename-Item "$env:APPDATA\Rime" Rime.old
   git clone https://github.com/afan0431/rime-config.git "$env:APPDATA\Rime"
   ```

3. 用**管理员** PowerShell 运行一键脚本（下载 400MB 语法模型、替换 librime 1.17.0、重新部署、启动服务）：

   ```powershell
   cd "$env:APPDATA\Rime"
   powershell -ExecutionPolicy Bypass -File .\setup-new-device.ps1
   ```

## 日常同步

- 在某台设备上改了配置：`git add -A; git commit -m "说明改了什么"; git push`
- 其他设备拉取：`git pull`，然后右键小狼毫图标 →「重新部署」

## 仓库里没有的东西

| 内容 | 原因 | 怎么获得 |
|---|---|---|
| `wanxiang-lts-zh-hans.gram` 语法模型（400MB） | 超过 GitHub 单文件 100MB 上限 | `setup-new-device.ps1` 自动从 [RIME-LMDG LTS](https://github.com/amzxyz/RIME-LMDG/releases/tag/LTS) 下载并校验 |
| `build/` | 每台设备部署时自动生成 | 重新部署 |
| `*.userdb/` 用户词频 | LevelDB 数据库，不适合放进 git | 每台设备各自积累；想同步可用小狼毫的「用户资料同步」 |
| `installation.yaml`、`user.yaml` | 设备专属 | 小狼毫自动生成 |

## 为什么要把 rime.dll 换成 librime 1.17.0

小狼毫 0.17.4 自带的 librime 1.13.1 所用的 librime-lua，每调用一次 Lua translator 就做一次全量垃圾回收
（上游提交 `7f3eca2` 引入，`ec52e48`「Amortize GC latency」修复）。万象挂了 10 个 Lua translator，
实测每次按键引擎耗时 5.4ms → 换成 librime 1.17.0 后 2.1ms，候选结果完全一致。
新旧 librime 的词典索引格式不同，所以替换后必须删掉 `build/` 完整重新部署（脚本会自动做）。

另外：不要安装把苹果 emoji 伪装成「Segoe UI Emoji」的 244MB 位图字体（AppleColorEmoji-Windows.ttf），
实测它会让小狼毫候选框每次按键多耗约 10 倍 CPU，打字明显卡顿。

## 致谢与许可

- 输入方案、词库、Lua 脚本来自 [万象拼音 rime_wanxiang](https://github.com/amzxyz/rime_wanxiang)（作者 amzxyz），
  以 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) 许可发布；本仓库在其基础上加入了个人定制。
- 输入法框架：[Rime / 小狼毫](https://github.com/rime/weasel)、[librime](https://github.com/rime/librime)。
