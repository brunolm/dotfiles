---
name: brunolm-anime-list-recent
description: Use this skill when the user wants to see TV anime premiering around now - shows whose first episode aired within the last 2 weeks or premieres within the next 2 weeks. Triggers include "/brunolm-anime-list-recent", "check anime", "what anime is starting", "new anime this season", "what's airing soon", or any phrasing pairing anime with a near-term premiere window. Uses the MyAnimeList (MAL) MCP to pull seasonal anime, filters to media type TV inside a -2 week / +2 week window around today, hides shows already on the user's watching / plan-to-watch lists and anything tagged Kids, and prints a table of title (with alternative / Japanese names), genres/tags, air start date, and a link to its MAL page. Accepts an optional argument: `html` writes and opens an HTML file in the browser, `both` does terminal + HTML, and the default (no argument) prints the terminal table.
version: 1.0.0
allowed-tools:
  - mcp__mal-mcp__get_seasonal_anime
  - mcp__mal-mcp__get_anime_details
  - mcp__mal-mcp__get_auth_status
  - mcp__mal-mcp__get_user_anime_list
  - PowerShell
---

# Check anime (premiering +/-2 weeks)

List **TV** anime whose first episode aired within the last 2 weeks **or** premieres within the next 2 weeks, using the MyAnimeList MCP (`mal-mcp`). Output is sorted by air start date and rendered to the terminal, to an HTML file, or both, depending on the argument - see **Output mode**.

The window is `[today - 14 days, today + 14 days]`, inclusive, recomputed every run from the real current date - never hardcode dates.

## Output mode (argument)

This skill takes one optional argument - the text after the skill name - matched case-insensitively:

- **(omitted)** - render the Markdown table to the terminal. This is the default and the current behavior.
- **`html`** - write a styled HTML file to the temp folder and open it in the default browser; don't print the terminal table.
- **`both`** - do both: print the terminal table **and** write + open the HTML file.

Any other value falls back to the default (terminal) - note that in one line so the user knows the argument wasn't recognized.

Steps 1-5 (gather, filter) are identical for every mode; only the output in step 6 differs.

## 1. Confirm the MAL MCP is reachable and authenticated

Call `get_auth_status`. Two things must be true:

- **Client credentials configured** - needed for the public seasonal listing. If missing, stop and tell the user to configure the `mal-mcp` server, then exit.
- **User token present** (`authenticated: true`) - needed to read the user's *watching* / *plan-to-watch* lists for the exclusion in step 4. If absent, stop and tell the user to run the MAL MCP `authenticate` tool first, then exit. The exclusion is a core part of this skill, so don't silently fall back to an unfiltered list.

## 2. Compute the window and the seasons to query

MAL serves anime by season, so first turn "today +/-14 days" into the season buckets that overlap the window. A 4-week window touches at most two adjacent seasons (it only spans two when today is within ~2 weeks of a season boundary, including the Dec->Jan year rollover).

Run this in PowerShell to get the window bounds and the season(s) to query:

```powershell
$today = Get-Date
$lower = $today.AddDays(-14)
$upper = $today.AddDays(14)

function Get-MalSeason([datetime]$d) {
  $season = @('winter','winter','winter','spring','spring','spring','summer','summer','summer','fall','fall','fall')[$d.Month - 1]
  [pscustomobject]@{ Year = $d.Year; Season = $season }
}

[pscustomobject]@{
  Today  = $today.ToString('yyyy-MM-dd')
  Lower  = $lower.ToString('yyyy-MM-dd')
  Upper  = $upper.ToString('yyyy-MM-dd')
  SeasonLower = (Get-MalSeason $lower)
  SeasonUpper = (Get-MalSeason $upper)
} | ConvertTo-Json
```

Keep `Lower`/`Upper` as `yyyy-MM-dd` strings for the date filter in step 4. Collect the distinct `(Year, Season)` pairs from `SeasonLower` and `SeasonUpper` - usually one, sometimes two.

## 3. Pull the seasonal anime

For **each** distinct `(Year, Season)` pair, call `get_seasonal_anime`:

