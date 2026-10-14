"""
The safety check that runs FIRST on every typed question, in plain code, before anything else
(rule L3, PDF §11-12). A harmful question gets the red policy message and NO answer.

What counts as harmful: asking how to hurt, kill, hunt, trap, poison, capture or trade wild
animals, how to cut, clear or burn forest illegally, or to fish with poison, electricity or
explosives. Asking how to PROTECT animals or crops, whether an idea harms wildlife, how to report
or stop poaching, or about an animal that harmed his stock ("a leopard killed my goat") is not
harmful.

How it decides (English): a harm verb in its base or "-ing" form ("kill", "killing", never
"killed") together with a wild animal anywhere in the question, unless the animal is the one doing
the harm to his stock ("the leopard keeps killing my goats"). Marathi and Hindi use the same idea
with their own verb stems; an animal with the "ने" ending is the doer, not the target.

THESE WORD LISTS ARE A DRAFT. They must be checked by the forest-law and animal-welfare reviewers
and by Marathi and Hindi speakers (docs/OPEN_QUESTIONS.md Q12), and widened from what real
villagers type. When in doubt the check refuses: a wrongly refused question can be asked again in
other words; a wrongly answered one cannot be taken back.
"""

import re

from .ask_text import find_indexes, has_any, normalise, tokens

# ── English ──────────────────────────────────────────────────────────────────

_WILDLIFE_EN = (
    "tiger", "tigers", "tigress", "lion", "lions", "lioness", "leopard", "panther", "cheetah",
    "bear", "bears", "deer", "chital", "sambar", "sambhar", "boar", "boars", "monkey", "langur",
    "peacock", "peafowl", "peahen", "elephant", "nilgai", "blackbuck", "bison", "gaur", "python",
    "snake", "cobra", "pangolin", "wildlife", "fox", "foxes", "jackal", "hyena", "wolf", "wolves",
    "dhole", "crocodile", "owl", "owls", "vulture", "parrot", "eagle", "hornbill", "mongoose",
    "antelope", "bird", "porcupine", "turtle", "tortoise", "lizard", "hare", "bat", "bats",
    "bagh", "sher", "tendua", "bandar", "hiran", "haathi", "saanp",
)  # fmt: skip
# animals whose sale or purchase is the problem (a bird or a deer on its own may be farm stock or
# feed: "buy birds for poultry", "deer feed")
_TRADE_WILDLIFE_EN = tuple(w for w in _WILDLIFE_EN if w not in ("bird", "deer", "wildlife"))
_ANIMAL_PARTS_EN = (
    "meat", "skin", "horn", "horns", "antler", "antlers", "tusk", "tusks", "hide", "bones",
    "scales", "claws", "teeth", "bushmeat",
)  # fmt: skip

# exact tokens: the base and "-ing" forms, never the past tense ("killed")
_HARM_VERBS_EN = tuple(
    "=" + w
    for w in (
        "kill", "killing", "hunt", "hunting", "poison", "poisoning", "shoot", "shooting", "trap",
        "trapping", "snare", "snaring", "capture", "capturing", "catch", "catching", "exterminate",
        "exterminating", "electrocute", "electrocuting", "slaughter", "slaughtering", "maar",
        "maare", "maarna", "maarne", "maaro", "shikar", "shikaar",
    )
)  # fmt: skip
_TRADE_VERBS_EN = tuple(
    "=" + w
    for w in (
        "sell",
        "selling",
        "buy",
        "buying",
        "smuggle",
        "smuggling",
        "skin",
        "skinning",
        "cage",
    )
)
# these are harmless in a question ("does dairy harm wildlife?"), so they count only after "how to"
_SOFT_HARM = re.compile(
    r"\b(?:how (?:to|do i|can i|could i|should i)|want to|need to|way to|ways to|trying to"
    r"|plan to|can i|should i)\s+(?:\w+\s+){0,2}?"
    r"(?:harm|hurt|injure|drown|beat|eliminate|get rid of|wipe out|destroy|finish)\b"
)
# the animal is the one doing harm to his stock: "the leopard keeps killing my goats"
_VICTIM_WORDS = ("my", "our", "his", "her", "their")
_HUNT_VERBS_EN = ("=hunt", "=hunting", "=poach", "=poaching", "=trap", "=trapping", "=snare")
_ANIMAL_GENERIC_EN = ("animal", "animals", "=birds", "creature", "creatures")
_STRONG_EN = (
    "snare", "bushmeat", "ivory", "dynamite", "wildlife trade", "wildlife trafficking",
    "blast fishing", "electric fishing", "electrofishing", "electric shock", "electric current",
    "electricity to catch",
)  # fmt: skip
# "poach" and the like are refused as plain words, unless the question is about stopping them
_BLANKET_EN = ("poach",)
_PROTECTIVE_EN = (
    "prevent", "stop", "report", "against", "penalty", "punish", "complain", "protect", "anti",
    "fight",
)  # fmt: skip

