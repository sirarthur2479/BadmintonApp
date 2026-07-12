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


class MatchLog(BaseModel):
    """Mirrors Flutter MatchLog.toMap() (TASK-035): standalone per-match
    reflection log, not tied to a tournamentId. isWin is a 0/1 int, date an
    ISO-8601 string, videoRef nullable — stored opaquely, never re-encoded.
    """

    id: str = Field(min_length=1)
    date: str = Field(min_length=1)
    opponent: str = Field(min_length=1)
    eventContext: str = ""
    scores: str = ""
    isWin: int = Field(ge=0, le=1)
    gameplan: str = ""
    readinessScore: int = Field(default=3, ge=1, le=5)
    performanceNotes: str = ""
    keyMoments: str = ""
    videoRef: str | None = None


class Match(BaseModel):
    """Mirrors Flutter TournamentMatch.toMap(): pipe scores, isWin 0/1."""

    id: str = Field(min_length=1)
    tournamentId: str = Field(min_length=1)
    opponent: str
    scores: str
    isWin: int = Field(ge=0, le=1)
    notes: str | None = None


class TournamentIn(BaseModel):
    id: str = Field(min_length=1)
    name: str = Field(min_length=1)
    date: str = Field(min_length=1)
    location: str
    format: str


class TournamentOut(TournamentIn):
    matches: list[Match] = []


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
