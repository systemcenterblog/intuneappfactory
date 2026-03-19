#Requires -RunAsAdministrator

<#
    This script updates IntuneWin32App module files by locating the existing
    $ExpiresOnUTC DateTimeOffset parsing logic, commenting it out, and replacing
    it with a culture-safe version to prevent failures on en-GB and other
    non‑US regional settings.
#>


$modRoot = 'C:\Program Files\WindowsPowerShell\Modules\IntuneWin32App\1.5.0'

$files = @(
    Join-Path $modRoot 'Private\Invoke-AzureStorageBlobUpload.ps1'
    Join-Path $modRoot 'Public\Test-AccessToken.ps1'
)

# --- "Find" block (as a regex, tolerant to whitespace/newlines) ---
# Matches:
# $ExpiresOnUTC = [DateTimeOffset]::Parse(#     $Global:AccessToken.ExpiresOn.ToString(),
#     [System.Globalization.CultureInfo]::InvariantCulture,
#     [System.Globalization.DateTimeStyles]::AssumeUniversal
#     ).ToUniversalTime()
$findPattern = @'
(?ms)                            # multi-line + dot matches newline
\$ExpiresOnUTC\s*=\s*\[DateTimeOffset\]::Parse\(\s*
\$Global:AccessToken\.ExpiresOn\.ToString\(\)\s*,\s*
\[System\.Globalization\.CultureInfo\]::InvariantCulture\s*,\s*
\[System\.Globalization\.DateTimeStyles\]::AssumeUniversal\s*
\)\.ToUniversalTime\(\)
'@

# --- Replacement (exact string you requested) ---
$replaceText = '$ExpiresOnUTC = [DateTimeOffset]::Parse($Global:AccessToken.ExpiresOn.ToString([System.Globalization.CultureInfo]::InvariantCulture), [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()'

foreach ($file in $files) {
    if (-not (Test-Path $file)) {
        Write-Warning "File not found: $file"
        continue
    }

    $content = Get-Content -Path $file -Raw -Encoding UTF8

    if ($content -match $findPattern) {

        # Backup
        $backup = "$file.bak"
        Copy-Item -Path $file -Destination $backup -Force

        # Replace
        $newContent = [regex]::Replace($content, $findPattern, $replaceText)

        # Write back
        Set-Content -Path $file -Value $newContent -Encoding UTF8

        Write-Host "UPDATED: $file" -ForegroundColor Green
        Write-Host "Backup : $backup" -ForegroundColor DarkGray
    }
    else {
        Write-Host "NO MATCH: $file (nothing changed)" -ForegroundColor Yellow
    }
}

Write-Host "`nDone." -ForegroundColor Cyan
