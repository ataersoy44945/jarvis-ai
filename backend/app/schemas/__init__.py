from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    name: str = Field(min_length=1, max_length=120)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    name: str
    email: EmailStr


class UserOut(BaseModel):
    id: int
    email: EmailStr
    name: str

    model_config = {"from_attributes": True}


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=8000)
    conversation_id: int | None = None


class ChatResponse(BaseModel):
    reply: str
    conversation_id: int
    message_id: int | None = None  # id of the assistant reply, for feedback


class FeedbackRequest(BaseModel):
    rating: int = Field(ge=-1, le=1)  # 1 good, -1 bad, 0 = clear
    correction: str | None = Field(default=None, max_length=8000)


class FeedbackOut(BaseModel):
    message_id: int
    rating: int
    correction: str | None

    model_config = {"from_attributes": True}


class MessageOut(BaseModel):
    id: int
    role: str
    content: str
    model: str | None = None
    rating: int | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class ConversationOut(BaseModel):
    id: int
    title: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ConversationDetail(ConversationOut):
    messages: list[MessageOut]


class TrainMessage(BaseModel):
    role: str
    content: str = Field(min_length=1, max_length=8000)


class ManualExampleIn(BaseModel):
    messages: list[TrainMessage] = Field(min_length=2)


class ManualExampleOut(BaseModel):
    id: int
    messages: list[TrainMessage]
    created_at: datetime

    model_config = {"from_attributes": True}


class TrainingStats(BaseModel):
    corrected: int
    liked: int
    manual: int
    total: int
    target: int = 100
