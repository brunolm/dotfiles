update-skype() {
  curl -L "https://repo.skype.com/latest/skypeforlinux-64-alpha.deb" > /tmp/skype.deb
  sudo dpkg -i /tmp/skype.deb && sudo apt install -f
}
