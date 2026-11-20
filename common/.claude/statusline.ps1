$ErrorActionPreference = 'SilentlyContinue'

$data = [Console]::In.ReadToEnd() | ConvertFrom-Json

$esc = [char]27
$reset = "$esc[0m"
$cyan = "$esc[36m"
$yellow = "$esc[33m"
$dim = "$esc[2m"
$sep = " $dim|$reset "

$dir = $data.workspace.current_dir
if (-not $dir) { $dir = $data.cwd }
if (-not $dir) { $dir = (Get-Location).Path }

$parts = @()

$folder = Split-Path -Leaf $dir
if (-not $folder) { $folder = $dir }
$parts += "$cyan$folder$reset"

if (Test-Path -LiteralPath $dir) {
    $branch = git -C $dir --no-optional-locks branch --show-current 2>$null
    if ($LASTEXITCODE -eq 0) {
        if (-not $branch) { $branch = git -C $dir --no-optional-locks rev-parse --short HEAD 2>$null }
        $dirty = git -C $dir --no-optional-locks status --porcelain 2>$null | Select-Object -First 1
        $marker = if ($dirty) { '*' } else { '' }
        if ($branch) { $parts += "$yellow$branch$marker$reset" }
    }
}

$model = $data.model.display_name
if ($model) { $parts += "$dim$model$reset" }

$used = $data.context_window.used_percentage
if ($null -ne $used) {
    $pct = [math]::Round([double]$used)
    $color = if ($pct -ge 80) { "$esc[31m" } elseif ($pct -ge 60) { "$esc[33m" } else { "$esc[32m" }
    $parts += "ctx $color$pct%$reset"
}

[Console]::Out.Write($parts -join $sep)
