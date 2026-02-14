# ========================================================
#  NPU Raw Dashboard (Fixed Formatting Issue)
# ========================================================

# 指定您的 NPU LUID
$targetLuid = "11D3B" 

# 取樣間隔 (秒)
$interval = 2

while ($true) {
    try {
        # 1. 抓取數據 (使用寬鬆路徑確保抓得到)
        $path = "\GPU Engine(*luid*$targetLuid*engtype_3D)\Utilization Percentage"
        $counters = Get-Counter -Counter $path -SampleInterval $interval -ErrorAction Stop
        $samples = $counters.CounterSamples
        
        # 2. 準備數據列表
        $outputList = @()
        $totalLoad = 0

        foreach ($s in $samples) {
            $val = $s.CookedValue
            $totalLoad += $val
            
            # 解析 PID
            if ($s.InstanceName -match "pid_(\d+)_") {
                $pidVal = $matches[1]
                
                # 取得 Process 名稱
                try { 
                    $pName = (Get-Process -Id $pidVal -ErrorAction SilentlyContinue).ProcessName 
                } catch { 
                    $pName = "Unknown/Ended" 
                }
                
                # 特殊標註
                if ($pName -eq "svchost") { $pName = "svchost (Camera/System)" }
                if ($pName -eq "audiodg") { $pName = "audiodg (Audio/Voice)" }

                $outputList += [PSCustomObject]@{
                    PID = $pidVal
                    Process = $pName
                    Usage = $val
                }
            }
        }

        # 3. 清除舊畫面，只顯示當前資訊
        Clear-Host
        $timeStr = Get-Date -Format "HH:mm:ss"
        Write-Host "=== NPU Raw Dashboard [$timeStr] ===" -ForegroundColor Cyan
        Write-Host "Target: $targetLuid (Engine: 3D)"
        
        # 總負載 (注意這裡加上了括號)
        $bar = "|" + "=" * [Math]::Min([int]($totalLoad), 40)
        Write-Host ("Total Load: {0,5:N1}% {1}" -f $totalLoad, $bar) -ForegroundColor Yellow
        Write-Host "----------------------------------------------------"
        
        # [修正點] 這裡加上了括號 ( )，避免 -f 被誤判為顏色參數
        Write-Host ("{0,-8} {1,-30} {2,-10}" -f "PID", "Process Name", "Usage")
        Write-Host "----------------------------------------------------"

        if ($outputList.Count -eq 0) {
            Write-Host " (No counters found)" -ForegroundColor Red
        } else {
            # 依使用率排序 (高的在上面)，即使是 0 也顯示
            $outputList | Sort-Object Usage -Descending | ForEach-Object {
                $u = $_.Usage
                
                # 顏色邏輯：有負載亮綠色，0% 顯示暗灰色
                if ($u -gt 0.1) {
                    $color = "Green"
                    $uStr = "{0,5:N1}%" -f $u
                } else {
                    $color = "DarkGray"
                    $uStr = "  0.0%"
                }
                
                # [修正點] 這裡也加上了括號
                Write-Host ("{0,-8} {1,-30} {2}" -f $_.PID, $_.Process, $uStr) -ForegroundColor $color
            }
        }
        
    } catch {
        # 錯誤處理
        Clear-Host
        Write-Host "=== NPU Monitor Paused ===" -ForegroundColor Yellow
        Write-Host "Error accessing counters (or Device Sleeping)."
        Write-Host "Details: $_"
        Start-Sleep 1
    }
}
