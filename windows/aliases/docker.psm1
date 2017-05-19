function cup { docker-compose up $args }
function cr { docker-compose run --service-ports --rm $args }

function crl { docker-compose run --service-ports --rm local $args }
function crd { docker-compose run --service-ports --rm develop $args }
function crp { docker-compose run --service-ports --rm production $args }
function crb { docker-compose run --service-ports --rm build $args }
function crs { docker-compose run --service-ports --rm setup $args }

function crt { docker-compose run --rm test $args }
function crci { docker-compose run --rm ci $args }

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

#region Bash / Logs

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

Set-Alias -Name "dbash" -Value Invoke-DockerBash
Set-Alias -Name "dlogs" -Value Invoke-DockerLogs

#endregion

#region Start / Reset

function Reset-Containers() {
  if ((docker ps -a | Measure-Object -Line).Lines -gt 1) {
    docker rm -f $(docker ps -qa)
  }
}

function Start-DockitoProxy() {
  $containerName = "dockito-proxy"
  $exists = (docker ps -a --filter name=$containerName | Measure-Object -Line).Lines -gt 1

  if ($exists) {
    Write-Output "Removing $containerName..."
    docker rm -f $(docker ps -aq --filter name=$containerName)
  }

  Write-Output "Starting $containerName..."
  docker run --privileged=true -d --name $containerName -v /data/dockito-proxy/certs:/etc/nginx/certs -v /var/run/docker.sock:/tmp/docker.sock -p 80:80 -p 443:443 dockito/proxy:latest
}

function Start-DockitoVault() {
  $containerName = "dockito-vault"
  $exists = (docker ps -a --filter name=$containerName | Measure-Object -Line).Lines -gt 1

  if ($exists) {
    Write-Output "Removing $containerName..."
    docker rm -f $(docker ps -aq --filter name=$containerName)
  }

  Write-Output "Starting $containerName..."
  $sshfolder = "${env:HomeDrive}${env:HomePath}\.ssh\bravi"
  docker run -d --name $containerName -p 14242:3000 -v ${sshfolder}:/vault/.ssh dockito/vault
}

function Start-DockerEtcd2() {
  $containerName = "etcd2"
  $exists = (docker ps -a --filter name=$containerName | Measure-Object -Line).Lines -gt 1

  if ($exists) {
    Write-Output "Removing $containerName..."
    docker rm -f $(docker ps -aq --filter name=$containerName)
  }

  Write-Output "Starting $containerName..."
  docker run -d -ti --name etcd2 -p 4001:4001 -p 2379:2379 quay.io/coreos/etcd:v2.1.2 -name devbox -advertise-client-urls "http://10.0.75.2:2379,http://10.0.75.2:4001" -listen-client-urls "http://0.0.0.0:2379,http://0.0.0.0:4001" -debug
}

function Start-BaseContainers() {
  Start-DockitoProxy
  Start-DockitoVault
  Start-DockerEtcd2
}

Set-Alias -Name "dup" -Value Start-BaseContainers
Set-Alias -Name "docker-proxy" -Value Start-DockitoProxy
Set-Alias -Name "docker-vault" -Value Start-DockitoVault
Set-Alias -Name "docker-etcd2" -Value Start-DockerEtcd2

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
