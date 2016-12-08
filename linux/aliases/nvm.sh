update-nvm() {
  # nvm & Node https://github.com/creationix/nvm
  curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.29.0/install.sh | bash
  echo ". ~/.nvm/nvm.sh" >> ~/.bashrc
  echo ". ~/.nvm/nvm.sh" >> ~/.zshrc
  source ~/.nvm/nvm.sh
  nvm install stable #or nvm install <version>
  nvm use stable
  n=$(which node);n=${n%/bin/node}; sudo chmod -R 755 $n/bin/*; sudo cp -r $n/{bin,lib,share} /usr/local

  sudo chmod g+w /usr/local/lib/node_modules
  sudo chmod g+w /usr/bin/npm
  sudo chmod g+w /usr/local/bin/npm
}
