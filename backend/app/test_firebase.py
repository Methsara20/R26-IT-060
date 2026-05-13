from app.firebase_config import db

def test():
    doc_ref = db.collection("test").add({
        "message": "Firebase connected successfully"
    })
    print("Data written to Firebase!")

if __name__ == "__main__":
    test()