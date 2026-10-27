from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    event,
    select,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .data_protection import ProtectedFloat, ProtectedText, email_lookup
from .database import Base


def utcnow():
    return datetime.now(timezone.utc)


class SchemaRevision(Base):
    __tablename__ = "schema_revisions"
    version: Mapped[str] = mapped_column(String(40), primary_key=True)
    applied_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )


class AccountAction(Base):
    __tablename__ = "account_actions"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    actor: Mapped[str] = mapped_column(String(100))
    action: Mapped[str] = mapped_column(String(30))
    reason: Mapped[str] = mapped_column(ProtectedText("account_actions.reason"))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )


class User(Base):
    __tablename__ = "users"
    __table_args__ = (CheckConstraint("role IN ('cliente', 'profissional')"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(ProtectedText("users.name"))
    email: Mapped[str] = mapped_column(ProtectedText("users.email"))
    email_lookup: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    phone: Mapped[str] = mapped_column(ProtectedText("users.phone"), default="")
    role: Mapped[str] = mapped_column(String(20))
    password_hash: Mapped[str] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    email_verified_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    closed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    terms_version: Mapped[str | None] = mapped_column(String(30), nullable=True)
    terms_accepted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class AccountChallenge(Base):
    __tablename__ = "account_challenges"
    digest: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    purpose: Mapped[str] = mapped_column(String(30))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    consumed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class MailDelivery(Base):
    __tablename__ = "mail_deliveries"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    recipient: Mapped[str] = mapped_column(ProtectedText("mail_deliveries.recipient"))
    subject: Mapped[str] = mapped_column(String(120))
    body: Mapped[str] = mapped_column(ProtectedText("mail_deliveries.body"))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )
    retry_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    leased_until: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class AuthToken(Base):
    __tablename__ = "auth_tokens"
    digest: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    original_expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class RequestEvent(Base):
    __tablename__ = "request_events"
    id: Mapped[int] = mapped_column(primary_key=True)
    request_id: Mapped[int] = mapped_column(
        ForeignKey("service_requests.id"), index=True
    )
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    kind: Mapped[str] = mapped_column(String(40))
    body: Mapped[str] = mapped_column(ProtectedText("request_events.body"))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class EventDelivery(Base):
    __tablename__ = "event_deliveries"
    event_id: Mapped[int] = mapped_column(
        ForeignKey("request_events.id"), primary_key=True
    )
    device_digest: Mapped[str] = mapped_column(
        ForeignKey("push_devices.digest"), primary_key=True
    )
    session_digest: Mapped[str] = mapped_column(ForeignKey("auth_tokens.digest"))
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    retry_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    leased_until: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class SocketLease(Base):
    __tablename__ = "socket_leases"
    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


class Category(Base):
    __tablename__ = "categories"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(80), unique=True)


class Professional(Base):
    __tablename__ = "professionals"
    __table_args__ = (
        CheckConstraint("hourly_rate_cents >= 0"),
        CheckConstraint(
            "visit_fee_cents IS NULL OR visit_fee_cents BETWEEN 0 AND 10000000",
            name="ck_professionals_visit_fee_cents",
        ),
        CheckConstraint("latitude IS NULL OR latitude BETWEEN -90 AND 90"),
        CheckConstraint("longitude IS NULL OR longitude BETWEEN -180 AND 180"),
        CheckConstraint(
            "(latitude IS NULL AND longitude IS NULL) OR (latitude IS NOT NULL AND longitude IS NOT NULL)"
        ),
    )
    id: Mapped[int] = mapped_column(ForeignKey("users.id"), primary_key=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id"), index=True)
    bio: Mapped[str] = mapped_column(Text, default="")
    city: Mapped[str] = mapped_column(String(100), default="Natal, RN")
    hourly_rate_cents: Mapped[int] = mapped_column(Integer, default=0)
    visit_fee_cents: Mapped[int | None] = mapped_column(Integer, nullable=True)
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True, index=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    public_name: Mapped[str] = mapped_column(String(100), default="")
    latitude_private: Mapped[float | None] = mapped_column(
        ProtectedFloat("professionals.latitude"), nullable=True
    )
    longitude_private: Mapped[float | None] = mapped_column(
        ProtectedFloat("professionals.longitude"), nullable=True
    )
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    user: Mapped[User] = relationship()
    category: Mapped[Category] = relationship()


class AvailabilitySlot(Base):
    __tablename__ = "availability_slots"
    __table_args__ = (
        CheckConstraint("ends_at > starts_at"),
        Index("ix_availability_professional_start", "professional_id", "starts_at"),
    )
    id: Mapped[int] = mapped_column(primary_key=True)
    professional_id: Mapped[int] = mapped_column(ForeignKey("professionals.id"))
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )


