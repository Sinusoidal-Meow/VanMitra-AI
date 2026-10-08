"""
Boundary geometry with Shapely + PyProj: validity, areas/lengths in UTM 43N, GeoJSON out,
and overlap detection against neighbouring villages' claims, which opens disputes [Rule 12(3)].
"""

import hashlib
import json
import uuid
from datetime import date
from decimal import Decimal
from typing import Any

import numpy as np
import numpy.typing as npt
import shapely
from pyproj import Transformer
from shapely.geometry import mapping, shape
from shapely.validation import explain_validity

from ..db import Store
from ..geo import GeoError
from ..models import (
    BoundaryStatus,
    CaseState,
    CfrBoundary,
    ClaimCase,
    ClaimType,
    Dispute,
    DisputeOutcome,
    GramSabha,
    Village,
)
from ..schemas.boundary import (
    BoundaryOut,
    DisputeOut,
    LandmarkOut,
    SegmentOut,
    UseZoneOut,
)

GPS_LIMIT_M = 15.0  # B-14
CLOSED_STATES = (CaseState.REJECTED, CaseState.EXPIRED)
MIN_OVERLAP_HA = Decimal("0.0001")  # 1 m²: below this it is GPS noise along a shared edge

_transformer = Transformer.from_crs("EPSG:4326", "EPSG:32643", always_xy=True)


def to_utm(geom: Any) -> Any:
    """The shape in UTM zone 43N metres, for areas, lengths and distances."""
    return shapely.transform(geom, _project)


def _project(coords: npt.NDArray[np.float64]) -> npt.NDArray[np.float64]:
    xs, ys = _transformer.transform(coords[:, 0], coords[:, 1])
    return np.column_stack([xs, ys])


def ensure_valid(geom_or_wkt: str | dict[str, Any]) -> None:
    geom = shapely.from_wkt(geom_or_wkt) if isinstance(geom_or_wkt, str) else shape(geom_or_wkt)
    if not geom.is_valid:
        raise GeoError("geo.invalid_polygon", explain_validity(geom))


def area_ha(geom_or_wkt: str | dict[str, Any]) -> Decimal:
    geom = shapely.from_wkt(geom_or_wkt) if isinstance(geom_or_wkt, str) else shape(geom_or_wkt)
    utm_geom = to_utm(geom)
    return (Decimal(str(utm_geom.area)) / 10000).quantize(Decimal("0.0001"))


def length_m(geom_or_wkt: str | dict[str, Any]) -> float:
    geom = shapely.from_wkt(geom_or_wkt) if isinstance(geom_or_wkt, str) else shape(geom_or_wkt)
    utm_geom = to_utm(geom)
    return round(float(utm_geom.length), 2)


def current_boundary(db: Store, case_id: uuid.UUID) -> CfrBoundary | None:
    return db.find_one(CfrBoundary, {"case_id": case_id, "is_current": True})


# ── Output ────────────────────────────────────────────────────────────────────


def _segments_out(b: CfrBoundary) -> list[SegmentOut]:
    counts: dict[int, int] = {}
    for lm in b.landmarks:
        counts[lm.segment_seq] = counts.get(lm.segment_seq, 0) + 1
    return [
        SegmentOut(
            seq=s.seq,
            geometry=s.geom,
            length_m=s.length_m,
            landmark_count=counts.get(s.seq, 0),
        )
        for s in sorted(b.segments, key=lambda s: s.seq)
    ]


def landmarks_out(b: CfrBoundary) -> list[LandmarkOut]:
    seg_by_seq = {s.seq: s for s in b.segments}
    out: list[LandmarkOut] = []
    for lm in sorted(b.landmarks, key=lambda item: (item.segment_seq, item.created_at)):
        seg = seg_by_seq.get(lm.segment_seq)
        dist = 0.0
        if seg is not None:
            seg_utm = to_utm(shape(seg.geom))
            pt_utm = to_utm(shape(lm.point))
            dist = round(float(pt_utm.distance(seg_utm)), 1)
        coords = lm.point.get("coordinates", [0.0, 0.0])
        lon, lat = float(coords[0]), float(coords[1])
        out.append(
            LandmarkOut(
                id=lm.id,
                segment_seq=lm.segment_seq,
                name=lm.name,
                kind=lm.kind,
                lon=lon,
                lat=lat,
                distance_to_segment_m=dist,
                photo_media_id=lm.photo_media_id,
                evidence_id=lm.evidence_id,
            )
        )
    return out


