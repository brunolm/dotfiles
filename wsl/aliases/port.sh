## stop-port: kill the process listening on a TCP port.
stop-port() {
  local port="$1"
  [[ -z "$port" ]] && { echo "usage: stop-port <port>"; return 1; }
  local pid
  pid=$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null | head -1)
  if [[ -z "$pid" ]]; then
    fuser -k "${port}/tcp" 2>/dev/null
    return
  fi
  echo "killing pid $pid on port $port"
  kill -9 "$pid"
}

alias kill-port=stop-port
