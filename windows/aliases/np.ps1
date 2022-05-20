function NP() {
  $e = @'
root = true

[*]
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 2
trim_trailing_whitespace = true

[windows/**]
indent_size = 2
'@

  $p = @'
{
  "arrowParens": "always",
  "printWidth": 120,
  "singleQuote": true,
  "trailingComma": "all",
  "semi": false
}
'@

  Out-File -FilePath ".editorconfig" -InputObject $e
  Out-File -FilePath ".prettierrc" -InputObject $p
}
