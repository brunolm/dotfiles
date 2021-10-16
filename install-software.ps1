function InstallSoftware() {
  choco install powershell-core -y

  choco install docker-desktop -y

  # choco install powertoys -y
  choco install ditto -y
  choco install sharex -y

  choco install git -y

  # choco install heroku-cli
  # choco install vercel
  choco install nvs -y
  choco install vim -y
  choco install gnupg -y

  choco install vscode-insiders -y

  choco install python -y

  choco install slack -y
  choco install obs-studio -y
}

InstallSoftware
