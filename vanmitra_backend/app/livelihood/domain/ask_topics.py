"""
Which part of his report a question is about. Plain keyword matching in English, Marathi and Hindi.

Three outcomes besides "a part of the report":
- the question asks for something the report does not hold (prices, loans, crop disease...) →
  "not in your report";
- it names an idea we have not checked for his land ("can I start rabbit farming?") → a general,
  labelled "not checked for your land" note with no numbers;
- it is about nothing in the report at all → grey "I can only answer questions about your report".

THE KEYWORD LISTS ARE A DRAFT for the Marathi and Hindi reviewers (docs/OPEN_QUESTIONS.md Q12).
"""

import re
from dataclasses import dataclass

from ..schemas import Idea
from .ask_text import has_any, normalise

# topic ids
HEADING = "heading"
TOP_IDEAS = "top_ideas"
WATER = "water"
RESOURCES = "resources"
WILDLIFE = "wildlife"
COST = "cost"
FOREST = "forest"
OWN = "own"
WEATHER = "weather"
FLOOD = "flood"
REMOVED = "removed"
SCHEMES = "schemes"
OUTSIDE = "outside_report"
IDEA = "idea"
IDEA_UNCHECKED = "idea_unchecked"
OFF_TOPIC = "off_topic"

_KEYWORDS: dict[str, tuple[str, ...]] = {
    REMOVED: (
        "removed",
        "held back",
        "not shown",
        "why not",
        "why was",
        "not suggested",
        "left out",
        "का नाही",
        "काढले",
        "काढून",
        "वगळ",
        "क्यों नहीं",
        "हटाए",
        "हटा दि",
        "क्यों हटा",
    ),
    SCHEMES: (
        "scheme",
        "subsidy",
        "subsidies",
        "yojana",
        "grant",
        "योजना",
        "अनुदान",
        "सबसिडी",
        "सब्सिडी",
        "सरकारी मदत",
        "सरकारी मदद",
    ),
    OUTSIDE: (
        "price",
        "prices",
        "market",
        "mandi",
        "rate",
        "rates",
        "loan",
        "bank",
        "insurance",
        "profit",
        "income",
        "earn",
        "salary",
        "disease",
        "fertilizer",
        "fertiliser",
        "pesticide",
        "seed",
        "seeds",
        "vaccine",
        "tax",
        "court",
        "भाव",
        "बाजार",
        "बाजारात",
        "कर्ज",
        "विमा",
        "किंमत",
        "=दर",
        "नफा",
        "कमाई",
        "उत्पन्न",
        "रोग",
        "=खत",
        "खताचे",
        "खतां",
        "औषध",
        "बियाणे",
        "=लस",
        "मंडी",
        "ऋण",
        "बीमा",
        "कीमत",
        "मुनाफा",
        "आमदनी",
        "बीमारी",
        "खाद",
        "दवा",
        "बीज",
        "टीका",
        "compensation",
        "attack",
        "attacked",
        "killed my",
        "protect my",
        "protect the",
        "protect from",
        "keep away",
        "keep out",
        "scare",
        "drive away",
        "crop damage",
        "sick",
        "unwell",
        "dying",
        "cure",
        "treatment",
        "medicine",
        "मुआवजा",
        "भरपाई",
        "हल्ला",
        "वाचवायचे",
        "वाचवा",
        "how much money",
        "kitna paisa",
        "किती पैसे मिळ",
        "कितना कमा",
    ),
    WILDLIFE: (
        "wildlife",
        "wild animal",
        "forest department",
        "forest dept",
        "protected",
        "sanctuary",
        "reserve",
        "forest officer",
        "वन्यजीव",
        "वन्य",
        "वन विभाग",
        "वनविभाग",
        "अभयारण्य",
        "संरक्षित",
        "राखीव",
        "वन अधिकारी",
    ),
    FLOOD: ("flood", "floods", "=पूर", "=बाढ़", "=बाढ", "पुराचा", "पुराची", "बाढ़"),
    WEATHER: (
        "weather",
        "rain",
        "rainfall",
        "season",
        "summer",
        "monsoon",
        "temperature",
        "hot",
        "month",
        "months",
        "हवामान",
        "पाऊस",
        "पावसा",
        "ऋतू",
        "उन्हाळ",
        "तापमान",
        "मौसम",
        "बारिश",
        "गर्मी",
        "महिना",
        "महिने",
        "महीना",
        "महीने",
    ),
    COST: (
        "cost",
        "costs",
        "invest",
        "investment",
        "budget",
        "expensive",
        "cheap",
        "afford",
        "खर्च",
        "गुंतवणूक",
        "लागत",
        "पैसे",
        "पैसा",
        "निवेश",
        "खर्चा",
        "बजेट",
        "स्वस्त",
        "सस्ता",
    ),
    WATER: (
        "water",
        "well",
        "wells",
        "pond",
        "tank",
        "river",
        "borewell",
        "irrigation",
        "canal",
        "पाणी",
        "विहीर",
        "विहिरी",
        "तलाव",
        "नदी",
        "बोअरवेल",
        "सिंचन",
        "ओलित",
        "पानी",
        "कुआं",
        "कुआँ",
        "तालाब",
        "नदी",
        "सिंचाई",
        "नहर",
    ),
    FOREST: (
        "forest",
        "gram sabha",
        "community forest",
        "cfr",
        "fra",
        "jungle",
        "जंगल",
        "ग्रामसभा",
        "=वन",
        "वनहक्क",
        "वन हक्क",
        "वनोपज",
        "वन उपज",
        "ग्राम सभा",
        "वनाधिकार",
    ),
    OWN: (
        "my land",
        "my cows",
        "my goats",
        "my animals",
        "my details",
        "i have",
        "i told",
        "own",
        "owned",
        "माझी जमीन",
        "माझ्याकडे",
        "माझे प्राणी",
        "मी सांगितले",
        "मेरी जमीन",
        "मेरे पास",
        "मेरे जानवर",
        "मैंने बताया",
        "माझ्या जमिनीत",
    ),
    TOP_IDEAS: (
        "idea",
        "ideas",
        "suggest",
        "suggestion",
        "recommend",
        "best",
        "top",
        "option",
        "options",
        "what should i do",
        "what can i do",
        "which work",
        "कल्पना",
        "सुचव",
        "सुचवा",
        "शिफारस",
        "सर्वोत्तम",
        "पर्याय",
        "काय करू",
        "काय करावे",
        "विचार",
        "सुझाव",
        "सिफारिश",
        "सबसे अच्छा",
        "विकल्प",
        "क्या करूं",
        "क्या करें",
    ),
    RESOURCES: (
        "resource",
        "resources",
        "nearby",
        "near me",
        "around me",
        "within",
        "5 km",
        "available",
        "संसाधन",
        "जवळ",
        "जवळपास",
        "आसपास",
        "उपलब्ध",
        "साधने",
        "साधन",
        "संसाधनों",
        "नजदीक",
        "पास में",
    ),
    HEADING: (
        "summary",
        "overall",
        "heading",
        "headline",
        "main",
        "report",
        "सारांश",
        "थोडक्यात",
        "एकूण",
        "अहवाल",
        "रिपोर्ट",
        "सार",
        "कुल मिलाकर",
        "संक्षेप",
    ),
}

