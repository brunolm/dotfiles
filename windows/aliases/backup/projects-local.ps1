## B-Backup-ProjectsLocal: zips the untracked .env*, *.local.* and docs/local files of every git repo under a folder, keeping the folder structure so the zip unpacks on top of fresh clones
function B-Backup-ProjectsLocal {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0)]
    [string]$Path = '.',
    [string]$Output = 'projects-local-backup.zip',
    [switch]$DryRun
  )

  if (!(Test-Path -LiteralPath $Path -PathType Container)) {
    Write-Error "Folder '$Path' does not exist."
    return
  }

  $root = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
  $files = BBackup-FindLocalFiles $root | Sort-Object Entry
  if (!$files) {
    Write-Host "No untracked local files found under $root." -ForegroundColor Yellow
    return
  }

  foreach ($group in ($files | Group-Object Repo)) {
    Write-Host ""
    Write-Host $group.Name -ForegroundColor Cyan
    foreach ($file in $group.Group) { Write-Host "  $($file.Entry)" }
  }
  Write-Host ""
  if ($DryRun) {
    Write-Host "Dry run: $($files.Count) files would be zipped." -ForegroundColor Yellow
    return
  }

  $zip = BBackup-WriteZip $files $Output
  Write-Host "Wrote $($files.Count) files to $zip" -ForegroundColor Green
  Write-Host "Unzip it into $root to restore." -ForegroundColor DarkGray
}

function BBackup-FindLocalFiles($root) {
  $skipDirs = [System.Collections.Generic.HashSet[string]]::new([string[]](BBackup-SkipDirs), [System.StringComparer]::OrdinalIgnoreCase)
  $localFile = [regex]::new((BBackup-LocalFilePattern))
  $candidates = [System.Collections.Generic.List[object]]::new()
  $pending = [System.Collections.Generic.Stack[object]]::new()
  $pending.Push([pscustomobject]@{ Dir = $root; Repo = $null; InLocalDir = $false })

  while ($pending.Count) {
    $current = $pending.Pop()
    $dir = $current.Dir
    $repo = $current.Repo
    $inLocalDir = $current.InLocalDir
    $gitMarker = [System.IO.Path]::Combine($dir, '.git')
    if ([System.IO.Directory]::Exists($gitMarker) -or [System.IO.File]::Exists($gitMarker)) {
      $repo = $dir
      $inLocalDir = $false
    }
    if ($repo -and !$inLocalDir) {
      $inLocalDir = BBackup-IsLocalDir $repo $dir
    }

    try {
      if ($repo) {
        foreach ($file in [System.IO.Directory]::EnumerateFiles($dir)) {
          if ($inLocalDir -or $localFile.IsMatch([System.IO.Path]::GetFileName($file))) {
            $candidates.Add([pscustomobject]@{ Repo = $repo; Path = $file })
          }
        }
      }
      $parent = [System.IO.Path]::GetFileName($dir)
      foreach ($sub in [System.IO.Directory]::EnumerateDirectories($dir)) {
        $name = [System.IO.Path]::GetFileName($sub)
        if ($skipDirs.Contains($name) -or $skipDirs.Contains("$parent/$name")) { continue }
        if (($name -eq 'bin' -or $name -eq 'obj') -and (BBackup-HasDotnetProject $dir)) { continue }
        $pending.Push([pscustomobject]@{ Dir = $sub; Repo = $repo; InLocalDir = $inLocalDir })
      }
    }
    catch [System.UnauthorizedAccessException] {
      Write-Warning "Skipping unreadable folder $dir"
    }
  }

  foreach ($group in ($candidates | Group-Object Repo)) {
    $repo = $group.Name
    $tracked = BBackup-TrackedFiles $repo
    foreach ($candidate in $group.Group) {
      $relative = BBackup-RelativePath $repo $candidate.Path
      if ($tracked.Contains($relative)) { continue }
      [pscustomobject]@{
        Repo  = $repo
        Path  = $candidate.Path
        Entry = BBackup-RelativePath $root $candidate.Path
      }
    }
  }
}

function BBackup-IsLocalDir($repo, $dir) {
  $relative = BBackup-RelativePath $repo $dir
  foreach ($pattern in (BBackup-LocalDirs)) {
    if ($relative -eq $pattern -or $relative -like "*/$pattern") { return $true }
  }
  return $false
}

function BBackup-HasDotnetProject($dir) {
  foreach ($file in [System.IO.Directory]::EnumerateFiles($dir, '*.*proj')) { return $true }
  return $false
}

function BBackup-TrackedFiles($repo) {
  $tracked = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $lines = & git -C $repo -c core.quotepath=false ls-files 2>$null
  foreach ($line in @($lines)) {
    if ($line) { $tracked.Add($line) | Out-Null }
  }
  return $tracked
}

# .env, .env.<anything>, and <name>.local.<ext> (settings.local.json, CLAUDE.local.md).
# The .local. part is case-sensitive so .NET assemblies like System.Transactions.Local.dll stay out.
function BBackup-LocalFilePattern() {
  return '^((?i)\.env(\..*)?|.*\.local\..+)$'
}

function BBackup-LocalDirs() {
  return @('docs/local')
}

# Names match any folder; "parent/name" entries match only that pair (so a project called "obj" is still scanned).
function BBackup-SkipDirs() {
  return @(
    '.git', 'node_modules', 'bower_components', 'vendor',
    '.venv', 'venv', '__pycache__', '.tox', '.mypy_cache', '.pytest_cache',
    'dist', 'built', 'build', 'out', 'target', '.next', '.nuxt', '.svelte-kit', '.turbo', '.parcel-cache',
    'coverage', '.cache',
    'bin/Debug', 'bin/Release', 'obj/Debug', 'obj/Release',
    '.gradle', '.idea', '.vs'
  )
}
