#!/usr/bin/env python3
"""Builds qa/dashboard/index.html and QA_DEFECTS.md from QA artifacts.

Every number comes from files written by real runs:
  qa/reports/history.jsonl   one line per Maestro flow (scripts/qa/run_flows.sh)
  qa/reports/current.json    what is running right now
  qa/reports/code_gate.json  format/analyze/test counts (scripts/qa/code_gate.py)
  qa/defects.json            defect register, edited by hand with evidence
Nothing is estimated; a missing source renders as "yok".
"""
import html
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
QA = ROOT / "qa"
SEVERITIES = ["P0", "P1", "P2", "P3"]
OPEN = {"Open", "Reproduced", "Fixing", "Blocked", "Deferred"}


def read_json(path, fallback):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return fallback


def read_history():
    path = QA / "reports" / "history.jsonl"
    if not path.exists():
        return []
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            rows.append(json.loads(line))
        except ValueError:
            continue
    return rows


def latest_by_flow(history):
    latest = {}
    for row in history:
        latest[(row["flow"], row["device"], row.get("config", ""))] = row
    return latest


def esc(value):
    return html.escape(str(value))


def media(path):
    return f"../{esc(path)}"


def defect_rows(defects):
    out = []
    for d in defects:
        before = d.get("before")
        after = d.get("after")
        shots = ""
        if before or after:
            shots = '<div class="shots">'
            if before:
                shots += (
                    f'<a href="{media(before)}"><img src="{media(before)}" '
                    'alt="Düzeltme öncesi" loading="lazy"><span>Önce</span></a>'
                )
            if after:
                shots += (
                    f'<a href="{media(after)}"><img src="{media(after)}" '
                    'alt="Düzeltme sonrası" loading="lazy"><span>Sonra</span></a>'
                )
            shots += "</div>"
        out.append(
            f'<tr><td class="mono">{esc(d["id"])}</td>'
            f'<td><span class="sev {esc(d["severity"])}">{esc(d["severity"])}</span></td>'
            f'<td>{esc(d["screen"])}</td><td>{esc(d["problem"])}{shots}</td>'
            f'<td>{esc(d["root_cause"])}</td><td>{esc(d["status"])}</td>'
            f'<td>{esc(d.get("regression", "—"))}</td></tr>'
        )
    return "\n".join(out)


def run_rows(history):
    out = []
    for r in reversed(history[-60:]):
        video = pathlib.Path(r["dir"]) / "video.mp4"
        report = pathlib.Path(r["dir"]) / "report.html"
        links = []
        if (ROOT / video).exists():
            links.append(f'<a href="{media(video.relative_to("qa"))}">video</a>')
        if (ROOT / report).exists():
            links.append(f'<a href="{media(report.relative_to("qa"))}">rapor</a>')
        out.append(
            f'<tr><td class="mono">{esc(r["ts"])}</td><td>{esc(r["flow"])}</td>'
            f'<td>{esc(r["device"])} · {esc(r.get("runtime", ""))}'
            f'{(" · " + esc(r["config"])) if r.get("config") else ""}</td>'
            f'<td><span class="res {esc(r["result"])}">{esc(r["result"])}</span></td>'
            f'<td>{esc(r["seconds"])} sn</td><td>{" · ".join(links)}</td></tr>'
        )
    return "\n".join(out)


def videos(latest):
    cards = []
    for row in sorted(latest.values(), key=lambda r: r["flow"]):
        if row["result"] != "PASS":
            continue
        video = pathlib.Path(row["dir"]) / "video.mp4"
        if not (ROOT / video).exists():
            continue
        src = media(video.relative_to("qa"))
        cards.append(
            f'<figure><video src="{src}" controls preload="none"></video>'
            f'<figcaption>{esc(row["flow"])} · {esc(row["device"])}</figcaption></figure>'
        )
    return "\n".join(cards[:12]) or "<p>Kayıt yok.</p>"


