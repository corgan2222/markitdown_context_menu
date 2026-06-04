BeforeAll {
    Import-Module "$PSScriptRoot/../src/modules/Batch.psm1" -Force
}

Describe 'Queue ownership' {
    AfterEach {
        $q = Join-Path $TestDrive 'queue.txt'
        if (Test-Path $q) { Remove-Item $q -Force }
    }
    It 'first enqueue becomes owner, subsequent do not' {
        $q = Join-Path $TestDrive 'queue.txt'
        $m = 'MarkItDownTest_' + [guid]::NewGuid().ToString('N')
        (Add-ToQueue -QueuePath $q -Path 'C:\a.pdf' -MutexName $m) | Should -BeTrue
        (Add-ToQueue -QueuePath $q -Path 'C:\b.pdf' -MutexName $m) | Should -BeFalse
    }
    It 'drains all queued paths and clears the file' {
        $q = Join-Path $TestDrive 'queue.txt'
        $m = 'MarkItDownTest_' + [guid]::NewGuid().ToString('N')
        Add-ToQueue -QueuePath $q -Path 'C:\a.pdf' -MutexName $m | Out-Null
        Add-ToQueue -QueuePath $q -Path 'C:\b.pdf' -MutexName $m | Out-Null
        $drained = Read-AndClearQueue -QueuePath $q -MutexName $m
        $drained | Should -Be @('C:\a.pdf','C:\b.pdf')
        (Test-Path $q) | Should -BeFalse
    }
}
