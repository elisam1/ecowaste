# Regex-based codemod: replace .withOpacity(x) -> .withValues(alpha: x)
# Creates a .bak backup for each changed file.

$root = 'C:\Users\Elikem\dev\ecowaste'
$files = Get-ChildItem -Path $root -Recurse -Filter *.dart -File -ErrorAction SilentlyContinue
$pattern = '\.withOpacity\s*\(\s*([^\)]+)\s*\)'

foreach ($f in $files) {
    try {
        $text = Get-Content -Raw -LiteralPath $f.FullName -ErrorAction Stop
    } catch {
        Write-Output "Skip (read error): $($f.FullName)"
        continue
    }

    $new = [System.Text.RegularExpressions.Regex]::Replace($text, $pattern, '.withValues(alpha: $1)')

    if ($new -ne $text) {
        Copy-Item -LiteralPath $f.FullName -Destination "$($f.FullName).bak" -Force
        Set-Content -LiteralPath $f.FullName -Value $new -Encoding UTF8
        Write-Output "Patched: $($f.FullName)"
    }
}

Write-Output "\nRegex codemod complete."
