from datetime import datetime, timedelta, timezone
from enum import Enum
from typing import Annotated, Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    StringConstraints,
    field_validator,
    model_validator,
)

AVAILABILITY_EXAMPLE_START = (datetime.now(timezone.utc) + timedelta(days=1)).replace(
    second=0, microsecond=0
)


class Role(str, Enum):
    cliente = "cliente"
    profissional = "profissional"


class RequestStatus(str, Enum):
    pendente = "pendente"
    aceita = "aceita"
    em_andamento = "em_andamento"
    concluida = "concluida"
    cancelada = "cancelada"
    recusada = "recusada"


class Input(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class UserInput(Input):
    name: str = Field(min_length=2, max_length=100, examples=["Maria Souza"])
    phone: str = Field(
        default="", max_length=20, pattern=r"^[0-9+() \-]*$", examples=["84999990000"]
    )


class Register(UserInput):
    accepted_terms: bool = False
    terms_version: str | None = Field(default=None, max_length=30)
    email: EmailStr = Field(examples=["maria@example.com"])
    password: Annotated[str, StringConstraints(strip_whitespace=False)] = Field(
        min_length=8,
        max_length=72,
        examples=["MinhaSenha123!"],
        description="Mínimo 8 caracteres e máximo 72 bytes UTF-8 (limite bcrypt). Espaços são preservados.",
    )
    role: Role = Role.cliente

    @field_validator("password")
    @classmethod
    def bcrypt_limit(cls, value):
        if len(value.encode("utf-8")) > 72:
            raise ValueError("A senha deve ter no máximo 72 bytes UTF-8.")
        return value


class Login(Input):
    email: EmailStr = Field(examples=["cliente@example.com"])
    password: Annotated[str, StringConstraints(strip_whitespace=False)] = Field(
        min_length=1, max_length=72, examples=["Demo12345!"]
    )

    @field_validator("password")
    @classmethod
    def bcrypt_limit(cls, value):
        return Register.bcrypt_limit(value)


class UserOut(UserInput):
    model_config = ConfigDict(from_attributes=True)
    id: int
    email: EmailStr
    role: Role
    verification_required: bool = False


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_at: datetime
    user: UserOut


class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str


class ProfessionalInput(Input):
    category_id: int = Field(gt=0, examples=[1])
    bio: str = Field(default="", max_length=2000)
    city: str = Field(min_length=2, max_length=100, examples=["Natal, RN"])
    visit_fee_cents: int = Field(
        strict=True,
        ge=0,
        le=10000000,
        examples=[8000],
        description="Valor fixo da visita em centavos de real; não representa o preço total do serviço. Zero indica visita gratuita. Preços adicionais podem ser informados na descrição.",
    )
    latitude: float | None = Field(
        default=None,
        ge=-90,
        le=90,
        allow_inf_nan=False,
        description="Latitude da base de atendimento. Visível somente ao proprietário.",
    )
    longitude: float | None = Field(default=None, ge=-180, le=180, allow_inf_nan=False)
    is_available: bool = True

    @model_validator(mode="after")
    def coordinate_pair(self):
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("Informe latitude e longitude juntas.")
        return self


class ProfessionalOut(BaseModel):
    category_id: int
    bio: str
    city: str
    visit_fee_cents: int | None
    next_available_at: datetime | None = None
    is_available: bool
    distance_km: float | None = Field(
        default=None,
        description="Distância aproximada em linha reta, nunca distância de viagem.",
    )
    id: int
    name: str
    category_name: str
    rating: float
    review_count: int


class ProfessionalOwnOut(ProfessionalInput):
    visit_fee_cents: int | None = Field(default=None, strict=True, ge=0, le=10000000)


class AvailabilityInput(Input):
    starts_at: datetime = Field(
        examples=[AVAILABILITY_EXAMPLE_START.isoformat()],
        description="Início futuro com fuso horário, até 180 dias a partir da publicação.",
    )
    ends_at: datetime = Field(
        examples=[(AVAILABILITY_EXAMPLE_START + timedelta(hours=1)).isoformat()],
        description="Fim com fuso horário; duração inteira de 30 a 480 minutos.",
    )

    @field_validator("starts_at", "ends_at")
    @classmethod
    def timezone_required(cls, value):
        if value.tzinfo is None:
            raise ValueError("Informe data e horário com fuso horário.")
        return value.astimezone(timezone.utc)

    @model_validator(mode="after")
    def interval(self):
        now = datetime.now(timezone.utc)
        seconds = (self.ends_at - self.starts_at).total_seconds()
        if self.starts_at <= now or self.starts_at > now + timedelta(days=180):
            raise ValueError(
                "O início deve ser futuro e estar dentro dos próximos 180 dias."
            )
        if not 1800 <= seconds <= 28800 or seconds % 60 != 0:
            raise ValueError("O horário deve durar de 30 a 480 minutos inteiros.")
        return self


class AvailabilityOut(BaseModel):
    id: int
    professional_id: int
    starts_at: datetime
    ends_at: datetime
    is_active: bool
    is_booked: bool


class RequestInput(Input):
    professional_id: int = Field(gt=0, examples=[2])
    slot_id: int = Field(
        strict=True,
        gt=0,
        examples=[5],
        description="Horário livre publicado por este profissional. A reserva fica pendente até ele aceitar.",
    )
    expected_visit_fee_cents: int = Field(
        strict=True,
        ge=0,
        le=10000000,
        examples=[8000],
        description="Valor da visita visto pelo cliente. O servidor rejeita alterações de preço com 409 e grava o valor real do perfil, nunca um preço enviado pelo cliente.",
    )
    title: str = Field(min_length=3, max_length=120, examples=["Instalação de tomadas"])
    description: str = Field(
        min_length=10,
        max_length=4000,
        examples=["Preciso instalar três tomadas na sala."],
    )
    address: str = Field(
        min_length=5, max_length=300, examples=["Rua das Flores, 123, Natal, RN"]
    )


class StatusInput(Input):
    status: RequestStatus = Field(examples=["aceita"])
    reason: str | None = Field(
        default=None,
        min_length=5,
        max_length=300,
        description="Motivo obrigatório quando o prestador cancela um atendimento aceito.",
    )


class RequestOut(BaseModel):
    id: int
    client_id: int
    client_name: str
    professional_id: int
    professional_name: str
    slot_id: int | None
    visit_fee_cents: int | None = Field(
        description="Valor fixo da visita no momento da reserva, preservado mesmo se o perfil mudar. Nulo em solicitações legadas; não é o total do serviço."
    )
    title: str
    description: str
    address: str
    scheduled_at: datetime
    duration_minutes: int
    status: RequestStatus
    hold_expires_at: datetime | None = None
    cancellation_reason: str | None = None
    cancelled_by: int | None = None
    created_at: datetime
    review_id: int | None


class ReviewInput(Input):
    rating: int = Field(ge=1, le=5, examples=[5])
    comment: str = Field(
        min_length=3, max_length=2000, examples=["Serviço realizado com capricho."]
    )


class ReviewOut(ReviewInput):
    id: int
    request_id: int
    client_name: str
    created_at: datetime


class PublicReviewOut(ReviewInput):
    id: int
    client_name: str
    created_at: datetime


class MessageInput(Input):
    body: str = Field(
        min_length=1, max_length=2000, examples=["Podemos confirmar o horário?"]
    )


class MessageOut(MessageInput):
    model_config = ConfigDict(from_attributes=True)
    id: int
    request_id: int
    sender_id: int
    created_at: datetime

    @field_validator("created_at", mode="before")
    @classmethod
    def utc_date(cls, value):
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


class SocketAuth(Input):
    type: Literal["auth"]
    token: str = Field(min_length=1, max_length=200)
    after: int = Field(default=0, ge=0)
    events_after: int = Field(default=0, ge=0)


class SocketMessage(MessageInput):
    type: Literal["message"]
    client_message_id: str = Field(
        min_length=16, max_length=64, pattern=r"^[a-zA-Z0-9_-]+$"
    )


class ErrorOut(BaseModel):
    detail: str = Field(examples=["Permissão insuficiente."])


class RequestEventOut(BaseModel):
    id: int
    request_id: int
    kind: str
    body: str
    created_at: datetime
    is_read: bool


class RequestSummaryOut(BaseModel):
    counts: dict[RequestStatus, int]
    requests: list[RequestOut]


class DocumentOut(BaseModel):
    version: str
    title: str
    body: str
    contact: str


class SessionOut(BaseModel):
    issued_at: datetime
    expires_at: datetime
    revoked: bool


class OperationAccepted(BaseModel):
    message: str


class PasswordChange(Input):
    current_password: Annotated[str, StringConstraints(strip_whitespace=False)] = Field(
        min_length=1, max_length=72, examples=["SenhaAtual123!"]
    )
    new_password: Annotated[str, StringConstraints(strip_whitespace=False)] = Field(
        min_length=8, max_length=72, examples=["NovaSenha123!"]
    )

    @field_validator("current_password", "new_password")
    @classmethod
    def bcrypt_limit(cls, value):
        return Register.bcrypt_limit(value)


class AddressInput(Input):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
        json_schema_extra={
            "examples": [
                {
                    "label": "Casa",
                    "postal_code": "59000000",
                    "street": "Rua das Flores",
                    "number": "123",
                    "complement": "Apto 10",
                    "neighborhood": "Centro",
                    "city": "Natal",
                    "state": "RN",
                    "is_default": True,
                }
            ]
        },
    )
    label: str = Field(min_length=2, max_length=40, examples=["Casa"])
    postal_code: str = Field(pattern=r"^[0-9]{8}$", examples=["59000000"])
    street: str = Field(min_length=2, max_length=120)
    number: str = Field(min_length=1, max_length=20, examples=["123", "S/N"])
    complement: str = Field(default="", max_length=80)
    neighborhood: str = Field(min_length=2, max_length=80)
    city: str = Field(min_length=2, max_length=80)
    state: Literal[
        "AC",
        "AL",
        "AP",
        "AM",
        "BA",
        "CE",
        "DF",
        "ES",
        "GO",
        "MA",
        "MT",
        "MS",
        "MG",
        "PA",
        "PB",
        "PR",
        "PE",
        "PI",
        "RJ",
        "RN",
        "RS",
        "RO",
        "RR",
        "SC",
        "SP",
        "SE",
        "TO",
    ]
    is_default: bool = False

    @model_validator(mode="after")
    def address_length(self):
        text = f"{self.street}, {self.number}" + (
            f", {self.complement}" if self.complement else ""
        )
        text += f" · {self.neighborhood} · {self.city}/{self.state} · CEP {self.postal_code}"
        if len(text) > 300:
            raise ValueError(
                "O endereço completo deve ter até 300 caracteres para uso nas solicitações."
            )
        return self


class AddressOut(AddressInput):
    model_config = ConfigDict(from_attributes=True)
    id: int
    is_active: bool


class NotificationOut(BaseModel):
    id: int
    request_id: int
    sender_name: str
    body: str
    created_at: datetime
    is_read: bool


class PushDeviceInput(Input):
    token: str = Field(
        min_length=20,
        max_length=4096,
        description="Token FCM do dispositivo atual. Não aparece nas respostas.",
    )
