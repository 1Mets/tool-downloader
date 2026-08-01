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

# ask the user where their mods folder is
Write-Host "Enter path to the mods folder: " -NoNewline
Write-Host "(press Enter to use default)" -ForegroundColor DarkGray
$modsPath = Read-Host "PATH"
Write-Host

if ([string]::IsNullOrWhiteSpace($modsPath)) {
    $modsPath = "$env:USERPROFILE\AppData\Roaming\.minecraft\mods"
    Write-Host "Continuing with " -NoNewline
    Write-Host $modsPath -ForegroundColor White
    Write-Host
}

if (-not (Test-Path $modsPath -PathType Container)) {
    Write-Host "Invalid Path!" -ForegroundColor Red
    Write-Host "The directory does not exist or is not accessible." -ForegroundColor DarkYellow
    Write-Host
    Write-Host "Tried to access: $modsPath" -ForegroundColor DarkGray
    Write-Host
    Write-Host "Press any key to exit..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

Write-Host "Scanning directory: $modsPath" -ForegroundColor DarkMagenta
Write-Host

# check if minecraft is already running
$mcProcess = Get-Process javaw -ErrorAction SilentlyContinue
if (-not $mcProcess) {
    $mcProcess = Get-Process java -ErrorAction SilentlyContinue
}

if ($mcProcess) {
    try {
        $startTime = $mcProcess.StartTime
        $uptime = (Get-Date) - $startTime
        Write-Host "{ Minecraft Uptime }" -ForegroundColor DarkGray
        Write-Host "   $($mcProcess.Name) PID $($mcProcess.Id) started at $startTime" -ForegroundColor DarkGray
        Write-Host "   Running for: $($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s" -ForegroundColor DarkGray
        Write-Host ""
    } catch {
        # couldn't grab process info, no biggie
    }
}

function Get-FileSHA1 {
    param([string]$Path)
    return (Get-FileHash -Path $Path -Algorithm SHA1).Hash
}

function Get-DownloadSource {
    param([string]$Path)
    $zoneData = Get-Content -Raw -Stream Zone.Identifier $Path -ErrorAction SilentlyContinue
    if ($zoneData -match "HostUrl=(.+)") {
        $url = $matches[1].Trim()
        if ($url -match "mediafire\.com")                                        { return "MediaFire" }
        elseif ($url -match "discord\.com|discordapp\.com|cdn\.discordapp\.com") { return "Discord" }
        elseif ($url -match "dropbox\.com")                                      { return "Dropbox" }
        elseif ($url -match "drive\.google\.com")                                { return "Google Drive" }
        elseif ($url -match "mega\.nz|mega\.co\.nz")                             { return "MEGA" }
        elseif ($url -match "github\.com")                                       { return "GitHub" }
        elseif ($url -match "modrinth\.com")                                     { return "Modrinth" }
        elseif ($url -match "curseforge\.com")                                   { return "CurseForge" }
        elseif ($url -match "anydesk\.com")                                      { return "AnyDesk" }
        elseif ($url -match "doomsdayclient\.com")                               { return "DoomsdayClient" }
        elseif ($url -match "prestigeclient\.vip")                               { return "PrestigeClient" }
        elseif ($url -match "198macros\.com")                                    { return "198Macros" }
        else {
            if ($url -match "https?://(?:www\.)?([^/]+)") { return $matches[1] }
            return $url
        }
    }
    return $null
}

function Query-Modrinth {
    param([string]$Hash)
    try {
        $versionInfo = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_file/$Hash" -Method Get -UseBasicParsing -ErrorAction Stop
        if ($versionInfo.project_id) {
            $projectInfo = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/project/$($versionInfo.project_id)" -Method Get -UseBasicParsing -ErrorAction Stop
            return @{ Name = $projectInfo.title; Slug = $projectInfo.slug }
        }
    } catch { }
    return @{ Name = ""; Slug = "" }
}

function Query-Megabase {
    param([string]$Hash)
    try {
        $result = Invoke-RestMethod -Uri "https://megabase.vercel.app/api/query?hash=$Hash" -Method Get -UseBasicParsing -ErrorAction Stop
        if (-not $result.error) { return $result.data }
    } catch { }
    return $null
}

# --- detection lists ---
$suspiciousPatterns = @(
    "AimAssist", "AnchorTweaks", "AutoAnchor", "AutoCrystal", "AutoDoubleHand",
    "AutoHitCrystal", "AutoPot", "AutoTotem", "AutoArmor", "InventoryTotem",
    "Hitboxes", "JumpReset", "LegitTotem", "PingSpoof", "SelfDestruct",
    "ShieldBreaker", "TriggerBot", "Velocity", "AxeSpam", "WebMacro",
    "FastPlace", "WalskyOptimizer", "WalksyOptimizer", "walsky.optimizer",
    "WalksyCrystalOptimizerMod", "Donut", "Replace Mod", "Reach",
    "ShieldDisabler", "SilentAim", "Totem Hit", "Wtap", "FakeLag",
    "BlockESP", "dev.krypton", "Virgin", "AntiMissClick",
    "LagReach", "PopSwitch", "SprintReset", "ChestSteal", "AntiBot",
    "ElytraSwap", "FastXP", "FastExp", "Refill", "NoJumpDelay", "AirAnchor",
    "jnativehook", "FakeInv", "HoverTotem", "AutoClicker", "AutoFirework",
    "PackSpoof", "Antiknockback", "scrim", "catlean", "Argon",
    "AuthBypass", "Asteria", "Prestige", "AutoEat", "AutoMine",
    "MaceSwap", "DoubleAnchor", "AutoTPA", "BaseFinder", "Xenon", "gypsy",
    "Grim", "grim",
    "org.chainlibs.module.impl.modules.Crystal.Y",
    "org.chainlibs.module.impl.modules.Crystal.bF",
    "org.chainlibs.module.impl.modules.Crystal.bM",
    "org.chainlibs.module.impl.modules.Crystal.bY",
    "org.chainlibs.module.impl.modules.Crystal.bq",
    "org.chainlibs.module.impl.modules.Crystal.cv",
    "org.chainlibs.module.impl.modules.Crystal.o",
    "org.chainlibs.module.impl.modules.Blatant.I",
    "org.chainlibs.module.impl.modules.Blatant.bR",
    "org.chainlibs.module.impl.modules.Blatant.bx",
    "org.chainlibs.module.impl.modules.Blatant.cj",
    "org.chainlibs.module.impl.modules.Blatant.dk",
    "imgui", "imgui.gl3", "imgui.glfw",
    "BowAim", "Criticals", "Flight", "Fakenick", "FakeItem",
    "invsee", "ItemExploit", "Hellion", "hellion",
    "LicenseCheckMixin", "ClientPlayerInteractionManagerAccessor",
    "ClientPlayerEntityMixim", "dev.gambleclient", "obfuscatedAuth",
    "phantom-refmap.json", "xyz.greaj",
    "じ.class", "ふ.class", "ぶ.class", "ぷ.class", "た.class",
    "ね.class", "そ.class", "な.class", "ど.class", "ぐ.class",
    "ず.class", "で.class", "つ.class", "べ.class", "せ.class",
    "と.class", "み.class", "び.class", "す.class", "の.class"
)

$cheatStrings = @(
    "AutoCrystal", "autocrystal", "auto crystal", "cw crystal",
    "dontPlaceCrystal", "dontBreakCrystal",
    "AutoHitCrystal", "autohitcrystal", "canPlaceCrystalServer", "healPotSlot",
    "AutoAnchor", "autoanchor", "auto anchor", "DoubleAnchor",
    "hasGlowstone", "HasAnchor", "anchortweaks", "anchor macro", "safe anchor", "safeanchor",
    "AutoTotem", "autototem", "auto totem", "InventoryTotem",
    "inventorytotem", "HoverTotem", "hover totem", "legittotem",
    "AutoPot", "autopot", "auto pot", "speedPotSlot", "strengthPotSlot",
    "AutoArmor", "autoarmor", "auto armor",
    "preventSwordBlockBreaking", "preventSwordBlockAttack",
    "AutoDoubleHand", "autodoublehand", "auto double hand",
    "AutoClicker",
    "Failed to switch to mace after axe!",
    "Breaking shield with axe...",
    "Donut", "JumpReset", "axespam", "axe spam",
    "shieldbreaker", "shield breaker", "EndCrystalItemMixin",
    "findKnockbackSword", "attackRegisteredThisClick",
    "AimAssist", "aimassist", "aim assist",
    "triggerbot", "trigger bot",
    "FakeInv", "Friends", "swapBackToOriginalSlot",
    "FakeLag", "pingspoof", "ping spoof", "velocity",
    "webmacro", "web macro",
    "lvstrng", "dqrkis", "selfdestruct", "self destruct",
    "AutoMace", "AutoFirework", "MaceSwap", "AirAnchor",
    "ElytraSwap", "FastXP", "FastExp", "NoJumpDelay",
    "PackSpoof", "Antiknockback", "scrim", "catlean",
    "AuthBypass", "obfuscatedAuth", "LicenseCheckMixin",
    "BaseFinder", "invsee", "ItemExploit",
    "NoFall", "nofall",
    "WalksyCrystalOptimizerMod", "WalksyOptimizer", "WalskyOptimizer",
    "autoCrystalPlaceClock",
    "setBlockBreakingCooldown", "getBlockBreakingCooldown", "blockBreakingCooldown",
    "onBlockBreaking", "setItemUseCooldown",
    "setSelectedSlot", "invokeDoAttack", "invokeDoItemUse", "invokeOnMouseButton",
    "onTickMovement", "onPushOutOfBlocks", "onIsGlowing",
    "Automatically switches to sword when hitting with totem",
    "arrayOfString", "POT_CHEATS",
    "Dqrkis Client", "Entity.isGlowing"
)

# ─────────────────────────────────────────────────────────────────────────────
# BYPASS / INJECTION DETECTION
# ─────────────────────────────────────────────────────────────────────────────

function Invoke-BypassScan {
    param([string]$FilePath)

    $flags = [System.Collections.Generic.List[string]]::new()

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $mavenPrefixes = @(
        "com_","org_","net_","io_","dev_","gs_","xyz_",
        "app_","me_","tv_","uk_","be_","fr_","de_"
    )

    function Test-SuspiciousJarName {
        param([string]$JarName)
        $base = [System.IO.Path]::GetFileNameWithoutExtension($JarName)
        if ($base -match '\d')                                          { return $false }
        foreach ($pfx in $mavenPrefixes) {
            if ($base.ToLower().StartsWith($pfx))                       { return $false }
        }
        if ($base.Length -gt 20)                                        { return $false }
        return $true
    }

    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($FilePath)

        $nestedJars   = @($zip.Entries | Where-Object { $_.FullName -match "^META-INF/jars/.+\.jar$" })
        $outerClasses = @($zip.Entries | Where-Object { $_.FullName -match "\.class$" })

        # ── 1. SUSPICIOUS NESTED JAR NAME ────────────────────────────────────
        $suspiciousNestedJars = @()
        foreach ($nj in $nestedJars) {
            $njBase = [System.IO.Path]::GetFileName($nj.FullName)
            if (Test-SuspiciousJarName -JarName $njBase) {
                $suspiciousNestedJars += $njBase
            }
        }
        foreach ($sj in $suspiciousNestedJars) {
            $flags.Add("Suspicious nested JAR — no version number, not a known dependency: $sj")
        }

        # ── 2. HOLLOW SHELL ───────────────────────────────────────────────────
        if ($nestedJars.Count -eq 1 -and $outerClasses.Count -lt 3) {
            $njName = [System.IO.Path]::GetFileName(($nestedJars | Select-Object -First 1).FullName)
            $flags.Add("Hollow shell — outer JAR has only $($outerClasses.Count) own class(es) but wraps: $njName")
        }

        # ── Read outer mod ID for later use ──────────────────────────────────
        $outerModId = ""
        $fmje = $zip.Entries | Where-Object { $_.FullName -eq "fabric.mod.json" } | Select-Object -First 1
        if ($fmje) {
            try {
                $s = $fmje.Open()
                $r = New-Object System.IO.StreamReader($s)
                $t = $r.ReadToEnd(); $r.Close(); $s.Close()
                if ($t -match '"id"\s*:\s*"([^"]+)"') { $outerModId = $matches[1] }
            } catch { }
        }

        # ── 3. BYTECODE CHECKS — scan outer + all nested JARs ────────────────
        $allEntries = [System.Collections.Generic.List[object]]::new()
        foreach ($e in $zip.Entries) { $allEntries.Add($e) }

        $innerZips = [System.Collections.Generic.List[object]]::new()
        foreach ($nj in $nestedJars) {
            try {
                $ns = $nj.Open()
                $ms = New-Object System.IO.MemoryStream
                $ns.CopyTo($ms); $ns.Close()
                $ms.Position = 0
                $iz = [System.IO.Compression.ZipArchive]::new($ms, [System.IO.Compression.ZipArchiveMode]::Read)
                $innerZips.Add($iz)
                foreach ($ie in $iz.Entries) { $allEntries.Add($ie) }
            } catch { }
        }

        $runtimeExecFound  = $false
        $httpDownloadFound = $false
        $httpExfilFound    = $false
        $obfuscatedCount   = 0
        $totalClassCount   = 0

        foreach ($entry in $allEntries) {
            $name = $entry.FullName

            if ($name -match "\.class$") {
                $totalClassCount++

                # ── FIX: Obfuscation detection — consecutive single-char segments ──────
                # The old check required ALL path segments to be <=2 chars, which missed
                # obfuscated subpackages hidden inside a legitimate-looking root package.
                # e.g. "realmod/realmod/compat/a/a/e/d.class" was not caught because
                # the root segments are long, even though the inner path is obfuscated.
                #
                # New check: flag any class that has 3 or more CONSECUTIVE single-char
                # path segments anywhere in the path. Legitimate mods never have this —
                # they always use real package names throughout (com/example/mod/...).
                $segs = ($name -replace "\.class$","") -split "/"
                $consecutiveSingle = 0
                $maxConsecutive    = 0
                foreach ($seg in $segs) {
                    if ($seg.Length -eq 1) {
                        $consecutiveSingle++
                        if ($consecutiveSingle -gt $maxConsecutive) { $maxConsecutive = $consecutiveSingle }
                    } else {
                        $consecutiveSingle = 0
                    }
                }
                if ($maxConsecutive -ge 3) { $obfuscatedCount++ }

                # ── FIX: Read bytecode as raw bytes to avoid StreamReader encoding issues ──
                # The old StreamReader with Latin1 encoding could silently drop or corrupt
                # bytes during string conversion, causing regex matches on constant-pool
                # strings (e.g. "java/lang/Runtime", "exec") to fail unpredictably.
                # Reading as raw bytes and converting to ASCII is more reliable for
                # scanning printable strings embedded in JVM bytecode.
                try {
                    $st = $entry.Open()
                    $ms2 = New-Object System.IO.MemoryStream
                    $st.CopyTo($ms2)
                    $st.Close()
                    $rawBytes = $ms2.ToArray()
                    $ms2.Dispose()
                    # Convert to ASCII string — non-ASCII bytes become '?' but constant-pool
                    # strings (URLs, class names, method names) are pure ASCII and survive intact
                    $ct = [System.Text.Encoding]::ASCII.GetString($rawBytes)

                    # Runtime.exec detection.
                    # Legitimate mods (ModMenu, YACL) use Runtime.exec to open folders/files
                    # in the system file manager or editor — that's completely normal UI behaviour.
                    # We only record the hit here; the flag is only EMITTED below when the mod
                    # is also heavily obfuscated, which no legitimate mod ever is.
                    if ($ct -match "java/lang/Runtime" -and
                        $ct -match "getRuntime" -and
                        $ct -match "exec") {
                        $runtimeExecFound = $true
                    }

                    # HTTP file download: fetches a remote URL and writes the result to disk.
                    # No legitimate Fabric mod downloads arbitrary files to disk at runtime —
                    # updates go through the launcher and assets are bundled in the JAR.
                    # This pattern alone is enough to flag regardless of obfuscation.
                    if ($ct -match "openConnection" -and
                        $ct -match "HttpURLConnection" -and
                        $ct -match "FileOutputStream") {
                        $httpDownloadFound = $true
                    }

                    # HTTP POST exfiltration: sends a request body to an external server.
                    # Update checkers and crash reporters also use setDoOutput+getOutputStream,
                    # so this pattern alone produces false positives on library mods (e.g. ukulib).
                    # We tighten it: only flag when the same class ALSO reads system properties
                    # (getProperty), which indicates harvesting of environment data (tokens,
                    # usernames, OS info) before sending — a strong exfiltration signal.
                    if ($ct -match "openConnection" -and
                        $ct -match "setDoOutput" -and
                        $ct -match "getOutputStream" -and
                        $ct -match "getProperty") {
                        $httpExfilFound = $true
                    }
                } catch { }
            }
        }

        foreach ($iz in $innerZips) { try { $iz.Dispose() } catch { } }
        $zip.Dispose()

        # ── Emit dangerous-code flags ─────────────────────────────────────────

        # Compute obfuscation percentage here so the Runtime.exec gate can use it.
        $obfPct = if ($totalClassCount -ge 10) { [math]::Round(($obfuscatedCount / $totalClassCount) * 100) } else { 0 }

        # Runtime.exec is only flagged when the mod is also obfuscated.
        # Legitimate mods like ModMenu and YACL use exec() to open folders/files in the
        # OS file manager or text editor — perfectly normal. But no legitimate mod is
        # obfuscated, so combining exec + obfuscation is a reliable malice signal.
        if ($runtimeExecFound -and $obfPct -ge 40) {
            $flags.Add("Runtime.exec() inside obfuscated code — mod can execute arbitrary OS commands (combined with heavy obfuscation this is a strong malice indicator)")
        }

        if ($httpDownloadFound) {
            $flags.Add("HTTP file download — mod fetches and writes files from a remote server at runtime (no legitimate Fabric mod does this)")
        }

        # HTTP POST is only flagged when system properties are also read in the same class,
        # indicating data harvesting (tokens, session IDs, OS/user info) before exfiltration.
        # Pure update checkers and crash reporters do NOT read system properties alongside POST.
        if ($httpExfilFound) {
            $flags.Add("HTTP POST exfiltration — mod reads system properties and sends data to an external server (possible token/session theft)")
        }

        # ── FIX: Obfuscation threshold lowered from 60% to 40% ───────────────
        # The old 60% threshold was calibrated for fully-obfuscated standalone cheats.
        # Trojanized legitimate mods hide their payload in an obfuscated subpackage while
        # keeping the real mod's classes readable — still producing ~93% obfuscation.
        # 40% is still far above anything a legitimate mod produces (always 0%).
        if ($totalClassCount -ge 10 -and $obfPct -ge 40) {
            $flags.Add("Heavy obfuscation — $obfPct% of classes have 3+ consecutive single-letter path segments (a/b/c style). Legitimate mods never do this.")
        }

        # ── Fake mod identity (only with corroborating dangerous flags) ───────
        $knownLegitModIds = @(
            "vmp-fabric","vmp","lithium","sodium","iris","fabric-api",
            "modmenu","ferrite-core","lazydfu","starlight","entityculling",
            "memoryleakfix","krypton","c2me-fabric","smoothboot-fabric",
            "immediatelyfast","noisium","threadtweak"
        )
        $dangerCount = ($flags | Where-Object {
            $_ -match "Runtime\.exec|HTTP file download|HTTP POST|Heavy obfuscation|Suspicious nested JAR"
        }).Count
        if ($outerModId -and ($knownLegitModIds -contains $outerModId) -and $dangerCount -gt 0) {
            $flags.Add("Fake mod identity — outer JAR claims to be '$outerModId' but dangerous code was found inside (trojanized build)")
        }

    } catch { }

    return $flags
}