_FOREST_EN = (
    "forest", "jungle", "woods", "national park", "sanctuary", "protected area", "reserve forest",
)  # fmt: skip
_WOOD_EN = ("timber", "teak", "sandalwood", "tree", "trees", "wood", "log", "logs")
_CUT_EN = (
    "=cut", "=cuts", "=cutting", "felling", "felled", "=fell", "chop", "steal", "smuggl",
    "=log", "=clear", "=clearing", "encroach", "=grab", "=occupy", "burn",
)  # fmt: skip
_CLEAR_FOREST = ("=clear", "=clearing", "encroach", "=grab", "=occupy")
_ILLEGAL_WORDS = ("illegal", "illegally", "without permit", "without permission", "secretly")
_ILLEGAL_WOOD = ("timber", "teak", "sandalwood", "logging", "felling", "tree", "trees", "cutting")
_BURN_FOREST = re.compile(
    r"set (?:\w+ ){0,3}on fire|set fire|start(?:ing)? (?:a )?fire(?! ?line)|arson"
    r"|burn(?:ing)? (?:down )?(?:the )?(?:\w+ )?(?:forest|jungle|woods)"
    r"|clear\w* (?:the )?(?:\w+ )?(?:forest|jungle) .*burn"
)
# fishing with poison, bleach, explosives or electricity
_FISH_HARM = re.compile(
    r"\b(?:poison|bleach|pesticide|dynamite|explosive\w*|bomb|blast\w*)\b(?:\W+\w+){0,5}\W+fish"
    r"|\bfish\w*(?:\W+\w+){0,5}\W+(?:poison|bleach|pesticide|dynamite|explosive\w*)"
    r"|\bpoison\w* (?:the |a |my )?(?:pond|river|lake|stream|water|well)\b"
)
# "wild animal", "wild pig" ... count as wildlife; "wild honey" does not
_WILD_ANIMAL = re.compile(r"\bwild (?:animal|bird|pig|cat|dog|creature|boar)\w*")

# ── Marathi and Hindi (draft; to be vetted by native speakers) ────────────────

