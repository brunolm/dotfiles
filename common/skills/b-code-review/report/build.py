"""Assemble per-target review fragments into one self-contained HTML report.

Usage: python build.py <work-dir> <out.html> [--title TEXT] [--repo OWNER/NAME] [--no-gh]

<work-dir> holds one `<slug>.json` + `<slug>.html` pair per reviewed target (PR or branch).
Targets are ordered by the JSON `order` field, then by file name.
"""

import argparse
import datetime
import html
import json
import pathlib
import re
import subprocess

STYLE = pathlib.Path(__file__).with_name("style.css")
SEVERITIES = ("blocker", "major", "minor", "nit")
e = html.escape


def main():
    args = parse_args()
    work = pathlib.Path(args.work_dir)
    out = pathlib.Path(args.out)
    gh = not args.no_gh
    me = gh_text(["api", "user", "--jq", ".login"]) if gh else ""
    repo = args.repo or (gh_text(["repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"]) if gh else "")

    targets, missing = load_targets(work)
    for t in targets:
        t["mine"] = my_reviews(repo, t["id"], me) if gh and me and repo else None
    totals = {k: sum(t["data"].get(k, 0) for t in targets) for k in SEVERITIES}

    out.write_text(render_page(args.title, out.stem, targets, missing, totals, me), encoding="utf8")
    print(f"wrote {out} - {len(targets)} targets, missing {missing}, totals {totals}")


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("work_dir")
    p.add_argument("out")
    p.add_argument("--title", default=f"Code review ({datetime.date.today().isoformat()})")
    p.add_argument("--repo", default="")
    p.add_argument("--no-gh", action="store_true", help="skip GitHub lookups (repo, login, posted-review counts)")
    return p.parse_args()


def gh_text(argv):
    try:
        out = subprocess.run(["gh", *argv], capture_output=True, text=True, timeout=60)
        return out.stdout.strip() if out.returncode == 0 else ""
    except (OSError, subprocess.TimeoutExpired):
        return ""


def load_targets(work):
    targets, missing = [], []
    for jp in sorted(work.glob("*.json")):
        hp = jp.with_suffix(".html")
        if not hp.exists():
            missing.append(jp.stem)
            continue
        data = json.loads(jp.read_text(encoding="utf8"))
        data.setdefault("id", jp.stem)
        targets.append({"id": str(data["id"]), "slug": jp.stem, "data": data, "section": prepare_section(hp.read_text(encoding="utf8"), data)})
    targets.sort(key=lambda t: (t["data"].get("order", 0), t["slug"]))
    return targets, missing


def prepare_section(section, data):
    section = section.replace('<details class="part" open>', '<details class="part">')
    return re.sub(r'(<p class="lede">.*?</p>)', lambda m: m.group(1) + where_html(data.get("where")), section, count=1, flags=re.S)


def where_html(rows):
    if not rows:
        return ""
    body = "".join(f"<tr><td>{k}</td><td>{v}</td></tr>" for k, v in rows)
    return f'<h3>Where to see it</h3><table class="ba where"><tbody>{body}</tbody></table>'


def my_reviews(repo, target_id, me):
    if not target_id.isdigit():
        return None
    count = gh_text(["api", "--paginate", f"repos/{repo}/pulls/{target_id}/reviews", "--jq", f'[.[] | select(.user.login=="{me}")] | length'])
    return sum(int(n) for n in count.split()) if count else None