def use_zones_out(b: CfrBoundary) -> list[UseZoneOut]:
    poly = shape(b.geom)
    out: list[UseZoneOut] = []
    for z in sorted(b.use_zones, key=lambda u: u.created_at):
        zone_poly = shape(z.geom)
        inside = poly.covers(zone_poly) or poly.contains(zone_poly)
        out.append(
            UseZoneOut(
                id=z.id,
                use_type=z.use_type,
                name=z.name,
                geometry=z.geom,
                area_ha=z.area_ha,
                season=z.season,
                user_hamlets=list(z.user_hamlets),
                within_boundary=bool(inside),
            )
        )
    return out


def segments_without_landmark(b: CfrBoundary) -> int:
    marked = {lm.segment_seq for lm in b.landmarks}
    return sum(1 for s in b.segments if s.seq not in marked)


def boundary_out(db: Store, b: CfrBoundary) -> BoundaryOut:
    return BoundaryOut(
        id=b.id,
        case_id=b.case_id,
        version=b.version,
        status=b.status,
        source=b.source,
        geometry=b.geom,
        area_ha=b.area_ha,
        accuracy_stats=b.accuracy_stats,
        sealed_hash=b.sealed_hash,
        approved_on=b.approved_on,
        segments=_segments_out(b),
        landmarks=landmarks_out(b),
        use_zones=use_zones_out(b),
        segments_without_landmark=segments_without_landmark(b),
        open_disputes=open_disputes(db, b.case_id),
        created_at=b.created_at,
    )


# ── Disputes ──────────────────────────────────────────────────────────────────


def open_disputes(db: Store, case_id: uuid.UUID) -> int:
    """Open overlaps of this claim with a neighbour's claim that still stands."""
    involving = db.find(
        Dispute,
        {"$or": [{"case_id": case_id}, {"neighbour_case_id": case_id}]},
    )
    count = 0
    for d in involving:
        if not d.is_open:
            continue
        c1 = db.get(ClaimCase, d.case_id)
        c2 = db.get(ClaimCase, d.neighbour_case_id)
        if (
            c1 is not None
            and c1.state not in CLOSED_STATES
            and c2 is not None
            and c2.state not in CLOSED_STATES
        ):
            count += 1
    return count


