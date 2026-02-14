# ========================================================
#  NPU Raw Dashboard (Zero-Flicker & Aligned)
# ========================================================

# [設定] 指定您的 NPU LUID
$targetLuid = "11D3B"

# [設定] 取樣間隔 (秒)
$interval = 0.5
# [設定] Process Name 最大顯示長度
$maxNameLength = 35

# 1. 程式啟動時，先清空一次畫面
Clear-Host

while ($true) {
    try {
        # 2. 將游標重置到左上角 (這就是不閃爍的秘密)
        try { [Console]::SetCursorPosition(0, 0) } catch { Clear-Host }

        # --- 資料抓取邏輯 (維持不變) ---
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

        # --- UI 繪製 (含對齊邏輯) ---
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
        # 標籤文字 "Utilization: 100.0% " 佔 20 字元，加上邊界 [] 佔 2 字元
        # 我們動態計算：總寬度 - 標籤長度 - 邊界(2)
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

        # 顯示列表
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
                # 這裡補上 5 個空白，確保覆蓋掉舊資料
                Write-Host (($fmtString -f $_.PID, $_.Process, $uStr) + "     ") -ForegroundColor $color
            }
        }

        # 3. [關鍵] 清除下方殘留的舊資料 (Ghosting)
        # 假設之前有 20 行，現在只有 5 行，我們要印出空白行把下面蓋掉
        for ($i = 0; $i -lt 10; $i++) {
            Write-Host (" " * ($tableTotalWidth + 5))
        }

    } catch {
        # 錯誤處理時才用 Clear-Host
        Clear-Host
        Write-Host "=== Windows Powershell NPU Performance Monitor v1.0 ===" -ForegroundColor Cyan
        Write-Host "Performance monitor paused, error while accessing counters." -ForegroundColor Yellow
        Start-Sleep 1
    }
}
