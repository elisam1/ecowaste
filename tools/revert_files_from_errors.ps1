# Revert files listed in error_lines.txt by restoring their .bak backups if present
$root = 'C:\Users\Elikem\dev\ecowaste'
$errorsFile = Join-Path $root 'error_lines.txt'
if (-not (Test-Path $errorsFile)) { Write-Error "Errors file not found: $errorsFile"; exit 1 }
$lines = Get-Content -LiteralPath $errorsFile
$seen = @{}
foreach ($l in $lines) {
    $m = [regex]::Match($l, ' (lib\\[^:]+):')
    if ($m.Success) {
        $rel = $m.Groups[1].Value
        if (-not $seen.ContainsKey($rel)) {
            $seen[$rel] = $true
            $filePath = Join-Path $root $rel
            $bak = $filePath + '.bak'
            if (Test-Path $bak) {
                Copy-Item -LiteralPath $bak -Destination $filePath -Force
                Write-Output "Restored: $filePath from .bak"
            } else {
                Write-Output "No .bak for: $filePath"
            }
        }
    }
}
Write-Output "Revert complete."