"""
G-series documents as printable HTML (Jinja2, autoescaped). Each document carries a
footer with the case id, the time generated, a SHA-256 of its body and the notice that
it is a community record, not a government document. Headings come in English and
Marathi; the content is whatever the Gram Sabha recorded.
"""

import hashlib
import math
from datetime import UTC, datetime
from typing import Any

from jinja2 import DictLoader, Environment, select_autoescape

DISCLAIMER = "Community record prepared with VanMitra. Not a government document."

TITLES: dict[str, dict[str, str]] = {
    "g4": {"en": "Acknowledgement of claim received", "mr": "दावा प्राप्त झाल्याची पोच"},
    "g7": {"en": "Letter of intimation / request", "mr": "पत्र / पूर्वसूचना"},
    "g8": {"en": "Field verification proceeding", "mr": "प्रत्यक्ष पडताळणी कार्यवाही"},
    "g9": {"en": "Participatory boundary delineation record", "mr": "सीमा निश्चिती नोंद"},
    "g10": {"en": "Community forest resource map sheet", "mr": "सामूहिक वन संसाधन नकाशा"},
    "g12": {"en": "Attendance and quorum sheet", "mr": "उपस्थिती व गणपूर्ती पत्रक"},
    "g13": {"en": "Gram Sabha resolution", "mr": "ग्रामसभा ठराव"},
    "g17": {
        "en": "Joint meeting record for conflicting claims",
        "mr": "परस्परविरोधी दाव्यांची संयुक्त बैठक नोंद",
    },
}

LAYOUT = """<!doctype html>
<html lang="{{ lang }}"><head><meta charset="utf-8"><title>{{ title }}</title>
<style>
body{font-family:'Noto Sans Devanagari','Noto Sans',Arial,sans-serif;margin:2cm;font-size:12pt}
h1{font-size:16pt;text-align:center} h2{font-size:13pt;margin-top:1.2em}
table{border-collapse:collapse;width:100%;margin:.5em 0} td,th{border:1px solid #444;padding:4px 6px;text-align:left;vertical-align:top}
.meta td{border:none;padding:2px 6px} footer{margin-top:2em;border-top:1px solid #444;font-size:9pt;color:#333}
.sign{margin-top:2.5em} .sign span{display:inline-block;width:30%;border-top:1px solid #000;margin-right:3%;text-align:center}
</style></head><body>
<h1>{{ title }}</h1>
<table class="meta"><tr><td>Village / गाव</td><td>{{ v.name_mr }} ({{ v.name_en }})</td>
<td>Gram Panchayat</td><td>{{ v.gram_panchayat }}</td></tr>
<tr><td>Taluka</td><td>{{ v.taluka }}</td><td>District</td><td>{{ v.district }}</td></tr></table>
{{ content|safe }}
<footer>Case {{ case_id }} · generated {{ generated }} · body SHA-256 {{ digest }}<br>{{ disclaimer }}</footer>
</body></html>"""

