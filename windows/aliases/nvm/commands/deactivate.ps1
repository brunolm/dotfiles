. "$PSScriptRoot\_base.ps1"

$isHelp = ($args -contains "--help" -or $args -contains "-h");

if ($isHelp) {
    Write-Host ""
    Write-Host -ForegroundColor Green "nvm deactivate"
    Write-Host "  Sets node back to default PATH"
    Write-Host ""
}
else {
    Node-Use default
}
