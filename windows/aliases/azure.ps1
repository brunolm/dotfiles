function AZ-PROpen($id, $title, $branch) {
  az repos pr create --title $title --work-items $id -t $branch
}
