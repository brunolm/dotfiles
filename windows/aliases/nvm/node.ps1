$env:NODE_DIR = "C:\Program Files\nodejs";
$env:NODE_VERSIONS_DIR = (Join-Path $env:NODE_DIR "versions");

function nvm(
    [ValidateSet(
        "deactivate",
        "default",
        "install",
        "ls-remote",
        "ls",
        "use"
    )]
    $command,
    [Alias("h")][Switch]
    $help
) {
    if ($command) {
        $commandPath = "$PSScriptRoot\commands\$command.ps1";

        & "$commandPath" @args $(If ($help) {"--help"})
    }
    elseif ($help) {
        Write-Host "Usage:"
        Write-Host -ForegroundColor Green "  nvm <command> <args>"

        Write-Host ""
        Write-Host "Available commands"

        Write-Host "deactivate"
        Write-Host "default"
        Write-Host "install"
        Write-Host "ls-remote"
        Write-Host "ls"
        Write-Host "use"

        Write-Host ""
        Write-Host "Use -h or --help for info on each command"
        Write-Host ""
    }
}