def write_defects_md(defects):
    lines = [
        "# QA_DEFECTS — Vocalart",
        "",
        "`qa/defects.json` dosyasından üretilir; elle düzenleme yapma.",
        "",
        "| ID | Ekran | Önem | Sorun | Kök neden | Durum | Kanıt |",
        "|---|---|---|---|---|---|---|",
    ]
    for d in defects:
        evidence = d.get("regression", "—")
        lines.append(
            "| {id} | {screen} | {severity} | {problem} | {root_cause} | {status} | {e} |".format(
                e=evidence, **{k: str(v).replace("|", "/") for k, v in d.items()}
            )
        )
    (ROOT / "QA_DEFECTS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    history = read_history()
    latest = latest_by_flow(history)
    current = read_json(QA / "reports" / "current.json", {"status": "IDLE"})
    gate = read_json(QA / "reports" / "code_gate.json", None)
    defects = read_json(QA / "defects.json", [])
    write_defects_md(defects)

    passed = sum(r["result"] == "PASS" for r in latest.values())
    failed = sum(r["result"] != "PASS" for r in latest.values())
    blocked = sum(d["status"] == "Blocked" for d in defects)
    by_sev = {
        s: (
            sum(d["severity"] == s for d in defects),
            sum(d["severity"] == s and d["status"] in OPEN for d in defects),
        )
        for s in SEVERITIES
    }
    verified = sum(d["status"] == "Verified" for d in defects)
    live = (
        f'<b>Çalışıyor:</b> {esc(current.get("flow", ""))} · {esc(current.get("device", ""))}'
        if current.get("status") == "RUNNING"
        else "<b>Boşta</b> — çalışan senaryo yok"
    )
    gate_text = (
        f'{gate["passed"]} geçti · {gate["failed"]} başarısız · {gate["skipped"]} atlandı'
        f' · format {gate["format"]} · analyze {gate["analyze"]} · {esc(gate["ts"])}'
        f'{(" · düşen adım: " + esc(gate["failedStep"])) if gate.get("failedStep") else ""}'
        if gate
        else "yok"
    )
    sev_cards = "".join(
        f'<div class="stat"><span class="sev {s}">{s}</span>'
        f"<b>{by_sev[s][0]}</b><small>{by_sev[s][1]} açık</small></div>"
        for s in SEVERITIES
    )
    page = f"""<!doctype html>
<html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="5">
<title>Vocalart QA</title>
<style>
:root {{ --bg:#f8f6f2; --card:#fff; --ink:#27183a; --muted:#6b6478; --line:#e6e1ea;
  --accent:#6e40e8; --good:#14804a; --bad:#c62f2f; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg:#17121f; --card:#221b2d; --ink:#f2eef8;
  --muted:#a79fb6; --line:#372e45; --accent:#a98bff; --good:#4cc98a; --bad:#ff7b7b; }} }}
* {{ box-sizing:border-box; }}
body {{ margin:0; background:var(--bg); color:var(--ink);
  font:15px/1.5 -apple-system, "Segoe UI", sans-serif; }}
main {{ max-width:1180px; margin:0 auto; padding:24px 16px 64px; }}
h1 {{ margin:0; font-size:26px; }} h2 {{ margin:32px 0 10px; font-size:17px; }}
.live {{ margin-top:10px; padding:10px 14px; background:var(--card); border:1px solid var(--line);
  border-radius:10px; }}
.stats {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(130px,1fr)); gap:10px; }}
.stat {{ background:var(--card); border:1px solid var(--line); border-radius:10px; padding:12px;
  display:flex; flex-direction:column; gap:2px; }}
.stat b {{ font-size:24px; font-variant-numeric:tabular-nums; }}
.stat small {{ color:var(--muted); }}
.scroll {{ overflow-x:auto; background:var(--card); border:1px solid var(--line);
  border-radius:10px; }}
table {{ border-collapse:collapse; width:100%; min-width:760px; }}
th,td {{ text-align:left; padding:9px 12px; border-bottom:1px solid var(--line);
  vertical-align:top; font-size:13.5px; }}
th {{ color:var(--muted); font-weight:600; }}
.mono {{ font-family:ui-monospace,Menlo,monospace; font-size:12px; white-space:nowrap; }}
.sev,.res {{ font-weight:700; font-size:12px; }}
.sev.P0,.sev.P1,.res.FAIL {{ color:var(--bad); }} .res.PASS {{ color:var(--good); }}
.sev.P2 {{ color:var(--accent); }} .sev.P3 {{ color:var(--muted); }}
.shots {{ display:flex; gap:8px; margin-top:8px; }}
.shots a {{ color:var(--muted); font-size:12px; text-decoration:none; }}
.shots img {{ display:block; width:96px; border-radius:6px; border:1px solid var(--line); }}
.videos {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(180px,1fr)); gap:12px; }}
figure {{ margin:0; }} video {{ width:100%; border-radius:8px; background:#000; }}
figcaption {{ font-size:12px; color:var(--muted); margin-top:4px; }}
a {{ color:var(--accent); }}
</style></head><body><main>
<h1>Vocalart QA</h1>
<div class="live">{live}</div>
<h2>Son durum (her senaryonun cihaz başına son koşusu)</h2>
<div class="stats">
<div class="stat"><small>Geçen senaryo</small><b>{passed}</b></div>
<div class="stat"><small>Başarısız senaryo</small><b>{failed}</b></div>
<div class="stat"><small>Engelli hata</small><b>{blocked}</b></div>
<div class="stat"><small>Doğrulanan düzeltme</small><b>{verified}</b></div>
{sev_cards}
</div>
<h2>Kod kapısı</h2><div class="live">{gate_text}</div>
<h2>Hatalar</h2>
<div class="scroll"><table><thead><tr><th>ID</th><th>Önem</th><th>Ekran</th><th>Sorun</th>
<th>Kök neden</th><th>Durum</th><th>Regresyon</th></tr></thead><tbody>
{defect_rows(defects)}
</tbody></table></div>
<h2>Yolculuk kayıtları</h2><div class="videos">{videos(latest)}</div>
<h2>Çalıştırma geçmişi</h2>
<div class="scroll"><table><thead><tr><th>Koşu</th><th>Senaryo</th><th>Cihaz</th><th>Sonuç</th>
<th>Süre</th><th>Çıktı</th></tr></thead><tbody>
{run_rows(history)}
</tbody></table></div>
</main></body></html>
"""
    out = QA / "dashboard" / "index.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page, encoding="utf-8")
    print(out)


if __name__ == "__main__":
    main()
