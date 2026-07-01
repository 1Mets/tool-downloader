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

# Create folders
$folders.Values | ForEach-Object {
    New-Item -ItemType Directory -Path $_ -Force | Out-Null
}

# =========================
# DOWNLOAD JOB
# =========================
function Start-JobDownload($url, $file, $folder, $type = "normal", $jobId) {

    Start-Job -ArgumentList $url, $file, $folder, $type, $jobId -ScriptBlock {

        param($url, $file, $folder, $type, $jobId)

        try {
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "Mozilla/5.0")

            $path = Join-Path $folder $file
            $wc.DownloadFile($url, $path)
            
            if ($file -like "*.zip") {
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                
                if ($type -eq "zimmerman") {
                    $subfolderName = [System.IO.Path]::GetFileNameWithoutExtension($file)
                    $extractPath = Join-Path $folder $subfolderName
                    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($path, $extractPath)
                    Remove-Item $path -Force -ErrorAction SilentlyContinue
                }
                elseif ($type -eq "nirsoft") {
                    $zip = [System.IO.Compression.ZipFile]::OpenRead($path)
                    foreach ($entry in $zip.Entries) {
                        if ($entry.Name -like "*.exe" -or $entry.Name -like "*.EXE") {
                            $targetPath = Join-Path $folder $entry.Name
                            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $targetPath, $true)
                        }
                    }
                    $zip.Dispose()
                    Remove-Item $path -Force -ErrorAction SilentlyContinue
                }
                elseif ($type -eq "die") {
                    $extractPath = Join-Path $folder "Detect It Easy"
                    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($path, $extractPath)
                    Remove-Item $path -Force -ErrorAction SilentlyContinue
                }
                else {
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($path, $folder)
                }
            }

            return "OK|$jobId|$file"
        }
        catch {
            return "FAIL|$jobId|$file|$($_.Exception.Message)"
        }
    }
}

