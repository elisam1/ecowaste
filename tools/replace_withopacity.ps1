# Backup and replace .withOpacity(...) -> .withValues(alpha: ...)
# Usage: powershell -ExecutionPolicy Bypass -File tools\replace_withopacity.ps1

$files = Get-ChildItem -Path . -Recurse -Filter *.dart
foreach ($f in $files) {
    $path = $f.FullName
    $text = Get-Content -Raw -Encoding UTF8 $path
    if ($text -match "\\.withOpacity\(") {
        $bak = "$path.bak"
        Copy-Item -Path $path -Destination $bak -Force
        $new = [regex]::Replace($text, '\\.withOpacity\\(\\s*([^\\)]+)\\)', '.withValues(alpha: $1)')
        Set-Content -Path $path -Value $new -Encoding UTF8
        Write-Host "Updated: $path"
    }
}
Write-Host 'Replacement complete.'
