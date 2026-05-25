$ProgressPreference = 'SilentlyContinue'

function Start-PersistentScript {
    param (
        [string]$Url
    )

    $command = "powershell -NoExit -ExecutionPolicy Bypass -Command `"try { iex (irm '$Url') }"
    Start-Process cmd.exe -Verb RunAs -ArgumentList "/k $command"
}

Start-PersistentScript "https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/CommonDirectories.ps1"
Start-PersistentScript "https://raw.githubusercontent.com/1Mets/tool-downloader/refs/heads/main/ToolDownloader.ps1"
