param(
    [Parameter(Mandatory = $true)][string]$BootPack,
    [string]$GpuName,
    [switch]$Restore
)

$ErrorActionPreference = 'Stop'
$packPath = (Resolve-Path -LiteralPath $BootPack).ProviderPath
$backupPath = $packPath + '.before-ultra.bak'
$recordPath = $packPath + '.ultra-record.json'
function Get-BytesHash([byte[]]$Bytes) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($Bytes))).Replace('-', '') }
    finally { $hasher.Dispose() }
}
foreach ($gameProcess in @(Get-Process -Name shogun2_complete_edition -ErrorAction SilentlyContinue)) {
    if (-not $gameProcess.Path) { throw 'Close the game before continuing.' }
    $runningPack = Join-Path (Split-Path -Parent $gameProcess.Path) 'data\boot.pack'
    if ([string]::Equals($runningPack, $packPath, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Close the game before continuing.'
    }
}
$packBytes = [IO.File]::ReadAllBytes($packPath)
$currentHash = Get-BytesHash $packBytes
if ($Restore) {
    if (-not (Test-Path -LiteralPath $recordPath)) { throw 'Repair record not found.' }
    $record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
    if ($currentHash -eq $record.originalHash) { Write-Output 'Already restored.'; return }
    if ($currentHash -ne $record.patchedHash) { throw 'File changed since repair. No changes made.' }
    $resultBytes = [IO.File]::ReadAllBytes($backupPath)
    if ((Get-BytesHash $resultBytes) -ne $record.originalHash) { throw 'Backup validation failed.' }
    $expectedHash = $record.originalHash
} else {
    if ([string]::IsNullOrWhiteSpace($GpuName) -or $GpuName -notmatch '^[A-Za-z0-9 ()_.:+/\-]{3,128}$') {
        throw 'Enter the GPU name from device_description in gfx.log.txt, without quotation marks.'
    }
    $GpuName = $GpuName.Trim()
    if (Test-Path -LiteralPath $recordPath) {
        $record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
        if ($currentHash -eq $record.patchedHash) {
            if ($GpuName -eq $record.gpuName) { Write-Output 'Already patched.'; return }
            throw 'Restore the previous repair before changing GPU names.'
        }
        if ($currentHash -ne $record.originalHash) { throw 'File changed since repair. No changes made.' }
    }
    if ($packBytes.Length -lt 32 -or [Text.Encoding]::ASCII.GetString($packBytes, 0, 4) -ne 'PFHs' -or
        [BitConverter]::ToUInt32($packBytes, 4) -ne 64) {
        throw 'Unsupported pack format. Expected an uncompressed PFHs boot pack with timestamps.'
    }
    $indexStart = 32L + [BitConverter]::ToUInt32($packBytes, 12)
    $fileCount = [BitConverter]::ToUInt32($packBytes, 16)
    $indexEnd = $indexStart + [BitConverter]::ToUInt32($packBytes, 20)
    if ($indexEnd -gt $packBytes.Length -or $fileCount -gt 100000) { throw 'Invalid pack index.' }
    $position = $indexStart
    $capsEntries = @()
    for ($i = 0; $i -lt $fileCount; $i++) {
        if ($position + 20 -gt $indexEnd) { throw 'Invalid entry header.' }
        $offset = [BitConverter]::ToUInt64($packBytes, [int]$position)
        $length = [BitConverter]::ToUInt32($packBytes, [int]($position + 8))
        $pathStart = $position + 20
        $pathEnd = $pathStart
        while ($pathEnd -lt $indexEnd -and $packBytes[$pathEnd] -ne 0) { $pathEnd++ }
        if ($pathEnd -ge $indexEnd) { throw 'Invalid entry path.' }
        $entryName = [Text.Encoding]::UTF8.GetString($packBytes, [int]$pathStart, [int]($pathEnd - $pathStart))
        if ($offset -lt $indexEnd -or $offset -gt $packBytes.Length -or $length -gt $packBytes.Length - $offset) {
            throw 'Invalid entry bounds.'
        }
        if ($entryName.Replace('\', '/') -ieq 'fx/cardcaps.txt') {
            $capsEntries += [pscustomobject]@{ offset = [int]$offset; length = [int]$length }
        }
        $position = $pathEnd + 1
    }
    if ($position -ne $indexEnd -or $capsEntries.Count -ne 1) { throw 'GPU resource index validation failed.' }
    $entry = $capsEntries[0]
    $utf8 = [Text.Encoding]::UTF8
    $capsText = $utf8.GetString($packBytes, $entry.offset, $entry.length)
    if ($capsText -notmatch 'Shogun 2 Complete Edition') { throw 'Not a Complete Edition GPU rule table.' }
    $nameRows = @([regex]::Matches($capsText, '(?m)^[^\r\n]+') | Where-Object {
        $row = $_.Value.Trim()
        -not $row.StartsWith(';') -and -not $row.Contains('=') -and $row.Length -ge 3 -and
        $GpuName.IndexOf($row, [StringComparison]::OrdinalIgnoreCase) -ge 0
    } | Sort-Object { $_.Value.Trim().Length } -Descending)
    if ($nameRows.Count -gt 0) {
        $nameRow = $nameRows[0]
        $previousQualities = [regex]::Matches($capsText.Substring(0, $nameRow.Index), '(?m)^DefaultQuality=(LOW|MEDIUM|HIGH|ULTRA)\s*$')
        if ($previousQualities.Count -eq 0) { throw 'GPU profile group not found.' }
        $previousQuality = $previousQualities[$previousQualities.Count - 1].Groups[1].Value
        if ($previousQuality -eq 'ULTRA') { Write-Output 'This GPU already matches an Ultra profile.'; return }
        $replacement = "DefaultQuality=ULTRA`r`n$GpuName`r`nDefaultQuality=$previousQuality"
        $newCaps = $capsText.Remove($nameRow.Index, $nameRow.Length).Insert($nameRow.Index, $replacement)
    } else {
        $firstGroup = [regex]::Match($capsText, '(?m)^DefaultQuality=(LOW|MEDIUM|HIGH|ULTRA)\s*$')
        if (-not $firstGroup.Success) { throw 'GPU profile groups not found.' }
        $newRule = "DefaultQuality=ULTRA`r`nGPUMemoryType=DISCRETE`r`n$GpuName`r`n"
        $newCaps = $capsText.Insert($firstGroup.Index, $newRule)
    }
    $extraBytes = $utf8.GetByteCount($newCaps) - $entry.length
    $commentRows = [regex]::Matches($newCaps, '(?m)^;[^\r\n]*\r?\n')
    for ($j = $commentRows.Count - 1; $j -ge 0 -and $extraBytes -gt 0; $j--) {
        $comment = $commentRows[$j]
        if ($comment.Value -match 'Shogun 2 Complete Edition') { continue }
        $newLine = if ($comment.Value.EndsWith("`r`n")) { "`r`n" } else { "`n" }
        $removeCount = [Math]::Min($extraBytes, $comment.Length - 1 - $newLine.Length)
        if ($removeCount -le 0) { continue }
        $padding = ';' + (' ' * ($comment.Length - $removeCount - 1 - $newLine.Length)) + $newLine
        $newCaps = $newCaps.Remove($comment.Index, $comment.Length).Insert($comment.Index, $padding)
        $extraBytes -= $removeCount
    }
    $newCapsBytes = $utf8.GetBytes($newCaps)
    if ($newCapsBytes.Length -ne $entry.length) { throw 'Insufficient comment space. No changes made.' }
    $resultBytes = [byte[]]$packBytes.Clone()
    [Array]::Copy($newCapsBytes, 0, $resultBytes, $entry.offset, $entry.length)
    $expectedHash = Get-BytesHash $resultBytes
    if (Test-Path -LiteralPath $backupPath) {
        if ((Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash -ne $currentHash) {
            throw 'An incompatible backup exists. No changes made.'
        }
    } else { [IO.File]::WriteAllBytes($backupPath, $packBytes) }
    [ordered]@{ gpuName = $GpuName; originalHash = $currentHash; patchedHash = $expectedHash } |
        ConvertTo-Json | Set-Content -LiteralPath $recordPath -Encoding UTF8
}
$temporaryPath = $packPath + '.ultra-' + [Guid]::NewGuid().ToString('N') + '.tmp'
$previousPath = $temporaryPath + '.previous'
try {
    [IO.File]::WriteAllBytes($temporaryPath, $resultBytes)
    [IO.File]::Replace($temporaryPath, $packPath, $previousPath)
} finally {
    if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath }
    if (Test-Path -LiteralPath $previousPath) { Remove-Item -LiteralPath $previousPath }
}
if ((Get-FileHash -LiteralPath $packPath -Algorithm SHA256).Hash -ne $expectedHash) { throw 'Final validation failed.' }
if ($Restore) { Write-Output 'Original boot.pack restored.' }
else { Write-Output "Ultra profile written for: $GpuName. Start the game and select Ultra." }
