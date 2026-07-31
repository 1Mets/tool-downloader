cls
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   ScreenShare Start — Made by vMets" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$CurrentDate = Get-Date

Write-Host "SYSTEM:" -ForegroundColor DarkBlue
$LastBootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
Write-Host "  Last Boot Time: " -NoNewline -ForegroundColor White
Write-Host $LastBootTime.ToString("MM/dd/yyyy hh:mm:ss tt") -ForegroundColor White

$Uptime = (Get-Date) - $LastBootTime
$UptimeParts = @()
if ($Uptime.Days -gt 0) { $UptimeParts += "$($Uptime.Days) days" }
if ($Uptime.Hours -gt 0) { $UptimeParts += "$($Uptime.Hours) hours" }
if ($Uptime.Minutes -gt 0) { $UptimeParts += "$($Uptime.Minutes) minutes" }
if ($UptimeParts.Count -eq 0) { $UptimeParts = "Less than a minute" }
Write-Host "  System Uptime: " -NoNewline -ForegroundColor White
Write-Host ($UptimeParts -join ', ') -ForegroundColor White

$ExecutionTime = Get-Date
Write-Host "  Script Execution Time: " -NoNewline -ForegroundColor White
Write-Host $ExecutionTime.ToString("h:mm:ss tt") -ForegroundColor White
Write-Host ""

Write-Host "DRIVES:" -ForegroundColor DarkBlue
$Drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
foreach ($Drive in $Drives) {
    $DriveLetter = $Drive.DeviceID
    $FileSystem = $Drive.FileSystem
    $SizeGB = [math]::Round($Drive.Size / 1GB, 2)
    $FreeGB = [math]::Round($Drive.FreeSpace / 1GB, 2)
    $UsedGB = $SizeGB - $FreeGB
    
    if ($FileSystem -eq "NTFS") {
        Write-Host "  $DriveLetter ($FileSystem) - $UsedGB GB / $SizeGB GB" -ForegroundColor Green
    } elseif ($FileSystem -eq "FAT32") {
        Write-Host "  $DriveLetter ($FileSystem) - $UsedGB GB / $SizeGB GB" -ForegroundColor Red
    } else {
        Write-Host "  $DriveLetter ($FileSystem) - $UsedGB GB / $SizeGB GB" -ForegroundColor White
    }
}
Write-Host ""

Write-Host "MINECRAFT:" -ForegroundColor DarkBlue

$verdictFlags = @()
$mcProc = $null

