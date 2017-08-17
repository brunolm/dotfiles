. "$PSScriptRoot\_base.ps1"

$isHelp = ($args -contains "--help" -or $args -contains "-h");

if ($isHelp) {
    Write-Host ""
    Write-Host -ForegroundColor Green "nvm use <version>"
    Write-Host "  Set PATH to use specified <version>"
    Write-Host ""
    Write-Host "Example usage:"
    Write-Host -ForegroundColor Green "  nvm use 8"
    Write-Host ""
}
else {
    Node-Use $1
}
