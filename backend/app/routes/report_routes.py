from fastapi import APIRouter, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel
from app.services import report_service

router = APIRouter(prefix="/reports", tags=["Reports"])


class ReportRequest(BaseModel):
    period_type: str  # "yearly" | "monthly" | "quarterly"
    periods: list[str]  # e.g. ["2025", "2026"] or ["2025-01", "2025-02"] or ["2025Q1", "2025Q2"]


@router.post("/generate")
def generate_report(req: ReportRequest):
    if req.period_type not in ("yearly", "monthly", "quarterly"):
        raise HTTPException(status_code=400, detail="period_type must be 'yearly', 'monthly', or 'quarterly'.")
    if not req.periods:
        raise HTTPException(status_code=400, detail="At least one period must be selected.")

    try:
        pdf_bytes = report_service.generate_report_pdf(req.period_type, req.periods)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Report generation failed: {str(e)}")

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": "attachment; filename=skyhigh_marketing_report.pdf"},
    )