# =========================
# RUNNER WITH PROGRESS DISPLAY
# =========================
function Run($list, $folderName, $type = "normal", $limit = 8) {
    
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "  📁 Downloading to: $folderName" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    
    $folderPath = $folders[$folderName]
    $jobs = @()
    $total = $list.Count
    
    # Start all jobs
    $jobId = 0
    foreach ($item in $list) {
        $jobId++
        $jobs += Start-JobDownload $item.Url $item.File $folderPath $type $jobId
        Start-Sleep -Milliseconds 50  # Small delay to prevent overwhelming the system
        
        # Limit concurrent jobs
        while (($jobs | Where-Object {$_.State -eq 'Running'}).Count -ge $limit) {
            Start-Sleep -Milliseconds 200
        }
    }
    
    # Wait for all jobs to complete
    $allJobs = $jobs
    while (($allJobs | Where-Object {$_.State -eq 'Running' -or $_.State -eq 'NotStarted'}).Count -gt 0) {
        $running = ($allJobs | Where-Object {$_.State -eq 'Running'}).Count
        $completed = ($allJobs | Where-Object {$_.State -eq 'Completed'}).Count
        $failed = ($allJobs | Where-Object {$_.State -eq 'Failed'}).Count
        $percent = [math]::Round((($completed + $failed) / $total) * 100, 0)
        
        Write-Host "`r  Progress: [$($completed + $failed)/$total] $percent% | Running: $running | Failed: $failed" -ForegroundColor Green -NoNewline
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "`n"  # New line after progress
    
    # Receive results
    $success = 0
    $failures = 0
    
    foreach ($job in $allJobs) {
        $result = Receive-Job $job
        Remove-Job $job
        
        if ($result -match "OK\|") {
            $success++
            $parts = $result -split '\|'
            Write-Host "  ✓ $($parts[2])" -ForegroundColor Green
        } else {
            $failures++
            $parts = $result -split '\|'
            Write-Host "  ✗ $($parts[2])" -ForegroundColor Red
        }
    }
    
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "  ✅ Successful: $success  |  ❌ Failed: $failures" -ForegroundColor $(if ($failures -eq 0) { "Green" } else { "Yellow" })
}

# =========================
# TOOL LISTS
# =========================

function Download-All {

    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              STARTING DOWNLOAD PROCESS                 ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # ---------------- SPOKWN ----------------
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

    # ---------------- ORBDIFF ----------------
    $orb = @(
        @{Url="https://github.com/Orbdiff/PrefetchView/releases/download/v1.6.6/pv++.exe"; File="pv++.exe"},
        @{Url="https://github.com/Orbdiff/BAMReveal/releases/download/v1.3/BAMReveal.exe"; File="BAMReveal.exe"},
        @{Url="https://github.com/Orbdiff/DPS-Analyzer/releases/download/v1.1/dpsanalyzer.exe"; File="dpsanalyzer.exe"},
        @{Url="https://github.com/Orbdiff/Fileless/releases/download/v1.3/fileless.exe"; File="fileless.exe"},
        @{Url="https://github.com/Orbdiff/AmcacheParser/releases/download/v1.0/AmcacheParser.exe"; File="AmcacheParser.exe"},
        @{Url="https://github.com/Orbdiff/JARParser/releases/download/v1.2/JARParser.exe"; File="JARParser.exe"},
        @{Url="https://github.com/Orbdiff/CheckDeletedUSN/releases/download/v0.2.1/CheckDeletedUSN.exe"; File="CheckDeletedUSN.exe"},
        @{Url="https://github.com/Orbdiff/UserAssistView/releases/download/v1.0/UserAssistView.exe"; File="UserAssistView.exe"},
        @{Url="https://github.com/Orbdiff/SSTool/releases/download/yay/SSTool.exe"; File="SSTool.exe"}
    )

    # ---------------- ZIMMERMAN ----------------
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

    # ---------------- NIRSOFT ----------------
    $nirsoft = @(
        @{Url="https://www.nirsoft.net/utils/winprefetchview-x64.zip"; File="winprefetchview.zip"},
        @{Url="https://www.nirsoft.net/utils/usbdeview-x64.zip"; File="usbdeview.zip"},
        @{Url="https://www.nirsoft.net/utils/networkusageview-x64.zip"; File="networkusageview.zip"},
        @{Url="https://www.nirsoft.net/utils/alternatestreamview-x64.zip"; File="alternatestreamview.zip"},
        @{Url="https://www.nirsoft.net/utils/uninstallview-x64.zip"; File="uninstallview.zip"},
        @{Url="https://www.nirsoft.net/utils/previousfilesrecovery-x64.zip"; File="previousfilesrecovery.zip"},
        @{Url="https://www.nirsoft.net/utils/fulleventlogview-x64.zip"; File="fulleventlogview.zip"},
        @{Url="https://www.nirsoft.net/utils/taskschedulerview-x64.zip"; File="taskschedulerview.zip"},
        @{Url="https://www.nirsoft.net/utils/driverview-x64.zip"; File="driverview.zip"},
        @{Url="https://www.nirsoft.net/utils/userassistview.zip"; File="userassistview.zip"},
        @{Url="https://www.nirsoft.net/utils/regscanner-x64.zip"; File="regscanner.zip"},
        @{Url="https://www.nirsoft.net/utils/lastactivityview.zip"; File="lastactivityview.zip"}
    )

    # ---------------- OTHER ----------------
    $other = @(
        @{Url="https://github.com/winsiderss/si-builds/releases/download/3.2.25297.1516/systeminformer-build-canary-setup.exe"; File="system-informer-canary-setup.exe"},
        @{Url="https://www.voidtools.com/Everything-1.4.1.1029.x86-Setup.exe"; File="everything.exe"},
        @{Url="https://github.com/NotRequiem/InjGen/releases/download/v2.0/InjGen.exe"; File="InjGen.exe"},
        @{Url="https://d1kpmuwb7gvu1i.cloudfront.net/AccessData_FTK_Imager_4.7.1.exe"; File="FTKImager.exe"},
        @{Url="https://github.com/Orbdiff/PrefetchView/releases/download/v1.5.4/PrefetchView++.exe"; File="PrefetchView++.exe"},
        @{Url="https://github.com/Velocidex/velociraptor/releases/download/v0.6.6-1/velociraptor-v0.6.6-3-windows-386.exe"; File="velociraptor.exe"},
        @{Url="https://github.com/Col-E/Recaf/releases/download/4.0.0-alpha/recaf-4x-alpha-win-86x64.jar"; File="recaf.jar"},
        @{Url="https://github.com/Yamato-Security/hayabusa/releases/download/v3.6.0/hayabusa-3.6.0-win-x64.zip"; File="hayabusa.zip"},
        @{Url="https://github.com/horsicq/DIE-engine/releases/download/3.10/die_win64_portable_3.10_x64.zip"; File="die_win64_portable.zip"},
        @{Url="https://github.com/MeowTonynoh/MeowDoomsdayFucker/releases/download/V.1.2/MeowDoomsdayFucker.exe"; File="MeowDoomsdayFucker.exe"},
        @{Url="https://github.com/MeowTonynoh/MeowResolver/releases/download/MeowResolver/MeowResolver.exe"; File="MeowResolver.exe"},
        @{Url="https://github.com/ItzIceHere/RedLotus-Mod-Analyzer/releases/download/RL/RedLotusModAnalyzer.exe"; File="RedLotusModAnalyzer.exe"},
        @{Url="https://github.com/Col-E/Recaf/releases/download/4.0.0-alpha/recaf-launcher-gui-0.8.8.jar"; File="RecafLauncher.jar"}
    )

    # Run downloads with proper flow control
    Run $spokwn "Spokwn" "normal"
    Run $orb "OrbDiff" "normal"
    Run $zimmer "Zimmer" "zimmerman"
    Run $nirsoft "Nirsoft" "nirsoft"
    Run $other "Other" "die"

    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║          ✅ ALL DOWNLOADS COMPLETE ✅                   ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Read-Host "`nPress Enter to exit"
    exit
}

# =========================
# DELETE
# =========================
function Delete-All {
    if (Test-Path $base) {
        Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "`n🗑️  Deleted: $base" -ForegroundColor Red
    } else {
        Write-Host "`n⚠️  Folder not found: $base" -ForegroundColor Yellow
    }
}

# =========================
# MENU
# =========================
while ($true) {

    Write-Host ""
    Write-Host "╔════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     🔧 TOOL DOWNLOADER v2.0         ║" -ForegroundColor Cyan
    Write-Host "╠════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║  [1] Download all tools            ║" -ForegroundColor White
    Write-Host "║  [2] Delete tools                  ║" -ForegroundColor White
    Write-Host "║  [3] Exit                          ║" -ForegroundColor White
    Write-Host "╚════════════════════════════════════╝" -ForegroundColor Cyan

    $c = Read-Host "`nSelect"

    switch ($c) {
        "1" { Download-All }
        "2" { Delete-All }
        "3" { exit }
    }
}
