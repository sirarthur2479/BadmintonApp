"""Pydantic request/response models."""

from pydantic import BaseModel, Field


class Credentials(BaseModel):
    email: str = Field(min_length=3, pattern=r".+@.+")
    password: str = Field(min_length=1)


class AccountOut(BaseModel):
    id: str
    email: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


class Session(BaseModel):
    """Mirrors the current Flutter TrainingSession.toMap() exactly.

    drills is a JSON-array STRING (schema v2 / TASK-007) — the backend
    stores it opaquely and never re-encodes it. intensity is nullable
    (legacy rating).
    """

    id: str = Field(min_length=1)
    date: str = Field(min_length=1)  # ISO-8601 string, as Flutter emits it
    durationMinutes: int
    drills: str
    intensity: int | None = None
    notes: str = ""
    photoPath: str | None = None
    sessionGoal: str = ""
    goalAchievementScore: int = 3
    playerRemarks: str = ""
    coachRemarks: str = ""
    reflectionAnswersJson: str = "[]"


class Player(BaseModel):
    """Mirrors the Flutter PlayerProfile fields plus the client UUID id."""

    id: str = Field(min_length=1)
    name: str = Field(min_length=1)
    age: int | None = None
    club: str = ""
    playingStyle: str = ""
    preferredGrip: str = ""
    shortTermGoal: str = ""
    longTermGoal: str = ""
    photoPath: str | None = None
