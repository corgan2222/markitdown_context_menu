function Invoke-WithMutex {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Action)
    $mutex = New-Object System.Threading.Mutex($false, "Global\$Name")
    [void]$mutex.WaitOne()
    try { & $Action } finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
}

function Add-ToQueue {
    param(
        [Parameter(Mandatory)][string]$QueuePath,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$MutexName
    )
    Invoke-WithMutex -Name $MutexName -Action {
        $wasEmpty = -not (Test-Path $QueuePath) -or ((Get-Item $QueuePath).Length -eq 0)
        $dir = Split-Path -Parent $QueuePath
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -Path $QueuePath -Value $Path -Encoding utf8
        return $wasEmpty
    }
}

function Read-AndClearQueue {
    param([Parameter(Mandatory)][string]$QueuePath, [Parameter(Mandatory)][string]$MutexName)
    Invoke-WithMutex -Name $MutexName -Action {
        if (-not (Test-Path $QueuePath)) { return @() }
        $lines = @(Get-Content -Path $QueuePath | Where-Object { $_ -ne '' })
        Remove-Item -Path $QueuePath -Force
        return $lines
    }
}

Export-ModuleMember -Function Add-ToQueue, Read-AndClearQueue, Invoke-WithMutex
