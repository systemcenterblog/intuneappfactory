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

# The new line you want inserted:
$newLine = '$ExpiresOnUTC = [DateTimeOffset]::Parse($Global:AccessToken.ExpiresOn.ToString([System.Globalization.CultureInfo]::InvariantCulture), [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()'

# Match any statement that:
# - starts with $ExpiresOnUTC = [DateTimeOffset]
# - contains ::Parse(
# - ends with ).ToUniversalTime()
# Works across single-line or multi-line.
$pattern = '(?ms)^\s*\$ExpiresOnUTC\s*=\s*\[DateTimeOffset\].*?\)\s*\.ToUniversalTime\(\)\s*'

foreach ($file in $files) {
    if (-not (Test-Path $file)) {
        Write-Warning "File not found: $file"
        continue
    }

    $content = Get-Content -Path $file -Raw -Encoding UTF8

    $matches = [regex]::Matches($content, $pattern)

    if ($matches.Count -eq 0) {
        Write-Host "NO MATCH: $file (nothing changed)" -ForegroundColor Yellow
        continue
    }

    if ($matches.Count -gt 1) {
        Write-Warning "Multiple matches found in $file. Script will patch the FIRST match only to reduce risk."
    }

    # Take first match only (safer)
    $oldBlock = $matches[0].Value.TrimEnd()

    # If it's already been patched (contains <# ... #> and the new line), skip
    if ($oldBlock -match '<#' -or $content -match [regex]::Escape($newLine)) {
        Write-Host "SKIP: $file appears already patched" -ForegroundColor Cyan
        continue
    }

    # Backup
    $backup = "$file.bak"
    Copy-Item -Path $file -Destination $backup -Force

    # Build replacement:
    # <# old statement #>
    # new statement
    $replacement = "<#`r`n$oldBlock`r`n#>`r`n$newLine`r`n"

    # Replace only first occurrence
    $newContent = $content -replace [regex]::Escape($matches[0].Value), $replacement

    Set-Content -Path $file -Value $newContent -Encoding UTF8

    Write-Host "UPDATED: $file" -ForegroundColor Green
    Write-Host "Backup : $backup" -ForegroundColor DarkGray
}

Write-Host "`nDone." -ForegroundColor Cyan
