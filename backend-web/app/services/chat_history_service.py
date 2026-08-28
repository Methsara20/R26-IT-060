from datetime import datetime
from typing import Optional
from uuid import uuid4

from google.cloud import firestore

from app.constants.collections import (
    MANAGER_CHAT_SESSIONS_COLLECTION,
    MANAGER_CHAT_MESSAGES_SUBCOLLECTION
)

from app.services.firebase_service import (
    get_collection,
    get_document_by_id
)


# ==========================================================
# CONFIGURATION
# ==========================================================

DEFAULT_HISTORY_LIMIT = 20

MAX_HISTORY_LIMIT = 50


# ==========================================================
# GENERAL HELPERS
# ==========================================================

def now() -> str:
    """
    Return an ISO formatted timestamp.

    ISO format is useful because it can also be sorted
    correctly as a string when all timestamps use the same
    format.
    """

    return datetime.now().isoformat()


def generate_session_id() -> str:
    """
    Generate a unique chat session ID.
    """

    return (
        "CHAT-"
        + datetime.now().strftime("%Y%m%d")
        + "-"
        + uuid4().hex[:10].upper()
    )


def generate_message_id() -> str:
    """
    Generate a unique message document ID.
    """

    return (
        "MSG-"
        + uuid4().hex.upper()
    )


def generate_chat_title(
    message: Optional[str]
) -> str:
    """
    Generate a simple title from the manager's first
    question.

    Example:

    "Explain this recommendation"
            ↓
    "Explain this recommendation"
    """

    if not message:
        return "New Manager Chat"

    cleaned = " ".join(
        message.strip().split()
    )

    if len(cleaned) <= 60:
        return cleaned

    return (
        cleaned[:57].rstrip()
        + "..."
    )


# ==========================================================
# COLLECTION HELPERS
# ==========================================================

def get_session_reference(
    session_id: str
):
    """
    Get Firestore reference for one chat session.
    """

    return (
        get_collection(
            MANAGER_CHAT_SESSIONS_COLLECTION
        )
        .document(session_id)
    )


def get_messages_reference(
    session_id: str
):
    """
    Get the messages subcollection for one chat session.
    """

    return (
        get_session_reference(
            session_id
        )
        .collection(
            MANAGER_CHAT_MESSAGES_SUBCOLLECTION
        )
    )


# ==========================================================
# SESSION MANAGEMENT
# ==========================================================

def create_chat_session(
    session_id: Optional[str] = None,
    movement_id: Optional[str] = None,
    user_id: Optional[str] = None,
    mode: str = "GENERAL",
    title: Optional[str] = None
) -> dict:
    """
    Create a persistent manager chat session.

    No AI call occurs here.
    """

    resolved_session_id = (
        session_id
        or generate_session_id()
    )

    timestamp = now()

    session = {
        "session_id": resolved_session_id,

        "user_id": user_id,

        "mode": mode,

        "title": (
            title
            or "New Manager Chat"
        ),

        "movement_id": movement_id,

        "message_count": 0,

        "last_question": None,
        "last_answer": None,

        "last_answer_source": None,
        "last_ai_model": None,

        "created_at": timestamp,
        "updated_at": timestamp
    }

    get_session_reference(
        resolved_session_id
    ).set(
        session,
        merge=False
    )

    return session


def get_chat_session(
    session_id: str
) -> Optional[dict]:
    """
    Return one persistent chat session.
    """

    session = get_document_by_id(
        MANAGER_CHAT_SESSIONS_COLLECTION,
        session_id
    )

    return session


def ensure_chat_session(
    session_id: str,
    movement_id: Optional[str] = None,
    user_id: Optional[str] = None,
    mode: str = "GENERAL",
    first_message: Optional[str] = None
) -> dict:
    """
    Return existing session or create it.

    This is useful when chat_service.py receives the first
    message from a new Flutter chat.
    """

    session = get_chat_session(
        session_id
    )

    if session is not None:
        return session

    return create_chat_session(
        session_id=session_id,
        movement_id=movement_id,
        user_id=user_id,
        mode=mode,
        title=generate_chat_title(
            first_message
        )
    )


# ==========================================================
# SAVE ONE MESSAGE
# ==========================================================

