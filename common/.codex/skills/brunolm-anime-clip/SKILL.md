---
name: brunolm-anime-clip
description: Use this skill when the user wants to cut a clip from an anime episode and get the spoken Japanese + romaji for that moment. Triggers include "/brunolm-anime-clip", "make a clip of <episode> <time range>", "clip <show> from MM:SS to MM:SS", "cut <episode> <start>~<end> and give me the japanese/romaji", or any phrasing pairing a video file + a time range with intent to export a short clip. Takes the video (name or path) and a time range, renders an optimized, subtitle-burned MP4 into the Downloads folder, then prints the dialogue that falls inside the clip as Japanese + Hepburn romaji. Optionally accepts a path (file or folder) telling it where to find external subtitle files.
version: 1.0.0
allowed-tools:
  - PowerShell
  - Glob
  - Read
---

# Anime clip + Japanese/romaji

Cut a short, optimized, subtitle-burned clip from an anime episode into the user's **Downloads** folder, then report the dialogue spoken inside that window as **Japanese + romaji**.

The deterministic media work (resolve tracks, time-shift subs/fonts, frame-accurate cut, burn-in, encode) is done by the bundled **`clip.ps1`**. Your job is to parse the request, call the script, then turn its JSON output into the final summary + Japanese/romaji block.

## Inputs

Parse these from the user's request (ask only if genuinely missing/ambiguous):

1. **Video** - a name fragment (e.g. `S01E17`, `Moonlight`) or a full path. Resolve it to one file (see step 1).
2. **Time range** - start and end, e.g. `15:42 ~ 16:14`, `15:42 - 16:14`, `15:42 to 16:14`. Each endpoint is `MM:SS` or `HH:MM:SS`. (`13:43` means 13 min 43 s.)
3. **Subtitle source** *(optional)* - a path to an external subtitle **file** or a **folder** of subtitle files, for when the episode has no embedded subs or the user wants a specific one. Omit to use the episode's embedded subtitles.

Defaults baked into `clip.ps1` (match the user's established "optimized H.265 clip" preference - only override if the user asks):

- Codec **H.265** (`libx265`, CRF **26**, preset **slow**, `hvc1` tag, `yuv420p`). `-Codec h264` switches to libx264 CRF 21.
- **Japanese** audio track, **AAC** stereo 160 kbps.
- Best **dialogue** subtitle burned in (prefers a track titled *Full*, avoids *Signs/Songs*), with the episode's embedded fonts.
- MP4 with `+faststart`, stray data/chapter tracks dropped.
- Output name: `<episode> - clip (<start>-<end>) [h265].mp4` in `~/Downloads`.

## 1. Resolve the video file

If the user gave a full path that exists, use it. Otherwise search for it - default to the current working directory, but if the request names a different library/location search there. Use **Glob** (e.g. `**/*S01E17*.{mkv,mp4}`) or PowerShell.

- **One match** -> use it.
- **Multiple** -> list them and ask which (or pick the obvious one if the fragment clearly points at a single episode).
- **None** -> tell the user; don't guess a path.

## 2. Run the clip script

Call the bundled script with the resolved values. It is at `<this skill folder>/clip.ps1`.

```powershell
& "C:\BrunoLM\Projects\dotfiles\common\.codex\skills\brunolm-anime-clip\clip.ps1" `
  -Video "<full path to episode>" `
  -Start "15:42" -End "16:14"
```

Add `-SubtitleSource "<path>"` when the user pointed at external subs (file or folder). Other optional params: `-Codec h264`, `-Crf <n>`, `-Preset <name>`, `-AudioLang <iso639-2>`, `-OutDir "<path>"`.

The encode for ~30-70 s of 1080p takes roughly 1-3 minutes; allow a generous timeout. x265 prints progress/info to stderr - that's normal, not an error.

The script prints a JSON object between `===BRUNOLM_ANIME_CLIP_JSON===` and `===END_BRUNOLM_ANIME_CLIP_JSON===`. Parse that block. Key fields:

- `output`, `sizeMB`, `durationSec` - the finished clip.
- `codec`, `crf`, `preset`, `audioTrack`, `audioNote`, `subtitleSource` - what was used (`audioNote` is set only when the requested audio language was missing and a fallback was used; surface it if present).
- `burnedLines` - the dialogue lines (with times + text) inside the clip window, from the burned subtitle. Usually **English** for these releases.
- `japaneseLines` - populated **only** if the video carried a Japanese-language subtitle track (rare). Each has time + Japanese text.
- `hasJapaneseSource` - `true` when `japaneseLines` is real extracted Japanese.

If `clip.ps1` throws, read the message - common causes are an unresolved path, end <= start, or no audio/subtitle stream - fix the inputs and retry.

## 3. Produce the Japanese + romaji

This is the part only you can do. Two cases:

- **`hasJapaneseSource` is true** - use `japaneseLines` as the authoritative Japanese, in order. Romanize each into **Hepburn** romaji. This is high-confidence; present it plainly.
- **`hasJapaneseSource` is false** (the normal case - these rips have English/Italian subs, no Japanese track) - there is **no Japanese to extract**. Reconstruct the spoken Japanese for each `burnedLines` entry from the English meaning + the show's actual dialogue where you recognize the scene, then romanize. **Be honest:** state clearly that the Japanese is a best-effort reconstruction (not extracted from a Japanese subtitle track), and don't overstate confidence on lines you're unsure of. Note proper nouns you're confident about (e.g. `シャドウ！` -> `Shadou!`).

Romaji style: Hepburn, with long vowels (ō/ū), word-spaced, sentence punctuation preserved - matching the example the user gave:

> 仰ぎ見よ！…我が至高にして究極たる、最強無比の一撃を……！
> Aogimiyo! … Waga shikō ni shite kyūkyoku-taru, saikyō-muhi no ichigeki o…!

## 4. Report

Show a compact summary, then the text. Suggested shape:

- One line confirming the clip path in Downloads, plus a small table: size, duration, codec/CRF, audio, subtitle source.
- A **Text in this clip** section: for each line, the Japanese and the romaji (and optionally the English gloss). If you reconstructed the Japanese, say so once up front.
- If `burnedLines` is empty (no subtitle source, or no dialogue in the window), say the clip has no spoken subtitle lines in that range and offer to widen the range or point at an external subtitle source.

## Notes

- **Why a 0-based subtitle copy:** the script seeks the input (`-ss` before `-i`) so the cut is frame-accurate *and* fast (decode-from-keyframe, drop to the exact frame), which resets timestamps to 0. It extracts the subtitle for the same window so its events are also 0-based and stay in sync with the burned video. Don't "fix" this by switching to output seeking - it's slow and unnecessary.
- **Why ffmpeg runs from the work dir:** libass's `subtitles` filter chokes on Windows drive-colon paths (`C:\...`) inside a filtergraph. Running with the temp work dir as CWD lets the filter use the bare relative names `subs.ass` / `fonts`, avoiding all escaping.
- **Windows filename gotcha:** clip names contain `[` `]` and `()`. Always use `-LiteralPath` with `Get-Item`/`Test-Path` on them - bare paths treat `[h265]` as a wildcard character class and silently miss.
- The script's bulk font dump (`-dump_attachment`) exits non-zero by design ("no output file") while still writing the fonts - that's handled, not a failure.
