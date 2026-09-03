"""SecureAI Ops Lab incident API."""
import json
import logging
import os
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Literal

from fastapi import Depends, FastAPI, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import DateTime, String, Text, create_engine, func, select
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./secureai.db")
# PostgreSQL uses JSONB; SQLite used for local development and unit tests.
JSON_TYPE = JSONB if DATABASE_URL.startswith("postgresql") else Text

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"), format="%(message)s")
logger = logging.getLogger("secureai")
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)


class Base(DeclarativeBase):
    pass


class Incident(Base):
    __tablename__ = "incidents"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    source_finding_id: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    title: Mapped[str] = mapped_column(String(500))
    description: Mapped[str] = mapped_column(Text)
    severity: Mapped[str] = mapped_column(String(16), index=True)
    status: Mapped[str] = mapped_column(String(32), default="open", index=True)
    is_simulated: Mapped[bool] = mapped_column(default=True)
    evidence_s3_uri: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    ai_brief: Mapped[str | None] = mapped_column(Text, nullable=True)
    enrichment_status: Mapped[str] = mapped_column(String(32), default="pending")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class AuditEvent(Base):
    __tablename__ = "audit_events"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    incident_id: Mapped[str] = mapped_column(String(36), index=True)
    action: Mapped[str] = mapped_column(String(100))
    actor_type: Mapped[str] = mapped_column(String(50))
    metadata_json: Mapped[str] = mapped_column(Text, default="{}")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class IncidentCreate(BaseModel):
    source_finding_id: str = Field(min_length=1, max_length=255)
    title: str = Field(min_length=1, max_length=500)
    description: str = Field(min_length=1)
    severity: Literal["low", "medium", "high", "critical"]
    is_simulated: bool = True
    evidence_s3_uri: str | None = None
    ai_brief: str | None = None
    enrichment_status: str = "pending"


class IncidentResponse(IncidentCreate):
    id: str
    status: str
    created_at: datetime
    updated_at: datetime


class AuditResponse(BaseModel):
    id: str
    action: str
    actor_type: str
    metadata: dict
    created_at: datetime


class IncidentDetail(IncidentResponse):
    audit_events: list[AuditResponse]


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def log_event(event: str, **fields: object) -> None:
    logger.info(json.dumps({"event": event, "timestamp": datetime.now(timezone.utc).isoformat(), **fields}))


@asynccontextmanager
async def lifespan(_: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="SecureAI Ops Lab", version="0.1.0", lifespan=lifespan)


@app.middleware("http")
async def request_logging(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    log_event("request_complete", request_id=request_id, method=request.method, path=request.url.path, status=response.status_code)
    return response


@app.get("/health")
def health():
    return {"status": "ok", "service": "secureai-ops-lab"}


@app.post("/api/incidents", response_model=IncidentResponse, status_code=201)
def create_incident(payload: IncidentCreate, db: Session = Depends(get_db)):
    if db.scalar(select(Incident).where(Incident.source_finding_id == payload.source_finding_id)):
        raise HTTPException(status_code=409, detail="source_finding_id already exists")
    incident = Incident(id=str(uuid.uuid4()), **payload.model_dump())
    db.add(incident)
    db.add(AuditEvent(id=str(uuid.uuid4()), incident_id=incident.id, action="incident_created", actor_type="api", metadata_json="{}"))
    db.commit()
    db.refresh(incident)
    log_event("incident_created", incident_id=incident.id, simulated=incident.is_simulated)
    return incident


@app.get("/api/incidents", response_model=list[IncidentResponse])
def list_incidents(
    severity: Literal["low", "medium", "high", "critical"] | None = None,
    status: str | None = None,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
):
    query = select(Incident).order_by(Incident.created_at.desc()).limit(limit).offset(offset)
    if severity:
        query = query.where(Incident.severity == severity)
    if status:
        query = query.where(Incident.status == status)
    return list(db.scalars(query))


@app.get("/api/incidents/{incident_id}", response_model=IncidentDetail)
def get_incident(incident_id: str, db: Session = Depends(get_db)):
    incident = db.get(Incident, incident_id)
    if not incident:
        raise HTTPException(status_code=404, detail="incident not found")
    audits = list(db.scalars(select(AuditEvent).where(AuditEvent.incident_id == incident_id).order_by(AuditEvent.created_at)))
    return {**{column.name: getattr(incident, column.name) for column in Incident.__table__.columns}, "audit_events": [
        {"id": a.id, "action": a.action, "actor_type": a.actor_type, "metadata": json.loads(a.metadata_json), "created_at": a.created_at} for a in audits
    ]}
