cup()  { docker-compose up "$@"; }
cr()   { docker-compose run --service-ports --rm "$@"; }
crl()  { docker-compose run --service-ports --rm local "$@"; }
crd()  { docker-compose run --service-ports --rm develop "$@"; }
crp()  { docker-compose run --service-ports --rm production "$@"; }
crb()  { docker-compose run --service-ports --rm build "$@"; }
crs()  { docker-compose run --service-ports --rm setup "$@"; }
crt()  { docker-compose run --rm test "$@"; }
crci() { docker-compose run --rm ci "$@"; }

## dps: list docker containers (filter by name; -a all, -e exited)
dps() {
  local name="" params=()
  if [[ -n "$1" && "${1:0:1}" != "-" ]]; then
    name="$1"; shift
  fi
  params=("$@")
  local fmt='table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}'
  if [[ " ${params[*]} " == *" -a "* ]]; then
    docker ps -a --filter "name=$name" --format "$fmt"
  elif [[ " ${params[*]} " == *" -e "* ]]; then
    docker ps --filter "status=exited" --filter "name=$name" --format "$fmt"
  else
    docker ps --filter "status=running" --filter "name=$name" --format "$fmt"
  fi
}

dpsi() {
  docker ps --filter "name=$*" --filter status=running \
    --format $'{{.ID}} {{.Names}} ---> {{.Status}}\n  {{.Image}}\n  {{.Mounts}}\n  {{.Command}}\n  {{.Ports}}\n'
}

_docker_pick_id() {
  local name="$1" extra="$2"
  # shellcheck disable=SC2086
  docker ps -q --filter "name=$name" $extra | sort -r | head -1
}

drestart() {
  local id; id=$(_docker_pick_id "$1" "")
  [[ -z "$id" ]] && { echo "no container matching '$1'"; return 1; }
  docker restart "$id"
}

dstop() {
  local id; id=$(_docker_pick_id "$1" "--filter status=running")
  [[ -z "$id" ]] && { echo "no running container matching '$1'"; return 1; }
  docker stop "$id"
}

drm() {
  local id; id=$(_docker_pick_id "$1" "")
  [[ -z "$id" ]] && { echo "no container matching '$1'"; return 1; }
  docker rm -f "$id"
}

dbash() {
  local id; id=$(_docker_pick_id "$1" "")
  [[ -z "$id" ]] && { echo "no container matching '$1'"; return 1; }
  docker exec -it "$id" bash
}

dlogs() {
  local name="$1"; shift
  local id; id=$(docker ps -aq --filter "name=$name" | sort -r | head -1)
  [[ -z "$id" ]] && { echo "no container matching '$name'"; return 1; }
  docker logs "$@" "$id"
}

reset-containers() {
  local ids; ids=$(docker ps -qa)
  [[ -n "$ids" ]] && docker rm -f $ids
}

clear-images() {
  local ids; ids=$(docker images -f dangling=true -q)
  [[ -n "$ids" ]] && docker rmi $ids
}
