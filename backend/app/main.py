import os
from typing import Optional, List, Dict, Any
from fastapi import FastAPI, Request, HTTPException, Query, Header, status
from fastapi.responses import PlainTextResponse, JSONResponse
from backend.app.models import (
    WhatsAppSettings,
    AttendanceEventPayload,
    DeliveryStatus,
)
from backend.app.services.whatsapp_service import WhatsAppService

app = FastAPI(
    title="College Attendance Monitoring System - Meta WhatsApp Business Platform API",
    version="1.0.0",
)

whatsapp_service = WhatsAppService()

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "whatsapp-attendance-notification"}

# 1. Meta Webhook Verification Endpoint (GET)
@app.get("/webhook")
def meta_webhook_verification(
    hub_mode: Optional[str] = Query(None, alias="hub.mode"),
    hub_verify_token: Optional[str] = Query(None, alias="hub.verify_token"),
    hub_challenge: Optional[str] = Query(None, alias="hub.challenge"),
):
    expected_token = os.getenv("WHATSAPP_WEBHOOK_VERIFY_TOKEN", "attendance_whatsapp_secret_token")
    if hub_mode == "subscribe" and hub_verify_token == expected_token:
        return PlainTextResponse(hub_challenge or "")
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Verification token mismatch")

# 2. Meta Webhook Status Update Event (POST)
@app.post("/webhook")
async def meta_webhook_handler(
    request: Request,
    x_hub_signature_256: Optional[str] = Header(None, alias="x-hub-signature-256"),
):
    raw_body = await request.body()
    app_secret = os.getenv("WHATSAPP_APP_SECRET")

    # Verify HMAC-SHA256 signature if secret is present
    if app_secret:
        if not whatsapp_service.verify_webhook_signature(raw_body, x_hub_signature_256, app_secret):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid webhook signature")

    payload = await request.json()
    entries = payload.get("entry", [])

    processed = 0
    for entry in entries:
        for change in entry.get("changes", []):
            for status_obj in change.get("value", {}).get("statuses", []):
                wamid = status_obj.get("id")
                raw_status = status_obj.get("status")
                timestamp = str(status_obj.get("timestamp", ""))
                errors = status_obj.get("errors")

                status_map = {
                    "sent": DeliveryStatus.SENT,
                    "delivered": DeliveryStatus.DELIVERED,
                    "read": DeliveryStatus.READ,
                    "failed": DeliveryStatus.FAILED,
                }
                mapped = status_map.get(raw_status, DeliveryStatus.PROCESSING)

                did_process = await whatsapp_service.process_webhook_status_update(
                    provider_message_id=wamid,
                    status=mapped,
                    timestamp=timestamp,
                    error_details=errors,
                )
                if did_process:
                    processed += 1

    return {"status": "success", "processed_events": processed}

# 3. Attendance Event Trigger (Called after attendance record is saved)
@app.post("/api/attendance/event")
async def attendance_event_handler(event: AttendanceEventPayload):
    try:
        outbox_item = await whatsapp_service.handle_attendance_event(event)
        # Asynchronously run outbox processor (attendance save does not block or fail on WhatsApp errors)
        try:
            await whatsapp_service.process_outbox_queue()
        except Exception:
            pass

        return {
            "status": "queued" if outbox_item else "ignored",
            "outbox_id": outbox_item.id if outbox_item else None,
        }
    except Exception as e:
        # Attendance transaction must not fail
        return {"status": "error_handled", "error": str(e)}

# 4. Repeated-Absence Summary Trigger
@app.post("/api/attendance/summary/evaluate")
async def evaluate_repeated_absences_handler(
    payload: Dict[str, Any],
):
    class_id = payload.get("class_id", "")
    class_name = payload.get("class_name", "")
    records = payload.get("records", [])
    threshold = payload.get("threshold")
    window_days = payload.get("window_days")

    result = await whatsapp_service.evaluate_repeated_absences(
        class_id=class_id,
        class_name=class_name,
        records=records,
        custom_threshold=threshold,
        custom_window_days=window_days,
    )
    return {"status": "success", "result": result}

# 5. Outbox Worker Trigger
@app.post("/api/outbox/process")
async def process_outbox_handler():
    results = await whatsapp_service.process_outbox_queue()
    return {"status": "success", "processed": len(results), "details": results}

# 6. Admin Notification History & Delivery Status
@app.get("/api/notifications/history")
def get_notification_history():
    logs = list(whatsapp_service.logs.values())
    logs.sort(key=lambda x: x.created_at, reverse=True)
    return [l.model_dump() for l in logs]

# 7. WhatsApp Configuration Settings
@app.get("/api/notifications/settings")
def get_settings():
    return whatsapp_service.settings.model_dump()

@app.put("/api/notifications/settings")
def update_settings(settings: WhatsAppSettings):
    whatsapp_service.settings = settings
    return {"status": "success", "settings": whatsapp_service.settings.model_dump()}