BODIES: dict[str, str] = {
    "g4": """
<p>Serial: <b>{{ serial }}</b> · Date: {{ acknowledged_on }} · Form {{ form }}</p>
<p>Claimant: {{ claimant }}</p>
<p>Received within the call for claims: {{ 'Yes' if within_window else ('No' if within_window is false else 'No call recorded') }}</p>
<h2>Documents received</h2>
<ol>{% for d in documents %}<li>{{ d }}</li>{% else %}<li>None listed</li>{% endfor %}</ol>
<div class="sign"><span>Received by</span><span>Gram Panchayat seal</span></div>""",
    "g7": """
<p>To: {{ letter.addressee }}</p><p>Subject: {{ letter.subject }}</p>
{% if letter.body %}<p>{{ letter.body }}</p>{% endif %}
{% if letter.neighbour_village %}<p>Adjoining village: {{ letter.neighbour_village }}</p>{% endif %}
{% if letter.records_requested %}<p>Records requested:</p><ul>{% for r in letter.records_requested %}<li>{{ r }}</li>{% endfor %}</ul>{% endif %}
<p>Dispatched on: {{ letter.dispatched_on or 'not yet dispatched' }}</p>
<div class="sign"><span>Chairperson, FRC</span><span>Secretary, FRC</span></div>""",
    "g8": """
{% for p in proceedings %}
<h2>Visit {{ p.attempt_no }}: {{ p.visit_on }}</h2>
<p>{{ p.observations }}</p>
<table><tr><th>Name</th><th>Designation</th><th>Department</th></tr>
{% for x in p.presence %}<tr><td>{{ x.name }}</td><td>{{ x.designation or '' }}</td><td>{{ x.department }}</td></tr>{% endfor %}</table>
<table><tr><th>Department</th><th>Signature</th></tr>
<tr><td>Forest</td><td>{{ 'Signed' if p.forest_signed else ('Absent despite intimation' if p.forest_absence_recorded else 'Pending') }}</td></tr>
<tr><td>Revenue</td><td>{{ 'Signed' if p.revenue_signed else ('Absent despite intimation' if p.revenue_absence_recorded else 'Pending') }}</td></tr></table>
{% if p.finality_note %}<p><b>Note:</b> the officials were absent on the second visit; the Gram Sabha decision stands [Rule 12A(2)].</p>{% endif %}
{% else %}<p>No visit recorded yet.</p>{% endfor %}
<div class="sign"><span>Forest Department</span><span>Revenue Department</span><span>FRC Chairperson</span></div>""",
    "g9": """
{% for w in walks %}
<h2>Walk of {{ w.walked_on }}</h2>
<table><tr><th>Participant</th><th>Role</th></tr>
{% for p in w.participants %}<tr><td>{{ p.name }}</td><td>{{ p.role }}</td></tr>{% endfor %}</table>
{% if w.notes %}<p>{{ w.notes }}</p>{% endif %}
{% else %}<p>No walk recorded yet.</p>{% endfor %}
<h2>Segments and landmarks</h2>
<table><tr><th>Segment</th><th>Length (m)</th><th>Landmarks</th></tr>
{% for s in segments %}<tr><td>{{ s.seq + 1 }}</td><td>{{ s.length_m }}</td>
<td>{% for l in landmarks if l.segment_seq == s.seq %}{{ l.name }} ({{ l.kind.value }}){% if not loop.last %}, {% endif %}{% endfor %}</td></tr>{% endfor %}</table>
<div class="sign"><span>Elders</span><span>FRC</span><span>Gram Sabha</span></div>""",
    "g10": """
<p>Area: {{ area_ha }} ha · Boundary version {{ version }} ({{ status }}){% if sealed %} · sealed {{ sealed[:16] }}…{% endif %}</p>
{{ svg|safe }}
<h2>Landmarks</h2>
<table><tr><th>No.</th><th>Segment</th><th>Name</th><th>Kind</th><th>Position (lat, lon)</th></tr>
{% for l in landmarks %}<tr><td>{{ loop.index }}</td><td>{{ l.segment_seq + 1 }}</td><td>{{ l.name }}</td><td>{{ l.kind.value }}</td><td>{{ '%.5f'|format(l.lat) }}, {{ '%.5f'|format(l.lon) }}</td></tr>{% endfor %}</table>
<h2>Bordering villages</h2>
<p>{% for b in bordering %}{{ b }}{% if not loop.last %}, {% endif %}{% else %}None listed{% endfor %}</p>
<h2>Use zones</h2>
<table><tr><th>Use</th><th>Name</th><th>Season</th><th>Area (ha)</th></tr>
{% for z in zones %}<tr><td>{{ z.use_type.value }}</td><td>{{ z.name or '' }}</td><td>{{ z.season or '' }}</td><td>{{ z.area_ha }}</td></tr>{% else %}<tr><td colspan="4">None</td></tr>{% endfor %}</table>
<p>Resolution: {{ resolution or 'not yet passed' }}. North is up; the polygon is not clipped to forest or legal boundaries.</p>""",
    "g12": """
<p>Meeting of {{ m.held_on }} at {{ m.place }}. Agenda: {{ m.agenda }}</p>
<table><tr><th>Test</th><th>Required</th><th>Actual</th><th>Result</th></tr>
<tr><td>Members present</td><td>{{ q.required_present }} of {{ q.registered }}</td><td>{{ q.present }}</td><td>{{ 'Met' if q.t1 else 'Not met' }}</td></tr>
<tr><td>Women present</td><td>{{ q.required_women }}</td><td>{{ q.women_present }}</td><td>{{ 'Met' if q.t2 else 'Not met' }}</td></tr>
<tr><td>Claimants present</td><td>{{ q.required_claimants }} of {{ q.claimants_total }}</td><td>{{ q.claimants_present }}</td><td>{{ 'Met' if q.t3 else 'Not met' }}</td></tr></table>
<p><b>Quorum {{ 'complete' if q.passed else 'NOT complete' }}</b> [Rule 4(2)].</p>
<h2>Attendance</h2>
<table><tr><th>No.</th><th>Name</th><th>Present</th></tr>
{% for a in attendance %}<tr><td>{{ loop.index }}</td><td>{{ a.name }}</td><td>{{ 'Yes' if a.present else 'No' }}</td></tr>{% endfor %}</table>""",
    "g13": """
<p>Resolution no. <b>{{ r.number }}</b> · Meeting of {{ meeting.held_on }} at {{ meeting.place }}</p>
<p>Agenda: {{ meeting.agenda }}</p>
<h2>Decision</h2><p>{{ r.decision_text }}</p>
<p>Votes for: {{ r.votes_for }} · against: {{ r.votes_against }} · present: {{ q.present }} of {{ q.registered }} ({{ q.women_present }} women; {{ q.claimants_present }} of {{ q.claimants_total }} claimants)</p>
<p>Quorum {{ 'complete' if q.passed else 'NOT complete' }} [Rule 4(2)].{% if boundary_sealed %} Approves the boundary sealed as {{ boundary_sealed[:16] }}… [Rule 12(1)(g)].{% endif %}</p>
<div class="sign"><span>Chairperson</span><span>Secretary</span><span>Gram Sabha members</span></div>""",
    "g17": """
<p>Overlap of about {{ d.overlap_ha }} ha between the claim of {{ own }} and the claim of {{ d.neighbour_village }}. Detected on {{ d.detected_on }}.</p>
{% if d.joint_meeting_on %}<h2>Joint meeting of {{ d.joint_meeting_on }}</h2><p>{{ d.joint_meeting_findings }}</p>
<p>Outcome: {{ d.outcome.value if d.outcome else '' }}</p>{% else %}<p>No joint meeting recorded yet.</p>{% endif %}
{% if d.sdlc_referral_on %}<p>Referred to the SDLC on {{ d.sdlc_referral_on }} (ref. {{ d.sdlc_referral_ref }}) [Rule 12(3)].</p>{% endif %}
<div class="sign"><span>FRC of {{ own }}</span><span>FRC of {{ d.neighbour_village }}</span></div>""",
}

