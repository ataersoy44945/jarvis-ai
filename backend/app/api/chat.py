from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models import Conversation, Feedback, Message, User
from app.schemas import (
    ChatRequest,
    ChatResponse,
    ConversationDetail,
    ConversationOut,
    FeedbackOut,
    FeedbackRequest,
)
from app.services.llm import generate_reply

router = APIRouter(prefix="/chat", tags=["chat"])


def _owned_conversation(db: Session, user: User, conversation_id: int) -> Conversation:
    conv = db.scalar(
        select(Conversation)
        .where(Conversation.id == conversation_id, Conversation.user_id == user.id)
        .options(selectinload(Conversation.messages).selectinload(Message.feedback))
    )
    if conv is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
    return conv


@router.post("", response_model=ChatResponse)
def chat(
    body: ChatRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ChatResponse:
    if body.conversation_id is None:
        title = body.message.strip()[:60] or "New chat"
        conv = Conversation(user_id=user.id, title=title)
        db.add(conv)
        db.flush()
    else:
        conv = _owned_conversation(db, user, body.conversation_id)

    history = [{"role": m.role, "content": m.content} for m in conv.messages if m.role in ("user", "assistant")]
    # Keep last 20 turns for context window
    history = history[-20:]

    reply, model = generate_reply(history, body.message.strip())

    now = datetime.now(timezone.utc)
    db.add(Message(conversation_id=conv.id, role="user", content=body.message.strip()))
    assistant_msg = Message(conversation_id=conv.id, role="assistant", content=reply, model=model)
    db.add(assistant_msg)
    conv.updated_at = now
    db.commit()

    return ChatResponse(reply=reply, conversation_id=conv.id, message_id=assistant_msg.id)


@router.post("/messages/{message_id}/feedback", response_model=FeedbackOut | None)
def give_feedback(
    message_id: int,
    body: FeedbackRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Feedback | None:
    """Rate an assistant reply (1 / -1), optionally with a corrected answer. rating=0 removes the rating."""
    msg = db.scalar(
        select(Message)
        .join(Conversation)
        .where(Message.id == message_id, Conversation.user_id == user.id, Message.role == "assistant")
    )
    if msg is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")

    fb = db.scalar(select(Feedback).where(Feedback.message_id == msg.id))
    if body.rating == 0:
        if fb is not None:
            db.delete(fb)
            db.commit()
        return None
    correction = (body.correction or "").strip() or None
    if fb is None:
        fb = Feedback(message_id=msg.id, rating=body.rating, correction=correction)
        db.add(fb)
    else:
        fb.rating = body.rating
        fb.correction = correction
    db.commit()
    db.refresh(fb)
    return fb


@router.get("/conversations", response_model=list[ConversationOut])
def list_conversations(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[Conversation]:
    return list(
        db.scalars(
            select(Conversation)
            .where(Conversation.user_id == user.id)
            .order_by(Conversation.updated_at.desc())
        ).all()
    )


@router.get("/conversations/{conversation_id}", response_model=ConversationDetail)
def get_conversation(
    conversation_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Conversation:
    return _owned_conversation(db, user, conversation_id)
