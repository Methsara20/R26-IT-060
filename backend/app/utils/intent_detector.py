import re
from typing import Optional


# ==========================================================
# INTENT CONSTANTS
# ==========================================================

GREETING_INTENT = "greeting"
HELP_INTENT = "help"

MOVEMENT_STATUS_INTENT = "movement_status"
MOVEMENT_DETAILS_INTENT = "movement_details"
TRANSFER_QUANTITY_INTENT = "transfer_quantity"

RECOMMENDATION_CONFIDENCE_INTENT = "recommendation_confidence"
RECOMMENDATION_RISK_INTENT = "recommendation_risk"
ALTERNATIVE_STORES_INTENT = "alternative_stores"
RECOMMENDATION_EXPLANATION_INTENT = "recommendation_explanation"
STORE_COMPARISON_INTENT = "store_comparison"

CURRENT_STOCK_INTENT = "current_stock"
INVENTORY_HEALTH_INTENT = "inventory_health"

PENDING_APPROVALS_INTENT = "pending_approvals"
DASHBOARD_SUMMARY_INTENT = "dashboard_summary"

TRANSACTION_DETAILS_INTENT = "transaction_details"
EXECUTION_SUMMARY_INTENT = "execution_summary"

UNKNOWN_INTENT = "unknown"


# ==========================================================
# MESSAGE HELPERS
# ==========================================================

def normalize_message(message: str) -> str:
    """
    Normalize manager message for rule-based intent detection.

    Example:

    "Why wasn't CP008 selected?"
            ↓
    "why wasnt cp008 selected"
    """

    if not message:
        return ""

    message = message.lower()

    # Remove punctuation.
    message = re.sub(
        r"[^\w\s]",
        " ",
        message
    )

    # Remove extra spaces.
    return " ".join(
        message.split()
    )


def contains_any(
    message: str,
    phrases: list[str]
) -> bool:
    """
    Match complete words or phrases.

    Examples:

    "hi" matches:
        "hi good morning"

    But does NOT match:
        "this recommendation"
    """

    for phrase in phrases:

        normalized_phrase = normalize_message(
            phrase
        )

        pattern = (
            r"(?<!\w)"
            + re.escape(normalized_phrase)
            + r"(?!\w)"
        )

        if re.search(
            pattern,
            message,
            flags=re.IGNORECASE
        ):
            return True

    return False


def contains_all(
    message: str,
    words: list[str]
) -> bool:
    """
    Check whether all supplied words exist
    as complete words in the message.
    """

    for word in words:

        pattern = (
            r"(?<!\w)"
            + re.escape(word.lower())
            + r"(?!\w)"
        )

        if not re.search(
            pattern,
            message,
            flags=re.IGNORECASE
        ):
            return False

    return True


# ==========================================================
# ENTITY EXTRACTION
# ==========================================================

def extract_store_id(
    message: str
) -> Optional[str]:
    """
    Extract showroom IDs.

    Examples:

    CP001
    CP004
    CP008
    """

    if not message:
        return None

    match = re.search(
        r"\bCP\d{3}\b",
        message.upper()
    )

    if match:
        return match.group(0)

    return None


def extract_product_id(
    message: str
) -> Optional[str]:
    """
    Extract product IDs.

    Current project examples:

    P0001
    P0006

    Also supports:
    P001
    P1234
    """

    if not message:
        return None

    match = re.search(
        r"\bP\d{3,4}\b",
        message.upper()
    )

    if match:
        return match.group(0)

    return None


def extract_movement_id(
    message: str
) -> Optional[str]:
    """
    Extract stock movement IDs.

    Actual project example:

    MOV-20260707-P0001_CP001-V3

    Important:
    This must run against the ORIGINAL message,
    not the normalized message, because normalization
    removes hyphens.
    """

    if not message:
        return None

    upper_message = message.upper()

    patterns = [

        # Current real project format:
        # MOV-20260707-P0001_CP001-V3
        r"\bMOV-\d{8}-[A-Z0-9_]+-V\d+\b",

        # Slightly more flexible project format.
        r"\bMOV-\d{8}-[A-Z0-9_-]+-V\d+\b",

        # Fallback formats.
        r"\bMOV-\d+\b",
        r"\bMOV_\d+\b",
        r"\bSM-\d+\b",
        r"\bSM_\d+\b"
    ]

    for pattern in patterns:

        match = re.search(
            pattern,
            upper_message
        )

        if match:
            return match.group(0)

    return None


# ==========================================================
# INTENT DETECTION
# ==========================================================

