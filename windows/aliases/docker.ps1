Function c { docker-compose $args }
Function cb { docker-compose build $args }
Function cup { docker-compose up $args }
Function cr { docker-compose run -d --service-ports --rm $args }
Function crl { docker-compose run -d --service-ports --rm local $args }
Function crd { docker-compose run -d --service-ports --rm develop $args }
Function crprod { docker-compose run -d --service-ports --rm production $args }
Function crt { docker-compose run -d --rm test $args }
Function crp { docker-compose run -d --rm provision $args }
Function crci { docker-compose run -d --rm ci $args }
Function cps { docker-compose ps $args }
Function clogs { docker-compose logs $args }

Function docker-cleanup() {
  docker rmi $(docker images -q -f dangling=true)
  docker run -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker:/var/lib/docker --rm martin/docker-cleanup-volumes #--dry-run
}

Function docker-reset {
  docker stop $(docker ps -q)
  docker rm $(docker ps -aq)
}

Function docker-reset-force() {
  docker rm -f $(docker ps -aq)
}

Function docker-proxy {
  docker run --privileged=true -d --name dockito-proxy -v /data/dockito-proxy/certs:/etc/nginx/certs -v /var/run/docker.sock:/tmp/docker.sock -p 80:80 -p 443:443 dockito/proxy:latest
}

Function docker-vault {
  docker run -d --name dockito-vault -p 14242:3000 -v C:/Users/bruno/.ssh:/vault/.ssh dockito/vault
}

Function docker-up {
  docker-reset
  docker-proxy
  docker-vault
}

Function docker-up-force() {
  docker-reset-force
  docker-up
}

Function dup() {
  docker-up
}

Function dup-force() {
  docker-up-force
}

function dreset() {
  docker-reset
}

function dreset-force() {
  docker-reset-force
}

Function dps() {
  $NAME = $args[0]

  if ($NAME -and $NAME.ToString().StartsWith("-")) {
    $NAME = ""
    $PARAMS = $args
  }
  else {
    $PARAMS = $args | select -Skip 1
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
Function dpsi() {
  docker ps --filter "name=$args" --filter status=running --format '{{.ID}} {{.Names}} ---> {{.Status}}\n  {{.Image}}\n  {{.Mounts}}\n  {{.Command}}\n  {{.Ports}}\n'
}

Function dps-exited() {
  dps $args -e
}

Function dps-all() {
  dps $args -a
}

Function dbash() {
  $NAME = $args[0]

  echo ""
  docker ps -a --filter "name=$NAME" --format "{{.Names}}\t{{.ID}}" | Sort-Object -Descending | Select-Object -first 1
  docker exec -it $(docker ps -q --filter "name=$NAME" | Sort-Object -Descending | Select-Object -first 1) bash
}

Function dlogs() {
  $NAME = $args[0]
  $PARAMS = $args | select -Skip 1

  echo ""
  docker ps -a --filter "name=$NAME" --format "{{.Names}}\t{{.ID}}" | Sort-Object -Descending | Select-Object -first 1
  docker logs $PARAMS $(docker ps -aq --filter "name=$NAME" | Sort-Object -Descending | Select-Object -first 1)
}

Function dstart() {
  $NAME = $args[0]

  docker start $(docker ps -aq --filter "name=$NAME" | Sort-Object -Descending | Select-Object -first 1)
}

Function drestart() {
  $NAME = $args[0]

  docker restart $(docker ps -aq --filter "name=$NAME" | Sort-Object -Descending | Select-Object -first 1)
}

Function dstop() {
  $NAME = $args[0]

  docker stop $(docker ps -aq --filter "name=$NAME" | Sort-Object -Descending | Select-Object -first 1)
}

Function dre() {
  docker rm -f $(docker ps -q --filter status=exited)
}
