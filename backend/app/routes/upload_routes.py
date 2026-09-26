from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from fastapi.responses import Response
import pandas as pd
import io
from app.services import cleaner_service, firebase_service

router = APIRouter(tags=["Uploads"])

ALLOWED_FILE_TYPES = ["campaigns", "customers", "transactions"]


@router.get("/upload-history")
def upload_history(limit: int = 20):
    return firebase_service.get_upload_history(limit=limit)


@router.post("/upload")
async def upload_csv(file: UploadFile = File(...), file_type: str = Form(...)):
    if file_type not in ALLOWED_FILE_TYPES:
        raise HTTPException(status_code=400, detail=f"file_type must be one of {ALLOWED_FILE_TYPES}")

    try:
        contents = await file.read()
        df_raw = None
        last_error = None
        for encoding in ["utf-8", "utf-8-sig", "cp1252", "latin1"]:
            try:
                df_raw = pd.read_csv(io.BytesIO(contents), encoding=encoding)
                break
            except (UnicodeDecodeError, UnicodeError) as e:
                last_error = e
                continue
        if df_raw is None:
            raise last_error
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Could not read CSV: {e}")

    df_clean, report = cleaner_service.clean_csv(df_raw, file_type)

    success, error = firebase_service.save_csv_to_firebase(df_clean, file_type)
    if not success:
        raise HTTPException(status_code=500, detail=f"Cleaned successfully but could not save to Firebase: {error}")

    columns_detected = list(df_clean.columns)
    preview = df_clean.head(3).to_dict(orient="records")

    return {
        "file_type": file_type,
        "row_count": len(df_clean),
        "cleaning_report": report,
        "columns_detected": columns_detected,
        "preview": preview,
        "saved_to_firebase": True,
    }


@router.get("/upload/{upload_id}/download")
def download_upload(upload_id: str):
    """Downloads a specific past upload as a CSV file, exactly as it was stored."""
    file_type, csv_text = firebase_service.get_csv_download(upload_id)
    if csv_text is None:
        raise HTTPException(status_code=404, detail="Upload not found.")

    filename = f"{file_type}_{upload_id}.csv"
    return Response(
        content=csv_text,
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


@router.delete("/upload/{upload_id}")
def delete_upload(upload_id: str):
    """Deletes a specific past upload (history record + all its data chunks)."""
    success = firebase_service.delete_upload(upload_id)
    if not success:
        raise HTTPException(status_code=500, detail="Could not delete this upload.")
    return {"deleted": True}