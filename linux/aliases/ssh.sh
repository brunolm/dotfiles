ssh-gen-key() {
  ssh-keygen -t rsa
  sudo chmod 600 ~/.ssh/*
}

ssh-copy-key() {
  cat ~/.ssh/id_rsa.pub | xclip -selection clipboard
}
