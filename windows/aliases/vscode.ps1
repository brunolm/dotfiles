function Patch-VSCodeInsiders() {
    Copy-Item "C:\Programs\Microsoft VS Code Insiders\bin\code-insiders" "C:\Programs\Microsoft VS Code Insiders\bin\code"
    Copy-Item "C:\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd" "C:\Programs\Microsoft VS Code Insiders\bin\code.cmd"
}

function code() {
    code-insiders $args
}
