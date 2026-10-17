import hmac
import hashlib
import os
import uuid
import re
from typing import List, Dict, Optional, Any, Set
from datetime import datetime, timedelta
import httpx
from backend.app.models import (
    DeliveryStatus,
    NotificationType,
    WhatsAppSettings,
    OutboxItem,
    NotificationLog,
    AttendanceEventPayload,
)

class WhatsAppService:
    def __init__(self):
        self.settings = WhatsAppSettings()
        self.outbox: Dict[str, OutboxItem] = {}
        self.logs: Dict[str, NotificationLog] = {}
        self.processed_webhook_events: Set[str] = set()
        self.idempotency_keys: Set[str] = set()

        # Mocking flags for testing
        self.mock_fail_api = False
        self.mock_missing_credentials = False

    def normalize_phone(self, phone: str) -> str:
        clean = re.sub(r"\D", "", phone)
        if len(clean) == 10:
            return f"+91{clean}"
        if not phone.startswith("+"):
            return f"+{clean}"
        return phone

    def verify_webhook_signature(self, raw_body: bytes, signature_header: Optional[str], app_secret: str) -> bool:
        if not signature_header or not signature_header.startswith("sha256="):
            return False
        expected_sig = signature_header[len("sha256="):]
        computed_sig = hmac.new(app_secret.encode("utf-8"), raw_body, hashlib.sha256).hexdigest()
        return hmac.compare_digest(expected_sig.lower(), computed_sig.lower())

    async def handle_attendance_event(self, event: AttendanceEventPayload) -> Optional[OutboxItem]:
        # Only absent triggers immediate notification
        if event.new_status != "absent":
            return None

        # Duplicate protection: If already absent previously, do not send duplicate
        if event.previous_status == "absent":
            return None

        if not self.settings.immediate_alerts_enabled:
            return None

        idempotency_key = f"imm_abs_{event.session_id}_{event.student_id}_absent"
        if idempotency_key in self.idempotency_keys:
            return None
        self.idempotency_keys.add(idempotency_key)

        recipient_name = event.advisor_name or "Class Advisor"
        recipient_phone = self.normalize_phone(event.advisor_phone or "+919876543211")

        # Official Meta approved template placeholders:
        # {{1}} Advisor Name, {{2}} Student Name, {{3}} Reg No, {{4}} Class, {{5}} Date, {{6}} Session/Period, {{7}} Subject
        template_params = [
            recipient_name,
            event.student_name,
            event.register_number,
            event.class_name,
            event.attendance_date,
            event.session_type,
            "Daily Class Session",
        ]

        item_id = str(uuid.uuid4())
        outbox_item = OutboxItem(
            id=item_id,
            notification_type=NotificationType.IMMEDIATE_ABSENCE,
            recipient_phone=recipient_phone,
            recipient_name=recipient_name,
            recipient_role="Class Advisor",
            template_name=self.settings.absence_template_name,
            template_language=self.settings.absence_template_lang,
            template_parameters=template_params,
            payload=event.model_dump(),
            status=DeliveryStatus.QUEUED,
            idempotency_key=idempotency_key,
        )
        self.outbox[item_id] = outbox_item

        log_item = NotificationLog(
            id=str(uuid.uuid4()),
            outbox_id=item_id,
            student_id=event.student_id,
            student_name=event.student_name,
            register_number=event.register_number,
            class_id=event.class_id,
            class_name=event.class_name,
            session_id=event.session_id,
            notification_type=NotificationType.IMMEDIATE_ABSENCE,
            recipient_phone=recipient_phone,
            recipient_name=recipient_name,
            recipient_role="Class Advisor",
            status=DeliveryStatus.QUEUED,
        )
        self.logs[log_item.id] = log_item

        return outbox_item

    async def evaluate_repeated_absences(
        self,
        class_id: str,
        class_name: str,
        records: List[Dict[str, Any]],  # List of {student_id, student_name, register_number, session_id, date, status}
        as_of_date: Optional[datetime] = None,
        custom_threshold: Optional[int] = None,
        custom_window_days: Optional[int] = None,
    ) -> Optional[Dict[str, Any]]:
        threshold = custom_threshold or self.settings.absence_threshold
        window_days = custom_window_days or self.settings.reporting_window_days
        now = as_of_date or datetime.utcnow()
        start_date = now - timedelta(days=window_days - 1)

        # Count distinct qualifying absences per student, EXCLUDING 'od' (approved leave) and 'present'
        student_absences: Dict[str, Dict[str, Any]] = {}
        for r in records:
            r_date = datetime.strptime(r["date"], "%Y-%m-%d") if isinstance(r["date"], str) else r["date"]
            if start_date <= r_date <= now:
                if r["status"] == "absent":  # Strict qualifying absence only
                    sid = r["student_id"]
                    if sid not in student_absences:
                        student_absences[sid] = {
                            "student_id": sid,
                            "student_name": r["student_name"],
                            "register_number": r["register_number"],
                            "sessions": set(),
                        }
                    student_absences[sid]["sessions"].add(r["session_id"])

        qualifying = []
        for sid, data in student_absences.items():
            if len(data["sessions"]) >= threshold:
                qualifying.append({
                    "student_id": sid,
                    "student_name": data["student_name"],
                    "register_number": data["register_number"],
                    "absences": len(data["sessions"]),
                })

        if not qualifying:
            return None

        start_str = start_date.strftime("%Y-%m-%d")
        end_str = now.strftime("%Y-%m-%d")
        idempotency_key = f"rep_abs_{class_id}_{start_str}_{end_str}_th{threshold}"

        dean_notified = False
        if self.settings.summary_alerts_enabled and idempotency_key not in self.idempotency_keys:
            self.idempotency_keys.add(idempotency_key)
            dean_name = self.settings.dean_placement_name
            dean_phone = self.normalize_phone(self.settings.dean_placement_phone)

            item_id = str(uuid.uuid4())
            outbox_item = OutboxItem(
                id=item_id,
                notification_type=NotificationType.REPEATED_ABSENCE_SUMMARY,
                recipient_phone=dean_phone,
                recipient_name=dean_name,
                recipient_role="Dean of Placement & Training",
                template_name=self.settings.summary_template_name,
                template_language=self.settings.summary_template_lang,
                template_parameters=[
                    dean_name,
                    class_name,
                    str(len(qualifying)),
                    start_str,
                    end_str,
                ],
                payload={"class_id": class_id, "qualifying": qualifying},
                status=DeliveryStatus.QUEUED,
                idempotency_key=idempotency_key,
            )
            self.outbox[item_id] = outbox_item

            log_item = NotificationLog(
                id=str(uuid.uuid4()),
                outbox_id=item_id,
                class_id=class_id,
                class_name=class_name,
                notification_type=NotificationType.REPEATED_ABSENCE_SUMMARY,
                recipient_phone=dean_phone,
                recipient_name=dean_name,
                recipient_role="Dean of Placement & Training",
                status=DeliveryStatus.QUEUED,
            )
            self.logs[log_item.id] = log_item
            dean_notified = True

        return {
            "class_id": class_id,
            "class_name": class_name,
            "qualifying_count": len(qualifying),
            "qualifying_students": qualifying,
            "dean_notified": dean_notified,
            "idempotency_key": idempotency_key,
        }

    async def process_outbox_queue(self) -> List[Dict[str, Any]]:
        access_token = os.getenv("WHATSAPP_ACCESS_TOKEN", "mock_token")
        phone_number_id = os.getenv("WHATSAPP_PHONE_NUMBER_ID", self.settings.phone_number_id)
        api_version = os.getenv("WHATSAPP_API_VERSION", self.settings.api_version)

        if self.mock_missing_credentials or not access_token or not phone_number_id:
            raise ValueError("Configuration error: Missing WHATSAPP_ACCESS_TOKEN or WHATSAPP_PHONE_NUMBER_ID")

        now = datetime.utcnow()
        results = []

        pending_items = [
            item for item in self.outbox.values()
            if item.status == DeliveryStatus.QUEUED or (
                item.status == DeliveryStatus.FAILED and item.retry_count < item.max_retries and item.next_retry_at <= now
            )
        ]

        for item in pending_items:
            try:
                if self.mock_fail_api:
                    raise httpx.HTTPError("Meta Cloud API 503: Service Unavailable")

                # Mock or dispatch to Meta Cloud API
                wamid = f"wamid.HBgM{int(datetime.utcnow().timestamp())}{item.id[:6]}"

                item.status = DeliveryStatus.SENT
                item.provider_message_id = wamid
                item.updated_at = datetime.utcnow()

                # Update matching log
                for log in self.logs.values():
                    if log.outbox_id == item.id:
                        log.status = DeliveryStatus.SENT
                        log.provider_message_id = wamid
                        log.sent_at = datetime.utcnow()

                results.append({"id": item.id, "status": "sent", "wamid": wamid})
            except Exception as e:
                new_retry = item.retry_count + 1
                backoff_seconds = (2 ** new_retry) * 30
                next_retry = datetime.utcnow() + timedelta(seconds=backoff_seconds)

                item.retry_count = new_retry
                item.status = DeliveryStatus.FAILED
                item.next_retry_at = next_retry
                item.error_message = str(e)
                item.updated_at = datetime.utcnow()

                for log in self.logs.values():
                    if log.outbox_id == item.id:
                        log.status = DeliveryStatus.FAILED
                        log.error_message = str(e)

                results.append({"id": item.id, "status": "failed", "retry_count": new_retry, "error": str(e)})

        return results

    async def process_webhook_status_update(
        self,
        provider_message_id: str,
        status: DeliveryStatus,
        timestamp: str,
        error_details: Optional[Dict[str, Any]] = None,
    ) -> bool:
        event_key = f"{provider_message_id}_{status.value}_{timestamp}"
        if event_key in self.processed_webhook_events:
            return False  # Deduplicated

        self.processed_webhook_events.add(event_key)

        # Update outbox
        for item in self.outbox.values():
            if item.provider_message_id == provider_message_id:
                item.status = status
                item.updated_at = datetime.utcnow()

        # Update logs
        for log in self.logs.values():
            if log.provider_message_id == provider_message_id:
                log.status = status
                if status == DeliveryStatus.DELIVERED:
                    log.delivered_at = datetime.utcnow()
                elif status == DeliveryStatus.READ:
                    log.read_at = datetime.utcnow()
                if error_details:
                    log.error_message = str(error_details)

        return True
