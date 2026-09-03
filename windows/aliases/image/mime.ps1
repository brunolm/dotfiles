function B-Image-Get-MimeType($CheckFile) {
    Add-Type -AssemblyName "System.Web"

    [System.IO.FileInfo]$checkFile = $CheckFile
    $mime_type = ''

    if ($checkFile.Exists) {
        $mime_type = [System.Web.MimeMapping]::GetMimeMapping($checkFile.FullName);
    }

    return $mime_type;
}