_WILDLIFE_MR_HI = (
    "वाघ", "बाघ", "बिबट्या", "बिबट", "तेंदुआ", "तेंदुए", "हरीण", "हरिण", "रानडुकर", "रानडुक्कर", "डुक्कर",
    "सुअर", "सूअर", "माकड", "बंदर", "वानर", "=मोर", "मोरा", "मोरां", "हत्ती", "हाथी", "सांबर",
    "सांभर", "नीलगाय", "रानगवा", "=गवा", "अजगर", "=साप", "सापा", "सापां", "सर्प", "पक्षी",
    "पक्षि", "चिड़िया", "वन्यजीव", "वन्यप्राणी", "वन्य", "पैंगोलिन", "खवले", "कोल्ह्या",
    "कोल्हा", "लांडगा", "भेड़िया", "गीदड़", "घुबड", "उल्लू", "गिधाड", "गिद्ध", "मुंगूस",
    "साळिंदर", "सेहुल", "काळवीट", "चिंकारा", "सिंह", "चित्ता", "शेर", "कासव", "कछुआ",
)  # fmt: skip
_JUNGLI_ANIMAL = re.compile(r"जंगली (?:प्राणी|जानवर|पशु|पक्षी|सुअर|सूअर|डुक्कर)")
_HARM_VERBS_MR_HI = (
    "मारणे", "मारण्या", "मारायचे", "मारायचं", "मारायला", "मारायचा", "मारायची", "मारून", "मारुन",
    "मारू", "मारना", "मारने", "मारें", "मारकर", "मारे", "ठार", "पकडणे", "पकडायचे", "पकडायचा",
    "पकडायची", "पकडायला", "पकडून", "पकड़ना", "पकड़ने", "पकड़कर", "=विष", "=जहर", "ज़हर", "=फास",
    "=फासा", "विकणे", "विकायचे", "बेचना", "बेचने", "बेचकर", "संपवा", "संपवायचे", "संपवणे",
    "खत्म", "नष्ट", "तस्कर", "=इजा", "गोळी", "गोली", "बंदूक", "फंदा",
)  # fmt: skip
_STRONG_MR_HI = (
    "तस्कर", "लाकूडतोड", "वृक्षतोड", "अवैध कटाई", "अवैध वृक्षतोड", "पेड़ काट", "झाडे तोड",
    "झाड तोड", "झाडे कापा", "डायनामाइट", "जिलेटिन", "हाथी दांत",
)  # fmt: skip
_BLANKET_MR_HI = ("शिकार",)
_PROTECTIVE_MR_HI = (
    "रोख", "रोका", "रोकना", "रोकने", "थांबव", "तक्रार", "शिक्षा", "दंड", "विरोध", "बंद", "सजा",
)  # fmt: skip
# the animal did something to him ("बिबट्याने माझी शेळी ठार केली"): not a request to harm it
_DOER_ENDINGS = ("ने", "नं", "नी")
_PAST_MR_HI = (
    "=केली", "=केले", "=केल्या", "=मारली", "=मारले", "=मारल्या", "=मारला", "=झाली", "=झाले",
    "=मेली", "=मेले",
)  # fmt: skip
_FOREST_MR_HI = ("जंगल",)
_FOREST_HARM_MR_HI = (
    "तोड", "कापा", "कापणे", "कापायचे", "कापून", "काटना", "काटने", "काटें", "काटकर", "कटाई",
    "चोर", "साफ", "जाळ", "जला", "आग लाव", "आग लगा",
)  # fmt: skip
_FIRE_MR_HI = ("आग",)
_LIGHT_MR_HI = ("लाव", "लावा", "लावू", "लगा")  # "set / light" (a fire)
_FISH_MR_HI = ("मासे", "मासेमारी", "मत्स्य", "मछली", "मछलि")
_FISH_HARM_MR_HI = (
    "=विष",
    "=जहर",
    "ज़हर",
    "डायनामाइट",
    "जिलेटिन",
    "=वीज",
    "=बिजली",
    "=करंट",
    "स्फोट",
    "विस्फोट",
)

_LEET = str.maketrans("0134578@$", "oieastbas")
_SEPARATED_LETTERS = re.compile(r"\b(?:[a-z][.\-_*] ?){2,}[a-z]\b")


def _variants(question: str) -> list[str]:
    """The question as typed, plus spellings that hide a word: "k1ll", "k.i.l.l"."""
    norm = normalise(question)
    out = [norm]
    joined = _SEPARATED_LETTERS.sub(lambda m: re.sub(r"[^a-z]", "", m.group()), norm)
    if joined != norm:
        out.append(joined)
    leet = " ".join(t.translate(_LEET) if re.search(r"[a-z]", t) else t for t in norm.split())
    if leet != norm:
        out.append(leet)
    return out


