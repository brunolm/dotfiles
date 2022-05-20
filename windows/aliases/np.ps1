function NP() {
  $e = Get-Content "./.editorconfig"
  $p = Get-Content "./.prettierrc"

  Out-File -FilePath ".editorconfig" -InputObject $e
  Out-File -FilePath ".prettierrc" -InputObject $p
}
