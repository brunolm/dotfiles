update-linux() {
  sudo apt update
  sudo apt upgrade
  sudo apt dist-upgrade
}

fix-audio() {
  pulseaudio -k && sudo alsa force-reload
}

toggle-mic() {
  amixer set Capture toggle
}

free-memory() {
  sudo sysctl -w vm.drop_caches=3
  sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
}

fix-pc() {
  # echo "blacklist intel_powerclamp" > /etc/modprobe.d/disable-powerclamp.conf
  sudo rmmod intel_powerclamp # kidle_inject
  free-memory
}
