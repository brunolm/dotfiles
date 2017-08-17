. "$PSScriptRoot\_base.ps1"

$isHelp = ($args -contains "--help" -or $args -contains "-h");

if ($isHelp) {
    Write-Host ""
    Write-Host -ForegroundColor Green "nvm ls-remote [version]"
    Write-Host "  List remote versions matching [version] if specified"
    Write-Host ""
    Write-Host "Example usage:"
    Write-Host -ForegroundColor Green "  nvm ls-remote 8"
    Write-Host -ForegroundColor Green "  nvm ls-remote v8"
    Write-Host ""
}
else {
    Node-List-Versions @args
}
