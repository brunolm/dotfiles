function InstallSoftware() {
  choco install powershell-core -y

  choco install git -y
  choco install gnupg -y
  choco install ffmpeg -y
  choco install imagemagick -y

  choco install powertoys -y
  choco install autohotkey -y
  choco install ditto -y
  choco install sharex -y
  choco install slack -y
  choco install obs-studio -y
  choco install whatsapp -y

  # Gaming
  choco install discord -y
  choco install steam -y

  # choco install docker-desktop -y

  # choco install vercel -y
  # choco install vim -y
}

InstallSoftware


# Install chocolatey
# Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
