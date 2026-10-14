"""
Small text helpers for the Ask box: plain code, no model, no database.

Questions arrive in English, Marathi or Hindi. Words are matched as whole TOKENS (never as raw
substrings), because a short Devanagari stem sits inside many unrelated words (for example "मार"
inside "बाजार" or "मार्केट").

Keyword rules:
- a plain keyword matches the START of a token, so "goat" finds "goats" and "बिबट्या" finds
  "बिबट्याला" (Marathi and Hindi add endings to words);
- an English keyword of three letters or fewer must match the whole token ("bee" is not "beetle");
- a keyword written with a leading "=" must match the whole token, whatever its length;
- a keyword with a space is a phrase and is looked for in the whole question.
"""

import re
import unicodedata
from collections.abc import Iterable
from functools import lru_cache

_SPLIT = re.compile(r"[\s.,;:!?\"'()\[\]{}\-/\\|_*+=<>@#$%^&~`।॥]+")
_DEVANAGARI_DIGITS = str.maketrans("०१२३४५६७८९", "0123456789")
_INVISIBLE = dict.fromkeys(map(ord, "​‌‍⁠﻿"))

SHORT_ASCII = 3

_LONG_DIGITS = re.compile(r"[0-9\u0966-\u096f]{4,}")


def mask_long_digits(text: str) -> str:
    """Hide long digit runs (a phone or ID number typed by mistake) in either digit script."""
    return _LONG_DIGITS.sub("\u2022\u2022\u2022", text)


@lru_cache(maxsize=4096)
def normalise(text: str) -> str:
    """Lower-case, NFKC, no invisible joiners, one space between words, ASCII digits."""
    text = unicodedata.normalize("NFKC", text).translate(_INVISIBLE).casefold()
    return " ".join(text.translate(_DEVANAGARI_DIGITS).split())


def tokens(text: str) -> list[str]:
    return [t for t in _SPLIT.split(normalise(text)) if t]


def token_matches(token: str, keyword: str) -> bool:
    if keyword.startswith("="):
        return token == normalise(keyword[1:])
    keyword = normalise(keyword)
    if keyword.isascii() and len(keyword) <= SHORT_ASCII:
        return token == keyword
    return token.startswith(keyword)


def has_any(question: str, keywords: Iterable[str]) -> bool:
    """True if any keyword appears: a single word as a token, a phrase (with a space) as text."""
    norm = normalise(question)
    toks = tokens(question)
    for kw in keywords:
        if " " in kw.strip():
            if normalise(kw) in norm:
                return True
        elif any(token_matches(t, kw) for t in toks):
            return True
    return False


def find_indexes(toks: list[str], keywords: Iterable[str]) -> list[int]:
    """Positions of the tokens that match any single-word keyword."""
    kws = list(keywords)
    return [i for i, t in enumerate(toks) if any(token_matches(t, k) for k in kws)]
