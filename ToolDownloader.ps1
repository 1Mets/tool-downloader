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
# DOWNLOAD + EXTRACT WORKER
# =========================
function Start-DownloadJob {
    param(
        [string]$Url,
        [string]$OutFile,
        [string]$DestFolder
    )

    Start-Job -ArgumentList $Url, $OutFile, $DestFolder -ScriptBlock {

        param($Url, $OutFile, $DestFolder)

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
            catch { return $null }
        }

        function Extract-Zip {
            param($filePath, $folder)

            try {
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($filePath, $folder)
            }
            catch {
                # ignore extraction errors
            }
        }

        $outPath = Join-Path $DestFolder $OutFile

        try {
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "Mozilla/5.0")

            # MediaFire handling
            if ($Url -like "*mediafire.com*") {
                $resolved = Resolve-MediaFire $Url
                if ($resolved) { $Url = $resolved }
            }

            $wc.DownloadFile($Url, $outPath)

            # Auto extract ZIP
            if ($OutFile -like "*.zip") {
                Extract-Zip $outPath $DestFolder
            }

            "OK: $OutFile"
        }
        catch {
            "FAILED: $OutFile"
        }
    }
}

# =========================
# PARALLEL RUNNER
# =========================
function Run-Downloads {
    param(
        [array]$list,
        [string]$folder,
        [int]$Throttle = 6
    )

    $jobs = @()

    foreach ($item in $list) {

        $jobs += Start-DownloadJob -Url $item.Url -OutFile $item.File -DestFolder $folder

        # throttle
        while ((Get-Job -State Running).Count -ge $Throttle) {
            Start-Sleep -Milliseconds 300
        }
    }

    # Wait for all jobs
    Wait-Job $jobs | Out-Null

    # Print results
    foreach ($job in $jobs) {
        Receive-Job $job
        Remove-Job $job
    }
}

# =========================
# TOOL SETS
# =========================
function Download-All {

    $spokwnTools = @(
        @{Url="https://github.com/spokwn/KernelLiveDumpTool/releases/download/v1.1/KernelLiveDumpTool.exe"; File="KernelLiveDumpTool.exe"},
        @{Url="https://github.com/spokwn/BAM-parser/releases/download/v1.2.9/BAMParser.exe"; File="BAMParser.exe"}
    )

    $orbTools = @(
        @{Url="https://github.com/Orbdiff/PrefetchView/releases/download/v1.6.6/pv++.exe"; File="pv++.exe"},
        @{Url="https://github.com/Orbdiff/Fileless/releases/download/v1.3/fileless.exe"; File="fileless.exe"}
    )

    $zimmermanTools = @(
        @{Url="https://download.ericzimmermanstools.com/net9/AmcacheParser.zip"; File="AmcacheParser.zip"},
        @{Url="https://download.ericzimmermanstools.com/net9/PECmd.zip"; File="PECmd.zip"}
    )

    $nirsoftTools = @(
        @{Url="https://www.nirsoft.net/utils/winprefetchview-x64.zip"; File="winprefetchview.zip"},
        @{Url="https://www.nirsoft.net/utils/usbdeview-x64.zip"; File="usbdeview.zip"}
    )

    $otherTools = @(
        @{Url="https://www.voidtools.com/Everything-1.4.1.1029.x86-Setup.exe"; File="everything.exe"},
        @{Url="https://github.com/Yamato-Security/hayabusa/releases/download/v3.6.0/hayabusa.zip"; File="hayabusa.zip"}
    )

    Run-Downloads $spokwnTools $folders.Spokwn
    Run-Downloads $orbTools $folders.OrbDiff
    Run-Downloads $zimmermanTools $folders.Zimmer
    Run-Downloads $nirsoftTools $folders.Nirsoft
    Run-Downloads $otherTools $folders.Other
}

# =========================
# DELETE
# =========================
function Delete-All {
    if (Test-Path $base) {
        Remove-Item $base -Recurse -Force
        Write-Host "Deleted C:\SS" -ForegroundColor Yellow
    }
}

# =========================
# MENU
# =========================
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
        "3" { break }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
}
