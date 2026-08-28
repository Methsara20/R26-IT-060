from typing import List
from fastapi import APIRouter, HTTPException
from app.schemas.chat_schema import (
    ChatRequest,
    ChatResponse,
    ChatSessionSummary,
    ChatHistoryResponse
)
from app.services.chat_service import (
    handle_chat
)
from app.services.chat_history_service import (
    get_recent_chat_sessions,
    get_chat_history,
    get_chat_session
)


router = APIRouter(
    prefix="/manager-assistant",
    tags=["Manager Assistant"]
)


@router.post(
    "/chat",
    response_model=ChatResponse
)
def manager_assistant_chat(
    request: ChatRequest
):
    result = handle_chat(
        message=request.message,
        movement_id=request.movement_id,
        session_id=request.session_id,
        user_id=request.user_id,
        mode=request.mode
    )

    if (
        result.get("error_code")
        == "MOVEMENT_NOT_FOUND"
    ):
        raise HTTPException(
            status_code=404,
            detail=result
        )

    return result

@router.get(
    "/history",
    response_model=List[ChatSessionSummary]
)
def list_chat_history(
    limit: int = 20
):
    """
    Return recent manager chat sessions.
    """

    try:

        sessions = get_recent_chat_sessions(
            limit=limit
        )

        return sessions

    except Exception as exc:

        print(
            f"Chat history list error: {exc}"
        )

        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to load chat history."
            )
        )


@router.get(
    "/history/{session_id}",
    response_model=ChatHistoryResponse
)
def load_chat_history(
    session_id: str,
    limit: int = 20
):
    """
    Load one chat session and its recent messages.
    """

    try:

        session = get_chat_session(
            session_id
        )

        if session is None:

            raise HTTPException(
                status_code=404,
                detail=(
                    "Chat session not found."
                )
            )

        messages = get_chat_history(
            session_id=session_id,
            limit=limit
        )

        return {
            "session_id": session_id,

            "movement_id": session.get(
                "movement_id"
            ),

            "title": session.get(
                "title"
            ),

            "mode": session.get(
                "mode"
            ),

            "messages": messages
        }

    except HTTPException:
        raise

    except Exception as exc:

        print(
            f"Chat history load error: {exc}"
        )

        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to load chat messages."
            )
        )