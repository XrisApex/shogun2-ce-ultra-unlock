# Shogun 2 Complete Edition: Unlock Ultra Graphics

[中文](README.md) | [English](README.en.md)

For the Windows Complete Edition with a dedicated GPU.

This method successfully unlocked Ultra graphics on an AMD Radeon RX 7600M XT with Steam Build 25810990. Enter your own GPU name when running the script. It reads the Complete Edition's PFHs `boot.pack` format and locates the built-in GPU profile table automatically.

## Download

- [Download ZIP](https://github.com/XrisApex/shogun2-ce-ultra-unlock/archive/refs/heads/main.zip), extract it, and locate `Unlock-Shogun2CE-Ultra.ps1`.
- [Download the script](https://github.com/XrisApex/shogun2-ce-ultra-unlock/raw/refs/heads/main/Unlock-Shogun2CE-Ultra.ps1).

## How it works

The game matches your GPU name against `fx/cardcaps.txt` inside `boot.pack` to determine its graphics profile. In our test, the RX 7600M XT matched a Medium profile. After changing the profile, `final_quality` in the startup log changed from `1` to `3`, and Ultra became available in the game.

The script locates this resource and writes a `DefaultQuality=ULTRA` rule for the GPU name you provide. It adjusts comment lengths to preserve the original resource size, leaving the pack index and other resources unchanged.

## Instructions

1. Close the game completely.
2. In Steam, right-click the game and select **Manage → Browse local files**. Open the **data** folder.
3. Place the downloaded `Unlock-Shogun2CE-Ultra.ps1` in this folder.
4. Press **Win＋R**, enter this path, and press Enter:

   ```text
   %appdata%\The Creative Assembly\Shogun2CompleteEdition\Steam\logs
   ```

5. Open `gfx.log.txt` and find `device_description`. Copy the complete GPU name inside the quotation marks, for example `AMD Radeon RX 7600M XT`. If the log is missing, launch the game once and close it.
6. Return to the **data** folder, type `powershell` in the folder's address bar, and press Enter.
7. Replace `YOUR GPU NAME` below with the name you copied, keeping the single quotation marks, then run:

   ```powershell
   & ([scriptblock]::Create((Get-Content '.\Unlock-Shogun2CE-Ultra.ps1' -Raw))) -BootPack '.\boot.pack' -GpuName 'YOUR GPU NAME'
   ```

   Example:

   ```powershell
   & ([scriptblock]::Create((Get-Content '.\Unlock-Shogun2CE-Ultra.ps1' -Raw))) -BootPack '.\boot.pack' -GpuName 'AMD Radeon RX 7600M XT'
   ```

8. After `Ultra profile written for:` appears, restart the game, open **Options → Graphics**, select **Ultra**, and apply.

Only edit the GPU name in the command. You do not need to change the script or rename your GPU in Windows.

## Restore the original file

The script creates these files in the `data` folder:

- `boot.pack.before-ultra.bak`: the original-file backup.
- `boot.pack.ultra-record.json`: the GPU name and file checksums before and after modification.

Keep both files. To restore the original, close the game, open PowerShell in the same folder, and run:

```powershell
& ([scriptblock]::Create((Get-Content '.\Unlock-Shogun2CE-Ultra.ps1' -Raw))) -BootPack '.\boot.pack' -Restore
```

`Original boot.pack restored.` confirms that restoration is complete.

## Messages

- `Already patched.`: the same GPU has already been patched.
- `This GPU already matches an Ultra profile.`: the current rule already assigns Ultra to this GPU.
- `Close the game before continuing.`: close the game completely before running the script.
- `Unsupported pack format...`: the file does not use the supported Complete Edition PFHs format; the script stops without modifying it.
- `File changed since repair...`: the game file changed after the repair; the script stops without modifying it.

After a game update or Steam file verification, check whether the modification remains. Unlocking graphics options does not increase GPU performance. This repository contains the script and instructions, with no game resource packs, saves, or local logs.

## Verification

- In-game test: Ultra successfully unlocked on RX 7600M XT.
- File modification and restoration tested under Windows PowerShell.
- The restored file's SHA-256 matched the original.
- Resource-writing paths checked for both existing GPU entries and newly added entries.