# single pass scan — runs pattern matching and raw string search together
function Invoke-ModScan {
    param([string]$FilePath)

    $foundPatterns = [System.Collections.Generic.HashSet[string]]::new()
    $foundStrings  = [System.Collections.Generic.HashSet[string]]::new()

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    try {
        $patternRegex = [regex]::new(
            '(?<![A-Za-z])(' + ($suspiciousPatterns -join '|') + ')(?![A-Za-z])',
            [System.Text.RegularExpressions.RegexOptions]::Compiled
        )
        $archive = [System.IO.Compression.ZipFile]::OpenRead($FilePath)
        foreach ($entry in $archive.Entries) {
            foreach ($m in $patternRegex.Matches($entry.FullName)) { [void]$foundPatterns.Add($m.Value) }
            if ($entry.FullName -match '\.(class|json)$' -or $entry.FullName -match 'MANIFEST\.MF') {
                try {
                    $stream  = $entry.Open()
                    $reader  = New-Object System.IO.StreamReader($stream)
                    $content = $reader.ReadToEnd()
                    $reader.Close(); $stream.Close()
                    foreach ($m in $patternRegex.Matches($content)) { [void]$foundPatterns.Add($m.Value) }
                } catch { }
            }
        }
        $archive.Dispose()
    } catch { }

    try {
        $stringsExe = @(
            "C:\Program Files\Git\usr\bin\strings.exe",
            "C:\Program Files\Git\mingw64\bin\strings.exe",
            "$env:ProgramFiles\Git\usr\bin\strings.exe",
            "C:\msys64\usr\bin\strings.exe",
            "C:\cygwin64\bin\strings.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1

        if ($stringsExe) {
            $tmp = Join-Path $env:TEMP "void_str_$(Get-Random).txt"
            & $stringsExe $FilePath 2>$null | Out-File $tmp -Encoding UTF8
            if (Test-Path $tmp) {
                $raw = Get-Content $tmp -Raw
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
                foreach ($s in $cheatStrings) {
                    if ($s -eq "velocity") {
                        if ($raw -match "velocity(?:hack|module|cheat|bypass|packet|horizontal|vertical|amount|factor|setting)") {
                            [void]$foundStrings.Add($s)
                        }
                    } elseif ($raw -match [regex]::Escape($s)) {
                        [void]$foundStrings.Add($s)
                    }
                }
            }
        } else {
            $rawText = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($FilePath))
            foreach ($s in $cheatStrings) {
                if ($s -eq "velocity") {
                    if ($rawText -match "velocity(?:hack|module|cheat|bypass|packet|horizontal|vertical|amount|factor|setting)") {
                        [void]$foundStrings.Add($s)
                    }
                } elseif ($rawText -match [regex]::Escape($s)) {
                    [void]$foundStrings.Add($s)
                }
            }
            try {
                $zip = [System.IO.Compression.ZipFile]::OpenRead($FilePath)
                foreach ($entry in ($zip.Entries | Where-Object { $_.Name -like "*.class" })) {
                    try {
                        $stream    = $entry.Open()
                        $reader    = New-Object System.IO.StreamReader($stream)
                        $classText = $reader.ReadToEnd()
                        $reader.Close(); $stream.Close()
                        foreach ($s in $cheatStrings) {
                            if ($s -eq "velocity") {
                                if ($classText -match "velocity(?:hack|module|cheat|bypass|packet|horizontal|vertical|amount|factor|setting)") {
                                    [void]$foundStrings.Add($s)
                                }
                            } elseif ($classText -match [regex]::Escape($s)) {
                                [void]$foundStrings.Add($s)
                            }
                        }
                    } catch { }
                }
                $zip.Dispose()
            } catch { }
        }
    } catch { }

    return @{ Patterns = $foundPatterns; Strings = $foundStrings }
}