def detect_overlaps(
    db: Store, case: ClaimCase, boundary: CfrBoundary, today: date | None = None
) -> None:
    """
    Compare the boundary with every current CFR boundary of another Gram Sabha. Each
    overlap opens (or refreshes) a dispute; open disputes whose overlap has gone are
    emptied. Settled disputes are left as they were.
    """
    today = today or date.today()
    db.flush()

    poly1 = shape(boundary.geom)
    other_boundaries = db.find(
        CfrBoundary,
        {"is_current": True, "case_id": {"$ne": case.id}},
    )

    overlapping: set[uuid.UUID] = set()
    for other_b in other_boundaries:
        other_case = db.get(ClaimCase, other_b.case_id)
        if other_case is None:
            continue
        if other_case.claim_type is not ClaimType.CFR:
            continue
        if other_case.state in CLOSED_STATES:
            continue
        if other_case.gram_sabha_id == case.gram_sabha_id:
            continue

        poly2 = shape(other_b.geom)
        if not poly1.intersects(poly2):
            continue

        inter = poly1.intersection(poly2)
        if inter.is_empty:
            continue

        if inter.geom_type in ("Polygon", "MultiPolygon"):
            inter_poly = inter
        elif inter.geom_type == "GeometryCollection":
            polys = [
                g for g in getattr(inter, "geoms", []) if g.geom_type in ("Polygon", "MultiPolygon")
            ]
            if not polys:
                continue
            inter_poly = shapely.unary_union(polys)
        else:
            continue

        inter_utm = to_utm(inter_poly)
        ha = (Decimal(str(inter_utm.area)) / 10000).quantize(Decimal("0.0001"))
        if ha < MIN_OVERLAP_HA:
            continue

        overlapping.add(other_case.id)
        inter_geojson = mapping(inter_poly)

        existing = db.find_one(
            Dispute,
            {
                "$or": [
                    {"case_id": case.id, "neighbour_case_id": other_case.id},
                    {"case_id": other_case.id, "neighbour_case_id": case.id},
                ]
            },
        )
        if existing is None:
            db.add(
                Dispute(
                    case_id=case.id,
                    neighbour_case_id=other_case.id,
                    neighbour_gram_sabha_id=other_case.gram_sabha_id,
                    overlap_geom=inter_geojson,
                    overlap_ha=ha,
                    detected_on=today,
                )
            )
        elif existing.sdlc_referral_on is None and existing.outcome in (
            None,
            DisputeOutcome.NOT_RESOLVED,
        ):
            existing.overlap_geom = inter_geojson
            existing.overlap_ha = ha

    for d in db.find(Dispute, {"$or": [{"case_id": case.id}, {"neighbour_case_id": case.id}]}):
        if d.is_open:
            other_id = d.neighbour_case_id if d.case_id == case.id else d.case_id
            if other_id not in overlapping:
                d.overlap_geom = None
                d.overlap_ha = Decimal(0)


def disputes_out(db: Store, case_id: uuid.UUID) -> list[DisputeOut]:
    rows = db.find(
        Dispute,
        {"$or": [{"case_id": case_id}, {"neighbour_case_id": case_id}]},
        sort=[("created_at", 1)],
    )
    this_case = db.get(ClaimCase, case_id)
    is_this_closed = this_case.state in CLOSED_STATES if this_case else False

    out: list[DisputeOut] = []
    for d in rows:
        neighbour_case_id = d.neighbour_case_id if d.case_id == case_id else d.case_id
        neighbour_case = db.get(ClaimCase, neighbour_case_id)
        is_neighbour_closed = neighbour_case.state in CLOSED_STATES if neighbour_case else False
        village_str = ""
        if neighbour_case is not None:
            gs = db.get(GramSabha, neighbour_case.gram_sabha_id)
            if gs is not None:
                village = db.get(Village, gs.village_id)
                if village is not None:
                    village_str = f"{village.name_mr} ({village.name_en})"

        out.append(
            DisputeOut(
                id=d.id,
                case_id=case_id,
                neighbour_case_id=neighbour_case_id,
                neighbour_village=village_str,
                overlap=d.overlap_geom or {},
                overlap_ha=d.overlap_ha,
                detected_on=d.detected_on,
                joint_meeting_on=d.joint_meeting_on,
                joint_meeting_findings=d.joint_meeting_findings,
                joint_meeting_media_id=d.joint_meeting_media_id,
                outcome=d.outcome,
                sdlc_referral_on=d.sdlc_referral_on,
                sdlc_referral_ref=d.sdlc_referral_ref,
                is_open=d.is_open and not (is_this_closed or is_neighbour_closed),
            )
        )
    return out


def seal(b: CfrBoundary, today: date | None = None) -> None:
    """Freeze the version the Gram Sabha approved: a hash of its geometry and landmarks."""
    marks = [
        [lm.segment_seq, lm.name, lm.point]
        for lm in sorted(b.landmarks, key=lambda m: (m.segment_seq, m.name))
    ]
    payload = json.dumps([b.geom, marks], separators=(",", ":"), sort_keys=True)
    b.sealed_hash = hashlib.sha256(payload.encode("utf-8")).hexdigest()
    b.status = BoundaryStatus.GS_APPROVED
    b.approved_on = today or date.today()
