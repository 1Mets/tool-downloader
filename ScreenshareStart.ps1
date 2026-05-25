$ProgressPreference = 'SilentlyContinue'

function Start-PersistentScript {
    param (
        [string]$Url
    )

    $command = "powershell -NoExit -ExecutionPolicy Bypass -Command `"try { iex (irm '$Url') } catch { Write-Host `$_ -ForegroundColor Red }; Write-Host ''; Write-Host 'Keeping window open... Do NOT close the CMD window, all progress will be lost' -ForegroundColor Cyan; while (`$true) { Start-Sleep 3600 }`""

    Start-Process cmd.exe -Verb RunAs -ArgumentList "/k $command"
}

Start-PersistentScript "https://raw.githubusercontent.com/praiselily/lilith-ps/refs/heads/main/CommonDirectories.ps1"
Start-PersistentScript

# =========================
# Base folders
# =========================
$base = "C:\SS"

$folders = @{
    Root     = $base
    OrbDiff  = "$base\OrbDiff"
    Spokwn   = "$base\Spokwn"
    Nirsoft  = "$base\Nirsoft"
    Zimmer   = "$base\Zimmerman"
    Other    = "$base\Other"
}

# Create folders
$folders.Values | ForEach-Object {
    New-Item -ItemType Directory -Path $_ -Force | Out-Null
}

# =========================
# Download function
# =========================
function Download-File {
    param(
        [string]$Url,
        [string]$OutFile,
        [string]$DestFolder
    )

    $outPath = Join-Path $DestFolder $OutFile

    try {
        Start-BitsTransfer -Source $Url -Destination $outPath -ErrorAction Stop
    }
    catch {
        try {
            Invoke-WebRequest -Uri $Url -OutFile $outPath -UseBasicParsing -ErrorAction Stop
        }
        catch {
            Write-Host "FAILED: $OutFile" -ForegroundColor Red
            return
        }
    }

    Write-Host "Downloaded: $OutFile"
}

# =========================
# Spokwn Tools
# =========================
$spokwnTools = @(
    @{Url="https://github.com/spokwn/KernelLiveDumpTool/releases/download/v1.1/KernelLiveDumpTool.exe"; File="KernelLiveDumpTool.exe"},
    @{Url="https://github.com/spokwn/BAM-parser/releases/download/v1.2.9/BAMParser.exe"; File="BAMParser.exe"},
    @{Url="https://github.com/spokwn/PathsParser/releases/download/v1.2/PathsParser.exe"; File="PathsParser.exe"},
    @{Url="https://github.com/spokwn/JournalTrace/releases/download/1.2/JournalTrace.exe"; File="JournalTrace.exe"},
    @{Url="https://github.com/spokwn/Tool/releases/download/v1.1.3/espouken.exe"; File="espouken.exe"},
    @{Url="https://github.com/spokwn/pcasvc-executed/releases/download/v0.8.7/PcaSvcExecuted.exe"; File="PcaSvcExecuted.exe"},
    @{Url="https://github.com/spokwn/BamDeletedKeys/releases/download/v1.0/BamDeletedKeys.exe"; File="BamDeletedKeys.exe"},
    @{Url="https://github.com/spokwn/prefetch-parser/releases/download/v1.5.5/PrefetchParser.exe"; File="PrefetchParser.exe"}
)

foreach ($t in $spokwnTools) {
    Download-File $t.Url $t.File $folders.Spokwn
}

# =========================
# Zimmerman Tools
# =========================
$zimmermanTools = @(
    @{Url="https://download.ericzimmermanstools.com/net9/AmcacheParser.zip"; File="AmcacheParser.zip"},
    @{Url="https://download.ericzimmermanstools.com/net9/AppCompatCacheParser.zip"; File="AppCompatCacheParser.zip"},
    @{Url="https://download.ericzimmermanstools.com/net9/JumpListExplorer.zip"; File="JumpListExplorer.zip"},
    @{Url="https://download.ericzimmermanstools.com/net9/bstrings.zip"; File="bstrings.zip"},
    @{Url="https://download.ericzimmermanstools.com/net9/PECmd.zip"; File="PECmd.zip"},
    @{Url="https://download.ericzimmermanstools.com/net9/SrumECmd.zip"; File="SrumECmd.zip"},
    @{Url="https://download.ericzimmermanstools.com/net9/TimelineExplorer.zip"; File="TimelineExplorer.zip"},
    @{Url="https://download.ericzimmermanstools.com/net9/RegistryExplorer.zip"; File="RegistryExplorer.zip"},
    @{Url="https://download.ericzimmermanstools.com/net9/MFTECmd.zip"; File="MFTECmd.zip"}
)

foreach ($t in $zimmermanTools) {
    Download-File $t.Url $t.File $folders.Zimmer
}

# =========================
# Nirsoft Tools
# =========================
$nirsoftTools = @(
    @{Url="https://www.nirsoft.net/utils/winprefetchview-x64.zip"; File="winprefetchview.zip"},
    @{Url="https://www.nirsoft.net/utils/usbdeview-x64.zip"; File="usbdeview.zip"},
    @{Url="https://www.nirsoft.net/utils/networkusageview-x64.zip"; File="networkusageview.zip"},
    @{Url="https://www.nirsoft.net/utils/alternatestreamview-x64.zip"; File="alternatestreamview.zip"},
    @{Url="https://www.nirsoft.net/utils/uninstallview-x64.zip"; File="uninstallview.zip"},
    @{Url="https://www.nirsoft.net/utils/previousfilesrecovery-x64.zip"; File="previousfilesrecovery.zip"}
)

foreach ($t in $nirsoftTools) {
    Download-File $t.Url $t.File $folders.Nirsoft
}

# =========================
# Other Tools
# =========================
$otherTools = @(
    @{Url="https://github.com/Yamato-Security/hayabusa/releases/download/v3.6.0/hayabusa-3.6.0-win-x64.zip"; File="hayabusa.zip"},
    @{Url="https://www.mediafire.com/file/qqhbjhop1zgufsa/Exterro_FTK_Imager_%28x64%29-4.7.3.81.exe/file"; File="FTK_Imager.exe"},
    @{Url="https://github.com/winsiderss/si-builds/releases/download/3.2.25297.1516/systeminformer-build-canary-setup.exe"; File="systeminformer.exe"}
)

foreach ($t in $otherTools) {
    Download-File $t.Url $t.File $folders.Other
}

# =========================
# Root tools
# =========================
Download-File `
    "https://www.voidtools.com/Everything-1.4.1.1029.x86-Setup.exe" `
    "Everything.exe" `
    $folders.Root

# =========================
# Optional .NET SDK
# =========================
if ($dotnet -match '^[Yy]') {
    Download-File `
        "https://builds.dotnet.microsoft.com/dotnet/Sdk/9.0.306/dotnet-sdk-9.0.306-win-x64.exe" `
        "dotnet-sdk.exe" `
        $folders.Root
}
