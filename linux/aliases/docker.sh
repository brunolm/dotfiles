alias c='docker-compose'
alias cb='docker-compose build'
alias cup='docker-compose up'
alias cr='docker-compose run --service-ports --rm'
alias crl='docker-compose run --service-ports --rm local'
alias crd='docker-compose run --service-ports --rm develop'
alias crprod='docker-compose run --rm production'
alias crt='docker-compose run --rm test'
alias crp='docker-compose run --rm provision'
alias crci='docker-compose run --rm ci'
alias cps='docker-compose ps'
alias clogs='docker-compose logs'

docker-cleanup() {
  docker rmi $(docker images -q -f dangling=true)
  docker run -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker:/var/lib/docker --rm martin/docker-cleanup-volumes #--dry-run
}

docker-reset() {
  docker stop $(docker ps -q)
  docker rm $(docker ps -aq)
}

docker-reset-force() {
  docker rm -f $(docker ps -aq)
}

dps() {
  local SEARCH="${1:=/}"
  local ARGS="${2:=/}"
  local FILTER=""

  if [[ $SEARCH == \-* ]]; then
    SEARCH=""
    ARGS="${1:=/}"
  fi

  if [[ " ${ARGS[@]} " =~ " -a " ]]; then
    FILTER="-a"
  elif [[ " ${ARGS[@]} " =~ " -e " ]]; then
    FILTER="--filter status=exited"
  else
    FILTER="--filter status=running"
  fi

  FILTER=(`echo ${FILTER}`)

  docker ps $FILTER --filter "name=$SEARCH" --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}'
}
dpsi() {
  local SEARCH="${1:=/}"
  docker ps --filter "name=$SEARCH" --filter status=running --format '{{.ID}} {{.Names}} ---> {{.Status}}\n  {{.Image}}\n  {{.Mounts}}\n  {{.Command}}\n  {{.Ports}}\n'
}

dps-exited() { dps -e }
dpse() { dps -e }

dps-all() { dps -a }
dpsa() { dps -a }

dbash() {
  echo ""
  docker ps -a --filter "name=$1" --format "{{.Names}}\t{{.ID}}" | sort -r | head -1
  docker exec -it $(docker ps -aq --filter "name=$1" | sort -r | head -1) bash
}

drestart() {
  echo ""
  docker ps -a --filter "name=$1" --format "{{.Names}}" | sort -r | head -1
  docker restart $(docker ps -aq --filter "name=$1" | sort -r | head -1)
}

dstop() {
  echo ""
  docker ps -a --filter "name=$1" --format "{{.Names}}" | sort -r | head -1
  docker stop $(docker ps -aq --filter "name=$1" | sort -r | head -1)
}

drestart-exited() {
  docker restart $(docker ps -q --filter status=exited)
}
dre() { drestart-exited }

dlogs() {
  local NAME=$1
  local ARGS=${@:2}
  ARGS=(`echo ${ARGS}`)

  echo ""
  docker ps -a --filter "name=$NAME" --format "{{.Names}}\t{{.ID}}" | sort -r | head -1
  docker logs $ARGS $(docker ps -aq --filter "name=$NAME" | sort -r | head -1)
}

dreset() {
  docker-reset
}
dresetforce() {
  docker-reset-force
}


update-docker() {
  wget -qO- https://get.docker.com/ | sh
  sudo usermod -aG docker $USER
}

update-docker-compose() {
  local VERSION=$1

  if [ -z $VERSION ]; then
    VERSION=1.7.1
  fi

  # Docker Compose https://github.com/docker/compose/releases
  sudo touch /usr/local/bin/docker-compose && sudo chown $USER /usr/local/bin/docker-compose
  curl -L "https://github.com/docker/compose/releases/download/$VERSION/docker-compose-`uname -s`-`uname -m`" > /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
}