$verifiedMods   = @()
$unknownMods    = @()
$suspiciousMods = @()
$bypassMods     = @()

try {
    $jarFiles = Get-ChildItem -Path $modsPath -Filter *.jar -ErrorAction Stop
} catch {
    Write-Host "Error accessing directory: $_" -ForegroundColor Red
    Write-Host "Press any key to exit..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

if ($jarFiles.Count -eq 0) {
    Write-Host "No JAR files found in: $modsPath" -ForegroundColor DarkYellow
    Write-Host "Press any key to exit..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 0
}

$fileWord = if ($jarFiles.Count -eq 1) { "file" } else { "files" }
Write-Host "Found $($jarFiles.Count) JAR $fileWord to analyze" -ForegroundColor DarkMagenta
Write-Host

$spinnerFrames = @("⣾","⣽","⣻","⢿","⡿","⣟","⣯","⣷")
$totalFiles    = $jarFiles.Count
$idx           = 0

# pass 1 - hash lookup against modrinth and megabase
foreach ($jar in $jarFiles) {
    $idx++
    $spinner = $spinnerFrames[$idx % $spinnerFrames.Length]
    Write-Host "`r[$spinner] Verifying: $idx/$totalFiles - $($jar.Name)" -ForegroundColor Magenta -NoNewline

    $hash = Get-FileSHA1 -Path $jar.FullName

    if ($hash) {
        $modrinthData = Query-Modrinth -Hash $hash
        if ($modrinthData.Slug) {
            $verifiedMods += [PSCustomObject]@{ ModName = $modrinthData.Name; FileName = $jar.Name; FilePath = $jar.FullName }
            continue
        }
        $megabaseData = Query-Megabase -Hash $hash
        if ($megabaseData.name) {
            $verifiedMods += [PSCustomObject]@{ ModName = $megabaseData.Name; FileName = $jar.Name; FilePath = $jar.FullName }
            continue
        }
    }

    $src = Get-DownloadSource $jar.FullName
    $unknownMods += [PSCustomObject]@{ FileName = $jar.Name; FilePath = $jar.FullName; DownloadSource = $src }
}

Write-Host "`r$(' ' * 100)`r" -NoNewline

# pass 2 - deep scan every jar for cheat patterns and strings
$modWord = if ($totalFiles -eq 1) { "mod" } else { "mods" }
Write-Host "Deep-scanning all $totalFiles $modWord..." -ForegroundColor DarkMagenta
$idx = 0

foreach ($jar in $jarFiles) {
    $idx++
    $spinner = $spinnerFrames[$idx % $spinnerFrames.Length]
    Write-Host "`r[$spinner] Scanning: $idx/$totalFiles - $($jar.Name)" -ForegroundColor Magenta -NoNewline

    $result = Invoke-ModScan -FilePath $jar.FullName

    if ($result.Patterns.Count -gt 0 -or $result.Strings.Count -gt 0) {
        $suspiciousMods += [PSCustomObject]@{
            FileName = $jar.Name
            Patterns = $result.Patterns
            Strings  = $result.Strings
        }
        $verifiedMods = $verifiedMods | Where-Object { $_.FileName -ne $jar.Name }
    }
}

Write-Host "`r$(' ' * 100)`r" -NoNewline

# pass 3 - bypass / injection scan
Write-Host "Running bypass/injection scan on all $totalFiles $modWord..." -ForegroundColor DarkGray
$idx = 0

foreach ($jar in $jarFiles) {
    $idx++
    $spinner = $spinnerFrames[$idx % $spinnerFrames.Length]
    Write-Host "`r[$spinner] Bypass scan: $idx/$totalFiles - $($jar.Name)" -ForegroundColor Magenta -NoNewline

    $bypassFlags = Invoke-BypassScan -FilePath $jar.FullName

    if ($bypassFlags.Count -gt 0) {
        $bypassMods += [PSCustomObject]@{
            FileName = $jar.Name
            Flags    = $bypassFlags
        }
        $verifiedMods = $verifiedMods | Where-Object { $_.FileName -ne $jar.Name }
        $unknownMods  = $unknownMods  | Where-Object { $_.FileName -ne $jar.Name }
    }
}

Write-Host "`r$(' ' * 100)`r" -NoNewline

# --- results ---
Write-Host "`n" + ("━" * 76) -ForegroundColor DarkGray

if ($verifiedMods.Count -gt 0) {
    Write-Host "VERIFIED MODS ($($verifiedMods.Count))" -ForegroundColor DarkMagenta
    Write-Host ("─" * 76) -ForegroundColor DarkGray
    foreach ($mod in $verifiedMods) {
        Write-Host "  v " -ForegroundColor DarkMagenta -NoNewline
        Write-Host "$($mod.ModName)" -ForegroundColor White -NoNewline
        Write-Host " → " -ForegroundColor DarkGray -NoNewline
        Write-Host "$($mod.FileName)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

if ($unknownMods.Count -gt 0) {
    Write-Host "UNKNOWN MODS ($($unknownMods.Count))" -ForegroundColor DarkYellow
    Write-Host ("─" * 76) -ForegroundColor DarkGray
    foreach ($mod in $unknownMods) {
        $name = $mod.FileName
        if ($name.Length -gt 50) { $name = $name.Substring(0,47) + "..." }
        $topLine    = "  ╔═ ? " + $name + " " + ("═" * (65 - $name.Length)) + "╗"
        $sourceText = if ($mod.DownloadSource) { "Source: $($mod.DownloadSource)" } else { "Source: ?" }
        $bottomLine = "  ╚═ " + $sourceText + " " + ("═" * (67 - $sourceText.Length)) + "╝"
        Write-Host $topLine    -ForegroundColor DarkYellow
        Write-Host $bottomLine -ForegroundColor DarkYellow
        Write-Host ""
    }
}

if ($suspiciousMods.Count -gt 0) {
    Write-Host "SUSPICIOUS MODS ($($suspiciousMods.Count))" -ForegroundColor Red
    Write-Host ("─" * 76) -ForegroundColor DarkGray
    Write-Host ""
    foreach ($mod in $suspiciousMods) {
        Write-Host "  ╔═══ " -ForegroundColor Red -NoNewline
        Write-Host "FLAGGED" -ForegroundColor White -BackgroundColor DarkRed -NoNewline
        Write-Host " ═══════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host "  ║" -ForegroundColor Red
        Write-Host "  ║  File: " -ForegroundColor Red -NoNewline
        Write-Host "$($mod.FileName)" -ForegroundColor DarkYellow

        if ($mod.Patterns.Count -gt 0) {
            Write-Host "  ║" -ForegroundColor Red
            Write-Host "  ║  Detected Patterns:" -ForegroundColor Red
            foreach ($p in ($mod.Patterns | Sort-Object)) {
                Write-Host "  ║    • " -ForegroundColor Red -NoNewline
                Write-Host "$p" -ForegroundColor White
            }
        }

        $uniqueStrings = $mod.Strings | Where-Object { $mod.Patterns -notcontains $_ } | Sort-Object
        if ($uniqueStrings.Count -gt 0) {
            Write-Host "  ║" -ForegroundColor Red
            Write-Host "  ║  Detected Strings:" -ForegroundColor DarkRed
            foreach ($s in $uniqueStrings) {
                Write-Host "  ║    • " -ForegroundColor DarkRed -NoNewline
                Write-Host "$s" -ForegroundColor DarkRed
            }
        }

        Write-Host "  ║" -ForegroundColor Red
        Write-Host "  ╚═══════════════════════════════════════════════════════════════════════" -ForegroundColor Red
        Write-Host ""
    }
}

if ($bypassMods.Count -gt 0) {
    Write-Host "BYPASS / INJECTION DETECTED ($($bypassMods.Count))" -ForegroundColor DarkMagenta
    Write-Host ("─" * 76) -ForegroundColor DarkGray
    Write-Host ""
    foreach ($mod in $bypassMods) {
        Write-Host "  ╔═══ " -ForegroundColor DarkMagenta -NoNewline
        Write-Host "INJECTION" -ForegroundColor White -BackgroundColor DarkMagenta -NoNewline
        Write-Host " ══════════════════════════════════════════════════════════" -ForegroundColor DarkMagenta
        Write-Host "  ║" -ForegroundColor DarkMagenta
        Write-Host "  ║  File: " -ForegroundColor DarkMagenta -NoNewline
        Write-Host "$($mod.FileName)" -ForegroundColor DarkYellow
        Write-Host "  ║" -ForegroundColor DarkMagenta
        Write-Host "  ║  Bypass Flags:" -ForegroundColor DarkMagenta
        foreach ($flag in $mod.Flags) {
            Write-Host "  ║    ! " -ForegroundColor DarkMagenta -NoNewline
            Write-Host "$flag" -ForegroundColor White
        }
        Write-Host "  ║" -ForegroundColor DarkMagenta
        Write-Host "  ╚═══════════════════════════════════════════════════════════════════════" -ForegroundColor DarkMagenta
        Write-Host ""
    }
}

Write-Host "SUMMARY" -ForegroundColor DarkMagenta
Write-Host ("━" * 76) -ForegroundColor DarkGray
Write-Host "  Total files scanned: " -ForegroundColor DarkGray -NoNewline; Write-Host "$totalFiles"              -ForegroundColor White
Write-Host "  Verified mods:       " -ForegroundColor DarkGray -NoNewline; Write-Host "$($verifiedMods.Count)"   -ForegroundColor DarkMagenta
Write-Host "  Unknown mods:        " -ForegroundColor DarkGray -NoNewline; Write-Host "$($unknownMods.Count)"    -ForegroundColor DarkYellow
Write-Host "  Suspicious mods:     " -ForegroundColor DarkGray -NoNewline; Write-Host "$($suspiciousMods.Count)" -ForegroundColor Red
Write-Host "  Bypass/Injected:     " -ForegroundColor DarkGray -NoNewline; Write-Host "$($bypassMods.Count)"     -ForegroundColor DarkMagenta
