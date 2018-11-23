function Get-ImageBase64([string]$file) {
    if ($file -like 'http*') {
        return Get-ImageBase64FromUrl($file);
    }

    return Get-ImageBase64FromFile($file);
}

function Get-ImageBase64FromFile(
    [string]
    [ValidateScript( { Test-Path $_ })]
    $file
) {
    $type = Get-MimeType $file;
    $base64 = [convert]::ToBase64String((Get-Content $file -Encoding byte));

    return "data:$type;base64,$base64";
}

function Get-ImageBase64FromUrl([Uri]$url) {
    $b = Invoke-WebRequest $url;

    $type = $b.Headers["Content-Type"];
    $base64 = [convert]::ToBase64String($b.Content);

    return "data:$type;base64,$base64";
}

function Get-MimeType($CheckFile) {
    Add-Type -AssemblyName "System.Web"

    [System.IO.FileInfo]$checkFile = $CheckFile
    $mime_type = ''

    if ($checkFile.Exists) {
        $mime_type = [System.Web.MimeMapping]::GetMimeMapping($checkFile.FullName);
    }

    return $mime_type;
}
