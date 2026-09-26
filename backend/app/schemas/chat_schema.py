from typing import Optional, Literal, Dict, Any

from pydantic import BaseModel, Field

class ChatRequest(BaseModel):

    message: str = Field(
        ...,
        min_length=1,
        max_length=500,
        description="Manager question"
    )

    context: Optional[Dict[str, Any]] = {}

    session_id: Optional[str] = Field(
        default=None,
        min_length=1,
        max_length=100,
        description="Chat session ID used for conversation memory and persistent history"
    )

    movement_id: Optional[str] = Field(
        default=None,
        description="Optional stock movement ID for movement-related questions"
    )

    user_id: Optional[str] = Field(
        default=None,
        description="Optional authenticated user ID"
    )

    mode: Literal["GENERAL", "CONTEXTUAL"] = Field(
        default="GENERAL",
        description="GENERAL = main manager chat tab. CONTEXTUAL = prediction-page assistant."
    )


class ChatResponse(BaseModel):

    session_id: Optional[str] = None
    movement_id: Optional[str] = None
    movement_status: Optional[str] = None
    intent: str
    category: str
    answer: str
    answer_source: str
    ai_model: Optional[str] = None
    error_code: Optional[str] = None


# ==========================================================
# CHAT HISTORY
# ==========================================================

class ChatSessionSummary(BaseModel):

    session_id: str
    title: str
    movement_id: Optional[str] = None
    mode: Optional[str] = None
    message_count: int = 0
    last_question: Optional[str] = None
    last_answer: Optional[str] = None
    last_answer_source: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

class ChatMessageResponse(BaseModel):

    message_id: str
    session_id: str
    role: str
    content: str
    movement_id: Optional[str] = None
    answer_source: Optional[str] = None
    ai_model: Optional[str] = None
    intent: Optional[str] = None
    category: Optional[str] = None
    created_at: Optional[str] = None


class ChatHistoryResponse(BaseModel):

    session_id: str
    movement_id: Optional[str] = None
    title: Optional[str] = None
    mode: Optional[str] = None
    messages: list[ChatMessageResponse]
