# Replace print(...) with LoggingService.{info,debug,error} and add import if missing
$root = 'C:\Users\Elikem\dev\ecowaste'
$files = Get-ChildItem -Path $root -Recurse -Filter *.dart -File -ErrorAction SilentlyContinue
$logImport = "import 'package:flutter_application_1/mobile_app/service/logging_service.dart';"

foreach ($f in $files) {
    $text = Get-Content -Raw -LiteralPath $f.FullName
    $orig = $text

    # find simple print calls that are not commented out (avoid lines starting with //)
    # This is a conservative pattern: single-line print(...) ending with a semicolon.
    $pattern = '(?m)^(?!\s*//).*?\bprint\s*\(([^\)]*)\)\s*;'
    $new = [regex]::Replace($text, $pattern, {
        param($m)
        $inside = $m.Groups[1].Value.Trim()
        $insideLower = $inside.ToLower()
        if ($insideLower -match 'error|exception|failed|cannot') {
            return [regex]::Replace($m.Value, 'print\s*\(', 'LoggingService.error(')
        } elseif ($insideLower -match 'debug') {
            return [regex]::Replace($m.Value, 'print\s*\(', 'LoggingService.debug(')
        } else {
            return [regex]::Replace($m.Value, 'print\s*\(', 'LoggingService.info(')
        }
    })

    if ($new -ne $orig) {
        # ensure import exists (match by filename to be tolerant of spacing)
        if ($new -notmatch 'logging_service\.dart') {
            # insert after last import
            $lines = $new -split "\r?\n"
            $lastImportIndex = -1
            for ($i = 0; $i -lt $lines.Length; $i++) {
                if ($lines[$i] -match '^\s*import\s+') { $lastImportIndex = $i }
            }
            if ($lastImportIndex -ge 0) {
                $before = $lines[0..$lastImportIndex]
                if ($lastImportIndex + 1 -le ($lines.Length - 1)) {
                    $after = $lines[($lastImportIndex+1)..($lines.Length-1)]
                } else {
                    $after = @()
                }
                $combined = @()
                $combined += $before
                $combined += $logImport
                $combined += $after
                $new = $combined -join "`n"
            } else {
                $new = $logImport + "`n`n" + $new
            }
        }

        Copy-Item -LiteralPath $f.FullName -Destination "$($f.FullName).bak" -Force
        Set-Content -LiteralPath $f.FullName -Value $new -Encoding UTF8
        Write-Output "Patched: $($f.FullName)"
    }
}

Write-Output "`nReplace prints complete."
