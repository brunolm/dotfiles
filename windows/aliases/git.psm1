function Clear-GitBranches() {
    git remote prune origin
    (git branch --merged) -split '[\n]' `
        | Where-Object {$_} `
        | Select-Object -Property @{N='Name';E={$_.Trim().Replace('* ', '')}} `
        | Where-Object {$_.Name -notin ('develop','master','qa')}
}

Export-ModuleMember -Function "*"
Export-ModuleMember -Alias "*"
