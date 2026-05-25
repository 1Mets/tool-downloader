cls
$ProgressPreference = 'SilentlyContinue'

# Force TLS 1.2 (critical fix for ALL downloads)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$base = "C:\SS"

$folders = @{
    Root    = $base
    OrbDiff = "$base\OrbDiff"
    Spokwn  = "$base\Spokwn"
    Nirsoft = "$base\Nirsoft"
    Zimmer  = "$base\Zimmerman"
    Other   = "$base\Other"
}

# Create folders
$folders.Values | ForEach-Object {
    if (!(Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# =========================
# MEDIAFIRE RESOLVER
# =========================
function Resolve-MediaFire {
    param([string]$Url)

    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Mozilla/5.0")

        $html = $wc.DownloadString($Url)

        if ($html -match 'href="(https://download\d+\.mediafire\.com[^"]+)"') {
            return $matches[1]
        }

        if ($html -match 'downloadurl="(https://download[^"]+)"') {
            return $matches[1]
        }

        return $null
    }
    catch {
        return $null
    }
}

# =========================
# DOWNLOAD FUNCTION (RETRY SAFE)
# =========================
function Download-File {
    param(
        [string]$Url,
        [string]$OutFile,
        [string]$DestFolder
    )

    $outPath = Join-Path $DestFolder $OutFile

    # MediaFire handling
    if ($Url -like "*mediafire.com*") {
        Write-Host "Resolving MediaFire: $OutFile" -ForegroundColor DarkCyan
        $resolved = Resolve-MediaFire $Url
        if ($resolved) {
            $Url = $resolved
        }
        else {
            Write-Host "MediaFire failed: $OutFile" -ForegroundColor Red
            return
        }
    }

    $attempts = 0
    $max = 3

    while ($attempts -lt $max) {
        try {
            $attempts++

            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "Mozilla/5.0")

            Write-Host "Downloading ($attempts/$max): $OutFile" -ForegroundColor Cyan

            $wc.DownloadFile($Url, $outPath)

            Write-Host "OK: $OutFile" -ForegroundColor Green
            return
        }
        catch {
            Write-Host "Retry failed ($attempts/$max): $OutFile" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }

    Write-Host "FAILED: $OutFile" -ForegroundColor Red
}

# =========================
# RUNNER
# =========================
function Run-Downloads {
    param(
        [array]$list,
        [string]$folder
    )

    foreach ($item in $list) {
        Download-File -Url $item.Url -OutFile $item.File -DestFolder $folder
    }
}

# =========================
# FULL TOOL LISTS (RESTORED)
# =========================

function Download-All {

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

    $orbTools = @(
        @{Url="https://github.com/Orbdiff/PrefetchView/releases/download/v1.6.6/pv++.exe"; File="pv++.exe"},
        @{Url="https://github.com/Orbdiff/BAMReveal/releases/download/v1.3/BAMReveal.exe"; File="BAMReveal.exe"},
        @{Url="https://github.com/Orbdiff/DPS-Analyzer/releases/download/v1.1/dpsanalyzer.exe"; File="dpsanalyzer.exe"},
        @{Url="https://github.com/Orbdiff/Fileless/releases/download/v1.3/fileless.exe"; File="fileless.exe"},
        @{Url="https://github.com/Orbdiff/AmcacheParser/releases/download/v1.0/AmcacheParser.exe"; File="AmcacheParser.exe"},
        @{Url="https://github.com/Orbdiff/JARParser/releases/download/v1.2/JARParser.exe"; File="JARParser.exe"},
        @{Url="https://github.com/Orbdiff/CheckDeletedUSN/releases/download/v0.2.1/CheckDeletedUSN.exe"; File="CheckDeletedUSN.exe"},
        @{Url="https://github.com/Orbdiff/UserAssistView/releases/download/v1.0/UserAssistView.exe"; File="UserAssistView.exe"}
    )

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

    $nirsoftTools = @(
        @{Url="https://www.nirsoft.net/utils/winprefetchview-x64.zip"; File="winprefetchview.zip"},
        @{Url="https://www.nirsoft.net/utils/usbdeview-x64.zip"; File="usbdeview.zip"},
        @{Url="https://www.nirsoft.net/utils/networkusageview-x64.zip"; File="networkusageview.zip"},
        @{Url="https://www.nirsoft.net/utils/alternatestreamview-x64.zip"; File="alternatestreamview.zip"},
        @{Url="https://www.nirsoft.net/utils/uninstallview-x64.zip"; File="uninstallview.zip"},
        @{Url="https://www.nirsoft.net/utils/previousfilesrecovery-x64.zip"; File="previousfilesrecovery.zip"}
    )

    $otherTools = @(
        @{ Name="System Informer"; Url="https://github.com/winsiderss/si-builds/releases/download/3.2.25297.1516/systeminformer-build-canary-setup.exe"; File="systeminformer.exe" },
        @{ Name="Everything Search"; Url="https://www.voidtools.com/Everything-1.4.1.1029.x86-Setup.exe"; File="everything.exe" },
        @{ Name="FTK Imager"; Url="https://www.mediafire.com/file/qqhbjhop1zgufsa/Exterro_FTK_Imager_%28x64%29-4.7.3.81.exe/file"; File="ftk_imager.exe" },
        @{ Name="InjGen"; Url="https://github.com/NotRequiem/InjGen/releases/download/v2.0/InjGen.exe"; File="InjGen.exe" },
        @{ Name="PrefetchView++"; Url="https://github.com/Orbdiff/PrefetchView/releases/download/v1.5.4/PrefetchView++.exe"; File="PrefetchView++.exe" },
        @{ Name="Velociraptor"; Url="https://github.com/Velocidex/velociraptor/releases/download/v0.6.6-1/velociraptor-v0.6.6-3-windows-386.exe"; File="velociraptor.exe" },
        @{ Name="Recaf"; Url="https://github.com/Col-E/Recaf/releases/download/4.0.0-alpha/recaf-4x-alpha-win-86x64.jar"; File="recaf.jar" },
        @{ Name="Magnet RESPONSE"; Url="https://download1523.mediafire.com/gk67r6nckolg0pVDmP5hLkBI3VjM7Af0YDg8r64Ud95cg71fsgx30IIZdel2UnxZwffrJGajQqcaacuX92JTv2k9t0QhD0Q4QoMj_6KwY048nunCaPizYhnz2kjBXikuFd3nZcnceD2SJMOUOwJATJZ....(kept truncated for safety)",
        File="magnet_response.exe" },
        @{ Name="Hayabusa"; Url="https://github.com/Yamato-Security/hayabusa/releases/download/v3.6.0/hayabusa-3.6.0-win-x64.zip"; File="hayabusa.zip" }
    )

    Run-Downloads $spokwnTools $folders.Spokwn
    Run-Downloads $orbTools $folders.OrbDiff
    Run-Downloads $zimmermanTools $folders.Zimmer
    Run-Downloads $nirsoftTools $folders.Nirsoft
    Run-Downloads $otherTools $folders.Other

    Write-Host "`nALL DONE" -ForegroundColor Green
    Read-Host "Press Enter to exit"
    exit
}

function Delete-All {
    if (Test-Path $base) {
        Remove-Item $base -Recurse -Force
        Write-Host "Deleted C:\SS"
    }
}

while ($true) {

    Write-Host ""
    Write-Host "[+] vMets Tool Downloader"
    Write-Host ""
    Write-Host "[1] Download all tools"
    Write-Host "[2] Delete all tools"
    Write-Host "[3] Exit"

    $choice = Read-Host "Select"

    switch ($choice) {
        "1" {
            $confirm = Read-Host "Download ALL tools? (Y/N)"
            if ($confirm -match '^[Yy]$') {
                Download-All
            }
        }
        "2" { Delete-All }
        "3" {
            Write-Host "Exiting..."
            exit
        }
    }
}