_env = Environment(
    loader=DictLoader({"layout": LAYOUT, **BODIES}), autoescape=select_autoescape(default=True)
)


def render(code: str, lang: str, village: Any, case_id: str, data: dict[str, Any]) -> str:
    titles = TITLES[code]
    title = titles["mr"] + " / " + titles["en"] if lang == "mr" else titles["en"]
    body = _env.get_template(code).render(**data)
    digest = hashlib.sha256(body.encode("utf-8")).hexdigest()
    return _env.get_template("layout").render(
        lang=lang,
        title=title,
        v=village,
        content=body,
        case_id=case_id,
        generated=datetime.now(UTC).strftime("%Y-%m-%d %H:%M UTC"),
        digest=digest,
        disclaimer=DISCLAIMER,
    )


def map_svg(
    outline: dict[str, Any],
    landmarks: list[tuple[float, float]],
    zones: list[dict[str, Any]],
    size: int = 520,
) -> str:
    """The boundary, use zones and numbered landmarks as an SVG (equirectangular, north up)."""
    rings = [outline["coordinates"][0]]
    lons = [p[0] for p in rings[0]]
    lats = [p[1] for p in rings[0]]
    min_lon, max_lon, min_lat, max_lat = min(lons), max(lons), min(lats), max(lats)
    mid_lat = math.radians((min_lat + max_lat) / 2)
    width_m = max((max_lon - min_lon) * math.cos(mid_lat), 1e-9)
    height_m = max(max_lat - min_lat, 1e-9)
    scale = (size - 40) / max(width_m, height_m)

    def xy(lon: float, lat: float) -> tuple[float, float]:
        return (
            20 + (lon - min_lon) * math.cos(mid_lat) * scale,
            size - 20 - (lat - min_lat) * scale,
        )

    def path(ring: list[list[float]]) -> str:
        return " ".join(f"{x:.1f},{y:.1f}" for x, y in (xy(p[0], p[1]) for p in ring))

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">'
    ]
    parts.append(f'<rect width="{size}" height="{size}" fill="#fff" stroke="#999"/>')
    for z in zones:
        if z["geometry"].get("type") == "Polygon":
            parts.append(
                f'<polygon points="{path(z["geometry"]["coordinates"][0])}" fill="#9ccc65" fill-opacity=".35" stroke="#558b2f"/>'
            )
    parts.append(
        f'<polygon points="{path(rings[0])}" fill="none" stroke="#b71c1c" stroke-width="2"/>'
    )
    for n, (lon, lat) in enumerate(landmarks, 1):
        x, y = xy(lon, lat)
        parts.append(
            f'<circle cx="{x:.1f}" cy="{y:.1f}" r="5" fill="#1565c0"/><text x="{x + 7:.1f}" y="{y - 5:.1f}" font-size="12">{n}</text>'
        )
    parts.append(f'<text x="{size - 30}" y="30" font-size="14">N ↑</text></svg>')
    return "".join(parts)
