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
        api_keys = getattr(llm_manager, "api_keys", []) or [os.getenv("GEMINI_API_KEY", "")]
        for key in api_keys:
            if not key or key == "dummy_key":
                continue
            try:
                url = f"https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key={key}"
                resp = requests.post(
                    url, 
                    json={"model": "models/text-embedding-004", "content": {"parts": [{"text": text}]}},
                    timeout=10
                )
                if resp.status_code == 200:
                    return resp.json()["embedding"]["values"]
            except Exception as e:
                print(f"[GeminiEmbeddings] Embedding request failed with key: {e}")
                continue

        raise RuntimeError("Embedding service failed on all configured Gemini API keys.")

    def embed_documents(self, texts: list[str]) -> list[list[float]]:
        return [self._embed(t) for t in texts]

    def embed_query(self, text: str) -> list[float]:
        return self._embed(text)

from langchain_chroma import Chroma
from app.firebase_config import db
from app.constants.collections import PRODUCTS_COLLECTION

CHROMA_DB_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "chroma_db")

_embedding_model = None
_vector_store = None

def get_embedding_model():
    global _embedding_model
    if _embedding_model is None:
        print("Loading lightweight Gemini Embedding model...")
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
    Pulls products from memory cache and loads them into ChromaDB.
    """
    print("Fetching products from cache for ChromaDB ingestion...")
    from app.services.product_service import get_all_products
    products = get_all_products()
    
    # Load reviews if they exist
    reviews_data = {}
    reviews_file = os.path.join(os.path.dirname(__file__), "..", "data", "synthetic_reviews.json")
    if os.path.exists(reviews_file):
        with open(reviews_file, 'r', encoding='utf-8') as f:
            reviews_data = json.load(f)
    
    documents: List[Document] = []
    for data in products:
        desc = data.get("description", "") or data.get("product_name", "")
        pid = data.get("product_id") or data.get("id") or "prod"
        
        if not desc:
            continue
            
        # Append reviews to description
        product_reviews = reviews_data.get(pid, [])
        if product_reviews:
            desc += "\n\nCustomer Reviews:"
            for i, rev in enumerate(product_reviews, 1):
                desc += f"\n{i}. \"{rev}\""
            
        # Store essential metadata for retrieval
        price_val = data.get("price_lkr") or data.get("selling_price") or data.get("price") or 0.0
        try:
            float_price = float(price_val)
        except (ValueError, TypeError):
            float_price = 0.0

        metadata = {
            "product_id": pid,
            "product_name": data.get("product_name") or data.get("name") or "Item",
            "brand": data.get("brand") or "Brand",
            "category": data.get("category") or "General",
            "selling_price": float_price,
            "image_key": data.get("image_key", "")
        }
        
        # Create a LangChain Document
        documents.append(Document(page_content=desc, metadata=metadata))
    
    if not documents:
        return {"status": "error", "message": "No products with descriptions found."}
        
    print(f"Adding {len(documents)} documents to ChromaDB...")
    
    try:
        vector_store = get_vector_store()
        try:
            vector_store.delete_collection()
        except Exception:
            pass
            
        global _vector_store
        _vector_store = None
        vector_store = get_vector_store()
        
        vector_store.add_documents(documents)
        return {"status": "success", "message": f"Successfully ingested {len(documents)} products."}
    except Exception as e:
        print(f"Error during ChromaDB ingestion: {e}")
        return {"status": "error", "message": str(e)}

def retrieve_relevant_products(query: str, top_k: int = 3) -> List[Dict[str, Any]]:
    """
    Retrieves the most relevant products from ChromaDB based on the user's query.
    Falls back to product catalog if vector search fails.
    """
    try:
        vector_store = get_vector_store()
        
        if vector_store._collection.count() == 0:
            print("ChromaDB empty! Ingesting products on-the-fly...")
            ingest_products_to_chroma()
            
        # Perform similarity search
        results = vector_store.similarity_search(query, k=top_k)
        
        formatted_results = []
        for doc in results:
            formatted_results.append({
                "description": doc.page_content,
                "product_id": doc.metadata.get("product_id") or "prod",
                "product_name": doc.metadata.get("product_name") or "Fashion Item",
                "brand": doc.metadata.get("brand") or "Brand",
                "price": float(doc.metadata.get("selling_price") or 0.0)
            })
            
        if formatted_results:
            return formatted_results
    except Exception as e:
        print(f"[RAG] Vector search error (falling back to product catalog): {e}")

    # Fallback to direct product catalog
    from app.services.product_service import get_all_products
    products = get_all_products()
    
    formatted_results = []
    for p in products[:top_k]:
        price_val = p.get("price_lkr") or p.get("selling_price") or p.get("price") or 0.0
        try:
            float_price = float(price_val)
        except (ValueError, TypeError):
            float_price = 0.0

        formatted_results.append({
            "description": p.get("description") or p.get("product_name") or "Fashion product",
            "product_id": p.get("product_id") or p.get("id") or "prod",
            "product_name": p.get("product_name") or p.get("name") or "Fashion Item",
            "brand": p.get("brand") or "Brand",
            "price": float_price
        })
    return formatted_results
