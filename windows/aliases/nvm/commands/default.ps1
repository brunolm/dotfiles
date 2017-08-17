. "$PSScriptRoot\_base.ps1"

$isHelp = ($args -contains "--help" -or $args -contains "-h");

if ($isHelp) {
    Write-Host ""
    Write-Host -ForegroundColor Green "nvm default <version>"
    Write-Host "  Sets node default version to <version>"
    Write-Host ""
    Write-Host "Example usage:"
    Write-Host -ForegroundColor Green "  nvm default 8"
    Write-Host ""
}
else {
    Node-Set-Default $1
}
