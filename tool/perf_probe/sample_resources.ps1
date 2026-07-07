# דוגם CPU/RAM חיצוני לעץ התהליכים של otzaria (כולל תהליכי-בן כמו WebView2).
# רץ עד שקובץ ה-stop מופיע או שהתהליך נעלם (אחרי שהופיע לפחות פעם אחת).
# פלט: CSV עם שורה לכל תהליך בכל דגימה.
param(
  [Parameter(Mandatory = $true)][string]$OutCsv,
  [Parameter(Mandatory = $true)][string]$StopFile,
  [string]$ProcessName = "otzaria",
  [int]$IntervalMs = 500
)

$ErrorActionPreference = "SilentlyContinue"

"epoch_ms,pid,name,cpu_total_s,ws_mb,priv_mb" | Set-Content -LiteralPath $OutCsv -Encoding UTF8

function Get-ProcessTreeIds([int]$RootPid) {
  $all = Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId
  $ids = New-Object System.Collections.Generic.HashSet[int]
  [void]$ids.Add($RootPid)
  $changed = $true
  while ($changed) {
    $changed = $false
    foreach ($p in $all) {
      if ($ids.Contains([int]$p.ParentProcessId) -and -not $ids.Contains([int]$p.ProcessId)) {
        [void]$ids.Add([int]$p.ProcessId)
        $changed = $true
      }
    }
  }
  return @($ids)
}

$rootPid = $null
$sawProcess = $false
$treeRefreshCounter = 0
$treeIds = @()

while ($true) {
  if (Test-Path $StopFile) { break }

  if ($null -eq $rootPid) {
    $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc) {
      $rootPid = $proc.Id
      $sawProcess = $true
      $treeIds = Get-ProcessTreeIds $rootPid
    } else {
      if ($sawProcess) { break }
      Start-Sleep -Milliseconds 1000
      continue
    }
  }

  # רענון עץ התהליכים אחת ל-10 דגימות (שאילתת CIM יקרה יחסית).
  $treeRefreshCounter++
  if ($treeRefreshCounter -ge 10) {
    $treeRefreshCounter = 0
    $treeIds = Get-ProcessTreeIds $rootPid
  }

  $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $rootAlive = $false
  $lines = foreach ($procId in $treeIds) {
    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if ($p) {
      if ($procId -eq $rootPid) { $rootAlive = $true }
      $cpu = 0.0
      try { $cpu = [math]::Round($p.TotalProcessorTime.TotalSeconds, 3) } catch {}
      $ws = [math]::Round($p.WorkingSet64 / 1MB, 1)
      $priv = [math]::Round($p.PrivateMemorySize64 / 1MB, 1)
      "$now,$procId,$($p.ProcessName),$cpu,$ws,$priv"
    }
  }
  if ($lines) { Add-Content -LiteralPath $OutCsv -Value $lines -Encoding UTF8 }

  if (-not $rootAlive) {
    # ייתכן שהתהליך הוחלף (build מחדש) — ננסה לאתר מחדש פעם אחת.
    $rootPid = $null
    Start-Sleep -Milliseconds 1000
    $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc) {
      $rootPid = $proc.Id
      $treeIds = Get-ProcessTreeIds $rootPid
      continue
    }
    break
  }

  Start-Sleep -Milliseconds $IntervalMs
}
