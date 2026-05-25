cls
$ProgressPreference = 'SilentlyContinue'

$base = "C:\SS"

$folders = @{
    Root    = $base
    OrbDiff = "$base\OrbDiff"
    Spokwn  = "$base\Spokwn"
    Nirsoft = "$base\Nirsoft"
    Zimmer  = "$base\Zimmerman"
    Other   = "$base\Other"
}

$folders.Values | ForEach-Object {
    New-Item -ItemType Directory -Path $_ -Force | Out-Null
}

function Download-File {
    param($Url, $OutFile, $DestFolder)

    $outPath = Join-Path $DestFolder $OutFile

    try {
        Invoke-WebRequest -Uri $Url -OutFile $outPath -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Host "FAILED: $OutFile" -ForegroundColor Red
    }
}

function Run-Downloads($list, $folder) {
    $list | ForEach-Object -Parallel {
        Invoke-WebRequest -Uri $_.Url -OutFile (Join-Path $using:folder $_.File) -UseBasicParsing -ErrorAction SilentlyContinue
    } -ThrottleLimit 10
}

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
    @{ Name="System Informer"; Url="https://github.com/winsiderss/si-builds/releases/download/3.2.25297.1516/systeminformer-build-canary-setup.exe"; File="systeminformer-build-canary-setup.exe" },
    @{ Name="Everything Search"; Url="https://www.voidtools.com/Everything-1.4.1.1029.x86-Setup.exe"; File="Everything-1.4.1.1029.x86-Setup.exe" },
    @{ Name="FTK Imager"; Url="https://www.mediafire.com/file/qqhbjhop1zgufsa/Exterro_FTK_Imager_%28x64%29-4.7.3.81.exe/file"; File="Exterro_FTK_Imager_x64-4.7.3.81.exe" }
    @{ Name="InjGen"; Url="https://github.com/NotRequiem/InjGen/releases/download/v2.0/InjGen.exe"; File="InjGen.exe" },
    @{ Name="PrefetchView++"; Url="https://github.com/Orbdiff/PrefetchView/releases/download/v1.5.4/PrefetchView++.exe"; File="PrefetchView++.exe" },
    @{ Name="Velociraptor"; Url="https://github.com/Velocidex/velociraptor/releases/download/v0.6.6-1/velociraptor-v0.6.6-3-windows-386.exe"; File="velociraptor-v0.6.6-3-windows-386.exe" },
    @{ Name="Recaf"; Url="https://github.com/Col-E/Recaf/releases/download/4.0.0-alpha/recaf-4x-alpha-win-86x64.jar"; File="recaf-4x-alpha-win-86x64.jar" },
    @{ Name="Magnet RESPONSE"; Url="https://download1523.mediafire.com/gk67r6nckolg0pVDmP5hLkBI3VjM7Af0YDg8r64Ud95cg71fsgx30IIZdel2UnxZwffrJGajQqcaacuX92JTv2k9t0QhD0Q4QoMj_6KwY048nunCaPizYhnz2kjBXikuFd3nZcnceD2SJMOUOwJATJ-zBD7RIK-eXpcSI8L1JMUYXA/lxnu4z9sqzz63lc/MRCv120.exe"; File="MRCv120.exe" },
    @{ Name="Hayabusa"; Url="https://github.com/Yamato-Security/hayabusa/releases/download/v3.6.0/hayabusa-3.6.0-win-x64.zip"; File="hayabusa-3.6.0-win-x64.zip" }
)

    Run-Downloads $spokwnTools $folders.Spokwn
    Run-Downloads $orbTools $folders.OrbDiff
    Run-Downloads $zimmermanTools $folders.Zimmer
    Run-Downloads $nirsoftTools $folders.Nirsoft
    Run-Downloads $otherTools $folders.Other
}

function Delete-All {
    Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Deleted C:\SS"
}

while ($true) {

    Write-Host ""
    Write-Host "[+] vMets Tool Downloader"
    Write-Host ""
    Write-Host "[1] Download all tools"
    Write-Host "[2] Delete all tools"
    Write-Host "[3] Exit"

    $choice = Read-Host "Select"

    if ($choice -eq "1") {
        $confirm = Read-Host "Download ALL tools? (Y/N)"
        if ($confirm -match '^[Yy]$') {
            Download-All
        }
    }
    elseif ($choice -eq "2") {
        Delete-All
    }
    elseif ($choice -eq "3") {
        break
    }
}
