# ========================================================
#  NPU Raw Dashboard (Fixed Formatting + Name Truncation)
# ========================================================

# [設定] 指定您的 NPU LUID
$targetLuid = "11D3B" 

# [設定] 取樣間隔 (秒)
$interval = 1

# [設定] Process Name 最大顯示長度 (超過會顯示 ...)
$maxNameLength = 35

while ($true) {
    try {
        # 1. 抓取數據 (使用寬鬆路徑)
        $path = "\GPU Engine(*luid*$targetLuid*engtype_3D)\Utilization Percentage"
        $counters = Get-Counter -Counter $path -SampleInterval $interval -ErrorAction Stop
        $samples = $counters.CounterSamples
        
        # 2. 準備數據列表
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
                
                # 特殊標註
                if ($pName -eq "svchost") { $pName = "svchost (Camera/System)" }
                if ($pName -eq "audiodg") { $pName = "audiodg (Audio/Voice)" }
                
                # --- 長度裁切邏輯 ---
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

        # 3. 清除並繪製
        Clear-Host
        $timeStr = Get-Date -Format "HH:mm:ss"
        Write-Host "=== Windows Powershell NPU Performance Monitor v1.0 ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Time   : $timeStr"
        Write-Host "Target : $targetLuid (Engine: 3D)"

        # --- [UI 優化核心] 自動計算寬度與對齊 ---

        # 1. 計算表格的總寬度 (PID=8 + Space=1 + Name=$max + Space=1 + Usage=10)
        $tableTotalWidth = 8 + 1 + $maxNameLength + 1 + 10

        # 2. 準備分隔線
        $separator = "-" * $tableTotalWidth

        # 3. 計算進度條可用的空間
        # 標籤文字 "Total Load: 100.0% " 大約佔 19 字元，加上邊界 [] 佔 2 字元
        # 我們動態計算：總寬度 - 標籤長度 - 邊界(2)
        $labelLength = 19 
        $barWidth = $tableTotalWidth - $labelLength - 2

        # 4. 繪製固定長度的進度條 [====....]
        $cappedLoad = [Math]::Min($totalLoad, 100)
        $fillCount = [int](($cappedLoad / 100) * $barWidth)
        $emptyCount = $barWidth - $fillCount

        if ($barWidth -lt 10) { $barWidth = 10 } # 防止設太短變負數

        # 組合字串 (使用 . 作為空心，讓邊界更明顯)
        $barStr = "[" + ("=" * $fillCount) + (" " * $emptyCount) + "]"
        
        # 顯示總負載 (確保括號正確，避免顏色參數錯誤)
        Write-Host ("Total Load: {0,5:N1}% {1}" -f $totalLoad, $barStr) -ForegroundColor Yellow
        # Write-Host ""
        
        # 顯示分隔線與標題
        Write-Host $separator
        $fmtString = "{0,-8} {1,-" + $maxNameLength + "} {2,-10}"
        Write-Host ($fmtString -f "PID", "Process Name", "Usage")
        Write-Host $separator

        if ($outputList.Count -eq 0) {
            Write-Host " (No counters found)" -ForegroundColor Red
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
                Write-Host ($fmtString -f $_.PID, $_.Process, $uStr) -ForegroundColor $color
            }
        }
        
    } catch {
        Clear-Host
        Write-Host "=== NPU Monitor Paused ===" -ForegroundColor Yellow
        Write-Host "Error accessing counters (or Device Sleeping)."
        Start-Sleep 1
    }
}
