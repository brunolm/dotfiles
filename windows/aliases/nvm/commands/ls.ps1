. "$PSScriptRoot\_base.ps1"

$isHelp = ($args -contains "--help" -or $args -contains "-h");

if ($isHelp) {
    Write-Host ""
    Write-Host -ForegroundColor Green "nvm ls"
    Write-Host "  Lists all installed node versions"
    Write-Host ""
}
else {
    Node-List-Installed
}
