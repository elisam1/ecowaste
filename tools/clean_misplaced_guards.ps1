# Remove misplaced 'if (!mounted) return;' guards that break chained calls
$root = 'C:\Users\Elikem\dev\ecowaste'
$files = Get-ChildItem -Path $root -Recurse -Filter *.dart -File -ErrorAction SilentlyContinue
foreach ($f in $files) {
    $text = Get-Content -Raw -LiteralPath $f.FullName
    $lines = $text -split "\r?\n"
    $changed = $false
    $i = 0
    $newLines = @()
    while ($i -lt $lines.Length) {
        $line = $lines[$i]
        $trim = $line.Trim()
        if ($trim -eq 'if (!mounted) return;') {
            $prev = if ($newLines.Count -gt 0) { $newLines[-1] } else { '' }
            $next = if ($i+1 -lt $lines.Length) { $lines[$i+1] } else { '' }
            $prevEndsDot = $prev.TrimEnd().EndsWith('.')
            $nextStartsDot = $next.TrimStart().StartsWith('.')
            if ($prevEndsDot -or $nextStartsDot) {
                # skip this misplaced guard
                $changed = $true
                Write-Output "Removed misplaced guard in $($f.FullName) at original line $($i+1)"
                $i++
                continue
            }
            # avoid duplicate guards
            if ($newLines.Count -gt 0 -and $newLines[-1].Trim() -eq 'if (!mounted) return;') {
                $changed = $true
                Write-Output "Removed duplicate guard in $($f.FullName) at original line $($i+1)"
                $i++
                continue
            }
        }
        $newLines += $line
        $i++
    }
    if ($changed) {
        Copy-Item -LiteralPath $f.FullName -Destination ("{0}.bak2" -f $f.FullName) -Force
        $newText = $newLines -join "`n"
        Set-Content -LiteralPath $f.FullName -Value $newText -Encoding UTF8
    }
}
Write-Output "Cleaning misplaced guards complete."