# the order in which a question that matches several topics is answered: the more specific first
_PRIORITY = (
    OUTSIDE, SCHEMES, REMOVED, WILDLIFE, FLOOD, WEATHER, COST, WATER, FOREST, OWN,
    TOP_IDEAS, RESOURCES, HEADING,
)  # fmt: skip

# what each idea is called in everyday speech (draft; the idea library holds the formal names)
IDEA_WORDS: dict[str, tuple[str, ...]] = {
    "dairy_small": (
        "dairy",
        "milk",
        "cow",
        "cows",
        "buffalo",
        "दूध",
        "डेअरी",
        "गाय",
        "गायी",
        "गाई",
        "म्हैस",
        "म्हशी",
        "डेयरी",
        "भैंस",
    ),
    "goat_rearing": (
        "goat",
        "goats",
        "sheep",
        "शेळी",
        "शेळ्या",
        "शेळीपालन",
        "मेंढी",
        "मेंढ्या",
        "बकरी",
        "भेड़",
    ),
    "backyard_poultry": (
        "poultry",
        "hen",
        "hens",
        "chicken",
        "chickens",
        "eggs",
        "कोंबडी",
        "कोंबड्या",
        "कुक्कुट",
        "अंडी",
        "मुर्गी",
        "मुर्गीपालन",
        "अंडे",
    ),
    "vegetables_drip": (
        "vegetable",
        "vegetables",
        "drip",
        "भाजी",
        "भाजीपाला",
        "ठिबक",
        "सब्जी",
        "ड्रिप",
        "टपक",
    ),
    "mushroom_shed": ("mushroom", "मशरूम", "अळिंबी", "खुम्बी"),
    "plant_nursery": ("nursery", "saplings", "रोपवाटिका", "नर्सरी", "पौधशाला"),
    "millets_pulses": (
        "millet",
        "millets",
        "pulses",
        "dal",
        "jowar",
        "bajra",
        "ragi",
        "ज्वारी",
        "बाजरी",
        "नाचणी",
        "=डाळ",
        "डाळी",
        "कडधान्य",
        "ज्वार",
        "बाजरा",
        "रागी",
        "दाल",
    ),
    "agroforestry_fruit": (
        "fruit",
        "fruits",
        "mango",
        "orchard",
        "agroforestry",
        "फळ",
        "फळझाड",
        "फळझाडे",
        "आंबा",
        "फल",
        "=बाग",
        "बागेत",
    ),
    "beekeeping_box": (
        "bee",
        "bees",
        "beekeeping",
        "honey",
        "मधमाशी",
        "मधमाश्या",
        "=मध",
        "मधाचे",
        "मधुमक्खी",
        "शहद",
    ),
    "fodder_bank": ("fodder", "grass", "चारा", "चारे"),
    "fish_pond_group": (
        "fish",
        "fishing",
        "fisheries",
        "मासे",
        "मासेमारी",
        "मत्स्य",
        "मछली",
        "मछलीपालन",
    ),
    "mfp_collection_group": (
        "minor forest produce",
        "mfp",
        "bamboo",
        "lac",
        "forest produce",
        "गौण वनउपज",
        "बांबू",
        "बांस",
        "वनोपज",
        "वनउपज",
    ),
    "forest_watch_work": (
        "patrol",
        "fire line",
        "fire-line",
        "fireline",
        "nature guide",
        "watershed",
        "forest work",
        "गस्त",
        "गश्त",
        "वन रक्षक",
    ),
    "lease_land_commercial": (
        "lease",
        "leasing",
        "rent my land",
        "sell my land",
        "sell land",
        "भाडेपट्टा",
        "जमीन विक",
        "जमीन भाड्याने",
        "पट्टे",
        "जमीन बेच",
    ),
    "timber_sale": (
        "timber",
        "teak",
        "sandalwood",
        "लाकूड",
        "सागवान",
        "चंदन",
        "इमारती लाकूड",
        "लकड़ी",
        "सागौन",
    ),
    "wildlife_trapping": ("hunting", "trapping"),
}

