git-clear() {
  git remote prune origin
  git branch --merged | grep -v "\*" | grep -v "master" | grep -v "develop" | grep -v "qa" | xargs -n 1 git branch -d
}

git-setup-dev() {
  local NAME=$1
  local EMAIL=$2

  if [ -z $NAME ]; then
    echo "Required params: <name> <email>"
    return -1;
  fi

  if [ -z $EMAIL ]; then
    echo "Required params: <name> <email>"
    return -1;
  fi

  git config --global user.name "$NAME"
  git config --global user.email "$EMAIL"
  git config --global core.editor code
  git config --global core.autocrlf input
  git config --global help.autocorrect 5
  git config --global alias.lga 'log --graph --oneline --all --decorate'
}

update-git() {
  sudo apt install git-core -qqy
  sudo apt install xclip -qqy
}
