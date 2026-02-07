$ErrorActionPreference = 'SilentlyContinue'

param(
  [int]$TimeoutMinutes = 10,
  [int]$PollSeconds = 1,
  [string]$LogPath = '.\community\r1-openclaw-kit\r1-node-pair-watch.log'
)

New-Item -ItemType Directory -Path (Split-Path -Path $LogPath -Parent) -Force | Out-Null

"[$(Get-Date -Format o)] watcher started timeout=${TimeoutMinutes}m poll=${PollSeconds}s" | Out-File -FilePath $LogPath -Encoding utf8 -Append

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
while ((Get-Date) -lt $deadline) {
  $raw = & openclaw gateway call node.pair.list --json 2>$null
  if (-not [string]::IsNullOrWhiteSpace($raw)) {
    try {
      $data = $raw | ConvertFrom-Json
      $pending = @($data.pending)
      foreach ($p in $pending) {
        $rid = [string]$p.requestId
        $name = [string]$p.displayName
        $platform = [string]$p.platform
        $nodeId = [string]$p.nodeId
        "[$(Get-Date -Format o)] pending requestId=$rid displayName=$name platform=$platform nodeId=$nodeId" | Out-File -FilePath $LogPath -Encoding utf8 -Append
        if (-not [string]::IsNullOrWhiteSpace($rid)) {
          $params = ('{"requestId":"' + $rid + '"}')
          $resp = & openclaw gateway call node.pair.approve --params $params --json 2>&1
          "[$(Get-Date -Format o)] approve requestId=$rid result=$resp" | Out-File -FilePath $LogPath -Encoding utf8 -Append
          Write-Output "APPROVED:$rid"
          exit 0
        }
      }
    } catch {
      "[$(Get-Date -Format o)] parse error raw=$raw" | Out-File -FilePath $LogPath -Encoding utf8 -Append
    }
  }

  Start-Sleep -Seconds $PollSeconds
}

"[$(Get-Date -Format o)] timeout no pending node pair" | Out-File -FilePath $LogPath -Encoding utf8 -Append
Write-Output 'TIMEOUT'
exit 2
