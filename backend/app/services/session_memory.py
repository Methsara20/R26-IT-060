from typing import Optional


# ==========================================================
# CONFIGURATION
# ==========================================================

MAX_HISTORY_MESSAGES = 10


# ==========================================================
# IN-MEMORY SESSION STORE
# ==========================================================

_chat_sessions: dict[str, dict] = {}


# ==========================================================
# SESSION HELPERS
# ==========================================================

def create_session(
    session_id: str
) -> dict:
    """
    Create a new in-memory chat session.
    """

    session = {
        "session_id": session_id,
        "history": [],
        "movement_id": None,
        "last_context": None
    }

    _chat_sessions[session_id] = session

    return session


def get_session(
    session_id: str
) -> dict:
    """
    Get an existing session.

    If it does not exist, create it.
    """

    if session_id not in _chat_sessions:
        return create_session(
            session_id
        )

    return _chat_sessions[session_id]


def clear_session(
    session_id: str
) -> bool:
    """
    Remove one chat session.
    """

    if session_id in _chat_sessions:
        del _chat_sessions[session_id]
        return True

    return False


# ==========================================================
# HISTORY
# ==========================================================

def add_message(
    session_id: str,
    role: str,
    content: str
) -> None:
    """
    Add one message to session history.

    Supported roles:
    - user
    - assistant
    """

    if role not in {
        "user",
        "assistant"
    }:
        return

    session = get_session(
        session_id
    )

    session["history"].append({
        "role": role,
        "content": content
    })

    # Keep only the most recent messages.
    if (
        len(session["history"])
        > MAX_HISTORY_MESSAGES
    ):
        session["history"] = (
            session["history"][
                -MAX_HISTORY_MESSAGES:
            ]
        )


def get_history(
    session_id: str
) -> list[dict]:
    """
    Return recent conversation history.
    """

    session = get_session(
        session_id
    )

    return list(
        session.get(
            "history",
            []
        )
    )


# ==========================================================
# MOVEMENT CONTEXT
# ==========================================================

def set_movement_id(
    session_id: str,
    movement_id: Optional[str]
) -> None:
    """
    Remember the last selected movement.
    """

    session = get_session(
        session_id
    )

    session["movement_id"] = (
        movement_id
    )


def get_movement_id(
    session_id: str
) -> Optional[str]:
    """
    Get the last movement used in this session.
    """

    session = get_session(
        session_id
    )

    return session.get(
        "movement_id"
    )


# ==========================================================
# LAST CONTEXT
# ==========================================================

def set_last_context(
    session_id: str,
    context: Optional[dict]
) -> None:
    """
    Save the most recent compact AI context.
    """

    session = get_session(
        session_id
    )

    session["last_context"] = context


def get_last_context(
    session_id: str
) -> Optional[dict]:
    """
    Return the most recent compact AI context.
    """

    session = get_session(
        session_id
    )

    return session.get(
        "last_context"
    )


# ==========================================================
# DEBUG / TESTING
# ==========================================================

def get_session_snapshot(
    session_id: str
) -> dict:
    """
    Return a safe copy for testing/debugging.
    """

    session = get_session(
        session_id
    )

    return {
        "session_id": session.get(
            "session_id"
        ),
        "movement_id": session.get(
            "movement_id"
        ),
        "last_context": session.get(
            "last_context"
        ),
        "history": list(
            session.get(
                "history",
                []
            )
        )
    }