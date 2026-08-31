import os
import firebase_admin
from firebase_admin import credentials, firestore

FIREBASE_KEY_PATH = "firebase_key.json"
SHARED_FIREBASE_KEY_PATH = "shared-firebase-key.json"
SHARED_APP_NAME = "shared_inventory_project"

_firebase_app = None
_db = None

_shared_firebase_app = None
_shared_db = None


def init_firebase():
    global _firebase_app, _db
    if _firebase_app is not None:
        return True

    # We assume firebase-key.json is in the backend/ directory.
    # If the app is run from backend/ as `uvicorn app.main:app`, the cwd is backend/.
    key_path = os.path.join(os.getcwd(), FIREBASE_KEY_PATH)

    if not os.path.exists(key_path):
        return False
    try:
        cred = credentials.Certificate(key_path)
        _firebase_app = firebase_admin.initialize_app(cred)
        _db = firestore.client()
        return True
    except ValueError:
        _firebase_app = firebase_admin.get_app()
        _db = firestore.client()
        return True
    except Exception as e:
        print(f"Firebase connection failed: {e}")
        return False


def get_db():
    if not init_firebase():
        return None
    return _db


def init_shared_firebase():
    """
    Sets up a SEPARATE Firebase connection to the shared team project
    (finalyear-6bafb) — used ONLY for reading inventory data
    (marketing_opportunities collection). Kept completely independent from
    the main get_db() connection, which points at this project's own
    private Firebase project.
    """
    global _shared_firebase_app, _shared_db
    if _shared_firebase_app is not None:
        return True

    key_path = os.path.join(os.getcwd(), SHARED_FIREBASE_KEY_PATH)

    if not os.path.exists(key_path):
        return False
    try:
        cred = credentials.Certificate(key_path)
        _shared_firebase_app = firebase_admin.initialize_app(cred, name=SHARED_APP_NAME)
        _shared_db = firestore.client(app=_shared_firebase_app)
        return True
    except ValueError:
        _shared_firebase_app = firebase_admin.get_app(name=SHARED_APP_NAME)
        _shared_db = firestore.client(app=_shared_firebase_app)
        return True
    except Exception as e:
        print(f"Shared Firebase connection failed: {e}")
        return False


def get_shared_db():
    if not init_shared_firebase():
        return None
    return _shared_db