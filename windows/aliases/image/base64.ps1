function B-Image-Get-Base64([string]$file) {
    if ($file -like 'http*') {
        return B-Image-Get-Base64FromUrl($file);
    }

    return B-Image-Get-Base64FromFile($file);
}

function B-Image-Get-Base64FromFile(
    [string]
    [ValidateScript( { Test-Path $_ })]
    $file
) {
    $type = B-Image-Get-MimeType $file;
    $base64 = [convert]::ToBase64String((Get-Content $file -Encoding byte));

    if (!$type) {
        $type = [System.IO.Path]::GetExtension($file).Replace('.', '')
        $type = "image/${type}"
    }

    return "data:$type;base64,$base64";
}

function B-Image-Get-Base64FromUrl([Uri]$url) {
    $b = Invoke-WebRequest $url;

    $type = $b.Headers["Content-Type"];
    $base64 = [convert]::ToBase64String($b.Content);

    return "data:$type;base64,$base64";
}
