function cup { docker-compose up $args }
function cr { docker-compose run --service-ports --rm $args }

function crl { docker-compose run --service-ports --rm local $args }
function crd { docker-compose run --service-ports --rm develop $args }
function crp { docker-compose run --service-ports --rm production $args }
function crb { docker-compose run --service-ports --rm build $args }
function crs { docker-compose run --service-ports --rm setup $args }

function crt { docker-compose run --rm test $args }
function crci { docker-compose run --rm ci $args }
function fixDockerWsl { wsl -d docker-desktop echo }

#region List

function Get-DockerContainers() {
  $NAME = $args[0]

  if ($NAME -and $NAME.ToString().StartsWith("-")) {
    $NAME = ""
    $PARAMS = $args
  }
  else {
    $PARAMS = $args | Select-Object -Skip 1
  }

  if ($PARAMS -contains "-a") {
    docker ps -a --filter "name=$NAME" --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}'
  }
  elseif ($PARAMS -contains "-e") {
    docker ps --filter "status=exited" --filter "name=$NAME" --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}'
  }
  else {
    docker ps --filter "status=running" --filter "name=$NAME" --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}'
  }
}
function Get-DockerContainersAndImages() {
  docker ps --filter "name=$args" --filter status=running --format '{{.ID}} {{.Names}} ---> {{.Status}}\n  {{.Image}}\n  {{.Mounts}}\n  {{.Command}}\n  {{.Ports}}\n'
}

Set-Alias -Name "dps" -Value Get-DockerContainers
Set-Alias -Name "dpsi" -Value Get-DockerContainersAndImages

#endregion

#region Restart / Stop / Remove / Bash / Logs

function Invoke-DockerRestart() {
  $NAME = $args[0]

  Write-Output ""
  docker ps -a --filter "name=$NAME" --format "{{.Names}}\t{{.ID}}" | Sort-Object -Descending | Select-Object -first 1
  docker restart $(docker ps -q --filter "name=$NAME" | Sort-Object -Descending | Select-Object -first 1)
}
function Invoke-DockerStop() {
  $NAME = $args[0]

  Write-Output ""
  docker ps -a --filter "name=$NAME" --filter "status=running" --format "{{.Names}}\t{{.ID}}" | Sort-Object -Descending | Select-Object -first 1
  docker stop $(docker ps -q --filter "name=$NAME" --filter "status=running" | Sort-Object -Descending | Select-Object -first 1)
}

function Invoke-DockerRemove() {
  $NAME = $args[0]

  Write-Output ""
  docker ps -a --filter "name=$NAME" --format "{{.Names}}\t{{.ID}}" | Sort-Object -Descending | Select-Object -first 1
  docker rm -f $(docker ps -q --filter "name=$NAME" | Sort-Object -Descending | Select-Object -first 1)
}

function Invoke-DockerBash() {
  $NAME = $args[0]

  Write-Output ""
  docker ps -a --filter "name=$NAME" --format "{{.Names}}\t{{.ID}}" | Sort-Object -Descending | Select-Object -first 1
  docker exec -it $(docker ps -q --filter "name=$NAME" | Sort-Object -Descending | Select-Object -first 1) bash
}

function Invoke-DockerLogs() {
  $NAME = $args[0]
  $PARAMS = $args | Select-Object -Skip 1

  Write-Output ""
  docker ps -a --filter "name=$NAME" --format "{{.Names}}\t{{.ID}}" | Sort-Object -Descending | Select-Object -first 1
  docker logs $PARAMS $(docker ps -aq --filter "name=$NAME" | Sort-Object -Descending | Select-Object -first 1)
}

Set-Alias -Name "drestart" -Value Invoke-DockerRestart
Set-Alias -Name "dstop" -Value Invoke-DockerStop
Set-Alias -Name "drm" -Value Invoke-DockerRemove
Set-Alias -Name "dbash" -Value Invoke-DockerBash
Set-Alias -Name "dlogs" -Value Invoke-DockerLogs

#endregion

#region Start / Reset

function Reset-Containers() {
  if ((docker ps -a | Measure-Object -Line).Lines -gt 1) {
    docker rm -f $(docker ps -qa)
  }
}

#endregion

#region Clear

function Clear-Volumes() {
  docker run -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker:/var/lib/docker --rm martin/docker-cleanup-volumes #--dry-run
}

function Clear-Images() {
  docker rmi $(docker images -f dangling=true -q)
}

function Clear-Docker() {
  Clear-Images
  Clear-Volumes
}

#endregion

Export-ModuleMember -Function "*"
Export-ModuleMember -Alias "*"
