from dataclasses import dataclass

@dataclass
class Student:
    id: int
    name: str

    sex: str
    track: str

    sleep: float
    wake: float

    noise: int

    hobbies: set

    same_track: bool

    snore: bool

    must_have: list
    cant_have: list
