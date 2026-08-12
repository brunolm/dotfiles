---
name: b-video-finder
description: Use this skill when the user wants to find videos matching specific content criteria, verified by actually opening each video and inspecting frames. Triggers include "/b-video-finder", "find me N videos that show X", "search <site> for videos containing X", "look for videos with X", or any phrasing pairing video search with must-have visual criteria. Drives a real browser via the patchright MCP, screenshots each candidate at several timestamps, scores every candidate S/A/B/C/D against the criteria, keeps searching until the target count at the minimum rating is met (default 10 at B or better), then writes and opens an HTML report table (platform, thumbnail, title, duration, rating, tags).
version: 1.3.0
allowed-tools:
  - mcp__patchright__browser_navigate
  - mcp__patchright__browser_navigate_back
  - mcp__patchright__browser_snapshot
  - mcp__patchright__browser_take_screenshot
  - mcp__patchright__browser_click
  - mcp__patchright__browser_type
  - mcp__patchright__browser_press_key
  - mcp__patchright__browser_evaluate
  - mcp__patchright__browser_run_code
  - mcp__patchright__browser_wait_for
  - mcp__patchright__browser_tabs
  - mcp__patchright__browser_close
  - PowerShell
---

# Video finder

Find videos that actually contain what the user asked for - not videos whose *title* claims to. Search one or more video platforms with the patchright browser MCP, skip obvious misses from metadata, open the rest, capture frames, judge those frames against the criteria, and score the match. Keep going until enough videos meet the bar, then deliver an HTML report.

## What the user specifies

Parse these from the text after the skill name (all optional except criteria):

- **Target** - how many videos at what minimum rating, written like `10 B+` (count + rating + `+` meaning "or better"). Default: **10 at B or better**.
- **Platform(s)** - one or more sites to search (e.g. "on youtube", "youtube and vimeo"). Default: **any** - pick the platforms most likely to host the kind of content described.
- **Criteria** - the must-have elements a video needs to show. This is required; if the request has no discernible criteria, ask what to look for before opening the browser.

## Setup

Create a per-run temp folder under the workspace `.tmp` (patchright cannot write outside the workspace):

```powershell
$runDir = Join-Path (Join-Path (Get-Location) ".tmp") ("b-video-finder-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$runDir
```

Save every screenshot into `$runDir` as JPEG (`type: "jpeg"`) with a name that encodes candidate + timestamp (e.g. `03-yt-abc123-t120.jpg`). JPEG is smaller and faster to round-trip than PNG.

Platform notes live outside this skill so they can name hosts without bloating SKILL.md:

```powershell
$notes = Join-Path $env:USERPROFILE ".local\share\b-video-finder\platforms.md"
```

If that file exists, read it before searching and apply any section whose host you are about to open.

At the end of the run, upsert **one short section per host** you actually used. Replace that host's previous section; do not append a diary. Create the parent folder if needed. Store mechanical facts only: search URL shape, how to read a result card, how to start the player, how to seek, which overlay dismisses, what failed and what worked instead. Do not store queries, titles, video URLs, criteria, or anything about the content. Do not copy these notes into SKILL.md.

```markdown
# youtube.com
- search: /results?search_query=
- cards: title from the video-title link, not the thumbnail
- player: click once, wait until video.duration is finite, then currentTime seek
- overlays: consent button on the banner
```

## Hard limits

- **Single tab.** Do all navigation in one tab. If a click spawns a new tab, close it and `browser_navigate` to the URL directly instead.
- **At most 30 seconds per video**, total wall-clock from navigating to it until you move on. The budget wins over extra frames. If a video won't load, won't seek, or hits DRM/region walls inside the budget, score it on whatever evidence you have (or `C`) and move on - never burn the budget retrying.
- **Short interactions over long scripts.** Don't build long `browser_run_code` helpers. Per video: navigate -> click the player once -> wait ~2s or until `video.duration` is a finite number -> `play()` once if still paused -> seek + screenshot immediately for each timestamp (no `browser_wait_for` between seeks) -> then judge all frames together.
- **Dismiss cookies, banners, and other overlays** that block the player or search results before interacting or screenshotting. Match the overlay's own controls (role, visible label on the banner). Do not click a result title or other page text just because it contains "accept" / "ok".
- **Abandon stuck scripts.** If a `browser_evaluate` / `browser_run_code` call hangs or errors, don't retry the same script - switch method: seek by clicking positions on the player's seek bar, or use keyboard shortcuts (arrow keys, digit keys jump to 10%/20%/... on many players), and screenshot whatever frame that lands on. A cruder probe within budget beats a perfect script that never returns.

## 1. Search

For each platform:

