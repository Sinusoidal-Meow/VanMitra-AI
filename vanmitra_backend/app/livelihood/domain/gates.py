"""
The four legal gates (PDF §9). An idea that fails any gate is dropped, and we record WHICH gate,
so the "Why not others?" list can say why.

Legal bases are as written in the PDF and still need an FRA lawyer's confirmation:
  Sec 4(4) land cannot be sold or leased · Sec 3(1)(l) no hunting or trapping · Sec 5 no timber
  or harm to wildlife · CFR rules for what is not allowed in community forest.
"""

from ..schemas import Gate, Idea


def failed_gate(idea: Idea, *, plot_in_cfr: bool) -> Gate | None:
    """The first gate the idea fails, or None. Checked in a fixed order so results are stable."""
    flags = idea.gate_flags
    if flags.needs_sale_or_lease:
        return Gate.LAND_SALE_OR_LEASE
    if flags.hunting_trapping:
        return Gate.HUNTING_OR_TRAPPING
    if flags.timber_or_harm:
        return Gate.TIMBER_OR_HARM
    if flags.not_in_cfr and plot_in_cfr:
        return Gate.NOT_ALLOWED_IN_CFR
    return None
