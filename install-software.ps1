function InstallSoftware() {
  choco install powershell-core -y
  choco install git -y

  choco install powertoys -y
  choco install autohotkey -y

  choco install docker-desktop -y

  # choco install powertoys -y
  choco install ditto -y
  choco install sharex -y


  # choco install heroku-cli
  # choco install vercel
  choco install nvs -y
  choco install vim -y
  choco install gnupg -y

  choco install vscode-insiders -y

  choco install python -y

  choco install slack -y
  choco install obs-studio -y

  # yarn global add tree-cli

  # npm install --global opusfluxus

  # pyenv pyenv-win
  # Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1" -OutFile "./install-pyenv-win.ps1"; &"./install-pyenv-win.ps1"
  # choco install pyenv-win

  choco install tableplus -y

  # Gaming
  choco install discord -y
  choco install steam -y

  choco install whatsapp -y
}

InstallSoftware