def _near(toks: list[str], verbs: tuple[str, ...], objects: tuple[str, ...], span: int = 8) -> bool:
    """A verb with an object within `span` words on either side ("kill the leopard", "a leopard
    near my farm, how do I kill it")."""
    verb_at = find_indexes(toks, verbs)
    object_at = find_indexes(toks, objects)
    return any(abs(o - v) <= span for v in verb_at for o in object_at)


def _is_victim_phrase(toks: list[str], verbs: tuple[str, ...]) -> bool:
    """Every harm verb is followed by "my / our ..." (the animal is hurting his stock)."""
    positions = find_indexes(toks, verbs)
    return bool(positions) and all(
        any(t in _VICTIM_WORDS for t in toks[p + 1 : p + 3]) for p in positions
    )


def _english(norm: str, toks: list[str]) -> bool:
    if has_any(norm, _STRONG_EN):
        return True
    if has_any(norm, _BLANKET_EN) and not has_any(norm, _PROTECTIVE_EN):
        return True
    wild = find_indexes(toks, _WILDLIFE_EN)
    if wild and _SOFT_HARM.search(norm):
        return True
    if (
        wild
        and _near(toks, _HARM_VERBS_EN, _WILDLIFE_EN)
        and not _is_victim_phrase(toks, _HARM_VERBS_EN)
    ):
        return True
    # selling or buying wild animals, or their parts
    if _near(toks, _TRADE_VERBS_EN, _TRADE_WILDLIFE_EN):
        return True
    if _near(toks, _TRADE_VERBS_EN, _ANIMAL_PARTS_EN) and wild:
        return True
    # "how to hunt animals", "trap birds": the generic words count only with a hunting verb
    if _near(toks, _HUNT_VERBS_EN, _ANIMAL_GENERIC_EN):
        return True
    if _FISH_HARM.search(norm):
        return True
    in_forest = has_any(norm, _FOREST_EN)
    if in_forest and _near(toks, _CUT_EN, _WOOD_EN, span=5):
        return True
    if in_forest and _BURN_FOREST.search(norm):
        return True
    if in_forest and has_any(norm, _CLEAR_FOREST):
        return True
    if has_any(norm, ("steal", "stealing", "smuggl")) and has_any(
        norm, ("timber", "teak", "sandalwood", "wood", "trees")
    ):
        return True
    if has_any(norm, _ILLEGAL_WORDS) and has_any(norm, _ILLEGAL_WOOD):
        return True
    # sandalwood is state property; felling or smuggling it is never a livelihood idea
    return has_any(norm, ("sandalwood",)) and has_any(norm, _CUT_EN)


def _marathi_hindi(norm: str, toks: list[str]) -> bool:
    if has_any(norm, _STRONG_MR_HI):
        return True
    if has_any(norm, _BLANKET_MR_HI) and not has_any(norm, _PROTECTIVE_MR_HI):
        return True
    wild = find_indexes(toks, _WILDLIFE_MR_HI)
    verbs = find_indexes(toks, _HARM_VERBS_MR_HI)
    if wild and verbs:
        doer = any(
            toks[i].endswith(_DOER_ENDINGS) or (i + 1 < len(toks) and toks[i + 1] == "ने")
            for i in wild
        )
        past = bool(find_indexes(toks, _PAST_MR_HI))
        if not (doer and past):
            return True
    if has_any(norm, _FISH_MR_HI) and has_any(norm, _FISH_HARM_MR_HI):
        return True
    if not has_any(norm, _FOREST_MR_HI):
        return False
    return has_any(norm, _FOREST_HARM_MR_HI) or (
        has_any(norm, _FIRE_MR_HI) and has_any(norm, _LIGHT_MR_HI)
    )


def is_harmful(question: str) -> bool:
    """True if the question asks for something that would harm wildlife or forest."""
    for text in _variants(question):
        text = _WILD_ANIMAL.sub("wildlife", text)
        text = _JUNGLI_ANIMAL.sub("वन्यजीव", text)
        toks = tokens(text)
        if _english(text, toks) or _marathi_hindi(text, toks):
            return True
    return False
