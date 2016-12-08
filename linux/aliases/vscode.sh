update-vscode() {
  curl -L "https://go.microsoft.com/fwlink/?LinkID=760868" > /tmp/vscode.deb
  sudo dpkg -i /tmp/vscode.deb && sudo apt install -f
}

update-vscode-extensions() {
  code --install-extension aeschli.vscode-css-formatter
  code --install-extension alefragnani.Bookmarks
  code --install-extension christian-kohler.path-intellisense
  code --install-extension cssho.vscode-svgviewer
  code --install-extension donjayamanne.githistory
  code --install-extension EditorConfig.EditorConfig
  code --install-extension eg2.tslint
  code --install-extension MattiasPernhult.vscode-todo
  code --install-extension ms-vscode.csharp
  code --install-extension ms-vscode.PowerShell
  code --install-extension PeterJausovec.vscode-docker
  code --install-extension QassimFarid.ejs-language-support
  code --install-extension seanmcbreen.Spell
  code --install-extension Shan.code-settings-sync
  code --install-extension stevencl.addDocComments
  code --install-extension wmaurer.change-case
  code --install-extension zhutian.swig
}
