from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models import Conversation, Message, User
from app.schemas import ChatRequest, ChatResponse, ConversationDetail, ConversationOut
from app.services.llm import generate_reply

router = APIRouter(prefix="/chat", tags=["chat"])


def _owned_conversation(db: Session, user: User, conversation_id: int) -> Conversation:
    conv = db.scalar(
        select(Conversation)
        .where(Conversation.id == conversation_id, Conversation.user_id == user.id)
        .options(selectinload(Conversation.messages))
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

    reply = generate_reply(history, body.message.strip())

    now = datetime.now(timezone.utc)
    db.add(Message(conversation_id=conv.id, role="user", content=body.message.strip()))
    db.add(Message(conversation_id=conv.id, role="assistant", content=reply))
    conv.updated_at = now
    db.commit()

    return ChatResponse(reply=reply, conversation_id=conv.id)


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