def detect_intent(
    message: str
) -> dict:
    """
    Detect manager intent using lightweight
    deterministic routing rules.

    This detector:

    - does NOT access Firestore
    - does NOT call Gemini
    - does NOT call Groq
    - does NOT recalculate recommendations

    Unknown/open-ended questions are marked
    requires_ai=True so Groq can handle them later.
    """

    original_message = (
        message or ""
    )

    normalized = normalize_message(
        original_message
    )

    # Store/product extraction can work from either
    # message, but original preserves all formatting.
    store_ids = extract_store_ids(
        original_message
    )

    store_id = (
        store_ids[0]
        if store_ids
        else None
    )

    product_id = extract_product_id(
        original_message
    )

    # IMPORTANT:
    # Use original message because normalized text
    # removes the '-' characters in movement IDs.
    movement_id = extract_movement_id(
        original_message
    )

    intent = UNKNOWN_INTENT
    category = "unknown"

    requires_ai = False
    requires_movement = False


    # ======================================================
    # GREETING
    # ======================================================

    if contains_any(
        normalized,
        [
            "hi",
            "hello",
            "hey",
            "good morning",
            "good afternoon",
            "good evening",
            "greetings"
        ]
    ):
        intent = GREETING_INTENT
        category = "general"


    # ======================================================
    # HELP
    # ======================================================

    elif contains_any(
        normalized,
        [
            "help",
            "what can you do",
            "what can i ask",
            "how can you help",
            "supported questions",
            "available commands"
        ]
    ):
        intent = HELP_INTENT
        category = "general"


    # ======================================================
    # STORE COMPARISON
    # ======================================================
    #
    # Examples:
    #
    # Why wasn't CP008 selected?
    # Why was CP006 not selected?
    # Why CP004 instead of CP008?
    # Compare CP004
    # Why choose CP007 over CP006?
    # What about CP003?
    #
    # This intentionally runs BEFORE general
    # recommendation explanation detection.
    # ======================================================

    elif (
        store_id
        and (
            "compare" in normalized
            or "instead" in normalized
            or "selected" in normalized
            or "choose" in normalized
            or "chosen" in normalized
            or "what about" in normalized
            or "why" in normalized
        )
        and (
            "why" in normalized
            or "compare" in normalized
            or "instead" in normalized
            or "what about" in normalized
        )
    ):
        intent = STORE_COMPARISON_INTENT
        category = "recommendation"
        requires_movement = True


    # ======================================================
    # RECOMMENDATION EXPLANATION
    # ======================================================
    #
    # Examples:
    #
    # Explain this recommendation
    # Explain the recommendation
    # Why was this recommended?
    # What is the recommendation reason?
    # Why this recommendation?
    # Explain this decision
    # ======================================================

    elif (
        (
            "recommendation" in normalized
            or "recommended" in normalized
            or "decision" in normalized
        )
        and (
            "explain" in normalized
            or "why" in normalized
            or "reason" in normalized
        )
    ):
        intent = RECOMMENDATION_EXPLANATION_INTENT
        category = "recommendation"
        requires_movement = True


    # ======================================================
    # MOVEMENT STATUS
    # ======================================================

    elif contains_any(
        normalized,
        [
            "movement status",
            "current status",
            "what is the status",
            "status of movement",
            "was it approved",
            "was it rejected",
            "was it cancelled",
            "was it executed",
            "has it been executed",
            "is it approved",
            "is it rejected",
            "is it cancelled",
            "is it executed"
        ]
    ):
        intent = MOVEMENT_STATUS_INTENT
        category = "movement"
        requires_movement = True


    # ======================================================
    # MOVEMENT DETAILS
    # ======================================================

    elif contains_any(
        normalized,
        [
            "movement details",
            "transfer details",
            "what is recommended",
            "summarize recommendation",
            "show recommendation",
            "show transfer",
            "movement information",
            "transfer information"
        ]
    ):
        intent = MOVEMENT_DETAILS_INTENT
        category = "movement"
        requires_movement = True


    # ======================================================
    # TRANSFER QUANTITY
    # ======================================================

    elif contains_any(
        normalized,
        [
            "how many units",
            "what quantity",
            "transfer quantity",
            "recommended quantity",
            "quantity to transfer",
            "how much stock should move",
            "how many should transfer",
            "how many to transfer"
        ]
    ):
        intent = TRANSFER_QUANTITY_INTENT
        category = "movement"
        requires_movement = True


    # ======================================================
    # RECOMMENDATION CONFIDENCE
    # ======================================================

    elif contains_any(
        normalized,
        [
            "confidence",
            "how confident",
            "confidence score",
            "recommendation confidence",
            "decision confidence",
            "why high confidence",
            "why very high"
        ]
    ):
        intent = RECOMMENDATION_CONFIDENCE_INTENT
        category = "recommendation"
        requires_movement = True


    # ======================================================
    # RECOMMENDATION RISK / SAFETY
    # ======================================================

    elif contains_any(
        normalized,
        [
            "risk after transfer",
            "inventory risk",
            "recommendation risk",
            "transfer risk",
            "what is the risk",
            "is this safe",
            "is it safe",
            "remaining buffer",
            "simulation status",
            "safe transfer"
        ]
    ):
        intent = RECOMMENDATION_RISK_INTENT
        category = "recommendation"
        requires_movement = True


    # ======================================================
    # ALTERNATIVE STORES
    # ======================================================

    elif contains_any(
        normalized,
        [
            "alternative stores",
            "alternative store",
            "alternative sources",
            "alternative source",
            "other stores",
            "other showrooms",
            "which alternatives",
            "other source stores",
            "other source showrooms",
            "show alternatives"
        ]
    ):
        intent = ALTERNATIVE_STORES_INTENT
        category = "recommendation"
        requires_movement = True


    # ======================================================
    # CURRENT STOCK
    # ======================================================

    elif contains_any(
        normalized,
        [
            "current stock",
            "stock level",
            "stock quantity",
            "available stock",
            "how much stock",
            "how many in stock",
            "inventory quantity"
        ]
    ):
        intent = CURRENT_STOCK_INTENT
        category = "inventory"


    # ======================================================
    # INVENTORY HEALTH
    # ======================================================

    elif contains_any(
        normalized,
        [
            "inventory health",
            "stock health",
            "reorder status",
            "needs reorder",
            "need reorder",
            "overstock",
            "over stocked",
            "low stock",
            "days on hand"
        ]
    ):
        intent = INVENTORY_HEALTH_INTENT
        category = "inventory"


    # ======================================================
    # PENDING APPROVALS
    # ======================================================

    elif contains_any(
        normalized,
        [
            "pending approvals",
            "pending recommendations",
            "waiting for approval",
            "recommendations waiting",
            "how many pending",
            "approval count",
            "waiting for manager decision"
        ]
    ):
        intent = PENDING_APPROVALS_INTENT
        category = "dashboard"


    # ======================================================
    # DASHBOARD SUMMARY
    # ======================================================

    elif contains_any(
        normalized,
        [
            "dashboard summary",
            "dashboard counts",
            "inventory summary",
            "overall summary",
            "todays summary",
            "today summary",
            "overview",
            "show dashboard"
        ]
    ):
        intent = DASHBOARD_SUMMARY_INTENT
        category = "dashboard"


    # ======================================================
    # TRANSACTION DETAILS
    # ======================================================

    elif contains_any(
        normalized,
        [
            "transaction",
            "transaction id",
            "transaction details",
            "transaction record",
            "inventory transaction"
        ]
    ):
        intent = TRANSACTION_DETAILS_INTENT
        category = "movement"
        requires_movement = True


    # ======================================================
    # EXECUTION SUMMARY
    # ======================================================

    elif contains_any(
        normalized,
        [
            "execution summary",
            "summarize execution",
            "what happened after execution",
            "after execution",
            "execution result",
            "what happened when executed"
        ]
    ):
        intent = EXECUTION_SUMMARY_INTENT
        category = "movement"
        requires_movement = True


    # ======================================================
    # UNKNOWN / FUTURE GROQ AI
    # ======================================================

    else:
        intent = UNKNOWN_INTENT
        category = "unknown"

        # Open-ended questions will later be
        # handled by Groq.
        requires_ai = True


    # ======================================================
    # RESPONSE
    # ======================================================

    return {
        "intent": intent,
        "category": category,
        "requires_ai": requires_ai,
        "requires_movement": requires_movement,

        "entities": {
            "store_id": store_id,
            "store_ids": store_ids,
            "product_id": product_id,
            "movement_id": movement_id
        },

        "normalized_message": normalized
    }

def extract_store_ids(
    message: str
) -> list[str]:
    """
    Extract all unique store IDs from the message.

    Example:
    "Why was CP007 selected instead of CP004?"
        ->
    ["CP007", "CP004"]
    """

    if not message:
        return []

    matches = re.findall(
        r"\bCP\d{3}\b",
        message.upper()
    )

    # Remove duplicates while preserving order
    return list(
        dict.fromkeys(matches)
    )