- `year`: the four-digit year
- `season`: `winter | spring | summer | fall`
- `limit`: `500` (cover the whole season in one page)
- `sort`: `anime_num_list_users` (most-watched first; only affects ordering, not which rows you keep)
- `fields`: `alternative_titles,media_type,start_date,genres,start_season,status,mean,num_list_users,main_picture,synopsis` (`main_picture` and `synopsis` feed the HTML output's Image and Summary columns)

Merge the results from both seasons (when there are two) and **dedupe by anime id** - a show can appear in both buckets near a boundary.

## 4. Pull the user's exclusion lists

Fetch the two lists whose entries must be hidden, via `get_user_anime_list` (defaults to the authenticated user, `@me`):

- `status: "watching"`, `limit: 1000`
- `status: "plan_to_watch"`, `limit: 1000`

Collect every anime **id** from both responses into one exclusion set. 1000 is the per-status max; if either list runs longer, page with `offset` until exhausted - most users won't need to. MAL returns ids as **numbers**; when you test membership in step 5, coerce both sides to the same type (e.g. compare as strings) or the lookup silently misses and listed shows leak through.

## 5. Filter to the TV premieres in the window

Keep a row only if **all** hold:

- `media_type == "tv"` - exclude `ona`, `ova`, `movie`, `special`, `music`. (TV-only is the spec. If the user explicitly wants streaming/ONA shows too, widen the filter and say so.)
- `start_date` is a **full** `yyyy-MM-dd` (not year-only or year-month). Partial dates mean MAL hasn't confirmed a premiere day - set those aside.
- `Lower <= start_date <= Upper` (string compare on `yyyy-MM-dd` is correct for ISO dates).
- The anime **id is not in the exclusion set** from step 4 (not already on the user's *watching* or *plan-to-watch* lists).
- The anime's `genres` do **not** include **`Kids`** (case-insensitive match on the genre name).

Sort the survivors ascending by `start_date`.

## 6. Output

Build the survivor row set from steps 1-5 once; what you emit depends on the **Output mode** argument.

### Terminal table - default, and part of `both`

One Markdown table, sorted by air start date:

| # | Names | Tags | Air start | MAL |
|---|-------|------|-----------|-----|

- **Names** - every name the show has, one per line in a single cell. Put `node.title` (the MAL primary title, usually romaji) first, then from `alternative_titles` the English (`en`), Japanese (`ja`), and each of the `synonyms`. Omit empties. Separate them with `<br>` so they stack as lines inside the one cell (GitHub-flavored Markdown renders `<br>` in table cells).
- **Tags** - `genres[].name` joined with `, ` (these are MAL's genre/theme tags). `-` if none.
- **Air start** - two lines in the one cell (joined with `<br>`): the `start_date` on the first line, then a relative hint computed against today - `today`, `in 5d`, or `9d ago` - on the second.
- **MAL** - a Markdown link to the show's MyAnimeList page, built from the anime `id` as `https://myanimelist.net/anime/{id}` (no extra API call). Render as `[link](https://myanimelist.net/anime/{id})`.

### HTML file - `html` and `both`

Write a self-contained, styled HTML document to the temp folder and open it in the default browser. It uses an always-on **dark theme**, a **search box** above the table that live-filters rows by name or tag, and - on top of the terminal columns - an **Image** column (the show's MAL poster - click any image to enlarge it big on the left side of the screen) and a **Summary** column (the synopsis). The **Names** column stacks every name one per line, like the terminal table. **Air start** stacks the date and its relative hint on two lines; **MAL** is a real clickable anchor.

PowerShell variables don't persist between tool calls, so do this in **one** self-contained PowerShell call: re-read the season file(s), re-apply the step-5 filter to rebuild `$rows`, then build, write (UTF-8, so Japanese renders), and open the file. The Image and Summary columns need `main_picture` and `synopsis` in the seasonal `fields` (step 3). HTML-escape `&`, `<`, `>` in titles, tags, image URLs, and synopsis. Reference template (prefix it with the same read + filter that produced `$rows`):

```powershell
# $rows = step-5 survivors sorted by start_date; $lower/$upper = yyyy-MM-dd
# NOTE: name the escaper `Enc`, not `H` - `h` is the built-in alias for Get-History and outranks a function, so `H $x` would call Get-History.
function Enc([string]$s){ if(-not $s){return ''}; $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;') }
function Rel([string]$d){ $k=([datetime]$d-(Get-Date).Date).Days; if($k -eq 0){'today'}elseif($k -gt 0){"in ${k}d"}else{"$([math]::Abs($k))d ago"} }
$today = (Get-Date).ToString('yyyy-MM-dd')
$path  = Join-Path $env:TEMP "brunolm-anime-list-recent-$today.html"
$i = 0
$trs = $rows | ForEach-Object {
  $i++; $n = $_
  $names  = @($n.title, $n.alternative_titles.en, $n.alternative_titles.ja) + @($n.alternative_titles.synonyms) | Where-Object { $_ }
  $tagList = @($n.genres | ForEach-Object { $_.name })
  $namesHtml = ($names | ForEach-Object { Enc $_ }) -join '<br>'
  $tags   = ($tagList | ForEach-Object { Enc $_ }) -join ', '
  $large  = if($n.main_picture.large){ $n.main_picture.large } else { $n.main_picture.medium }
  $img    = if($n.main_picture.medium){ "<img src='$(Enc $n.main_picture.medium)' data-large='$(Enc $large)' alt='' loading='lazy'>" } else { '' }
  $sum    = if($n.synopsis){ Enc $n.synopsis } else { '' }
  $search = (Enc ((@($names) + $tagList) -join ' ')).Replace("'", '&#39;').ToLower()
  "<tr data-search='$search'><td>$i</td><td>$img</td><td class='names'>$namesHtml</td><td class='tags'>$tags</td><td>$($n.start_date)<br>$(Rel $n.start_date)</td><td class='sum'>$sum</td><td><a href='https://myanimelist.net/anime/$($n.id)' target='_blank' rel='noopener'>MAL &#8599;</a></td></tr>"
}
$html = @"
<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>Anime premiering - $today</title>
<style>
 body{font:14px/1.6 system-ui,sans-serif;margin:2rem;background:#0d1117;color:#e6edf3}
 h1{font-size:1.2rem;color:#f0f6fc}
 table{border-collapse:collapse;width:100%}
 th,td{border:1px solid #30363d;padding:.5rem .6rem;text-align:left;vertical-align:top}
 th{background:#161b22;position:sticky;top:0;color:#f0f6fc}
 tr:nth-child(even){background:#161b22}
 a{color:#6cb6ff;text-decoration:none} a:hover{text-decoration:underline}
 img{width:160px;height:auto;border-radius:4px;display:block;cursor:zoom-in}
 #lb{position:fixed;inset:0;display:none;align-items:center;justify-content:flex-start;padding:2rem;box-sizing:border-box;background:rgba(0,0,0,.85);cursor:zoom-out;z-index:10}
 #lb.open{display:flex}
 #lb img{width:auto;max-width:90vw;max-height:90vh;border-radius:8px;cursor:zoom-out}
 td.names{max-width:200px} td.tags{max-width:150px}
 td.sum{max-width:640px;font-size:.85rem;color:#c9d1d9}
 #q{width:100%;max-width:480px;margin:0 0 1rem;padding:.5rem .7rem;font-size:1rem;background:#161b22;color:#e6edf3;border:1px solid #30363d;border-radius:6px}
 #q::placeholder{color:#8b949e}
 .foot{margin-top:1rem;color:#8b949e;font-size:.9rem}
</style></head><body>
<h1>TV anime premiering $lower .. $upper</h1>
<input id="q" type="search" placeholder="Filter by name or tag..." autocomplete="off">
<table><thead><tr><th>#</th><th>Image</th><th>Names</th><th>Tags</th><th>Air start</th><th>Summary</th><th>MAL</th></tr></thead>
<tbody>
$($trs -join "`n")
</tbody></table>
<script>
const q=document.getElementById('q');
const rows=[...document.querySelectorAll('tbody tr')];
q.addEventListener('input',()=>{const t=q.value.trim().toLowerCase();for(const r of rows){r.style.display=r.dataset.search.includes(t)?'':'none';}});
const lb=document.createElement('div');lb.id='lb';const lbi=document.createElement('img');lb.appendChild(lbi);document.body.appendChild(lb);
document.querySelectorAll('tbody img').forEach(im=>im.addEventListener('click',()=>{lbi.src=im.dataset.large||im.src;lb.classList.add('open');}));
lb.addEventListener('click',()=>lb.classList.remove('open'));
addEventListener('keydown',e=>{if(e.key==='Escape')lb.classList.remove('open');});
</script>
</body></html>
"@
[System.IO.File]::WriteAllText($path, $html, [System.Text.UTF8Encoding]::new($false))
Start-Process $path
$path
```

Tell the user the path the file was written to.

### Date TBD and empty result (all modes)

If any in-window TV shows had only a **partial** start_date, list them in a short "Date TBD" note (below the terminal table, or under the HTML table) so they aren't silently dropped - but still drop the ones excluded above.

If nothing matches, say so plainly and still show the window + seasons queried so the user can see the search was real. In `html` / `both` mode, skip writing the file when there are zero rows and just report it in the terminal.

## Notes

- Don't call `get_anime_details` per row by default - the seasonal `fields` set already carries everything both outputs need. Reach for it only if the user asks for extra detail on a specific show (studio, episode count, broadcast day).
- `num_list_users` / `mean` are pulled only to order the season fetch; `main_picture` / `synopsis` are pulled only for the HTML output's **Image** and **Summary** columns. None of these appear in the terminal table.