def render_page(title, store, targets, missing, totals, me):
    has_mine = any(t["mine"] is not None for t in targets)
    rows = "\n".join(render_row(t, has_mine) for t in targets)
    sections = "\n".join(t["section"] for t in targets)
    targets_line = ", ".join(e(label(t)) for t in targets)
    mine_kpi = f'<div class="kpi"><b>{sum(t["mine"] or 0 for t in targets)}</b><span>My reviews posted</span></div>' if has_mine else ""
    mine_th = "<th>My reviews</th>" if has_mine else ""
    mine_note = f' "My reviews" counts reviews submitted on GitHub by <code>{e(me)}</code> when this report was built.' if has_mine else ""
    kpis = "".join(f'<div class="kpi"><b style="color:var(--{k})">{totals[k]}</b><span>{k.capitalize() + ("s" if k in ("blocker", "nit") else "")}</span></div>' for k in SEVERITIES)
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{e(title)}</title>
<style>{STYLE.read_text(encoding="utf8")}</style></head>
<body><main>
<h1>{e(title)}</h1>
<p class="sub">{datetime.date.today().isoformat()} · {targets_line} · code links point at each target's reviewed head commit · checkboxes are saved in this browser (localStorage)</p>
<div class="kpis">{kpis}{mine_kpi}</div>
<div class="note">{flagged(targets, "blocker", "Blockers")}{flagged(targets, "major", "Majors")}{f" Missing fragments: {e(', '.join(missing))}." if missing else ""}{mine_note}</div>
<p class="progress" id="progress"></p>
<table><thead><tr><th>Looked</th><th>Target</th><th>Title</th><th>Author</th><th>Size</th><th>Blocker</th><th>Major</th><th>Minor</th><th>Nit</th>{mine_th}<th>Verdict</th><th>Findings done</th></tr></thead><tbody>
{rows}
</tbody></table>
<div class="filters">Show:
<label><input type="checkbox" data-filter="blocker" checked> Blocker</label>
<label><input type="checkbox" data-filter="major" checked> Major</label>
<label><input type="checkbox" data-filter="minor" checked> Minor</label>
<label><input type="checkbox" data-filter="nit" checked> Nit</label>
<label><input type="checkbox" id="hide-done"> Hide done findings</label>
</div>
{sections}
<dialog class="detail" id="detail"><div class="head"><h2 id="detail-title"></h2><button class="close" id="detail-close" aria-label="Close" autofocus>×</button></div><div class="body" id="detail-body"></div></dialog>
</main>
<script>{SCRIPT.replace("__STORE__", json.dumps(store))}</script>
</body></html>
"""


def render_row(t, has_mine):
    d, slug = t["data"], t["slug"]
    author = f'<code>{e(d.get("author", ""))}</code>' + (f' (<code>{e(d["authorName"])}</code>)' if d.get("authorName") and d["authorName"] != d.get("author") else "")
    size = f'{d.get("files", 0)} files, +{d.get("additions", 0)}/-{d.get("deletions", 0)}'
    nums = "".join(f'<td class="num {k if d.get(k, 0) else "zero"}">{d.get(k, 0)}</td>' for k in SEVERITIES)
    mine = ""
    if has_mine:
        m = t["mine"]
        mine = f'<td class="num myrev{"" if m else " zero"}">{"—" if m is None else m}</td>'
    return (
        f'<tr data-slug="{e(slug)}"><td><input type="checkbox" class="track pr-track" data-key="{e(slug)}" aria-label="Looked at {e(label(t))}"></td>'
        f'<td class="mono"><a href="#{e(slug)}">{e(label(t))}</a></td>'
        f'<td>{e(d.get("title", ""))}<button class="headline" data-slug="{e(slug)}" title="Show details">{e(d.get("headline", ""))}</button></td>'
        f'<td>{author}</td><td class="mono">{size}</td>{nums}{mine}'
        f'<td><span class="pill {e(d.get("tone", "ok"))}">{e(d.get("verdict", ""))}</span></td>'
        f'<td class="mono"><span class="pr-progress" data-slug="{e(slug)}"></span></td></tr>'
    )


def flagged(targets, key, name):
    hit = [t for t in targets if t["data"].get(key)]
    if not hit:
        return f"No {name.lower()}. "
    return f"{name}: " + "; ".join(f'<a href="#{e(t["slug"])}">{e(label(t))}</a> {e(t["data"].get("verdict", ""))}' for t in hit) + ". "


def label(t):
    return f'#{t["id"]}' if t["id"].isdigit() else t["id"]


SCRIPT = """
const STORE = __STORE__;
const state = JSON.parse(localStorage.getItem(STORE) || "{}");
const hideDone = document.getElementById("hide-done");
const dialog = document.getElementById("detail");

