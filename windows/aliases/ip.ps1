function Get-IPExternal() {
    (Invoke-WebRequest ifconfig.me/ip).Content.Trim()
}

function pi {
    param(
        [Parameter(Position = 0)]
        [string]$Target = "8.8.8.8"
    )

    $e = [char]27
    $reset = "$e[0m"
    $bold = "$e[1m"
    $red = "$e[31m"
    $green = "$e[32m"
    $yellow = "$e[33m"
    $cyan = "$e[36m"
    $gray = "$e[90m"
    $clearEol = "$e[K"

    function Format-Latency([int]$ms) {
        if ($ms -le 50) { return "$green${ms}ms$reset" }
        if ($ms -le 150) { return "$yellow${ms}ms$reset" }
        return "$red${ms}ms$reset"
    }

    function Format-Status([string]$s, [int]$n) {
        $color = if ($s -eq "Success") { $green }
                 elseif ($s -eq "TimedOut") { $yellow }
                 else { $red }
        return "$color$s$reset=$bold$n$reset"
    }

    $ping = New-Object System.Net.NetworkInformation.Ping
    $history = [System.Collections.Generic.Queue[string]]::new()
    $statusCounts = [ordered]@{}
    $times = [System.Collections.Generic.List[int]]::new()
    $total = 0

    Clear-Host
    [Console]::CursorVisible = $false

    try {
        while ($true) {
            $total++
            $time = $null
            $status = $null
            try {
                $reply = $ping.Send($Target, 1000)
                $status = $reply.Status.ToString()
                if ($status -eq "Success") {
                    $time = [int]$reply.RoundtripTime
                    $times.Add($time)
                }
            }
            catch {
                $status = "Exception"
            }

            if (-not $statusCounts.Contains($status)) {
                $statusCounts[$status] = 0
            }
            $statusCounts[$status]++

            $stamp = (Get-Date).ToString("HH:mm:ss")
            if ($null -ne $time) {
                $line = "$gray[$stamp]$reset $green✓$reset Reply from $cyan$Target${reset}: time=$(Format-Latency $time)"
            }
            else {
                $statusColor = if ($status -eq "TimedOut") { $yellow } else { $red }
                $mark = if ($status -eq "TimedOut") { "⧗" } else { "✗" }
                $line = "$gray[$stamp]$reset $statusColor$mark$reset $cyan$Target${reset}: $statusColor$status$reset"
            }

            $history.Enqueue($line)
            while ($history.Count -gt 10) { [void]$history.Dequeue() }

            $width = [Math]::Max(40, [Console]::WindowWidth - 1)
            $sep = "$gray$('─' * [Math]::Min(60, $width))$reset"

            $output = [System.Collections.Generic.List[string]]::new()
            $output.Add("$bold${cyan}Pinging$reset $cyan$Target$reset  $gray(sent: $bold$total$reset$gray)  press ${bold}r$reset$gray to reset$reset")
            $output.Add($sep)
            foreach ($l in $history.ToArray()) { $output.Add($l) }
            for ($i = $history.Count; $i -lt 10; $i++) { $output.Add("") }
            $output.Add($sep)

            $countParts = $statusCounts.GetEnumerator() | ForEach-Object { Format-Status $_.Key $_.Value }
            $output.Add("${cyan}Counts:$reset " + ($countParts -join "  "))

            if ($times.Count -gt 0) {
                $stats = $times | Measure-Object -Minimum -Maximum -Average
                $minStr = Format-Latency ([int]$stats.Minimum)
                $maxStr = Format-Latency ([int]$stats.Maximum)
                $avgStr = Format-Latency ([int][Math]::Round($stats.Average))
                $avgRaw = "{0:N1}" -f $stats.Average
                $output.Add("${cyan}Ping (ms)$reset  min=$minStr  avg=$avgStr $gray($avgRaw)$reset  max=$maxStr")
            }
            else {
                $output.Add("${cyan}Ping (ms)$reset  ${gray}no successful replies yet$reset")
            }

            [Console]::SetCursorPosition(0, 0)
            foreach ($l in $output) {
                [Console]::Write($l + $clearEol + "`n")
            }

            $deadline = [Environment]::TickCount + 800
            while ([Environment]::TickCount -lt $deadline) {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if ($key.KeyChar -eq 'r' -or $key.KeyChar -eq 'R') {
                        $history.Clear()
                        $statusCounts.Clear()
                        $times.Clear()
                        $total = 0
                        Clear-Host
                        break
                    }
                }
                Start-Sleep -Milliseconds 30
            }
        }
    }
    finally {
        [Console]::CursorVisible = $true
        [Console]::Write($reset)
        Write-Host ""
    }
}
