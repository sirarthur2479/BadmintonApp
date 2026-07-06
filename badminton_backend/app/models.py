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
