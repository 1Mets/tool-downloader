cls
$ProgressPreference = 'SilentlyContinue'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$base = "C:\SS"

$folders = @{
    Spokwn  = "$base\Spokwn"
    OrbDiff = "$base\OrbDiff"
    Zimmer  = "$base\Zimmerman"
    Nirsoft = "$base\Nirsoft"
    Other   = "$base\Other"
}

$folders.Values | ForEach-Object {
    New-Item -ItemType Directory -Path $_ -Force | Out-Null
}

# =========================
# ZIP EXTRACT
# =========================
function Extract-Zip($file, $dest) {
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($file, $dest)
    } catch {}
}

# =========================
# DOWNLOAD JOB
# =========================
function Start-JobDownload($url, $file, $folder) {

    Start-Job -ArgumentList $url, $file, $folder -ScriptBlock {

        param($url, $file, $folder)

        try {
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "Mozilla/5.0")

            $path = Join-Path $folder $file
            $wc.DownloadFile($url, $path)

            if ($file -like "*.zip") {
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($path, $folder)
            }

            "OK: $file"
        }
        catch {
            "FAIL: $file"
        }
    }
}

# =========================
# RUNNER (FAST PARALLEL)
# =========================
function Run($list, $folder, $limit = 8) {

    $jobs = @()

    foreach ($i in $list) {

        $jobs += Start-JobDownload $i.Url $i.File $folder

        while ((Get-Job -State Running).Count -ge $limit) {
            Start-Sleep -Milliseconds 200
        }
    }

    Wait-Job $jobs | Out-Null

    $jobs | ForEach-Object {
        Receive-Job $_
        Remove-Job $_
    }
}

# =========================
# FULL TOOL LISTS (ALL URLS RESTORED)
# =========================

function Download-All {

    # -------------------------
    # SPOKWN
    # -------------------------
    $spokwn = @(
        @{Url="https://github.com/spokwn/KernelLiveDumpTool/releases/download/v1.1/KernelLiveDumpTool.exe"; File="KernelLiveDumpTool.exe"},
        @{Url="https://github.com/spokwn/BAM-parser/releases/download/v1.2.9/BAMParser.exe"; File="BAMParser.exe"},
        @{Url="https://github.com/spokwn/PathsParser/releases/download/v1.2/PathsParser.exe"; File="PathsParser.exe"},
        @{Url="https://github.com/spokwn/JournalTrace/releases/download/1.2/JournalTrace.exe"; File="JournalTrace.exe"},
        @{Url="https://github.com/spokwn/Tool/releases/download/v1.1.3/espouken.exe"; File="espouken.exe"},
        @{Url="https://github.com/spokwn/pcasvc-executed/releases/download/v0.8.7/PcaSvcExecuted.exe"; File="PcaSvcExecuted.exe"},
        @{Url="https://github.com/spokwn/BamDeletedKeys/releases/download/v1.0/BamDeletedKeys.exe"; File="BamDeletedKeys.exe"},
        @{Url="https://github.com/spokwn/prefetch-parser/releases/download/v1.5.5/PrefetchParser.exe"; File="PrefetchParser.exe"}
    )

    # -------------------------
    # ORBDIFF
    # -------------------------
    $orb = @(
        @{Url="https://github.com/Orbdiff/PrefetchView/releases/download/v1.6.6/pv++.exe"; File="pv++.exe"},
        @{Url="https://github.com/Orbdiff/BAMReveal/releases/download/v1.3/BAMReveal.exe"; File="BAMReveal.exe"},
        @{Url="https://github.com/Orbdiff/DPS-Analyzer/releases/download/v1.1/dpsanalyzer.exe"; File="dpsanalyzer.exe"},
        @{Url="https://github.com/Orbdiff/Fileless/releases/download/v1.3/fileless.exe"; File="fileless.exe"},
        @{Url="https://github.com/Orbdiff/AmcacheParser/releases/download/v1.0/AmcacheParser.exe"; File="AmcacheParser.exe"},
        @{Url="https://github.com/Orbdiff/JARParser/releases/download/v1.2/JARParser.exe"; File="JARParser.exe"},
        @{Url="https://github.com/Orbdiff/CheckDeletedUSN/releases/download/v0.2.1/CheckDeletedUSN.exe"; File="CheckDeletedUSN.exe"},
        @{Url="https://github.com/Orbdiff/UserAssistView/releases/download/v1.0/UserAssistView.exe"; File="UserAssistView.exe"}
    )

    # -------------------------
    # ZIMMERMAN
    # -------------------------
    $zimmer = @(
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

    # -------------------------
    # NIRSOFT
    # -------------------------
    $nirsoft = @(
        @{Url="https://www.nirsoft.net/utils/winprefetchview-x64.zip"; File="winprefetchview.zip"},
        @{Url="https://www.nirsoft.net/utils/usbdeview-x64.zip"; File="usbdeview.zip"},
        @{Url="https://www.nirsoft.net/utils/networkusageview-x64.zip"; File="networkusageview.zip"},
        @{Url="https://www.nirsoft.net/utils/alternatestreamview-x64.zip"; File="alternatestreamview.zip"},
        @{Url="https://www.nirsoft.net/utils/uninstallview-x64.zip"; File="uninstallview.zip"},
        @{Url="https://www.nirsoft.net/utils/previousfilesrecovery-x64.zip"; File="previousfilesrecovery.zip"}
    )

    # -------------------------
    # OTHER
    # -------------------------
    $other = @(
        @{Url="https://github.com/winsiderss/si-builds/releases/download/3.2.25297.1516/systeminformer-build-canary-setup.exe"; File="systeminformer.exe"},
        @{Url="https://www.voidtools.com/Everything-1.4.1.1029.x86-Setup.exe"; File="everything.exe"},
        @{Url="https://github.com/NotRequiem/InjGen/releases/download/v2.0/InjGen.exe"; File="InjGen.exe"},
        @{Url="https://github.com/Orbdiff/PrefetchView/releases/download/v1.5.4/PrefetchView++.exe"; File="PrefetchView++.exe"},
        @{Url="https://github.com/Velocidex/velociraptor/releases/download/v0.6.6-1/velociraptor-v0.6.6-3-windows-386.exe"; File="velociraptor.exe"},
        @{Url="https://github.com/Col-E/Recaf/releases/download/4.0.0-alpha/recaf-4x-alpha-win-86x64.jar"; File="recaf.jar"},
        @{Url="https://github.com/Yamato-Security/hayabusa/releases/download/v3.6.0/hayabusa-3.6.0-win-x64.zip"; File="hayabusa.zip"}
    )

    Run $spokwn $folders.Spokwn
    Run $orb $folders.OrbDiff
    Run $zimmer $folders.Zimmer
    Run $nirsoft $folders.Nirsoft
    Run $other $folders.Other

    Write-Host "`nALL DOWNLOADS COMPLETE" -ForegroundColor Green
    Read-Host "Press Enter to exit"
    exit
}

# =========================
# DELETE
# =========================
function Delete-All {
    Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Deleted C:\SS"
}

# =========================
# MENU
# =========================
while ($true) {

    Write-Host ""
    Write-Host "[1] Download all tools"
    Write-Host "[2] Delete tools"
    Write-Host "[3] Exit"

    $c = Read-Host "Select"

    switch ($c) {
        "1" { Download-All }
        "2" { Delete-All }
        "3" { exit }
    }
}
