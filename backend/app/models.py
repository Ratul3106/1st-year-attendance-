from enum import Enum
from typing import List, Optional, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field

class DeliveryStatus(str, Enum):
    QUEUED = "queued"
    PROCESSING = "processing"
    SENT = "sent"
    DELIVERED = "delivered"
    READ = "read"
    FAILED = "failed"

class NotificationType(str, Enum):
    IMMEDIATE_ABSENCE = "immediate_absence"
    REPEATED_ABSENCE_SUMMARY = "repeated_absence_summary"
    MANUAL_ALERT = "manual_alert"

class AttendanceEventPayload(BaseModel):
    session_id: str
    class_id: str
    class_name: str
    attendance_date: str
    session_type: str  # Morning / Afternoon
    student_id: str
    student_name: str
    register_number: str
    new_status: str  # present, absent, od, bunk
    previous_status: Optional[str] = None
    advisor_name: Optional[str] = "Class Advisor"
    advisor_phone: Optional[str] = "+919876543211"
    marked_by: str

class WhatsAppSettings(BaseModel):
    immediate_alerts_enabled: bool = True
    summary_alerts_enabled: bool = True
    absence_threshold: int = 3
    reporting_window_days: int = 7
    timezone: str = "Asia/Kolkata"
    phone_number_id: str = "100000000000000"
    api_version: str = "v21.0"
    absence_template_name: str = "attendance_absence_alert"
    absence_template_lang: str = "en_US"
    summary_template_name: str = "attendance_repeat_summary"
    summary_template_lang: str = "en_US"
    dean_placement_name: str = "Dean of Placement and Training"
    dean_placement_phone: str = "+919876543200"

class OutboxItem(BaseModel):
    id: str
    notification_type: NotificationType
    recipient_phone: str
    recipient_name: str
    recipient_role: str
    template_name: str
    template_language: str = "en_US"
    template_parameters: List[str] = []
    payload: Dict[str, Any] = {}
    status: DeliveryStatus = DeliveryStatus.QUEUED
    retry_count: int = 0
    max_retries: int = 5
    next_retry_at: datetime = Field(default_factory=datetime.utcnow)
    provider_message_id: Optional[str] = None
    error_message: Optional[str] = None
    idempotency_key: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

class NotificationLog(BaseModel):
    id: str
    outbox_id: Optional[str] = None
    student_id: Optional[str] = None
    student_name: Optional[str] = None
    register_number: Optional[str] = None
    class_id: Optional[str] = None
    class_name: Optional[str] = None
    session_id: Optional[str] = None
    notification_type: NotificationType
    recipient_phone: str
    recipient_name: str
    recipient_role: str
    provider_message_id: Optional[str] = None
    status: DeliveryStatus = DeliveryStatus.QUEUED
    error_code: Optional[str] = None
    error_message: Optional[str] = None
    sent_at: Optional[datetime] = None
    delivered_at: Optional[datetime] = None
    read_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
