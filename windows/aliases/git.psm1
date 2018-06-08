function Clear-GitBranches() {
    git fetch --all --prune
    git branch -vv `
        | Where-Object { $_ -like '*origin/*: gone*' } `
        | Select-Object -Property @{N='Name';E={($_ -split ' ')[2]}} `
        | ForEach-Object { git branch -d $_.Name }
}

function Update-Development() {
    git fetch --all --prune
    git checkout development
    git pull
}

Export-ModuleMember -Function "*"
Export-ModuleMember -Alias "*"