def save_chat_message(
    session_id: str,
    role: str,
    content: str,
    movement_id: Optional[str] = None,
    answer_source: Optional[str] = None,
    ai_model: Optional[str] = None,
    intent: Optional[str] = None,
    category: Optional[str] = None
) -> dict:
    """
    Save one visible manager/assistant message.

    Supported roles:
    - user
    - assistant

    System prompts and internal context should NOT be saved
    here.
    """

    if role not in {
        "user",
        "assistant"
    }:
        raise ValueError(
            "Chat role must be 'user' or 'assistant'."
        )

    if not content:
        raise ValueError(
            "Chat message content cannot be empty."
        )

    message_id = generate_message_id()

    timestamp = now()

    message = {
        "message_id": message_id,

        "session_id": session_id,

        "role": role,

        "content": content,

        "movement_id": movement_id,

        "answer_source": answer_source,

        "ai_model": ai_model,

        "intent": intent,

        "category": category,

        "created_at": timestamp
    }

    (
        get_messages_reference(
            session_id
        )
        .document(message_id)
        .set(
            message,
            merge=False
        )
    )

    return message


# ==========================================================
# SAVE COMPLETE CHAT TURN
# ==========================================================

def save_chat_turn(
    session_id: str,
    question: str,
    answer: str,
    movement_id: Optional[str] = None,
    answer_source: Optional[str] = None,
    ai_model: Optional[str] = None,
    intent: Optional[str] = None,
    category: Optional[str] = None,
    user_id: Optional[str] = None,
    mode: str = "GENERAL"
) -> dict:
    """
    Persist one complete manager-assistant conversation turn.

    One turn =
    manager message + assistant response.

    The session metadata is updated only once after both
    messages are stored.
    """

    session = ensure_chat_session(
        session_id=session_id,
        movement_id=movement_id,
        user_id=user_id,
        mode=mode,
        first_message=question
    )

    user_message = save_chat_message(
        session_id=session_id,
        role="user",
        content=question,
        movement_id=movement_id,
        intent=intent,
        category=category
    )

    assistant_message = save_chat_message(
        session_id=session_id,
        role="assistant",
        content=answer,
        movement_id=movement_id,
        answer_source=answer_source,
        ai_model=ai_model,
        intent=intent,
        category=category
    )

    timestamp = now()

    session_update = {
        "updated_at": timestamp,

        "last_question": question,

        "last_answer": answer,

        "last_answer_source": (
            answer_source
        ),

        "last_ai_model": ai_model,

        # Keep most recently used movement.
        "movement_id": (
            movement_id
            or session.get("movement_id")
        ),

        # Two visible messages were added.
        "message_count": (
            firestore.Increment(2)
        )
    }

    get_session_reference(
        session_id
    ).set(
        session_update,
        merge=True
    )

    return {
        "session_id": session_id,
        "user_message": user_message,
        "assistant_message": assistant_message
    }


# ==========================================================
# LOAD CHAT HISTORY
# ==========================================================

def get_chat_history(
    session_id: str,
    limit: int = DEFAULT_HISTORY_LIMIT
) -> list[dict]:
    """
    Load the most recent messages for one chat.

    We intentionally limit the result to protect Firestore
    read usage.

    Results are returned oldest → newest for the UI.
    """

    safe_limit = max(
        1,
        min(
            int(limit),
            MAX_HISTORY_LIMIT
        )
    )

    query = (
        get_messages_reference(
            session_id
        )
        .order_by(
            "created_at",
            direction=firestore.Query.DESCENDING
        )
        .limit(
            safe_limit
        )
    )

    messages = []

    for document in query.stream():

        data = document.to_dict()

        if data:
            messages.append(
                data
            )

    # Firestore returned newest first.
    # Flutter/Groq expects oldest first.
    messages.reverse()

    return messages


# ==========================================================
# UPDATE SESSION MOVEMENT
# ==========================================================

def update_session_movement(
    session_id: str,
    movement_id: Optional[str]
) -> None:
    """
    Persist the most recently used movement ID.
    """

    if not movement_id:
        return

    get_session_reference(
        session_id
    ).set(
        {
            "movement_id": movement_id,
            "updated_at": now()
        },
        merge=True
    )


# ==========================================================
# LIST RECENT CHAT SESSIONS
# ==========================================================

def get_recent_chat_sessions(
    limit: int = 20
) -> list[dict]:
    """
    Return recent chat sessions for the future Flutter
    Chat History screen.
    """

    safe_limit = max(
        1,
        min(
            int(limit),
            50
        )
    )

    query = (
        get_collection(
            MANAGER_CHAT_SESSIONS_COLLECTION
        )
        .order_by(
            "updated_at",
            direction=firestore.Query.DESCENDING
        )
        .limit(
            safe_limit
        )
    )

    sessions = []

    for document in query.stream():

        data = document.to_dict()

        if data:
            sessions.append(
                data
            )

    return sessions