# Apply conservative mounted guards for analyzer 'use_build_context_synchronously' warnings
$root = 'C:\Users\Elikem\dev\ecowaste'
$warningsFile = Join-Path $root 'async_warnings.txt'
if (-not (Test-Path $warningsFile)) {
    Write-Error "Warnings file not found: $warningsFile"
    exit 1
}

$warnings = Get-Content -LiteralPath $warningsFile | Where-Object { $_ -match 'use_build_context_synchronously' }

foreach ($w in $warnings) {
    # Extract relative path starting from 'lib\'
    $m = [regex]::Match($w, '((lib|packages)\\[^:]+):([0-9]+):')
    if (-not $m.Success) { continue }
    $relPath = $m.Groups[1].Value -replace '\\','\\'
    $lineNum = [int]$m.Groups[3].Value
    $filePath = Join-Path $root $relPath
    if (-not (Test-Path $filePath)) { Write-Output "File missing: $filePath"; continue }

    $textRaw = Get-Content -LiteralPath $filePath -Raw -Encoding UTF8 -ErrorAction Stop
    $lines = $textRaw -split "\r?\n"
    $idx = $lineNum - 1
    if ($idx -lt 0 -or $idx -ge $lines.Length) { Write-Output ("Line out of range: {0}:{1}" -f $filePath, $lineNum); continue }

    # Check if a mounted guard already exists within previous 3 lines
    $already = $false
    for ($i = [Math]::Max(0, $idx-3); $i -le $idx+0; $i++) {
        if ($lines[$i] -match 'if\s*\(\s*!\s*mounted\s*\)\s*return') { $already = $true; break }
    }
    if ($already) { Write-Output ("Guard exists: {0}:{1}" -f $filePath, $lineNum); continue }

    # Determine indentation of target line
    $targetLine = $lines[$idx]
    $indent = ''
    if ($targetLine -match '^(\s*)') { $indent = $matches[1] }

    # Insert guard before the target line
    $guard = "$indent`if (!mounted) return;"

    $newLines = @()
    if ($idx -gt 0) { $newLines += $lines[0..($idx-1)] }
    $newLines += $guard
    $newLines += $lines[$idx..($lines.Length - 1)]

    Copy-Item -LiteralPath $filePath -Destination ("{0}.bak" -f $filePath) -Force
    $newText = $newLines -join "`n"
    Set-Content -LiteralPath $filePath -Value $newText -Encoding UTF8
    Write-Output ("Inserted guard: {0}:{1}" -f $filePath, $lineNum)
}

Write-Output "`nMounted guard insertion complete."