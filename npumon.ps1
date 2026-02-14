# ========================================================
# Windows PowerShell NPU Performance Monitor v1.0
# ========================================================

# [Config] Specify your NPU LUID
$targetLuid = "11D3B"

# [Config] Sampling interval (seconds)
$interval = 1

# [Config] Max process name length
$maxNameLength = 35

# Hide cursor (makes it look like a native app)
[Console]::CursorVisible = $false

# Clear screen once at startup
Clear-Host

# Use try...finally to ensure cursor is restored on exit (Ctrl+C)
try {
    while ($true) {
        try {
            # Reset cursor to top-left (the secret to zero-flicker)
            try { [Console]::SetCursorPosition(0, 0) } catch { Clear-Host }

            $path = "\GPU Engine(*luid*$targetLuid*engtype_3D)\Utilization Percentage"
            $counters = Get-Counter -Counter $path -SampleInterval $interval -ErrorAction Stop
            $samples = $counters.CounterSamples

            $outputList = @()
            $totalLoad = 0

            foreach ($s in $samples) {
                $val = $s.CookedValue
                $totalLoad += $val

                if ($s.InstanceName -match "pid_(\d+)_") {
                    $pidVal = $matches[1]

                    try {
                        $pName = (Get-Process -Id $pidVal -ErrorAction SilentlyContinue).ProcessName
                    } catch {
                        $pName = "Unknown/Ended"
                    }

                    # Special labeling
                    if ($pName -eq "svchost") { $pName = "svchost (Camera/System)" }
                    if ($pName -eq "audiodg") { $pName = "audiodg (Audio/Voice)" }

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

            $timeStr = Get-Date -Format "HH:mm:ss"

            # Use whitespace padding (PadRight) to overwrite old text
            Write-Host "=== Windows PowerShell NPU Performance Monitor v1.0 ===   " -ForegroundColor Cyan
            Write-Host "                                                            " # Clear previous line artifacts
            Write-Host "Time   : $timeStr                                           "
            Write-Host "Target : $targetLuid (Engine: 3D)                           "

            # Calculate total table width (PID=8 + Space=1 + Name=$max + Space=1 + Usage=10)
            $tableTotalWidth = 8 + 1 + $maxNameLength + 1 + 10

            # Prepare separator
            $separator = "-" * $tableTotalWidth

            # Calculate available space for progress bar
            # Label text "Utilization: 100.0% " takes ~20 chars, plus brackets [] takes 2 chars
            # Dynamic calculation: Total Width - Label Length - Borders(2)
            $labelLength = 20
            $barWidth = $tableTotalWidth - $labelLength - 2
            if ($barWidth -lt 10) { $barWidth = 10 }

            $cappedLoad = [Math]::Min($totalLoad, 100)
            $fillCount = [int](($cappedLoad / 100) * $barWidth)
            $emptyCount = $barWidth - $fillCount
            $barStr = "[" + ("|" * $fillCount) + (" " * $emptyCount) + "]"

            Write-Host ("Utilization: {0,5:N1}% {1}  " -f $totalLoad, $barStr) -ForegroundColor Yellow
            Write-Host "$separator  "

            $fmtString = "{0,-8} {1,-" + $maxNameLength + "} {2,-10}"
            Write-Host ($fmtString -f "PID", "Process Name", "Usage")
            Write-Host "$separator  "

            # Display list
            if ($outputList.Count -eq 0) {
                Write-Host " (No counters found)                                    " -ForegroundColor Red
            } else {
                $outputList | Sort-Object Usage -Descending | ForEach-Object {
                    $u = $_.Usage
                    if ($u -gt 0.1) {
                        $color = "Green"
                        $uStr = "{0,5:N1}%" -f $u
                    } else {
                        $color = "DarkGray"
                        $uStr = "  0.0%"
                    }
                    # Add 5 spaces padding to ensure old data is overwritten
                    Write-Host (($fmtString -f $_.PID, $_.Process, $uStr) + "     ") -ForegroundColor $color
                }
            }

            # Clear residual old data at the bottom (Ghosting)
            # If there were 20 lines before and now only 5, we print blank lines to clear the bottom
            for ($i = 0; $i -lt 10; $i++) {
                Write-Host (" " * ($tableTotalWidth + 5))
            }

        } catch {
            # Only use Clear-Host during error handling
            Clear-Host
            Write-Host "=== Windows PowerShell NPU Performance Monitor v1.0 ===" -ForegroundColor Cyan
            Write-Host "Monitor paused. Error accessing performance counters." -ForegroundColor Yellow
            Start-Sleep 1
        }
    }
} finally {
    # Restore cursor when user presses Ctrl+C
    [Console]::CursorVisible = $true
    Clear-Host
    Write-Host "Monitor stopped. Cursor Restored." -ForegroundColor Gray
}
