# ========================================================
#  Windows PowerShell NPU Table of Processes v1.0
# ========================================================

# [Config] Specify your NPU LUID
$targetLuid = "11D3B"

# [Config] Sampling interval (seconds)
$interval = 1

# [Config] Max process name length
$maxNameLength = 60

# [Config] Minimum utilization to show (0 = show all)
$minUtilization = 0

# Hide cursor (makes it look like a native app)
[Console]::CursorVisible = $false

# Clear screen once at startup
Clear-Host

# 1. [Pre-build Cache] Create a lookup table for ShortName -> DisplayName
# This runs ONLY ONCE at script startup to avoid lagging the loop.
Write-Host "Initializing service cache..." -ForegroundColor Gray
$ServiceDisplayNameMap = @{}
Get-Service | ForEach-Object { $ServiceDisplayNameMap[$_.Name] = $_.DisplayName }
Clear-Host

# Initialize script-scope variable for line counting
$script:currentLineCount = 0
$script:maxLines = 0
$script:winWidth = 0

# Helper function to write line safely
function Write-SafeLine ($text, $color="White") {
    if ($script:currentLineCount -lt $script:maxLines) {
        # PadRight ensures we overwrite old characters
        $padded = $text.PadRight($script:winWidth - 1)
        if ($padded.Length -ge $script:winWidth) {
            $padded = $padded.Substring(0, $script:winWidth - 1)
        }
        Write-Host $padded -ForegroundColor $color
        $script:currentLineCount++
    }
}

# Use try...finally to ensure cursor is restored on exit (Ctrl+C)
try {
    while ($true) {
        try {
            # Reset cursor to top-left
            try { [Console]::SetCursorPosition(0, 0) } catch { Clear-Host }

            # 2. Get Window Dimensions (Dynamic Check)
            $script:winHeight = $Host.UI.RawUI.WindowSize.Height
            $script:winWidth = $Host.UI.RawUI.WindowSize.Width

            # Reserve 1 line at bottom to prevent auto-scroll
            $script:maxLines = $script:winHeight - 1
            $script:currentLineCount = 0

            # --- Data Retrieval ---
            $path = "\GPU Engine(*luid*$targetLuid*engtype_3D)\Utilization Percentage"
            $counters = Get-Counter -Counter $path -SampleInterval $interval -ErrorAction Stop
            $samples = $counters.CounterSamples

            $outputList = @()
            $totalUtilization = 0

            foreach ($s in $samples) {
                $val = $s.CookedValue
                $totalUtilization += $val

                # Only process items >= minUtilization
                if ($val -ge $minUtilization) {
                    if ($s.InstanceName -match "pid_(\d+)_") {
                        $pidVal = [int]$matches[1]

                        try {
                            $pName = (Get-Process -Id $pidVal -ErrorAction SilentlyContinue).ProcessName
                            
                            # [Service Name Lookup Logic]
                            if ($pName -eq "svchost") {
                                # Get service short names via tasklist (CSV format is fast)
                                $svcRaw = (tasklist /svc /fi "PID eq $pidVal" /fo csv | ConvertFrom-Csv)."Services"
                                
                                # tasklist may return multiple services, we pick the first one
                                if ($svcRaw) {
                                    $firstSvc = ($svcRaw -split ",")[0].Trim()

                                    # Fast lookup from our pre-built memory cache
                                    if ($ServiceDisplayNameMap.ContainsKey($firstSvc)) {
                                        $pName = "svchost (" + $ServiceDisplayNameMap[$firstSvc] + ")"
                                    } elseif ($firstSvc -and $firstSvc -ne "N/A") {
                                        # Fallback to short name if not found in map
                                        $pName = "svchost ($firstSvc)"
                                    }
                                }
                            }
                        } catch {
                            $pName = "Unknown/Ended"
                        }

                        # Name Truncation
                        if ($pName.Length -gt $maxNameLength) {
                            $pName = $pName.Substring(0, $maxNameLength - 3) + "..."
                        }

                        $outputList += [PSCustomObject]@{
                            PID = $pidVal
                            Process = $pName
                            Usage = $val
                        }
                    }
                }
            }

            # --- UI Rendering ---
            $timeStr = Get-Date -Format "HH:mm:ss"

            # Header section
            Write-SafeLine "top    : $timeStr"
            Write-SafeLine "Target : $targetLuid (Engine: 3D)"

            # Calculate layout
            $tableTotalWidth = 8 + 1 + $maxNameLength + 1 + 10
            $separator = "-" * $tableTotalWidth

            # Calculate available space for progress bar
            $barWidth = [Math]::Max(10, $tableTotalWidth - 22)
            $fillCount = [int]([Math]::Min($totalUtilization, 100) / 100 * $barWidth)
            $barStr = "[" + ("|" * $fillCount) + (" " * ($barWidth - $fillCount)) + "]"

            # Display Utilization
            Write-SafeLine ("Utilization: {0,5:N1}% {1}  " -f $totalUtilization, $barStr) "Yellow"
            Write-SafeLine "$separator"

            $fmtString = "{0,-8} {1,-" + $maxNameLength + "} {2,-10}"
            Write-SafeLine ($fmtString -f "PID", "Process Name", "Usage")
            Write-SafeLine "$separator"

            # Data List Section
            if ($outputList.Count -eq 0) {
                Write-SafeLine " (No active processes)" "DarkGray"
            } else {
                $outputList | Sort-Object `
                    @{Expression={ $_.Usage -le 0 }; Ascending=$true}, `
                    @{Expression="Usage"; Descending=$true}, `
                    @{Expression="Process"; Ascending=$true}, `
                    @{Expression="PID"; Ascending=$true} | ForEach-Object {

                    # Stop printing if screen is full
                    if ($script:currentLineCount -ge $script:maxLines) { break }

                    $u = $_.Usage
                    if ($u -gt 0) {
                        $color = "Green"
                        $uStr = "{0,5:N1}%" -f $u
                    } else {
                        $color = "DarkGray"
                        $uStr = "  0.0%"
                    }

                    # Add padding for overwrite safety
                    Write-SafeLine (($fmtString -f $_.PID, $_.Process, $uStr) + "     ") $color
                }
            }

            # Clear Residual Lines (Anti-Ghosting)
            while ($script:currentLineCount -lt $script:maxLines) {
                Write-SafeLine " "
            }
        } catch {
            Clear-Host
            Write-Host "Monitor paused. Error accessing performance counters." -ForegroundColor Yellow
            Start-Sleep 1
        }
    }
} finally {
    # Restore cursor on exit
    [Console]::CursorVisible = $true
    Clear-Host
    Write-Host "Monitor stopped. Cursor restored." -ForegroundColor Gray
}
