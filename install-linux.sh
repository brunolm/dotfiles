if [ ! -f $ZSH/oh-my-zsh.sh ];
then
  sudo apt install zsh -qqy
  sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
fi

install() {
  for file in $1; do
    ln -s "./linux/${file}" "~/${file}"
  done
}

install "$(ls -A ./common)"
install "$(ls -A ./linux)"
