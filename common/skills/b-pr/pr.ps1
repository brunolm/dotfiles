param(
  [ValidateSet('list', 'info')]
  [string]$Command = 'list',
  [string]$Target,
  [int]$Count = 10
)

$ErrorActionPreference = 'Stop'
# Redirected output otherwise uses the legacy OEM code page, which turns non-ASCII text into `?`.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$StateIcons = @{
  APPROVED          = '✅'
  CHANGES_REQUESTED = '❌'
  COMMENTED         = '💬'
  DISMISSED         = '🚫'
}

$Legend = 'Reviewers: ✅ approved · ❌ changes requested · 💬 commented · 🚫 dismissed. Conflicts `?` = GitHub has not computed mergeability yet.'

$MaxBodyLength = 800

$prFields = 'number,title,url,isDraft,mergeable,statusCheckRollup,reviews,comments,author'

function Main {
  if ($Command -eq 'info') {
    if (!$Target) { throw 'Usage: pr.ps1 info <PR number>' }
    Show-PrInfo $Target
    return
  }

  $author = if ($Target) { $Target } else { '@me' }
  Show-PrList $author
}

function Show-PrList($author) {
  $prs = gh pr list --author $author --state open --limit 100 --json $prFields | ConvertFrom-Json
  if ($LASTEXITCODE) { exit $LASTEXITCODE }
  if (!$prs) {
    "No open PRs by $author."
    return
  }

  $reviewers = $prs | ForEach-Object { (Get-ReviewerStates $_).Keys } | Sort-Object -Unique
  Format-PrTable $prs $reviewers
  ''
  $Legend
}

function Show-PrInfo($id) {
  $pr = gh pr view $id --json "$prFields,headRefName,baseRefName" | ConvertFrom-Json
  if ($LASTEXITCODE) { exit $LASTEXITCODE }
  $inline = gh api "repos/{owner}/{repo}/pulls/$id/comments" --paginate | ConvertFrom-Json
  if ($LASTEXITCODE) { exit $LASTEXITCODE }

  "## #$($pr.number) $($pr.title)"
  ''
  "$($pr.url) · by $($pr.author.login) · $($pr.headRefName) → $($pr.baseRefName)"
  ''
  $reviewers = (Get-ReviewerStates $pr).Keys | Sort-Object
  Format-PrTable @($pr) $reviewers
  ''
  $Legend

  $failing = Get-Checks $pr | Where-Object { $_.Result -eq 'fail' }
  if ($failing) {
    ''
    '**Failing checks:** ' + (($failing | ForEach-Object { $_.Name }) -join ', ')
  }

  ''
  "### Latest review comments"
  ''
  $entries = Get-CommentEntries $pr $inline | Sort-Object At -Descending | Select-Object -First $Count
  if (!$entries) {
    '(none)'
    return
  }
  foreach ($entry in $entries) {
    "- **$($entry.Author)** · $($entry.Kind) · $($entry.At.ToLocalTime().ToString('yyyy-MM-dd HH:mm'))"
    ''
    (Format-Body $entry.Body) -split "`n" | ForEach-Object { "  > $_" }
    ''
  }
}

function Format-PrTable($prs, $reviewers) {
  $header = @('#', 'Title', 'Draft', 'CI', 'Conflicts') + $reviewers
  '| ' + ($header -join ' | ') + ' |'
  '|' + (($header | ForEach-Object { '---' }) -join '|') + '|'

  foreach ($pr in $prs) {
    $states = Get-ReviewerStates $pr
    $cells = @(
      "[#$($pr.number)]($($pr.url))"
      $pr.title -replace '\|', '\|'
      $(if ($pr.isDraft) { 'draft' } else { '' })
      Format-Ci $pr
      Format-Conflicts $pr.mergeable
    )
    $cells += $reviewers | ForEach-Object { if ($states.Contains($_)) { $StateIcons[$states[$_]] } else { '' } }
    '| ' + ($cells -join ' | ') + ' |'
  }
}

# Mirrors GitHub's own "latest review" rule: a plain comment never overrides an earlier approval
# or change request, so only APPROVED / CHANGES_REQUESTED / DISMISSED replace a reviewer's state.
function Get-ReviewerStates($pr) {
  $states = [ordered]@{}
  $authorLogin = $pr.author.login

  foreach ($comment in $pr.comments) {
    $login = $comment.author.login
    if ($login -ne $authorLogin) { $states[$login] = 'COMMENTED' }
  }

  foreach ($review in ($pr.reviews | Sort-Object submittedAt)) {
    $login = $review.author.login
    if ($login -eq $authorLogin -or $review.state -eq 'PENDING') { continue }
    if ($review.state -ne 'COMMENTED' -or !$states.Contains($login)) { $states[$login] = $review.state }
  }

  $states
}

function Format-Ci($pr) {
  $checks = @(Get-Checks $pr)
  if (!$checks) { return '—' }

  $failed = @($checks | Where-Object { $_.Result -eq 'fail' }).Count
  if ($failed) { return "❌ $failed failed" }
  if ($checks | Where-Object { $_.Result -eq 'pending' }) { return '⏳ pending' }
  '✅'
}

# statusCheckRollup mixes CheckRun (status + conclusion) and StatusContext (state) entries.
function Get-Checks($pr) {
  foreach ($check in $pr.statusCheckRollup) {
    $outcome = if ($check.__typename -eq 'StatusContext') { $check.state } else {
      if ($check.status -ne 'COMPLETED') { 'PENDING' } else { $check.conclusion }
    }
    $result = switch ($outcome) {
      { $_ -in 'SUCCESS', 'NEUTRAL', 'SKIPPED' } { 'pass' }
      { $_ -in 'PENDING', 'EXPECTED' } { 'pending' }
      default { 'fail' }
    }
    [pscustomobject]@{ Name = $check.name ?? $check.context; Result = $result }
  }
}

function Get-CommentEntries($pr, $inline) {
  foreach ($review in $pr.reviews) {
    if (!$review.body -or $review.state -eq 'PENDING') { continue }
    New-Entry $review.author.login "review ($($review.state.ToLower() -replace '_', ' '))" $review.submittedAt $review.body
  }
  foreach ($comment in $pr.comments) {
    New-Entry $comment.author.login 'comment' $comment.createdAt $comment.body
  }
  foreach ($comment in $inline) {
    $line = $comment.line ?? $comment.original_line
    New-Entry $comment.user.login "inline ``$($comment.path):$line``" $comment.created_at $comment.body
  }
}

function New-Entry($author, $kind, $at, $body) {
  [pscustomobject]@{ Author = $author; Kind = $kind; At = [datetime]$at; Body = $body }
}

# Bot reviews embed HTML comments, <picture> badges and long collapsible sections; strip the markup
# and cap the length so one review cannot drown out the rest.
function Format-Body($body) {
  $text = $body -replace '(?s)<!--.*?-->', '' -replace '<[^>]+>', '' -replace "`r", ''
  $text = ($text -replace '\n{3,}', "`n`n").Trim()
  if ($text.Length -le $MaxBodyLength) { return $text }
  $text.Substring(0, $MaxBodyLength).TrimEnd() + ' …'
}

function Format-Conflicts($mergeable) {
  switch ($mergeable) {
    'CONFLICTING' { '⚠️ yes' }
    'MERGEABLE' { 'no' }
    default { '?' }
  }
}

Main
