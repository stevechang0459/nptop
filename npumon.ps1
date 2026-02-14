# 硬性指定您截圖中的 LUID (請確認這還是目前的 LUID)
$targetLuid = "11D3B" 

# 擴大取樣區間到 2 秒，以平滑化數值 (解決鋸齒問題)
$interval = 2

Clear-Host
Write-Host "=== NPU Raw Monitor (Debug Mode) ===" -ForegroundColor Cyan
Write-Host "Target: *$targetLuid* (Engine: 3D)"
Write-Host "Sampling Interval: $interval seconds..."
Write-Host "-------------------------------------"

while ($true) {
    try {
        # 使用最寬鬆的通配符 (*3D*) 來確保一定能抓到 engtype_3D
        $path = "\GPU Engine(*luid*$targetLuid*engtype_3D)\Utilization Percentage"
        
        # 抓取數據
        $counters = Get-Counter -Counter $path -SampleInterval $interval -ErrorAction Stop
        
        $samples = $counters.CounterSamples
        
        if ($samples.Count -eq 0) {
            Write-Host " [!] 找不到任何 Counter。確認 LUID 是否變更？" -ForegroundColor Red
        } else {
            foreach ($s in $samples) {
                # 即使是 0 也顯示出來
                $val = $s.CookedValue
                $name = $s.InstanceName
                
                # 簡單解析 PID 讓你看得懂是誰
                if ($name -match "pid_(\d+)_") {
                    $pidVal = $matches[1]
                    try { $pName = (Get-Process -Id $pidVal -ErrorAction SilentlyContinue).ProcessName } catch { $pName = "Unknown" }
                } else {
                    $pidVal = "N/A"
                    $pName = "N/A"
                }

                # 格式化輸出
                if ($val -gt 0) {
                    Write-Host "PID: $pidVal ($pName) | Usage: $(" {0,5:N1}" -f $val)%" -ForegroundColor Green
                } else {
                    # 數值為 0 用灰色顯示，證明有抓到但沒負載
                    Write-Host "PID: $pidVal ($pName) | Usage: 0.0% (Idle/Gap)" -ForegroundColor DarkGray
                }
            }
        }
        Write-Host "-------------------------------------"
        
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
        Start-Sleep 1
    }
}