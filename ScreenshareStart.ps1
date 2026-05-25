$ProgressPreference = 'SilentlyContinue'

function Start-PersistentScript {
    param (
        [string]$Url
    )

    $command = "powershell -NoExit -ExecutionPolicy Bypass -Command `"try { iex (irm '$Url') } catch { Write-Host `$_ -ForegroundColor Red }; Write-Host ''; Write-Host 'Keeping window open... Do NOT close the CMD window, all progress will be lost' -ForegroundColor Cyan; while (`$true) { Start-Sleep 3600 }`""

    Start-Process cmd.exe -Verb RunAs -ArgumentList "/k $command"
}

Start-PersistentScript "https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/CommonDirectories.ps1"
