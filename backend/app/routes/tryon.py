import os
import uuid
import shutil
from fastapi import APIRouter, UploadFile, File, HTTPException
from app.services.gemini_service import generate_try_on_image

router = APIRouter()

UPLOAD_DIR = "uploads"
GENERATED_DIR = "generated"

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(GENERATED_DIR, exist_ok=True)


def save_upload_file(upload_file: UploadFile, folder: str) -> str:
    file_extension = os.path.splitext(upload_file.filename)[1]

    if file_extension.lower() not in [".jpg", ".jpeg", ".png", ".webp"]:
        raise HTTPException(
            status_code=400,
            detail="Only JPG, JPEG, PNG, and WEBP images are allowed"
        )

    file_name = f"{uuid.uuid4()}{file_extension}"
    file_path = os.path.join(folder, file_name)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(upload_file.file, buffer)

    return file_path


@router.post("/generate")
async def generate_try_on(
    human_image: UploadFile = File(...),
    cloth_image: UploadFile = File(...),
):
    try:
        human_path = save_upload_file(human_image, UPLOAD_DIR)
        cloth_path = save_upload_file(cloth_image, UPLOAD_DIR)

        output_file_name = f"{uuid.uuid4()}.png"
        output_path = os.path.join(GENERATED_DIR, output_file_name)

        generate_try_on_image(
            human_image_path=human_path,
            cloth_image_path=cloth_path,
            output_path=output_path,
        )

        return {
            "message": "Try-on image generated successfully",
            "image_url": f"http://127.0.0.1:8000/generated/{output_file_name}",
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))