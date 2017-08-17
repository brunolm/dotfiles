# private
function Node-Install-Extract($zip, $version) {
    7z x $zip -o"$env:NODE_VERSIONS_DIR" -r -aoa
    # Expand-Archive $zip -DestinationPath "$env:NODE_VERSIONS_DIR" -Force
    $folder = Get-ChildItem $env:NODE_VERSIONS_DIR | Where-Object { $_.Name -match "node-v$version" }

    $targetDir = (Join-Path $folder[0].Parent.FullName $version);

    if (Test-Path $targetDir) {
        Remove-Item -Force -Recurse $targetDir;
    }

    Move-Item $folder[0].FullName $targetDir;
}

function Node-List-Versions($search) {
    $response=(Invoke-WebRequest https://nodejs.org/download/release/);
    $nodeLinks = $response.Content -split '\n';
    $nodeVersions = ($nodeLinks | Where-Object { $_ -match 'href="v\d+[.]\d+[.]\d+/"' });

    $versions = $nodeVersions `
        | Select-Object -Property `
            @{ name="Link"; expression={ [regex]::Match([regex]::Split($_, '\s\s+')[0], '>(?<Version>.*?)(/?)<').Groups["Version"].Value } }, `
            @{ name="Date"; expression={ [DateTime]::Parse([regex]::Split($_, '\s\s+')[1]) } } `
        | Where-Object { $_.Link -match "^v?$search" } `
        | Sort-Object -Property Date, Link -Descending

    $versions
}

function Node-List-Installed() {
    Get-ChildItem $env:NODE_VERSIONS_DIR `
        | Select-Object -Property `
            @{n='Order';e={ [Int32]::Parse( $_.Name.Replace(".", "") ) } }, `
            @{n='Name';e={ $_.Name } } `
        | Sort-Object -Descending -Property Order `
        | Select-Object -Property Name
}

function Node-Set-Default($version) {
    if ($version -match "latest") {
        $target = Node-List-Installed | Select-Object -First 1;
    }
    else {
        $target = Node-List-Installed | Where-Object { $_.Name -match $version } | Select-Object -First 1;
    }

    $sourceDir = (Join-Path $env:NODE_VERSIONS_DIR $target[0].Name);

    Get-ChildItem $sourceDir | ForEach-Object { Copy-Item $_.FullName $env:NODE_DIR -Recurse -Force }
}

function Node-Use($version) {
    if ($version -match "latest") {
        $target = Node-List-Installed | Select-Object -First 1;
    }
    else {
        $target = Node-List-Installed | Where-Object { $_.Name -match $version } | Select-Object -First 1;
    }

    $env:Path = ($env:Path -split ';' | Where-Object { $_ -notlike "$env:NODE_VERSIONS_DIR*" }) -join ';'

    if ($version -notmatch "default") {
        $env:Path = (Join-Path $env:NODE_VERSIONS_DIR $target[0].Name) + ";" + $env:Path;
    }

    node -v
    npm -v
}

function Node-Install($version) {
    $version = $version.ToString();

    $tag = 'v' + $version.Replace('v', '');

    if ($version -match "^v?\d+$") {
        $nodeBaseUrl = "https://nodejs.org/download/release/latest-${tag}.x";
    }
    elseif ($version -match "latest") {
        $nodeBaseUrl = "https://nodejs.org/download/release/latest";
    }
    else {
        $nodeBaseUrl = "https://nodejs.org/download/release/${tag}";
    }

    $downloadTag=((Invoke-WebRequest $nodeBaseUrl).Content | findstr "win-x64.zip") -replace "<(.*?)>", "" -replace "\s+.+", "";
    $downloadLink = "$nodeBaseUrl/$downloadTag";

    $dest = (join-path $env:TEMP "node-${tag}.zip");
    Invoke-WebRequest $downloadLink -OutFile $dest;

    $versionName = [regex]::Match($downloadTag, "-v(?<Version>\d+[.]\d+[.]\d+)-").Groups["Version"].Value;
    Node-Install-Extract $dest $versionName;
}