1. Navigate to the platform's search results for a query derived from the criteria. The first phrasing is a guess - the same words often name a different arrangement on that platform. Keep 2-3 phrasings ready (the specific arrangement, plus a broader query that still has the same people or setting). If the first page is mostly a different reading of the words, reword immediately; do not drain a bad list.
2. Extract candidates from the results (one short evaluate can return URL, title, duration, thumbnail, and tags as JSON). Read the title from the card's title/name text, not from thumbnail markup. Drop non-result links (watch-later, channel rails, ads). Start opening the plausible ones - don't screenshot the results page first, and don't stockpile a 2-3x batch before verifying.
3. **Skip from metadata before opening.** If title, duration, or tags already fail a hard criterion (too short, wrong genre, compilation when a single scene is required, sequential wording like "then" when the criterion is a simultaneous arrangement, etc.), do not open that video. Skipped-from-metadata videos are not verified and do not go in the report.
4. After a video meets the bar, pull the related / recommended / up-next rail on that page and prefer those next - their thumbnails often show the arrangement more clearly than search titles.

Go back for more (next result page, reworded query, next platform) when the current result list is exhausted or is clearly the wrong reading of the query.

## 2. Handle login walls

Some sites gate playback or search behind login. When that happens:

- Click the **Sign in with Google** option and choose my account.
- If Google asks for a password, 2FA, or any challenge the browser session can't answer, pause and tell the user to complete the login in the browser window, then continue.
- Don't create accounts, and don't dismiss-and-retry around a hard login wall - log in or skip the platform.

## 3. Verify each candidate

Judge with frames, not metadata - but only after the video survived the metadata skip. Per candidate, within the 30-second budget:

1. Navigate to the video.
2. Click the player once, wait ~2 seconds. A `<video>` node existing is not ready: wait until `readyState >= 2` and `duration` is a finite number, or the 2s elapsed. If still paused, `video.play()` once, then seek. Do not retry a null duration.
3. Read duration from `document.querySelector('video').duration` - not from a duration badge elsewhere on the page (those are often a related video or an ad). Pick probe timestamps: **3 by default**, spread across ~10%-90% of the duration. If the criterion is a specific arrangement that is usually a later beat, not the opening, bias the back half and always keep one late probe (~90%). Longer videos get more - one extra frame per 10 minutes after the first 10 minutes - as many as the 30-second budget allows. A compilation or long video cannot be confirmed from a handful of cuts: rate only the frames you captured.
4. For each timestamp: set `video.currentTime = <t>` in a one-line evaluate and screenshot immediately to `$runDir`. Do **not** `browser_wait_for` between seeks. If a frame is blank, clearly stale (previous timestamp still showing), or a bumper / slate / trailer card, one immediate retry of that timestamp is enough. Do not treat a bumper as evidence.
5. **Take all screenshots first, then evaluate them together** in one pass against the criteria. Do not score mid-stream.

If the player blocks seeking, fall back to whatever frames you can get (poster frame, early playback) and rate on that evidence.

## 4. Score

Rate every verified candidate:

| Rating | Meaning |
|--------|---------|
| **S** | Perfect match - all criteria clearly visible, high certainty |
| **A** | Match with high certainty - criteria present, minor ambiguity |
| **B** | Confident match - criteria appear present but evidence is partial |
| **C** | Probably not a match - weak or contradicting evidence |
| **D** | Not a match |

Record per candidate: platform, URL, title, duration, thumbnail, rating, a one-line justification, and the tags you'd classify the video with (short descriptive labels based on what the frames actually show). After each verified candidate, append one line to `$runDir/log.txt` (url, title, duration, rating) so report fields do not drift.

The same people or setting without the asked-for arrangement is not a match. One ambiguous still of a similar-looking setup is at most **B**. The title naming the criterion is not evidence.

Stop when the target is met (e.g. 10 videos rated B or better), or when candidates and reasonable query variations are exhausted - in that case report the shortfall honestly rather than inflating ratings.

## 5. Report

Write a self-contained dark-theme HTML file to `$runDir` and open it in the default browser. One table, rows sorted best rating first (S -> D), columns:

| # | Platform | Thumbnail | Title | Duration | Rating | Tags |

- **Thumbnail** - the platform's thumbnail URL when you captured one, else a relative path to one of the run's screenshots.
- **Title** - a clickable link to the video URL (`target="_blank"`).
- **Rating** - the letter plus the one-line justification underneath in smaller muted text.
- **Tags** - your classification labels, comma-separated.

Include every candidate you actually verified - the below-threshold ones too, so the user can see what was rejected and why. HTML-escape titles and attribute values; write the file UTF-8; `Start-Process` it; print the path.

Finish the terminal side with a one-line summary: how many videos met the bar out of how many verified, and per-platform counts.
