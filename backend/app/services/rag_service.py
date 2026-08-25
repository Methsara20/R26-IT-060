import os
os.environ["TOKENIZERS_PARALLELISM"] = "false"
os.environ["OMP_NUM_THREADS"] = "1"

import json
from typing import List, Dict, Any
from langchain_core.documents import Document
import requests
from app.services.llm_manager import llm_manager

class GeminiEmbeddings:
    def _embed(self, text: str) -> list[float]:
        api_key = llm_manager.api_keys[0] if getattr(llm_manager, "api_keys", None) else os.getenv("GEMINI_API_KEY", "")
        url = f"https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key={api_key}"
        resp = requests.post(url, json={"model": "models/text-embedding-004", "content": {"parts": [{"text": text}]}})
        resp.raise_for_status()
        return resp.json()["embedding"]["values"]

    def embed_documents(self, texts: list[str]) -> list[list[float]]:
        return [self._embed(t) for t in texts]

    def embed_query(self, text: str) -> list[float]:
        return self._embed(text)

from langchain_chroma import Chroma

from app.firebase_config import db
from app.constants.collections import PRODUCTS_COLLECTION

CHROMA_DB_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "chroma_db")

# We will initialize the embedding model lazily to save startup time
_embedding_model = None
_vector_store = None

def get_embedding_model():
    global _embedding_model
    if _embedding_model is None:
        print("Loading lightweight Gemini Embedding model (preventing OOM)...")
        _embedding_model = GeminiEmbeddings()
    return _embedding_model

def get_vector_store():
    global _vector_store
    if _vector_store is None:
        print(f"Connecting to ChromaDB at {CHROMA_DB_DIR}")
        _vector_store = Chroma(
            collection_name="products_gemini",
            embedding_function=get_embedding_model(),
            persist_directory=CHROMA_DB_DIR
        )
    return _vector_store

def ingest_products_to_chroma():
    """
    Pulls products from Firestore and loads them into ChromaDB.
    This should be run once, or whenever inventory significantly changes.
    """
    print("Fetching products from Firestore...")
    docs = db.collection(PRODUCTS_COLLECTION).stream()
    
    # Load reviews if they exist
    reviews_data = {}
    reviews_file = os.path.join(os.path.dirname(__file__), "..", "data", "synthetic_reviews.json")
    if os.path.exists(reviews_file):
        with open(reviews_file, 'r', encoding='utf-8') as f:
            reviews_data = json.load(f)
    
    documents: List[Document] = []
    for doc in docs:
        data = doc.to_dict()
        desc = data.get("description", "")
        pid = data.get("product_id", doc.id)
        
        if not desc:
            continue
            
        # Append reviews to description
        product_reviews = reviews_data.get(pid, [])
        if product_reviews:
            desc += "\n\nCustomer Reviews:"
            for i, rev in enumerate(product_reviews, 1):
                desc += f"\n{i}. \"{rev}\""
            
        # Store essential metadata for retrieval
        metadata = {
            "product_id": data.get("product_id", doc.id),
            "product_name": data.get("product_name", ""),
            "brand": data.get("brand", ""),
            "category": data.get("category", ""),
            "selling_price": float(data.get("selling_price", 0.0)),
            "image_key": data.get("image_key", "")
        }
        
        # Create a LangChain Document
        documents.append(Document(page_content=desc, metadata=metadata))
    
    if not documents:
        return {"status": "error", "message": "No products with descriptions found."}
        
    print(f"Adding {len(documents)} documents to ChromaDB...")
    vector_store = get_vector_store()
    
    # We clear the existing collection to avoid duplicates if re-running
    try:
        vector_store.delete_collection()
    except Exception:
        pass # Collection might not exist yet
        
    # Recreate the store after deletion
    global _vector_store
    _vector_store = None
    vector_store = get_vector_store()
    
    vector_store.add_documents(documents)
    return {"status": "success", "message": f"Successfully ingested {len(documents)} products."}

def retrieve_relevant_products(query: str, top_k: int = 3) -> List[Dict[str, Any]]:
    """
    Retrieves the most relevant products from ChromaDB based on the user's query.
    """
    vector_store = get_vector_store()
    
    try:
        if vector_store._collection.count() == 0:
            print("ChromaDB empty! Ingesting products on-the-fly...")
            ingest_products_to_chroma()
    except Exception as e:
        print(f"Error checking Chroma count: {e}")
    
    # Perform similarity search
    results = vector_store.similarity_search(query, k=top_k)
    
    formatted_results = []
    for doc in results:
        formatted_results.append({
            "description": doc.page_content,
            "product_id": doc.metadata.get("product_id"),
            "product_name": doc.metadata.get("product_name"),
            "brand": doc.metadata.get("brand"),
            "price": doc.metadata.get("selling_price")
        })
        
    return formatted_results