try {
    $mcProc = Get-Process javaw -ErrorAction SilentlyContinue
    if (-not $mcProc) { $mcProc = Get-Process java -ErrorAction SilentlyContinue }
    
    if ($mcProc) {
        $mcUptime = (Get-Date) - $mcProc.StartTime
        Write-Host "  Minecraft Start: " -NoNewline -ForegroundColor White
        Write-Host $mcProc.StartTime.ToString("yyyy-MM-dd h:mm:ss tt") -ForegroundColor White
        
        $mcUptimeParts = @()
        if ($mcUptime.Days -gt 0) { $mcUptimeParts += "$($mcUptime.Days) Days" }
        if ($mcUptime.Hours -gt 0) { $mcUptimeParts += "$($mcUptime.Hours) Hours" }
        if ($mcUptime.Minutes -gt 0) { $mcUptimeParts += "$($mcUptime.Minutes) Minutes" }
        if ($mcUptimeParts.Count -eq 0) { $mcUptimeParts = "Less than a minute" }
        
        Write-Host "  MC Uptime: " -NoNewline -ForegroundColor White
        Write-Host ($mcUptimeParts -join ', ') -ForegroundColor White
        
        $parentProc = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($mcProc.Id)" | ForEach-Object { 
            if ($_.ParentProcessId) { Get-Process -Id $_.ParentProcessId -ErrorAction SilentlyContinue }
        }

        if ($parentProc) {
            Write-Host "  Parent Process: " -NoNewline -ForegroundColor White
            Write-Host ("{0} (PID: {1})" -f $parentProc.ProcessName, $parentProc.Id) -ForegroundColor Green
            Write-Host "  Parent Started: " -NoNewline -ForegroundColor White
            Write-Host $parentProc.StartTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor White
            
            $suspiciousParents = @("cmd", "powershell", "wscript", "cscript", "rundll32", "mshta")
            if ($suspiciousParents -contains $parentProc.ProcessName.ToLower()) {
                Write-Host "  ! WARNING: Minecraft launched from suspicious parent process!" -ForegroundColor Red
                $verdictFlags += "Minecraft launched from suspicious parent process ($($parentProc.ProcessName))"
            }
        } else {
            Write-Host "  Parent Process: Unknown" -ForegroundColor White
        }

        $childProcs = Get-CimInstance -ClassName Win32_Process | Where-Object { $_.ParentProcessId -eq $mcProc.Id }
        if ($childProcs) {
            Write-Host "  Child Processes: " -NoNewline -ForegroundColor White
            Write-Host ("{0} found" -f $childProcs.Count) -ForegroundColor Green
            foreach ($child in $childProcs) {
                try {
                    $childProc = Get-Process -Id $child.ProcessId -ErrorAction SilentlyContinue
                    if ($childProc) {
                        Write-Host "    * " -NoNewline -ForegroundColor White
                        Write-Host ("{0} (PID: {1}) - Started: {2}" -f $childProc.ProcessName, $childProc.Id, $childProc.StartTime.ToString("HH:mm:ss")) -ForegroundColor White
                        
                        $suspiciousChildren = @("cmd", "powershell", "wscript", "cscript", "rundll32", "mshta", "regsvr32")
                        if ($suspiciousChildren -contains $childProc.ProcessName.ToLower()) {
                            Write-Host "      ! WARNING: Suspicious child process detected!" -ForegroundColor Red
                            $verdictFlags += "Suspicious child process spawned by Minecraft ($($childProc.ProcessName))"
                        }
                    }
                } catch { }
            }
        } else {
            Write-Host "  Child Processes: None" -ForegroundColor Green
        }

        $processChain = @()
        $currentProc = $mcProc
        
        for ($i = 0; $i -lt 5; $i++) {
            $parent = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($currentProc.Id)" | ForEach-Object { 
                if ($_.ParentProcessId) { Get-Process -Id $_.ParentProcessId -ErrorAction SilentlyContinue }
            }
            if ($parent) {
                $processChain = @($parent) + $processChain
                $currentProc = $parent
            } else {
                break
            }
        }

        if ($processChain.Count -gt 0) {
            Write-Host "  Process Chain (Parent -> Child): " -NoNewline -ForegroundColor White
            $chainStr = ($processChain | ForEach-Object { $_.ProcessName }) -join " -> "
            $chainStr += " -> $($mcProc.ProcessName)"
            Write-Host $chainStr -ForegroundColor Green
            
            $chainStrLower = $chainStr.ToLower()
            if ($chainStrLower -match "cmd.*powershell.*java" -or $chainStrLower -match "wscript.*java") {
                Write-Host "    ! WARNING: Potential injection chain detected!" -ForegroundColor Red
                $verdictFlags += "Suspicious process injection chain detected"
            }
        }
        
        if ($verdictFlags.Count -gt 0) {
            Write-Host "`n  VERDICT:" -ForegroundColor Yellow
            foreach ($flag in $verdictFlags) {
                Write-Host "    ! $flag" -ForegroundColor Red
            }
        } else {
            Write-Host "`n  VERDICT: Clean - No suspicious patterns detected" -ForegroundColor Green
        }
        
    } else {
        Write-Host "  Minecraft: Not running" -ForegroundColor White
    }
} catch {
    Write-Host "  Unable to retrieve Minecraft process info" -ForegroundColor White
}
Write-Host ""

Write-Host "SERVICES:" -ForegroundColor DarkBlue

$Services = @(
    @{ Name = "SysMain"; Display = "SysMain" },
    @{ Name = "PcaSvc"; Display = "Program Compatibility Assistant Service" },
    @{ Name = "DPS"; Display = "Diagnostic Policy Service" },
    @{ Name = "EventLog"; Display = "Windows Event Log" },
    @{ Name = "Schedule"; Display = "Task Scheduler" },
    @{ Name = "Bam"; Display = "Background Activity Moderator Driver" },
    @{ Name = "Dusmsvc"; Display = "Data Usage" },
    @{ Name = "Appinfo"; Display = "Application Information" },
    @{ Name = "DcomLaunch"; Display = "DCOM Server Process Launcher" },
    @{ Name = "PlugPlay"; Display = "Plug and Play" }
)