class ServiceRequest(Base):
    __tablename__ = "service_requests"
    __table_args__ = (
        CheckConstraint("client_id != professional_id"),
        CheckConstraint("duration_minutes BETWEEN 30 AND 480"),
        CheckConstraint(
            "visit_fee_cents IS NULL OR visit_fee_cents BETWEEN 0 AND 10000000",
            name="ck_service_requests_visit_fee_cents",
        ),
        CheckConstraint(
            "status IN ('pendente','aceita','em_andamento','concluida','cancelada','recusada')"
        ),
        Index(
            "uq_service_requests_occupied_slot",
            "slot_id",
            unique=True,
            sqlite_where=text(
                "slot_id IS NOT NULL AND status IN ('pendente','aceita','em_andamento','concluida')"
            ),
        ),
    )
    id: Mapped[int] = mapped_column(primary_key=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    professional_id: Mapped[int] = mapped_column(
        ForeignKey("professionals.id"), index=True
    )
    slot_id: Mapped[int | None] = mapped_column(
        ForeignKey("availability_slots.id"), nullable=True
    )
    visit_fee_cents: Mapped[int | None] = mapped_column(Integer, nullable=True)
    title: Mapped[str] = mapped_column(ProtectedText("service_requests.title"))
    description: Mapped[str] = mapped_column(
        ProtectedText("service_requests.description")
    )
    address: Mapped[str] = mapped_column(ProtectedText("service_requests.address"))
    scheduled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    duration_minutes: Mapped[int] = mapped_column(Integer, default=60)
    status: Mapped[str] = mapped_column(String(20), default="pendente", index=True)
    hold_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )
    cancellation_reason: Mapped[str | None] = mapped_column(String(300), nullable=True)
    cancelled_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )
    client: Mapped[User] = relationship(foreign_keys=[client_id])
    professional: Mapped[Professional] = relationship()
    review: Mapped["Review | None"] = relationship(
        back_populates="request", uselist=False
    )


class Review(Base):
    __tablename__ = "reviews"
    __table_args__ = (CheckConstraint("rating BETWEEN 1 AND 5"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    request_id: Mapped[int] = mapped_column(
        ForeignKey("service_requests.id"), unique=True
    )
    rating: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )
    request: Mapped[ServiceRequest] = relationship(back_populates="review")


class Message(Base):
    __tablename__ = "messages"
    __table_args__ = (UniqueConstraint("sender_id", "client_message_id"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    request_id: Mapped[int] = mapped_column(
        ForeignKey("service_requests.id"), index=True
    )
    sender_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    body: Mapped[str] = mapped_column(ProtectedText("messages.body"))
    client_message_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )


class Address(Base):
    __tablename__ = "addresses"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    label: Mapped[str] = mapped_column(ProtectedText("addresses.label"))
    postal_code: Mapped[str] = mapped_column(ProtectedText("addresses.postal_code"))
    street: Mapped[str] = mapped_column(ProtectedText("addresses.street"))
    number: Mapped[str] = mapped_column(ProtectedText("addresses.number"))
    complement: Mapped[str] = mapped_column(
        ProtectedText("addresses.complement"), default=""
    )
    neighborhood: Mapped[str] = mapped_column(ProtectedText("addresses.neighborhood"))
    city: Mapped[str] = mapped_column(ProtectedText("addresses.city"))
    state: Mapped[str] = mapped_column(ProtectedText("addresses.state"))
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class MessageReceipt(Base):
    __tablename__ = "message_receipts"
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), primary_key=True)
    message_id: Mapped[int] = mapped_column(ForeignKey("messages.id"), primary_key=True)
    read_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class PushDevice(Base):
    __tablename__ = "push_devices"
    digest: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    session_digest: Mapped[str] = mapped_column(
        ForeignKey("auth_tokens.digest"), index=True
    )
    token: Mapped[str] = mapped_column(ProtectedText("push_devices.token"))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class PushDelivery(Base):
    __tablename__ = "push_deliveries"
    message_id: Mapped[int] = mapped_column(ForeignKey("messages.id"), primary_key=True)
    device_digest: Mapped[str] = mapped_column(
        ForeignKey("push_devices.digest"), primary_key=True
    )
    session_digest: Mapped[str] = mapped_column(String(64))
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    next_attempt_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, index=True
    )
    lease_until: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    outcome: Mapped[str | None] = mapped_column(String(40), nullable=True)


class SecurityAttempt(Base):
    __tablename__ = "auth_attempts"
    key: Mapped[str] = mapped_column(String(64), primary_key=True)
    window_started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    count: Mapped[int] = mapped_column(Integer)


@event.listens_for(User, "before_insert")
@event.listens_for(User, "before_update")
def normalize_user(mapper, connection, user):
    user.email = user.email.strip().lower()
    user.email_lookup = email_lookup(user.email)


@event.listens_for(Professional, "before_insert")
def initialize_professional(mapper, connection, professional):
    if not professional.public_name:
        professional.public_name = connection.execute(
            select(User.name).where(User.id == professional.id)
        ).scalar_one()
    if professional.latitude_private is None and professional.latitude is not None:
        professional.latitude_private = professional.latitude
        professional.longitude_private = professional.longitude
    if professional.latitude is not None:
        professional.latitude = round(professional.latitude, 2)
        professional.longitude = round(professional.longitude, 2)
