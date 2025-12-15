# Conservative mounted guard inserter: only for files with a State<T> class
$root = 'C:\Users\Elikem\dev\ecowaste'
$warningsFile = Join-Path $root 'async_warnings.txt'
if (-not (Test-Path $warningsFile)) { Write-Error "Warnings file not found: $warningsFile"; exit 1 }

$warnings = Get-Content -LiteralPath $warningsFile | Where-Object { $_ -match 'use_build_context_synchronously' }

$keywords = @('Navigator', 'ScaffoldMessenger', 'showDialog', 'setState', 'showModalBottomSheet', 'showCupertinoModalPopup', 'context.')

foreach ($w in $warnings) {
    $m = [regex]::Match($w, '((lib\\[^:]+):([0-9]+):)')
    if (-not $m.Success) { continue }
    $relPath = $m.Groups[2].Value
    $lineNum = [int]$m.Groups[3].Value
    $filePath = Join-Path $root $relPath
    if (-not (Test-Path $filePath)) { Write-Output "File missing: $filePath"; continue }

    $textRaw = Get-Content -LiteralPath $filePath -Raw -Encoding UTF8 -ErrorAction Stop
    if ($textRaw -notmatch 'extends\s+State\s*<') { Write-Output "Not a State class file, skipping: $relPath"; continue }

    $lines = $textRaw -split "\r?\n"
    $idx = $lineNum - 1
    if ($idx -lt 0 -or $idx -ge $lines.Length) { Write-Output ("Line out of range: {0}:{1}" -f $filePath, $lineNum); continue }

    # Check existing guard nearby
    $already = $false
    for ($i = [Math]::Max(0, $idx-3); $i -le [Math]::Min($lines.Length-1, $idx+3); $i++) {
        if ($lines[$i] -match 'if\s*\(\s*!\s*mounted\s*\)\s*return') { $already = $true; break }
    }
    if ($already) { Write-Output ("Guard exists: {0}:{1}" -f $filePath, $lineNum); continue }

    # Find insertion point: prefer after nearest await before the target line (within 6 lines)
    $insertPos = -1
    for ($i = $idx; $i -ge [Math]::Max(0, $idx-6); $i--) {
        if ($lines[$i] -match '\bawait\b') { $insertPos = $i + 1; break }
    }

    # If no await found, find the first keyword line at or after idx up to +6 lines
    if ($insertPos -eq -1) {
        for ($i = $idx; $i -le [Math]::Min($lines.Length-1, $idx+6); $i++) {
            $trim = $lines[$i].TrimStart()
            foreach ($k in $keywords) {
                if ($trim.StartsWith($k)) { $insertPos = $i; break }
            }
            if ($insertPos -ne -1) { break }
        }
    }

    if ($insertPos -eq -1) { Write-Output ("No safe insertion point found, skipping: {0}:{1}" -f $filePath, $lineNum); continue }

    # Compute indentation from target insertPos line (or previous line if inserting after await)
    $refLine = if ($insertPos -lt $lines.Length) { $lines[$insertPos] } else { $lines[$insertPos-1] }
    if ($refLine -match '^(\s*)') { $indent = $matches[1] } else { $indent = '' }

    $guard = "$indent`if (!mounted) return;"

    Copy-Item -LiteralPath $filePath -Destination ("{0}.bak" -f $filePath) -Force

    $newLines = @()
    if ($insertPos -gt 0) { $newLines += $lines[0..($insertPos-1)] }
    $newLines += $guard
    if ($insertPos -le ($lines.Length - 1)) { $newLines += $lines[$insertPos..($lines.Length - 1)] }

    $newText = $newLines -join "`n"
    Set-Content -LiteralPath $filePath -Value $newText -Encoding UTF8
    Write-Output ("Inserted guard (v2): {0}:{1} at line {2}" -f $filePath, $lineNum, $insertPos+1)
}
Write-Output "`nMounted guard v2 insertion complete."