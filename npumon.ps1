# ========================================================
# Windows PowerShell NPU Performance Monitor v1.0
# ========================================================

# [Config] Specify your NPU LUID
$targetLuid = "11D3B"

# [Config] Sampling interval (seconds)
$interval = 1

# [Config] Max process name length
$maxNameLength = 35

# [Config] Minimum utilization to show (Set to 0 to show everything)
$minUtilization = 0

# Hide cursor (makes it look like a native app)
[Console]::CursorVisible = $false

# Clear screen once at startup
Clear-Host

# Use try...finally to ensure cursor is restored on exit (Ctrl+C)
try {
    while ($true) {
        try {
            # Reset cursor to top-left
            try { [Console]::SetCursorPosition(0, 0) } catch { Clear-Host }

            # 2. Get Window Dimensions (Dynamic Check)
            $winHeight = $Host.UI.RawUI.WindowSize.Height
            $winWidth = $Host.UI.RawUI.WindowSize.Width
            # Reserve 1 line at bottom to prevent auto-scroll when writing the last character
            $maxLines = $winHeight - 1
            $currentLineCount = 0

            # --- Data Retrieval ---
            $path = "\GPU Engine(*luid*$targetLuid*engtype_3D)\Utilization Percentage"
            $counters = Get-Counter -Counter $path -SampleInterval $interval -ErrorAction Stop
            $samples = $counters.CounterSamples

            $outputList = @()
            $totalLoad = 0

            foreach ($s in $samples) {
                $val = $s.CookedValue

                # Always add to Total Load for accuracy
                $totalLoad += $val

                # Only process items with usage > $minUtilization
                if ($val -ge $minUtilization) {
                    if ($s.InstanceName -match "pid_(\d+)_") {
                        # Cast PID to int for correct sorting
                        $pidVal = [int]$matches[1]

                        try {
                            $pName = (Get-Process -Id $pidVal -ErrorAction SilentlyContinue).ProcessName
                        } catch {
                            $pName = "Unknown/Ended"
                        }

                        # Special labeling
                        if ($pName -eq "svchost") { $pName = "svchost (Camera/System)" }
                        if ($pName -eq "audiodg") { $pName = "audiodg (Audio/Voice)" }

                        # Name truncation
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

            # Helper function to write line safely
            function Write-SafeLine ($text, $color="White") {
                if ($script:currentLineCount -lt $script:maxLines) {
                    # PadRight ensures we overwrite old characters on this line
                    $padded = $text.PadRight($script:winWidth - 1)
                    # Trim to avoid wrapping if exact width
                    if ($padded.Length -ge $script:winWidth) { $padded = $padded.Substring(0, $script:winWidth - 1) }

                    Write-Host $padded -ForegroundColor $color
                    $script:currentLineCount++
                }
            }

            $timeStr = Get-Date -Format "HH:mm:ss"

            # Header Section
            Write-SafeLine "=== Windows PowerShell NPU Performance Monitor v1.0 ===" "Cyan"
            Write-SafeLine " "
            Write-SafeLine "Time   : $timeStr"
            Write-SafeLine "Target : $targetLuid (Engine: 3D)"

            # Calculate table width
            $tableTotalWidth = 8 + 1 + $maxNameLength + 1 + 10

            # Prepare separator
            $separator = "-" * $tableTotalWidth

            # Calculate available space for progress bar
            # Label text "Utilization: 100.0% " takes ~20 chars, plus brackets [] takes 2 chars
            # Dynamic calculation: Total Width - Label Length - Borders(2)
            $barWidth = [Math]::Max(10, $tableTotalWidth - 22)
            $fillCount = [int]([Math]::Min($totalLoad, 100) / 100 * $barWidth)
            $barStr = "[" + ("|" * $fillCount) + (" " * ($barWidth - $fillCount)) + "]"

            # Display Utilization
            Write-SafeLine ("Utilization: {0,5:N1}% {1}  " -f $totalLoad, $barStr) "Yellow"
            Write-SafeLine "$separator"

            $fmtString = "{0,-8} {1,-" + $maxNameLength + "} {2,-10}"
            Write-SafeLine ($fmtString -f "PID", "Process Name", "Usage")
            Write-SafeLine "$separator"

            # Data List Section
            if ($outputList.Count -eq 0) {
                Write-SafeLine " (No active processes)" "DarkGray"
            } else {
                # [SORTING LOGIC]
                $outputList | Sort-Object `
                    @{Expression={ $_.Usage -le 0 }; Ascending=$true}, `
                    @{Expression="Usage"; Descending=$true}, `
                    @{Expression="Process"; Ascending=$true}, `
                    @{Expression="PID"; Ascending=$true} | ForEach-Object {
                    # Stop printing if we run out of screen space
                    if ($currentLineCount -ge $maxLines) { break }

                    $u = $_.Usage
                    if ($u -gt 0) {
                        $color = "Green"
                        $uStr = "{0,5:N1}%" -f $u
                    } else {
                        $color = "DarkGray"
                        $uStr = "  0.0%"
                    }
                    # Add 5 spaces padding to ensure old data is overwritten
                    Write-SafeLine (($fmtString -f $_.PID, $_.Process, $uStr) + "     ") $color
                }
            }

            # --- Cleaning Residual Lines (Anti-Ghosting) ---
            # Fill the REST of the screen with empty lines to clear old data
            # But DO NOT exceed window height
            while ($currentLineCount -lt $maxLines) {
                Write-SafeLine " "
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
    Write-Host "Monitor stopped. Cursor restored." -ForegroundColor Gray
}
