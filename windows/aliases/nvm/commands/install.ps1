. "$PSScriptRoot\_base.ps1"

$isHelp = ($args -contains "--help" -or $args -contains "-h");

if ($isHelp) {
    Write-Host ""
    Write-Host -ForegroundColor Green "nvm install <version>"
    Write-Host "  Instal node <version> on versions folder"
    Write-Host ""
    Write-Host "Example usage:"
    Write-Host -ForegroundColor Green "  nvm install 8"
    Write-Host -ForegroundColor Green "  nvm install v8"
    Write-Host -ForegroundColor Green "  nvm install 8.3.0"
    Write-Host ""
}
else {
    Node-Install @args
}
