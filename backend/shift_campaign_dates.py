import os
import pandas as pd
import io
import uuid
import pymongo
import certifi
from datetime import datetime

mongo_uri = os.environ.get("MONGODB_URI", "mongodb+srv://finalyear693_db_user:pHUqXaI43L1lgyNv@cluster0.es2z4ma.mongodb.net/")
client = pymongo.MongoClient(mongo_uri, tlsCAFile=certifi.where())
db = client.get_database("smart_retail_db")

def shift_campaign_dates():
    # Load the latest upload history for campaigns
    history_docs = list(db.skyhigh_upload_history.find({"file_type": "campaigns"}).sort("upload_time", -1).limit(1))
    if not history_docs:
        print("No campaigns found.")
        return
        
    upload_id = history_docs[0]["upload_id"]
    total_chunks = history_docs[0]["total_chunks"]
    
    # Reassemble CSV
    chunk_texts = [None] * total_chunks
    for chunk in db.skyhigh_csv_chunks.find({"upload_id": upload_id}):
        chunk_texts[chunk["chunk_index"]] = chunk["content"]
        
    raw_csv = "".join(chunk_texts)
    df = pd.read_csv(io.StringIO(raw_csv))
    
    if "sent_date" not in df.columns:
        print("No sent_date in campaigns.")
        return
        
    # Convert and shift dates forward by 1 year to reach 2026
    df["sent_date"] = pd.to_datetime(df["sent_date"])
    df["sent_date"] = df["sent_date"] + pd.DateOffset(years=1)
    # Format back to string
    df["sent_date"] = df["sent_date"].dt.strftime("%Y-%m-%d")
    
    # Generate new CSV string
    new_csv = df.to_csv(index=False)
    
    # Create new upload
    new_upload_id = f"UPL-{uuid.uuid4().hex[:12].upper()}"
    CHUNK_SIZE = 100000
    chunks = [new_csv[i:i+CHUNK_SIZE] for i in range(0, len(new_csv), CHUNK_SIZE)]
    
    # Insert new chunks
    chunk_docs = []
    for i, content in enumerate(chunks):
        chunk_docs.append({
            "upload_id": new_upload_id,
            "chunk_index": i,
            "content": content
        })
    db.skyhigh_csv_chunks.insert_many(chunk_docs)
    
    # Insert new history
    db.skyhigh_upload_history.insert_one({
        "upload_id": new_upload_id,
        "file_type": "campaigns",
        "total_chunks": len(chunks),
        "upload_time": datetime.utcnow().isoformat(),
        "filename": "campaigns_shifted.csv"
    })
    
    print(f"Shifted campaign dates forward by 1 year. New max date is {df['sent_date'].max()}")

if __name__ == "__main__":
    shift_campaign_dates()
