from fastapi import APIRouter, HTTPException
from firebase_admin import firestore, auth
from google.oauth2 import id_token
from google.auth.transport import requests

from app.models.profile import ProfileCreateRequest, ProfileUpdateRequest
from app.models.auth import LoginRequest, GoogleLoginRequest
from pydantic import BaseModel
from app.services.profile_service import get_size
from app.services.auth_service import hash_password, verify_password
from app.services.jwt_service import create_access_token
from app.services.body_measurement_service import predict_body_measurements
from app.firebase_config import db

router = APIRouter()


@router.post("/create")
def create_profile(data: ProfileCreateRequest):
    existing_users = db.collection("profiles").where("email", "==", data.email).stream()

    for _ in existing_users:
        raise HTTPException(status_code=400, detail="Email already registered")

    if len(data.password) < 8:
        raise HTTPException(
            status_code=400,
            detail="Password must be at least 8 characters long",
        )

    recommended_size = get_size(data.height, data.weight)

    try:
        body_measurements = predict_body_measurements(
            height=data.height,
            weight=data.weight,
            gender=data.gender,
        )
    except Exception as e:
        import traceback
        return {
            "error_caught": True,
            "message": str(e),
            "traceback": traceback.format_exc()
        }

    try:
        profile_data = {
            "email": data.email,
            "hashed_password": hash_password(data.password),
            "height": data.height,
            "weight": data.weight,
            "gender": data.gender,
            "recommended_size": recommended_size,
            "predicted_shoulder_width": body_measurements["predicted_shoulder_width"],
            "predicted_waist": body_measurements["predicted_waist"],
            "predicted_leg_length": body_measurements["predicted_leg_length"],
            "created_at": firestore.SERVER_TIMESTAMP,
            "updated_at": firestore.SERVER_TIMESTAMP,
        }
    except Exception as e:
        import traceback
        return {
            "error_caught": True,
            "message": str(e),
            "traceback": traceback.format_exc()
        }

    doc_ref = db.collection("profiles").add(profile_data)

    return {
        "message": "Profile created successfully",
        "profile_id": doc_ref[1].id,
        "email": data.email,
        "recommended_size": recommended_size,
        "body_measurements": body_measurements,
    }


@router.post("/login")
def login(data: LoginRequest):
    try:
        docs = db.collection("profiles").where("email", "==", data.email).stream()

        user_doc = None
        user_data = None

        for doc in docs:
            user_doc = doc
            user_data = doc.to_dict()
            break

        if not user_data:
            raise HTTPException(status_code=404, detail="Account not found")

        if not verify_password(data.password, user_data["hashed_password"]):
            raise HTTPException(status_code=401, detail="Invalid password")

        access_token = create_access_token({
            "sub": user_data["email"],
            "profile_id": user_doc.id,
        })

        return {
            "message": "Login successful",
            "access_token": access_token,
            "token_type": "bearer",
            "profile_id": user_doc.id,
            "email": user_data["email"],
            "recommended_size": user_data.get("recommended_size"),
            "body_measurements": {
                "predicted_shoulder_width": user_data.get("predicted_shoulder_width"),
                "predicted_waist": user_data.get("predicted_waist"),
                "predicted_leg_length": user_data.get("predicted_leg_length"),
            },
        }
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        return {
            "error_caught": True,
            "message": str(e),
            "traceback": traceback.format_exc()
        }

ALLOWED_CLIENT_IDS = {
    "171031337876-v1l7ha3nheuim0ijdh2f6paaqfkbdlie.apps.googleusercontent.com",  # Web client
    "171031337876-jfru9mjtq8ua2bqkhb7pplv00nf66b1i.apps.googleusercontent.com",  # iOS client
    "171031337876-jfru9mjtq8ua2bqkhb7pplv0nf66b1i.apps.googleusercontent.com",   # iOS client variant
    "171031337876-fjchepjlb2bafo89au0njerhr432gabh.apps.googleusercontent.com",  # Android client 1
    "171031337876-lniv56nmin67quomilspharlvq242np8.apps.googleusercontent.com",  # Android client 2
}


@router.post("/google-login")
def google_login(data: GoogleLoginRequest):
    try:
        decoded_token = id_token.verify_oauth2_token(
            data.id_token, 
            requests.Request(),
            audience=None
        )
        token_aud = decoded_token.get("aud")
        if token_aud not in ALLOWED_CLIENT_IDS:
            raise ValueError(f"Token has wrong audience {token_aud}")

        email = decoded_token.get("email")
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid Google token: {e}")

    if not email:
        raise HTTPException(status_code=400, detail="No email found in Google token")

    docs = db.collection("profiles").where("email", "==", email).stream()
    
    user_doc = None
    user_data = None
    for doc in docs:
        user_doc = doc
        user_data = doc.to_dict()
        break

    if not user_data:
        # The user successfully verified via Google, but has no sizing profile.
        # We return a flag telling the frontend to redirect to GoogleSetupPage.
        return {
            "requires_setup": True,
            "email": email,
            "message": "Account verified via Google, but body measurements are missing."
        }
    
    access_token = create_access_token({
        "sub": user_data["email"],
        "profile_id": user_doc.id,
    })

    return {
        "requires_setup": False,
        "message": "Login successful",
        "access_token": access_token,
        "token_type": "bearer",
        "profile_id": user_doc.id,
        "email": user_data["email"],
        "recommended_size": user_data.get("recommended_size"),
        "body_measurements": {
            "predicted_shoulder_width": user_data.get("predicted_shoulder_width"),
            "predicted_waist": user_data.get("predicted_waist"),
            "predicted_leg_length": user_data.get("predicted_leg_length"),
        },
    }