# "can I start ...", "what about ...": a question about trying something, whatever it is
_TRY_PHRASES = (
    "can i",
    "should i",
    "could i",
    "what about",
    "how about",
    "is it possible",
    "is it good",
    "will it work",
    "start",
    "begin",
    "farming",
    "rearing",
    "करू शकतो",
    "करू शकते",
    "करता येईल",
    "सुरू करू",
    "सुरु करू",
    "करावे",
    "करायचे",
    "करायचा",
    "सुरू करायचा",
    "कर सकता",
    "कर सकती",
    "शुरू कर",
    "करना चाहता",
    "करना चाहती",
    "कैसा रहेगा",
    "कसे राहील",
    "चालेल का",
    "कर पाऊंगा",
)


# "protect my goats from the leopard", "stop monkeys eating my crop": help the report does not hold
_PROTECT_FROM = re.compile(
    r"protect (?:\w+ ){0,3}from|keep (?:\w+ ){1,3}away"
    r"|stop (?:\w+ ){1,3}(?:from )?(?:eating|attacking|killing|damaging|destroying)"
)


@dataclass(frozen=True)
class Intent:
    topic: str
    idea_code: str | None = None


def idea_mentioned(question: str, library: list[Idea]) -> str | None:
    """The code of the idea the question names, if any: by everyday word, then by library name."""
    for code, words in IDEA_WORDS.items():
        if has_any(question, words):
            return code
    for idea in library:
        if has_any(question, (idea.name_en.lower(), idea.name_mr)):
            return idea.code
    return None


def detect(question: str, library: list[Idea]) -> Intent:
    """What the question is about. Specific first: an outside-the-report ask beats everything."""
    hit = {topic: has_any(question, words) for topic, words in _KEYWORDS.items()}
    if hit[OUTSIDE] or _PROTECT_FROM.search(normalise(question)):
        return Intent(OUTSIDE)
    if hit[SCHEMES]:
        return Intent(SCHEMES)

    code = idea_mentioned(question, library)
    if code is not None:
        return Intent(IDEA, code)  # "why not fishing?" is answered from that idea's own record

    for topic in _PRIORITY:
        if hit.get(topic):
            return Intent(topic)

    if has_any(question, _TRY_PHRASES):
        return Intent(IDEA_UNCHECKED)
    return Intent(OFF_TOPIC)
