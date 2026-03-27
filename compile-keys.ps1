dotnet publish "$PSScriptRoot\keys\Keys.csproj" -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -o "$PSScriptRoot\windows\startup-files"
