import os
import time
import itertools
from google import genai
from fastapi import HTTPException

class LLMManager:
    def __init__(self):
        keys_env = os.getenv("GEMINI_API_KEYS", "")
        if not keys_env:
            keys_env = os.getenv("GEMINI_API_KEY", "")
            
        self.api_keys = [k.strip() for k in keys_env.split(",") if k.strip()]
        
        if not self.api_keys:
            print("WARNING: No GEMINI API KEYS configured.")
            self.key_iterator = itertools.cycle(["dummy_key"])
        else:
            self.key_iterator = itertools.cycle(self.api_keys)

    def _get_next_client(self):
        key = next(self.key_iterator)
        return genai.Client(api_key=key)

    def generate_content_with_fallback(self, prompt: str, initial_model: str = "gemini-1.5-flash") -> str:
        if not self.api_keys:
            raise HTTPException(status_code=500, detail="GEMINI_API_KEYS not configured on the server.")

        models_to_try = [initial_model, "gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-pro"]
        
        for model in models_to_try:
            max_attempts = min(3, len(self.api_keys) * 2)
            
            for attempt in range(max_attempts):
                client = self._get_next_client()
                try:
                    response = client.models.generate_content(
                        model=model,
                        contents=prompt
                    )
                    res_text = getattr(response, "text", str(response))
                    if res_text and res_text.strip():
                        return res_text
                except Exception as e:
                    error_str = str(e)
                    print(f"[LLMManager] Model {model} attempt {attempt} failed: {error_str}")
                    time.sleep(0.5)

        raise HTTPException(status_code=500, detail="All Gemini API models and keys failed to respond.")

# Export a singleton instance to be used across the app
llm_manager = LLMManager()
