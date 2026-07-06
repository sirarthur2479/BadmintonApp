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
