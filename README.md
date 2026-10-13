# 幕府将军2完全版：解锁极高画质

[中文](README.md) | [English](README.en.md)

适用于 Windows 版《幕府将军2：全面战争 完全版》的独立显卡配置。

本方法已在 AMD Radeon RX 7600M XT、Steam Build 25810990 上成功解锁“极高”。脚本支持填写自己的显卡名称，自动读取完全版 PFHs 格式的 `boot.pack`，定位并修改内置显卡规则。

## 下载

- [下载 ZIP](https://github.com/XrisApex/shogun2-ce-ultra-unlock/archive/refs/heads/main.zip)，解压后取出 `Unlock-Shogun2CE-Ultra.ps1`。
- [单独下载脚本](https://github.com/XrisApex/shogun2-ce-ultra-unlock/raw/refs/heads/main/Unlock-Shogun2CE-Ultra.ps1)。

## 原理

游戏根据显卡名称匹配 `boot.pack` 内的 `fx/cardcaps.txt`，决定显卡识别档位。本次测试中，RX 7600M XT 匹配到“中”档规则。修改后，启动日志中的 `final_quality` 从 `1` 变为 `3`，游戏内的“极高”选项成功解锁。

脚本会自动定位规则文件，为填写的显卡名称写入 `DefaultQuality=ULTRA` 规则。它通过调整注释长度保留原有资源长度，使包索引和其他资源保持不变。

## 使用方法

1. 完全退出游戏。
2. 在 Steam 库中右键游戏，选择 **管理 → 浏览本地文件**，进入 **data** 文件夹。
3. 把下载的 `Unlock-Shogun2CE-Ultra.ps1` 放进这个文件夹。
4. 按 **Win＋R**，输入下面的路径并回车：

   ```text
   %appdata%\The Creative Assembly\Shogun2CompleteEdition\Steam\logs
   ```

5. 打开 `gfx.log.txt`，找到 `device_description`，复制双引号内的完整显卡名称，例如 `AMD Radeon RX 7600M XT`。如果没有日志，先启动游戏一次，再退出游戏查找。
6. 回到 **data** 文件夹，在地址栏输入 `powershell` 并回车。
7. 将下面命令中的 `【你的显卡名】` 替换成刚才复制的名称，保留两边的单引号，再运行：

   ```powershell
   & ([scriptblock]::Create((Get-Content '.\Unlock-Shogun2CE-Ultra.ps1' -Raw))) -BootPack '.\boot.pack' -GpuName '【你的显卡名】'
   ```

   例如：

   ```powershell
   & ([scriptblock]::Create((Get-Content '.\Unlock-Shogun2CE-Ultra.ps1' -Raw))) -BootPack '.\boot.pack' -GpuName 'AMD Radeon RX 7600M XT'
   ```

8. 看到 `Ultra profile written for:` 后，重新启动游戏，进入 **选项 → 画面**，选择 **极高** 并应用。

这里填写的是命令参数，脚本正文不用修改，也不用修改 Windows 里的显卡名称。

## 恢复原文件

脚本会在 `data` 文件夹中创建：

- `boot.pack.before-ultra.bak`：原文件备份。
- `boot.pack.ultra-record.json`：显卡名称及修改前后的文件校验记录。

请保留这两个文件。需要恢复时，退出游戏，在同一个文件夹打开 PowerShell，运行：

```powershell
& ([scriptblock]::Create((Get-Content '.\Unlock-Shogun2CE-Ultra.ps1' -Raw))) -BootPack '.\boot.pack' -Restore
```

看到 `Original boot.pack restored.` 表示恢复完成。

## 提示说明

- `Already patched.`：已为同一显卡完成修改，无需重复运行。
- `This GPU already matches an Ultra profile.`：当前规则已将该显卡归入极高档。
- `Close the game before continuing.`：先完全退出游戏再运行。
- `Unsupported pack format...`：文件格式不符合本脚本支持的完全版 PFHs 格式，脚本停止修改。
- `File changed since repair...`：游戏文件在修改后发生变化，脚本停止修改。

游戏更新或验证文件完整性后，重新检查修改是否保留。解锁画质选项不会提升显卡性能。本仓库提供脚本和使用说明，不包含游戏资源包、存档或本机日志。

## 验证记录

- 游戏内验证：RX 7600M XT 成功解锁极高画质。
- Windows PowerShell 下验证了脚本写入和恢复流程。
- 恢复后的原文件 SHA-256 与修改前一致。
- 检查了已有显卡条目和新增显卡条目的资源写入流程。