@router.get("/{profile_id}")
def get_profile(profile_id: str):
    doc = db.collection("profiles").document(profile_id).get()

    if not doc.exists:
        raise HTTPException(status_code=404, detail="Profile not found")

    data = doc.to_dict()

    return {
        "profile_id": doc.id,
        "email": data.get("email"),
        "height": data.get("height"),
        "weight": data.get("weight"),
        "gender": data.get("gender"),
        "recommended_size": data.get("recommended_size"),
        "body_measurements": {
            "predicted_shoulder_width": data.get("predicted_shoulder_width"),
            "predicted_waist": data.get("predicted_waist"),
            "predicted_leg_length": data.get("predicted_leg_length"),
        },
    }


@router.get("/")
def get_all_profiles():
    docs = db.collection("profiles").stream()

    profiles = []

    for doc in docs:
        data = doc.to_dict()

        profiles.append({
            "profile_id": doc.id,
            "email": data.get("email"),
            "height": data.get("height"),
            "weight": data.get("weight"),
            "gender": data.get("gender"),
            "recommended_size": data.get("recommended_size"),
            "body_measurements": {
                "predicted_shoulder_width": data.get("predicted_shoulder_width"),
                "predicted_waist": data.get("predicted_waist"),
                "predicted_leg_length": data.get("predicted_leg_length"),
            },
        })

    return {
        "count": len(profiles),
        "profiles": profiles,
    }


@router.put("/update/{profile_id}")
def update_profile(profile_id: str, data: ProfileUpdateRequest):
    doc_ref = db.collection("profiles").document(profile_id)
    doc = doc_ref.get()

    if not doc.exists:
        raise HTTPException(status_code=404, detail="Profile not found")

    old_data = doc.to_dict()
    update_data = {}

    if data.height is not None:
        update_data["height"] = data.height

    if data.weight is not None:
        update_data["weight"] = data.weight

    if data.gender is not None:
        update_data["gender"] = data.gender

    if data.password is not None and data.password.strip() != "":
        if len(data.password) < 8:
            raise HTTPException(
                status_code=400,
                detail="Password must be at least 8 characters long",
            )
        update_data["hashed_password"] = hash_password(data.password)

    if "height" in update_data or "weight" in update_data or "gender" in update_data:
        new_height = update_data.get("height", old_data.get("height"))
        new_weight = update_data.get("weight", old_data.get("weight"))
        new_gender = update_data.get("gender", old_data.get("gender")) or "Unisex"

        if new_height is not None and new_weight is not None:
            try:
                update_data["recommended_size"] = get_size(new_height, new_weight)
                
                body_measurements = predict_body_measurements(
                    height=new_height,
                    weight=new_weight,
                    gender=new_gender,
                )
                
                update_data["predicted_shoulder_width"] = body_measurements["predicted_shoulder_width"]
                update_data["predicted_waist"] = body_measurements["predicted_waist"]
                update_data["predicted_leg_length"] = body_measurements["predicted_leg_length"]
            except Exception as e:
                print(f"Warning: ML sizing failed during profile update: {e}")

    if not update_data:
        raise HTTPException(status_code=400, detail="No data provided to update")

    update_data["updated_at"] = firestore.SERVER_TIMESTAMP

    doc_ref.update(update_data)

    updated_doc = doc_ref.get()
    updated_data = updated_doc.to_dict()

    return {
        "message": "Profile updated successfully",
        "profile_id": profile_id,
        "email": updated_data.get("email"),
        "height": updated_data.get("height"),
        "weight": updated_data.get("weight"),
        "gender": updated_data.get("gender"),
        "recommended_size": updated_data.get("recommended_size"),
        "body_measurements": {
            "predicted_shoulder_width": updated_data.get("predicted_shoulder_width"),
            "predicted_waist": updated_data.get("predicted_waist"),
            "predicted_leg_length": updated_data.get("predicted_leg_length"),
        },
    }


@router.delete("/delete/{profile_id}")
def delete_profile(profile_id: str):
    doc_ref = db.collection("profiles").document(profile_id)
    doc = doc_ref.get()

    if not doc.exists:
        raise HTTPException(status_code=404, detail="Profile not found")

    doc_ref.delete()

    return {
        "message": "Profile deleted successfully",
        "profile_id": profile_id,
    }


class BrandSizingRequest(BaseModel):
    standard_size: str
    brand: str
    category: str

@router.post("/predict_brand_size")
def predict_brand_size(req: BrandSizingRequest):
    from app.services.brand_sizing_service import predict_brand_specific_size
    size = predict_brand_specific_size(req.standard_size, req.brand, req.category)
    return {"brand_specific_size": size}