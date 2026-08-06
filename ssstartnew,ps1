function Start-PersistentScript {
    param (
        [string]$Url
    )

    $command = "powershell -NoExit -ExecutionPolicy Bypass -Command `"try { iex (irm '$Url') } catch { Write-Host `$_ -ForegroundColor Red }; Write-Host ''; Write-Host 'Keeping window open... Do NOT close the CMD window, all progress will be lost' -ForegroundColor Cyan; while (`$true) { Start-Sleep 3600 }`""

    Start-Process cmd.exe -Verb RunAs -ArgumentList "/k $command"
}

Start-PersistentScript "https://raw.githubusercontent.com/1Mets/tool-downloader/refs/heads/main/ScreenshareStart.ps1"

Start-PersistentScript "https://raw.githubusercontent.com/piespeas/MyPowerShellScripts-ssing/refs/heads/main/Tools.ps1"

Start-PersistentScript "https://raw.githubusercontent.com/piespeas/MyPowerShellScripts-ssing/refs/heads/main/JVM.ps1"


Start-Process explorer.exe $env:TEMP
Start-Process explorer.exe "shell:recent"
