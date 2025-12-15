# Remove unused logging_service imports where LoggingService isn't referenced
$root = 'C:\Users\Elikem\dev\ecowaste'
$files = Get-ChildItem -Path $root -Recurse -Filter *.dart -File -ErrorAction SilentlyContinue
$importPattern = "import .*logging_service\.dart.*;"

foreach ($f in $files) {
    $text = Get-Content -Raw -LiteralPath $f.FullName
    if ($text -match $importPattern) {
        if ($text -notmatch 'LoggingService\.') {
            Copy-Item -LiteralPath $f.FullName -Destination "$($f.FullName).bak" -Force
            $new = [regex]::Replace($text, $importPattern, '', 'IgnoreCase')
            # remove any duplicate blank lines at top
            $new = $new -replace "(^\s*\r?\n)+", "`n"
            Set-Content -LiteralPath $f.FullName -Value $new -Encoding UTF8
            Write-Output "Removed import from: $($f.FullName)"
        }
    }
}

Write-Output "`nRemove unused logging imports complete."