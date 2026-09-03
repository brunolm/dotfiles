function B-Docker-Clear() {
  B-Docker-Clear-Images
  B-Docker-Clear-Volumes
}

function B-Docker-Clear-Images() {
  docker rmi $(docker images -f dangling=true -q)
}

function B-Docker-Clear-Volumes() {
  docker run -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker:/var/lib/docker --rm martin/docker-cleanup-volumes #--dry-run
}