$MaxNameLength = ($Services | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum + 2
$MaxDisplayLength = 40

foreach ($Service in $Services) {
    $ServiceName = $Service.Name
    $DisplayName = $Service.Display
    try {
        $Svc = Get-Service -Name $ServiceName -ErrorAction Stop

        $PaddedName = $ServiceName.PadRight($MaxNameLength)

        if ($DisplayName.Length -gt $MaxDisplayLength) {
            $DisplayName = $DisplayName.Substring(0, $MaxDisplayLength - 3) + "..."
        }
        $PaddedDisplay = $DisplayName.PadRight($MaxDisplayLength)
        
        if ($Svc.Status -eq 'Running') {

            $StartTime = $null
            $ServiceWMI = Get-WmiObject -Class Win32_Service | Where-Object { $_.Name -eq $ServiceName }
            if ($ServiceWMI -and $ServiceWMI.ProcessId -gt 0) {
                $Process = Get-Process -Id $ServiceWMI.ProcessId -ErrorAction SilentlyContinue
                if ($Process) {
                    $StartTime = $Process.StartTime
                }
            }
            
            if ($StartTime) {
                $FormattedTime = $StartTime.ToString("hh:mm:ss tt")
                Write-Host "  $PaddedName$PaddedDisplay | $FormattedTime" -ForegroundColor Green
            } else {
                Write-Host "  $PaddedName$PaddedDisplay | Running" -ForegroundColor Green
            }
        } else {
            Write-Host "  $PaddedName$PaddedDisplay | Stopped" -ForegroundColor White
        }
    } catch {
        $PaddedName = $ServiceName.PadRight($MaxNameLength)
        $PaddedDisplay = $DisplayName.PadRight($MaxDisplayLength)
        Write-Host "  $PaddedName$PaddedDisplay | Not Found" -ForegroundColor White
    }
}
Write-Host ""

Write-Host "RECYCLE BIN:" -ForegroundColor DarkBlue

try {
    $recycleBinPath = "$env:SystemDrive" + '\$Recycle.Bin'
    
    if (Test-Path $recycleBinPath) {
        $recycleBinFolder = Get-Item -LiteralPath $recycleBinPath -Force
        $userFolders = Get-ChildItem -LiteralPath $recycleBinPath -Directory -Force -ErrorAction SilentlyContinue
        
        if ($userFolders) {
            $allDeletedItems = @()
            $latestModTime = $recycleBinFolder.LastWriteTime
            
            foreach ($userFolder in $userFolders) {
                if ($userFolder.LastWriteTime -gt $latestModTime) {
                    $latestModTime = $userFolder.LastWriteTime
                }
                
                $userItems = Get-ChildItem -LiteralPath $userFolder.FullName -File -Force -ErrorAction SilentlyContinue
                if ($userItems) {
                    $allDeletedItems += $userItems
                    
                    $latestFile = $userItems | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    if ($latestFile -and $latestFile.LastWriteTime -gt $latestModTime) {
                        $latestModTime = $latestFile.LastWriteTime
                    }
                }
            }

            $TimeSinceMod = $latestModTime - $LastBootTime
            $IsBootInstance = $TimeSinceMod.TotalSeconds -gt 0 -and $TimeSinceMod.TotalSeconds -lt $Uptime.TotalSeconds
            
            Write-Host "  Last Modified: " -NoNewline -ForegroundColor White
            if ($IsBootInstance) {
                Write-Host ($latestModTime.ToString("yyyy-MM-dd hh:mm:ss tt") + " (CURRENT BOOT INSTANCE)") -ForegroundColor Red
            } else {
                Write-Host $latestModTime.ToString("yyyy-MM-dd hh:mm:ss tt") -ForegroundColor White
            }
            
            if ($allDeletedItems.Count -gt 0) {
                Write-Host "  Total Items: " -NoNewline -ForegroundColor White
                Write-Host $allDeletedItems.Count -ForegroundColor White
                
                $latestItem = $allDeletedItems | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                Write-Host "  Latest Item: " -NoNewline -ForegroundColor White
                Write-Host $latestItem.Name -ForegroundColor White
            } else {
                Write-Host "  Status: " -NoNewline -ForegroundColor White
                Write-Host "Folders present but empty" -ForegroundColor White
            }
        } else {
            Write-Host "  Status: " -NoNewline -ForegroundColor White
            Write-Host "Empty" -ForegroundColor White
            Write-Host "  Last Modified: " -NoNewline -ForegroundColor White
            Write-Host $recycleBinFolder.LastWriteTime.ToString("yyyy-MM-dd hh:mm:ss tt") -ForegroundColor White
        }
        
        $clearEvent = Get-WinEvent -FilterHashtable @{LogName="System"; Id=10006} -MaxEvents 1 -ErrorAction SilentlyContinue
        if ($clearEvent) {
            Write-Host "  Last Cleared (Event): " -NoNewline -ForegroundColor White
            Write-Host $clearEvent.TimeCreated.ToString("yyyy-MM-dd hh:mm:ss tt") -ForegroundColor White
        }
    } else {
        Write-Host "  Recycle Bin not found at: $recycleBinPath" -ForegroundColor White
        Write-Host "  Note: Recycle Bin may be empty or on different drive" -ForegroundColor White
    }
} catch {
    Write-Host "  Recycle Bin: Unable to access" -ForegroundColor White
}
Write-Host ""

Write-Host "USN JOURNAL:" -ForegroundColor DarkBlue

try {
    $UsnEvent = Get-WinEvent -LogName "Application" -FilterXPath "*[System[EventID=3079]]" -MaxEvents 1 -ErrorAction SilentlyContinue
    if ($UsnEvent) {
        $EventTime = $UsnEvent.TimeCreated
        $FormattedTime = $EventTime.ToString("M/d/yyyy hh:mm:ss tt")

        $TimeSinceEvent = $EventTime - $LastBootTime
        $IsBootInstance = $TimeSinceEvent.TotalSeconds -gt 0 -and $TimeSinceEvent.TotalSeconds -lt $Uptime.TotalSeconds
        
        Write-Host "  Last Cleared: " -NoNewline -ForegroundColor White
        if ($IsBootInstance) {
            Write-Host ($FormattedTime + " (CURRENT BOOT INSTANCE)") -ForegroundColor Red
        } else {
            Write-Host $FormattedTime -ForegroundColor Red
        }
    } else {
        Write-Host "  Status: NOT CLEARED" -ForegroundColor Green
    }
} catch {
    Write-Host "  USN Journal cleared check: Unable to query Event Log" -ForegroundColor White
}
Write-Host ""

Write-Host "EVENT LOGS:" -ForegroundColor DarkBlue

function Check-EventLog {
    param($LogName, $EventID, $Message)
    
    try {
        $event = Get-WinEvent -LogName $LogName -FilterXPath "*[System[EventID=$EventID]]" -MaxEvents 1 -ErrorAction SilentlyContinue
        
        if ($event) {
            $EventTime = $event.TimeCreated
            $FormattedTime = $EventTime.ToString("MM/dd hh:mm:ss tt")
            Write-Host ("  ${Message}: $FormattedTime") -ForegroundColor White
        }
    } catch {

        try {
            $event = Get-WinEvent -LogName $LogName | Where-Object { $_.Id -eq $EventID } | Select-Object -First 1
            if ($event) {
                $EventTime = $event.TimeCreated
                $FormattedTime = $EventTime.ToString("MM/dd hh:mm:ss tt")
                Write-Host ("  ${Message}: $FormattedTime") -ForegroundColor White
            }
        } catch {

        }
    }
}

Check-EventLog "System" 104 "Event Logs cleared"
Check-EventLog "System" 1102 "Event Logs cleared"
Check-EventLog "System" 1074 "Last PC Shutdown"
Check-EventLog "Security" 4616 "System time changed"
Check-EventLog "System" 6005 "Event Log Service started"
Write-Host ""

Write-Host "VOLUME DISMOUNT:" -ForegroundColor DarkBlue

$foundDismount = $false
try {
    $DismountEvent = Get-WinEvent -LogName "Microsoft-Windows-Ntfs/Operational" -FilterXPath "*[System[EventID=303]]" -MaxEvents 1 -ErrorAction SilentlyContinue
    
    if ($DismountEvent) {
        $EventTime = $DismountEvent.TimeCreated
        $FormattedTime = $EventTime.ToString("MM/dd hh:mm:ss tt")
        Write-Host ("  Last Dismount: $FormattedTime") -ForegroundColor White
        $foundDismount = $true
    }
} catch {
    try {

        $DismountEvent = Get-WinEvent -LogName "Microsoft-Windows-Ntfs/Operational" -ErrorAction SilentlyContinue | Where-Object { $_.Id -eq 303 } | Select-Object -First 1
        if ($DismountEvent) {
            $EventTime = $DismountEvent.TimeCreated
            $FormattedTime = $EventTime.ToString("MM/dd hh:mm:ss tt")
            Write-Host ("  Last Dismount: $FormattedTime") -ForegroundColor White
            $foundDismount = $true
        }
    } catch {

    }
}

if (-not $foundDismount) {
    Write-Host "  No Volume Dismounts Found" -ForegroundColor Green
}
Write-Host ""

Write-Host "TASK SCHEDULER:" -ForegroundColor DarkBlue

function Check-TaskSchedulerEvent {
    param($EventID, $Description)
    
    try {
        $event = Get-WinEvent -LogName "Microsoft-Windows-TaskScheduler/Operational" -FilterXPath "*[System[EventID=$EventID]]" -MaxEvents 1 -ErrorAction SilentlyContinue
        
        if ($event) {
            $EventTime = $event.TimeCreated
            $FormattedTime = $EventTime.ToString("MM/dd hh:mm:ss tt")
            Write-Host ("  ${Description}: $FormattedTime") -ForegroundColor White
        }
    } catch {
        try {

            $event = Get-WinEvent -LogName "Microsoft-Windows-TaskScheduler/Operational" -ErrorAction SilentlyContinue | Where-Object { $_.Id -eq $EventID } | Select-Object -First 1
            if ($event) {
                $EventTime = $event.TimeCreated
                $FormattedTime = $EventTime.ToString("MM/dd hh:mm:ss tt")
                Write-Host ("  ${Description}: $FormattedTime") -ForegroundColor White
            }
        } catch {

        }
    }
}

Check-TaskSchedulerEvent 141 "Deleted Scheduled Tasks"
Check-TaskSchedulerEvent 140 "Modified Scheduled Tasks"
Check-TaskSchedulerEvent 106 "Created Scheduled Tasks"
Write-Host ""

Write-Host "IMAGE FILE EXECUTION OPTIONS:" -ForegroundColor DarkBlue

$IFEOpath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
$debuggerFound = $false
$foundKeys = @()

try {
    $subKeys = Get-ChildItem -Path $IFEOpath -ErrorAction SilentlyContinue
    
    foreach ($key in $subKeys) {
        try {
            $debuggerValue = Get-ItemProperty -Path $key.PSPath -Name "Debugger" -ErrorAction SilentlyContinue
            if ($debuggerValue) {
                $debuggerFound = $true
                $foundKeys += @{
                    Key = $key.PSChildName
                    Debugger = $debuggerValue.Debugger
                }
            }
        } catch {

        }
    }
    
    if ($debuggerFound) {
        Write-Host "  DEBUGGER VALUES FOUND:" -ForegroundColor Red
        foreach ($entry in $foundKeys) {
            Write-Host "    $($entry.Key) -> $($entry.Debugger)" -ForegroundColor Red
        }
    } else {
        Write-Host "  Status: CLEAN - No Debugger Values Found" -ForegroundColor Green
    }
} catch {
    Write-Host "  Unable to query Image File Execution Options" -ForegroundColor White
}
Write-Host ""

Write-Host "PREFETCH INTEGRITY:" -ForegroundColor DarkBlue

$prefetchPath = "$env:SystemRoot\Prefetch"
$hasIssues = $false

if (Test-Path $prefetchPath) {
    $files = Get-ChildItem -Path $prefetchPath -Filter *.pf -Force -ErrorAction SilentlyContinue
    if (-not $files) {
        Write-Host "  No prefetch files found. Please check the folder." -ForegroundColor White
    } else {
        $hashTable = @{}
        $suspiciousFiles = @{}
        $totalFiles = $files.Count

        $hiddenFiles = @()
        $readOnlyFiles = @()
        $hiddenAndReadOnlyFiles = @()
        $errorFiles = @()

        foreach ($file in $files) {
            try {
                $isHidden = $file.Attributes -band [System.IO.FileAttributes]::Hidden
                $isReadOnly = $file.Attributes -band [System.IO.FileAttributes]::ReadOnly

                if ($isHidden -and $isReadOnly) {
                    $hiddenAndReadOnlyFiles += $file
                    if (-not $suspiciousFiles.ContainsKey($file.Name)) {
                        $suspiciousFiles[$file.Name] = "Hidden and Read-only"
                    }
                    $hasIssues = $true
                } elseif ($isHidden) {
                    $hiddenFiles += $file
                    if (-not $suspiciousFiles.ContainsKey($file.Name)) {
                        $suspiciousFiles[$file.Name] = "Hidden file"
                    }
                    $hasIssues = $true
                } elseif ($isReadOnly) {
                    $readOnlyFiles += $file
                    if (-not $suspiciousFiles.ContainsKey($file.Name)) {
                        $suspiciousFiles[$file.Name] = "Read-only file"
                    }
                    $hasIssues = $true
                }

                $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue
                if ($hash) {
                    if ($hashTable.ContainsKey($hash.Hash)) {
                        $hashTable[$hash.Hash].Add($file.Name)
                    } else {
                        $hashTable[$hash.Hash] = [System.Collections.Generic.List[string]]::new()
                        $hashTable[$hash.Hash].Add($file.Name)
                    }
                }
            } catch {
                $errorFiles += $file
                if (-not $suspiciousFiles.ContainsKey($file.Name)) {
                    $suspiciousFiles[$file.Name] = "Error analyzing file: $($_.Exception.Message)"
                }
                $hasIssues = $true
            }
        }

        $repeatedHashes = $hashTable.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }
        if ($repeatedHashes) {
            $hasIssues = $true
        }

        if ($hasIssues) {
            if ($hiddenAndReadOnlyFiles.Count -gt 0) {
                Write-Host "  Hidden & Read-only Files: $($hiddenAndReadOnlyFiles.Count) found" -ForegroundColor White
                foreach ($file in $hiddenAndReadOnlyFiles) {
                    Write-Host ("    {0}" -f $file.Name) -ForegroundColor White
                }
            }

            if ($hiddenFiles.Count -gt 0) {
                Write-Host "  Hidden Files: $($hiddenFiles.Count) found" -ForegroundColor White
                foreach ($file in $hiddenFiles) {
                    Write-Host ("    {0}" -f $file.Name) -ForegroundColor White
                }
            }

            if ($readOnlyFiles.Count -gt 0) {
                Write-Host "  Read-Only Files: $($readOnlyFiles.Count)" -ForegroundColor White
                foreach ($file in $readOnlyFiles) {
                    Write-Host ("    {0}" -f $file.Name) -ForegroundColor White
                }
            }

            if ($repeatedHashes) {
                Write-Host "  Duplicate Files: $($repeatedHashes.Count) sets found" -ForegroundColor White
                foreach ($entry in $repeatedHashes) {
                    foreach ($file in $entry.Value) {
                        if (-not $suspiciousFiles.ContainsKey($file)) {
                            $suspiciousFiles[$file] = "Duplicate file"
                        }
                    }
                    Write-Host ("    Duplicate set: {0}" -f ($entry.Value -join ", ")) -ForegroundColor White
                }
            }

            Write-Host "`n  SUSPICIOUS FILES FOUND: $($suspiciousFiles.Count)/$totalFiles" -ForegroundColor White
            foreach ($entry in $suspiciousFiles.GetEnumerator() | Sort-Object Key) {
                Write-Host ("    {0} : {1}" -f $entry.Key, $entry.Value) -ForegroundColor White
            }
        } else {
            Write-Host "  Hidden Files: None" -ForegroundColor Green
            Write-Host "  Read-Only Files: None" -ForegroundColor Green
            Write-Host "  Duplicates: None" -ForegroundColor Green
            Write-Host "`n  Status: CLEAN ($totalFiles files checked)" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  Prefetch folder not found" -ForegroundColor White
}
Write-Host ""

Write-Host "CONSOLE HOST HISTORY:" -ForegroundColor DarkBlue

try {
    $consoleHistoryPath = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt"
    
    if (Test-Path $consoleHistoryPath) {
        $historyFile = Get-Item -Path $consoleHistoryPath -Force
        
# Resetting environment state to default behavior
        $TimeSinceMod = $historyFile.LastWriteTime - $LastBootTime
        $IsBootInstance = $TimeSinceMod.TotalSeconds -gt 0 -and $TimeSinceMod.TotalSeconds -lt $Uptime.TotalSeconds
        
        Write-Host "  Last Modified: " -NoNewline -ForegroundColor White
        if ($IsBootInstance) {
            Write-Host ($historyFile.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") + " (CURRENT BOOT INSTANCE)") -ForegroundColor Red
        } else {
            Write-Host $historyFile.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor White
        }
        
        $attributes = $historyFile.Attributes
        if ($attributes -ne "Archive") {
            Write-Host "  Attributes: " -NoNewline -ForegroundColor White
            Write-Host $attributes -ForegroundColor White
        } else {
            Write-Host "  Attributes: Normal" -ForegroundColor White
        }
        $fileSize = $historyFile.Length
        Write-Host "  File Size: " -NoNewline -ForegroundColor White
        Write-Host "$([math]::Round($fileSize/1024, 2)) KB" -ForegroundColor White
    } else {
        Write-Host "  File not found: $consoleHistoryPath" -ForegroundColor Yellow
        Write-Host "  Note: PowerShell history may be disabled or never used" -ForegroundColor White
    }
} catch {
    Write-Host "  Error accessing system information: $($_.Exception.Message)" -ForegroundColor White
}
Write-Host ""

Write-Host "WINDOWS DEFENDER:" -ForegroundColor DarkBlue

try {
    $defenderKey  = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection"
    $defenderPol  = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"

    $rtpValue     = (Get-ItemProperty -Path $defenderKey  -Name "DisableRealtimeMonitoring" -ErrorAction SilentlyContinue).DisableRealtimeMonitoring
    $polValue     = (Get-ItemProperty -Path $defenderPol  -Name "DisableRealtimeMonitoring" -ErrorAction SilentlyContinue).DisableRealtimeMonitoring
    $tamperValue  = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name "TamperProtection" -ErrorAction SilentlyContinue).TamperProtection

    $rtpDisabled  = ($rtpValue -eq 1) -or ($polValue -eq 1)

    Write-Host "  Real-Time Protection: " -NoNewline -ForegroundColor White
    if ($rtpDisabled) {
        Write-Host "DISABLED" -ForegroundColor Red
    } else {
        Write-Host "Enabled" -ForegroundColor Green
    }

    Write-Host "  Tamper Protection: " -NoNewline -ForegroundColor White
    if ($tamperValue -eq 5) {
        Write-Host "Enabled" -ForegroundColor Green
    } elseif ($null -eq $tamperValue) {
        Write-Host "Unknown" -ForegroundColor White
    } else {
        Write-Host "DISABLED" -ForegroundColor Red
    }

    if ($polValue -eq 1) {
        Write-Host "  Note: Disabled via Group Policy" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Error reading Defender status: $($_.Exception.Message)" -ForegroundColor White
}
Write-Host ""

Write-Host "SECURITY SETTINGS:" -ForegroundColor DarkBlue

$settings = @(
    @{ Name = "CMD"; Path = "HKCU:\Software\Policies\Microsoft\Windows\System"; Key = "DisableCMD" },
    @{ Name = "PowerShell Logging"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"; Key = "EnableScriptBlockLogging" },
    @{ Name = "Activities Cache"; Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Key = "EnableActivityFeed" },
    @{ Name = "Prefetch Enabled"; Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"; Key = "EnablePrefetcher" }
)

foreach ($Setting in $settings) {
    $Name = $Setting.Name
    $Path = $Setting.Path
    $Key = $Setting.Key
    
    try {
        $Value = Get-ItemProperty -Path $Path -Name $Key -ErrorAction Stop
        $CurrentValue = $Value.$Key
        
        if ($Name -eq "CMD") {
            if ($CurrentValue -eq 0) {
                Write-Host "  $Name -> Enabled" -ForegroundColor Green
            } elseif ($CurrentValue -eq 1) {
                Write-Host "  $Name -> Disabled" -ForegroundColor Red
            } else {
                Write-Host "  $Name -> Enabled" -ForegroundColor Green
            }
        } elseif ($Name -eq "PowerShell Logging") {
            if ($CurrentValue -eq 1) {
                Write-Host "  $Name -> Enabled" -ForegroundColor Green
            } else {
                Write-Host "  $Name -> Disabled" -ForegroundColor Red
            }
        } elseif ($Name -eq "Activities Cache") {
            if ($CurrentValue -eq 0) {
                Write-Host "  $Name -> Disabled" -ForegroundColor Green
            } elseif ($CurrentValue -eq 1) {
                Write-Host "  $Name -> Enabled" -ForegroundColor Green
            } else {
                Write-Host "  $Name -> Enabled" -ForegroundColor Green
            }
        } elseif ($Name -eq "Prefetch Enabled") {
            if ($CurrentValue -eq 0) {
                Write-Host "  $Name -> Disabled" -ForegroundColor Red
            } elseif ($CurrentValue -eq 1 -or $CurrentValue -eq 2 -or $CurrentValue -eq 3) {
                Write-Host "  $Name -> Enabled" -ForegroundColor Green
            } else {
                Write-Host "  $Name -> Enabled" -ForegroundColor Green
            }
        }
    } catch {

        if ($Name -eq "CMD") {
            Write-Host "  $Name -> Enabled" -ForegroundColor Green
        } elseif ($Name -eq "PowerShell Logging") {
            Write-Host "  $Name -> Disabled" -ForegroundColor Red
        } elseif ($Name -eq "Activities Cache") {
            Write-Host "  $Name -> Enabled" -ForegroundColor Green
        } elseif ($Name -eq "Prefetch Enabled") {
            Write-Host "  $Name -> Enabled" -ForegroundColor Green
        }
    }
}
Write-Host ""

Write-Host "BAM SERVICE:" -ForegroundColor DarkBlue

try {
    $bamServicePath = "HKLM:\SYSTEM\CurrentControlSet\Services\bam"
    if (Test-Path $bamServicePath) {
        $bamStart = (Get-ItemProperty -Path $bamServicePath -Name "Start" -ErrorAction SilentlyContinue).Start
        if ($null -ne $bamStart) {
            $startDesc = switch ($bamStart) {
                0 { "Boot" }
                1 { "System" }
                2 { "Automatic" }
                3 { "Manual" }
                4 { "Disabled" }
                default { "Unknown ($bamStart)" }
            }
            Write-Host "  BAM Service Start Type: " -NoNewline -ForegroundColor White
            Write-Host "$bamStart ($startDesc)" -ForegroundColor Green
        } else {
            Write-Host "  BAM Service Start value not found" -ForegroundColor White
        }
    } else {
        Write-Host "  BAM Service registry key not found" -ForegroundColor White
    }
} catch {
    Write-Host "  Error reading BAM Service: $($_.Exception.Message)" -ForegroundColor White
}
Write-Host ""

Write-Host "BAM - EXECUTABLES LINKED TO MINECRAFT SESSION:" -ForegroundColor DarkBlue

try {
    $mcProc2 = Get-Process javaw -ErrorAction SilentlyContinue
    if (-not $mcProc2) { $mcProc2 = Get-Process java -ErrorAction SilentlyContinue }

    if (-not $mcProc2) {
        Write-Host "  Minecraft is not running - cannot correlate BAM entries" -ForegroundColor White
    } else {
        $mcStart = $mcProc2.StartTime

        $bamRoot = "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings"
        if (-not (Test-Path $bamRoot)) {
            $bamRoot = "HKLM:\SYSTEM\CurrentControlSet\Services\bam\UserSettings"
        }

        if (-not (Test-Path $bamRoot)) {
            Write-Host "  BAM registry key not found - service may be disabled" -ForegroundColor White
        } else {
            $sidKeys   = Get-ChildItem -Path $bamRoot -ErrorAction SilentlyContinue
            $bamHits   = [System.Collections.Generic.List[object]]::new()

            foreach ($sidKey in $sidKeys) {
                $entries = Get-ItemProperty -Path $sidKey.PSPath -ErrorAction SilentlyContinue
                if (-not $entries) { continue }

                foreach ($prop in $entries.PSObject.Properties) {

                    if ($prop.Name -match '^PS|SequenceNumber|Version') { continue }
                    if ($prop.Value -isnot [byte[]]) { continue }
                    if ($prop.Value.Length -lt 8) { continue }

                    try {
                        $ft        = [BitConverter]::ToInt64($prop.Value, 0)
                        if ($ft -le 0) { continue }
                        $lastRun   = [datetime]::FromFileTime($ft)

                        if ($lastRun -lt $mcStart) { continue }

                        $exePath   = $prop.Name -replace '\\Device\\HarddiskVolume\d+', '' -replace '\\', '\'
                        $exeName   = Split-Path $exePath -Leaf

                        if ($prop.Name -notmatch '^\\Device\\HarddiskVolume') {
                            continue
                        }

                        $bamHits.Add([PSCustomObject]@{
                            Name     = $exeName
                            FullPath = $exePath
                            LastRun  = $lastRun
                        })
                    } catch { continue }
                }
            }

            if ($bamHits.Count -eq 0) {
                Write-Host "  No BAM entries found during current Minecraft session" -ForegroundColor Green
            } else {

                $filtered = $bamHits | Where-Object { $_.Name -notmatch '^javaw?\.exe$' } | Sort-Object LastRun -Descending
                if ($filtered.Count -eq 0) {
                    Write-Host "  No other executables ran during current Minecraft session" -ForegroundColor Green
                } else {
                    Write-Host "  Executables run since Minecraft launched ($($filtered.Count) found):" -ForegroundColor White
                    foreach ($entry in $filtered) {
                        $timeDiff = ($entry.LastRun - $mcStart).TotalSeconds
                        $tag      = if ($timeDiff -le 120) { " [within 2min of launch]" } else { "" }
                        $color    = if ($tag) { "Red" } else { "White" }

                        $sigStatus = ""
                        $sigColor = "White"
                        try {
                            if (Test-Path $entry.FullPath) {
                                $sig = Get-AuthenticodeSignature -FilePath $entry.FullPath -ErrorAction SilentlyContinue
                                if ($sig) {
                                    if ($sig.Status -eq "Valid") {
                                        $sigStatus = " [Signed]"
                                        $sigColor = "Green"
                                    } else {
                                        $sigStatus = " [UNSIGNED]"
                                        $sigColor = "Red"
                                    }
                                } else {
                                    $sigStatus = " [UNSIGNED]"
                                    $sigColor = "Red"
                                }
                            } else {
                                $sigStatus = " [File not found]"
                                $sigColor = "Yellow"
                            }
                        } catch {
                            $sigStatus = " [Unable to verify]"
                            $sigColor = "Yellow"
                        }
                        
                        Write-Host "    * " -NoNewline -ForegroundColor DarkBlue
                        Write-Host ("{0,-35}" -f $entry.Name) -NoNewline -ForegroundColor $color
                        Write-Host (" {0}{1}" -f $entry.LastRun.ToString("HH:mm:ss"), $tag) -NoNewline -ForegroundColor $color
                        Write-Host $sigStatus -ForegroundColor $sigColor
                    }
                }
            }
        }
    }
} catch {
    Write-Host "  Error reading BAM entries: $($_.Exception.Message)" -ForegroundColor White
}
Write-Host ""

Write-Host "STARTUP ITEMS (RUN KEYS):" -ForegroundColor DarkBlue

$runKeys = @(
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"; Name = "HKCU\Run" },
    @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"; Name = "HKLM\Run" }
)

$startupItems = @()

foreach ($runKey in $runKeys) {
    $path = $runKey.Path
    $name = $runKey.Name
    
    Write-Host ("  ${name}:") -ForegroundColor White
    
    if (Test-Path $path) {
        $items = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
        $foundItems = $false
        
        foreach ($prop in $items.PSObject.Properties) {
            if ($prop.Name -match '^PS|Path') { continue }
            $foundItems = $true
            $value = $prop.Value
            $propName = $prop.Name
            
# Handling basic setup tasks required for initialization
            $filePath = $value
            if ($value -match '"([^"]+\.exe)"') {
                $filePath = $Matches[1]
            } elseif ($value -match '^([^ ]+\.exe)') {
                $filePath = $Matches[1]
            } elseif ($value -match '([A-Za-z]:\\[^"]+\.exe)') {
                $filePath = $Matches[1]
            }

            $isFullPath = Test-Path $filePath -ErrorAction SilentlyContinue
            if (-not $isFullPath) {

                $possiblePaths = @(
                    "$env:SystemRoot\System32\$filePath",
                    "$env:SystemRoot\$filePath",
                    "$env:ProgramFiles\$filePath",
                    "$env:ProgramFiles(x86)\$filePath"
                )
                foreach ($tryPath in $possiblePaths) {
                    if (Test-Path $tryPath) {
                        $filePath = $tryPath
                        $isFullPath = $true
                        break
                    }
                }
            }
            
            $startupItems += [PSCustomObject]@{
                KeyName = $name
                ItemName = $propName
                Value = $value
                FilePath = $filePath
                IsFullPath = $isFullPath
            }
        }
        
        if (-not $foundItems) {
            Write-Host "    (Empty)" -ForegroundColor Green
        }
    } else {
        Write-Host "    Registry key not found" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($startupItems.Count -gt 0) {
    Write-Host "  STARTUP ITEMS DETAILED ($($startupItems.Count) found):" -ForegroundColor White
    
    foreach ($item in $startupItems) {
        Write-Host "    * " -NoNewline -ForegroundColor DarkBlue
        Write-Host ("{0,-25}" -f $item.ItemName) -NoNewline -ForegroundColor White
        Write-Host ("({0})" -f $item.KeyName) -NoNewline -ForegroundColor Gray
        
        if ($item.IsFullPath) {

            $sigStatus = ""
            $sigColor = "White"
            try {
                $sig = Get-AuthenticodeSignature -FilePath $item.FilePath -ErrorAction SilentlyContinue
                if ($sig) {
                    if ($sig.Status -eq "Valid") {
                        $sigStatus = " [Signed]"
                        $sigColor = "Green"
                    } else {
                        $sigStatus = " [UNSIGNED]"
                        $sigColor = "Red"
                    }
                } else {
                    $sigStatus = " [UNSIGNED]"
                    $sigColor = "Red"
                }
                Write-Host $sigStatus -ForegroundColor $sigColor
            } catch {
                Write-Host " [Unable to verify]" -ForegroundColor Yellow
            }
            Write-Host "      Path: " -NoNewline -ForegroundColor Gray
            Write-Host $item.FilePath -ForegroundColor White
        } else {
            Write-Host " [File path not resolved]" -ForegroundColor Yellow
            Write-Host "      Value: " -NoNewline -ForegroundColor Gray
            Write-Host $item.Value -ForegroundColor White
        }
        Write-Host ""
    }
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   REPORT COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
