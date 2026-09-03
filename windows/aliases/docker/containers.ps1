function B-Docker-Get-Containers() {
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
function B-Docker-Get-ContainersAndImages() {
  docker ps --filter "name=$args" --filter status=running --format '{{.ID}} {{.Names}} ---> {{.Status}}\n  {{.Image}}\n  {{.Mounts}}\n  {{.Command}}\n  {{.Ports}}\n'
}

Set-Alias -Name "dps" -Value B-Docker-Get-Containers
Set-Alias -Name "dpsi" -Value B-Docker-Get-ContainersAndImages

function B-Docker-Restart() {
  $NAME = $args[0]

  Write-Output ""
  docker ps -a --filter "name=$NAME" --format "{{.Names}}\t{{.ID}}" | Sort-Object -Descending | Select-Object -first 1
  docker restart $(docker ps -q --filter "name=$NAME" | Sort-Object -Descending | Select-Object -first 1)
}
function B-Docker-Stop() {
  $NAME = $args[0]

  Write-Output ""
  docker ps -a --filter "name=$NAME" --filter "status=running" --format "{{.Names}}\t{{.ID}}" | Sort-Object -Descending | Select-Object -first 1
  docker stop $(docker ps -q --filter "name=$NAME" --filter "status=running" | Sort-Object -Descending | Select-Object -first 1)
}

function B-Docker-Remove() {
  $NAME = $args[0]

  Write-Output ""
  docker ps -a --filter "name=$NAME" --format "{{.Names}}\t{{.ID}}" | Sort-Object -Descending | Select-Object -first 1
  docker rm -f $(docker ps -q --filter "name=$NAME" | Sort-Object -Descending | Select-Object -first 1)
}

function B-Docker-Bash() {
  $NAME = $args[0]

  Write-Output ""
  docker ps -a --filter "name=$NAME" --format "{{.Names}}\t{{.ID}}" | Sort-Object -Descending | Select-Object -first 1
  docker exec -it $(docker ps -q --filter "name=$NAME" | Sort-Object -Descending | Select-Object -first 1) bash
}

function B-Docker-Logs() {
  $NAME = $args[0]
  $PARAMS = $args | Select-Object -Skip 1

  Write-Output ""
  docker ps -a --filter "name=$NAME" --format "{{.Names}}\t{{.ID}}" | Sort-Object -Descending | Select-Object -first 1
  docker logs $PARAMS $(docker ps -aq --filter "name=$NAME" | Sort-Object -Descending | Select-Object -first 1)
}

Set-Alias -Name "drestart" -Value B-Docker-Restart
Set-Alias -Name "dstop" -Value B-Docker-Stop
Set-Alias -Name "drm" -Value B-Docker-Remove
Set-Alias -Name "dbash" -Value B-Docker-Bash
Set-Alias -Name "dlogs" -Value B-Docker-Logs

function B-Docker-Reset-Containers() {
  if ((docker ps -a | Measure-Object -Line).Lines -gt 1) {
    docker rm -f $(docker ps -qa)
  }
}