function render() {
  const sevOn = Object.fromEntries([...document.querySelectorAll("[data-filter]")].map((cb) => [cb.dataset.filter, cb.checked]));
  document.querySelectorAll("section .finding").forEach((el) => {
    const cb = el.querySelector("input.track");
    const done = !!cb && cb.checked;
    el.classList.toggle("done", done);
    el.classList.toggle("hidden", sevOn[el.dataset.sev] === false || (hideDone.checked && done));
  });
  document.querySelectorAll("input.pr-track").forEach((cb) => cb.closest("tr").classList.toggle("done", cb.checked));
  let all = 0, doneAll = 0;
  document.querySelectorAll(".pr-progress").forEach((el) => {
    const f = [...document.querySelectorAll("#" + CSS.escape(el.dataset.slug) + " .finding input.track")];
    const d = f.filter((cb) => cb.checked).length;
    all += f.length; doneAll += d;
    el.textContent = f.length ? d + "/" + f.length : "—";
  });
  const prDone = document.querySelectorAll("input.pr-track:checked").length;
  document.getElementById("progress").innerHTML = "<b>" + prDone + "/" + document.querySelectorAll("input.pr-track").length + "</b> targets looked at · <b>" + doneAll + "/" + all + "</b> findings done";
}

function openDetail(slug) {
  const row = document.querySelector('tr[data-slug="' + CSS.escape(slug) + '"]');
  const section = document.getElementById(slug);
  const cells = row.querySelectorAll("td");
  document.getElementById("detail-title").innerHTML = cells[1].innerHTML + " " + cells[2].firstChild.textContent;
  const body = document.getElementById("detail-body");
  body.replaceChildren();
  const add = (html) => body.insertAdjacentHTML("beforeend", html);
  add('<p><span class="pill ' + row.querySelector(".pill").className.replace("pill", "").trim() + '">' + row.querySelector(".pill").textContent + "</span></p>");
  add("<p>" + row.querySelector("button.headline").innerHTML + "</p>");
  const heads = [...document.querySelectorAll("thead th")].map((th) => th.textContent);
  add('<div class="counts">' + [...cells].slice(3, -2).map((td, i) => "<span>" + heads[i + 3] + ": <b>" + td.innerHTML + "</b></span>").join("") + "</div>");
  section?.querySelectorAll(".finding").forEach((f) => {
    const copy = f.cloneNode(true);
    copy.classList.remove("hidden");
    copy.querySelectorAll("input").forEach((i) => i.remove());
    body.append(copy);
  });
  const summary = section?.querySelector(".summary");
  if (summary) body.append(summary.cloneNode(true));
  add('<p><a href="#' + slug + '" id="detail-jump">Go to the full section ↓</a></p>');
  document.getElementById("detail-jump").addEventListener("click", () => dialog.close());
  dialog.showModal();
}

document.querySelectorAll("input.track").forEach((cb) => {
  cb.checked = !!state[cb.dataset.key];
  cb.addEventListener("change", () => { state[cb.dataset.key] = cb.checked; localStorage.setItem(STORE, JSON.stringify(state)); render(); });
});
document.querySelectorAll("[data-filter]").forEach((cb) => cb.addEventListener("change", render));
hideDone.addEventListener("change", render);
document.querySelectorAll("button.headline").forEach((b) => b.addEventListener("click", () => openDetail(b.dataset.slug)));
document.getElementById("detail-close").addEventListener("click", () => dialog.close());
dialog.addEventListener("click", (ev) => { if (ev.target === dialog) dialog.close(); });
render();
"""

if __name__ == "__main__":
    main()
