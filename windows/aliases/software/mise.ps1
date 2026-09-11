# Installing mise is only half the job: the toolchains in ~\.config\mise\config.toml are what put
# node/npm on the PATH for the Codex install that follows.
function B-Software-Update-Mise() {
  Software-WingetInstall 'jdx.mise'

  if (!(Get-Command mise -ErrorAction SilentlyContinue)) {
    Write-Warning "mise is not on the PATH yet; open a new shell and run 'mise install'."
    return
  }

  mise install

  # The profile brings tools in with `mise activate`; a shell that started before mise existed
  # reaches them through the shims directory instead.
  $shims = Join-Path $env:LOCALAPPDATA 'mise\shims'
  if ((Test-Path $shims) -and (@($env:Path -split ';') -notcontains $shims)) {
    $env:Path = "$shims;$env:Path"
  }
}
