from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models import Conversation, Feedback, ManualExample, Message, User
from app.schemas import ManualExampleIn, ManualExampleOut, TrainingStats
from app.services.llm import JARVIS_SYSTEM_PROMPT
from app.services.training_select import normalize_manual_messages, select_training_examples

router = APIRouter(prefix="/training", tags=["training"])

TARGET_EXAMPLES = 100
ALLOWED_MODEL_PREFIXES = ["vllm:"]


def _stored_messages(raw: list[dict]) -> list[dict]:
    try:
        full = normalize_manual_messages(raw, JARVIS_SYSTEM_PROMPT)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    return [m for m in full if m["role"] != "system"]


@router.post("/examples", response_model=ManualExampleOut, status_code=status.HTTP_201_CREATED)
def create_example(
    body: ManualExampleIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ManualExample:
    row = ManualExample(
        user_id=user.id,
        messages=_stored_messages([m.model_dump() for m in body.messages]),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.get("/examples", response_model=list[ManualExampleOut])
def list_examples(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[ManualExample]:
    return list(
        db.scalars(
            select(ManualExample)
            .where(ManualExample.user_id == user.id)
            .order_by(ManualExample.id.desc())
        ).all()
    )


@router.delete("/examples/{example_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_example(
    example_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    row = db.scalar(
        select(ManualExample).where(ManualExample.id == example_id, ManualExample.user_id == user.id)
    )
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Example not found")
    db.delete(row)
    db.commit()


@router.get("/stats", response_model=TrainingStats)
def training_stats(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TrainingStats:
    rows = db.execute(
        select(
            Message.conversation_id,
            Message.role,
            Message.content,
            Message.model,
            Feedback.rating,
            Feedback.correction,
        )
        .join(Conversation, Conversation.id == Message.conversation_id)
        .outerjoin(Feedback, Feedback.message_id == Message.id)
        .where(Conversation.user_id == user.id, Message.role.in_(("user", "assistant")))
        .order_by(Message.conversation_id, Message.id)
    ).mappings().all()
    _, stats = select_training_examples(
        rows,
        prefixes=ALLOWED_MODEL_PREFIXES,
        include_unrated=False,
        max_context=6,
        system_prompt=JARVIS_SYSTEM_PROMPT,
    )
    manual = len(
        db.scalars(select(ManualExample.id).where(ManualExample.user_id == user.id)).all()
    )
    corrected = stats["corrected"]
    liked = stats["liked"]
    return TrainingStats(
        corrected=corrected,
        liked=liked,
        manual=manual,
        total=corrected + liked + manual,
        target=TARGET_EXAMPLES,
    )
