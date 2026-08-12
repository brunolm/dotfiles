---
name: b-video-finder
description: Use this skill when the user wants to find videos matching specific content criteria, verified by actually opening each video and inspecting frames. Triggers include "/b-video-finder", "find me N videos that show X", "search <site> for videos containing X", "look for videos with X", or any phrasing pairing video search with must-have visual criteria. Drives a real browser via the patchright MCP, screenshots each candidate at several timestamps, scores every candidate S/A/B/C/D against the criteria, keeps searching until the target count at the minimum rating is met (default 10 at B or better), then writes and opens an HTML report table (platform, thumbnail, title, duration, rating, tags).
version: 1.0.0
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

Find videos that actually contain what the user asked for - not videos whose *title* claims to. Search one or more video platforms with the patchright browser MCP, open each promising candidate, capture frames from several points in the video, judge those frames against the criteria, and score the match. Keep going until enough videos meet the bar, then deliver an HTML report.

## What the user specifies

Parse these from the text after the skill name (all optional except criteria):

- **Target** - how many videos at what minimum rating, written like `10 B+` (count + rating + `+` meaning "or better"). Default: **10 at B or better**.
- **Platform(s)** - one or more sites to search (e.g. "on youtube", "youtube and vimeo"). Default: **any** - pick the platforms most likely to host the kind of content described.
- **Criteria** - the must-have elements a video needs to show. This is required; if the request has no discernible criteria, ask what to look for before opening the browser.

## Setup

Create a per-run temp folder for screenshots, debug artifacts, and the report:

```powershell
$runDir = Join-Path $env:TEMP ("b-video-finder-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $runDir | Out-Null
$runDir
```

Save every screenshot into `$runDir` with a name that encodes candidate + timestamp (e.g. `03-yt-abc123-t120.png`) so the report can reference them and debugging a misjudged video is possible after the fact.

## Hard limits

- **Single tab.** Do all navigation in one tab. If a click spawns a new tab, close it and `browser_navigate` to the URL directly instead.
- **At most 30 seconds per video**, total wall-clock from navigating to it until you move on. If a video won't load, won't seek, or hits DRM/region walls inside the budget, score it on whatever evidence you have (or `C`) and move on - never burn the budget retrying.
- **Short interactions over long scripts.** Don't build long `browser_run_code` helpers. The whole per-video path is: navigate -> click the player once (to start playback / satisfy autoplay gating) -> wait ~2s -> set `video.currentTime` via a one-line evaluate -> screenshot. Repeat the seek + screenshot per timestamp.
- **Dismiss cookies, banners, and other overlays** that block the player or search results before interacting or screenshotting.
- **Abandon stuck scripts.** If a `browser_evaluate` / `browser_run_code` call hangs or errors, don't retry the same script - switch method: seek by clicking positions on the player's seek bar, or use keyboard shortcuts (arrow keys, digit keys jump to 10%/20%/... on many players), and screenshot whatever frame that lands on. A cruder probe within budget beats a perfect script that never returns.

## 1. Search

For each platform:

1. Navigate to the platform's search results for a query derived from the criteria.
2. **Screenshot the page first** to see where things are before interacting - search box, result cards, filters. Use the screenshot (plus `browser_snapshot` when you need element refs) to orient; don't guess selectors blind.
3. Collect a batch of candidates from the results: URL, title, duration, and thumbnail URL (grab `img` `src` attributes from the results page - one short evaluate can return all of them as JSON). Prefer candidates whose title/thumbnail/duration already look plausible for the criteria.

Collect roughly 2-3x the target count of candidates before verifying, and go back for more (next result page, reworded query, next platform) if verification burns through them.

## 2. Handle login walls

Some sites gate playback or search behind login. When that happens:

- Click the **Sign in with Google** option and choose my account.
- If Google asks for a password, 2FA, or any challenge the browser session can't answer, pause and tell the user to complete the login in the browser window, then continue.
- Don't create accounts, and don't dismiss-and-retry around a hard login wall - log in or skip the platform.

## 3. Verify each candidate

Judge with frames, not metadata. Per candidate, within the 30-second budget:

1. Navigate to the video.
2. Click the player once, wait ~2 seconds for playback to start.
3. Read the duration (`document.querySelector('video').duration`) and pick the probe timestamps: **at least 8**, spread evenly across ~5%-95% of the duration (skip intros/outros). Longer videos get more - roughly one probe per 2 minutes - as many as the 30-second budget allows.
4. For each timestamp: set `video.currentTime = <t>` in a one-line evaluate, wait ~1s for the seek to render, screenshot to `$runDir`.
5. **Take all screenshots first, then evaluate them together** in one pass against the criteria - one combined judgment per video is faster and more consistent than deciding frame-by-frame.

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

Record per candidate: platform, URL, title, duration, thumbnail, rating, a one-line justification, and the tags you'd classify the video with (short descriptive labels based on what the frames actually show).

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
