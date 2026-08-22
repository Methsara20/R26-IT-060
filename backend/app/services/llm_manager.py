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

    def generate_content_with_fallback(self, prompt: str, model: str = "gemini-flash-latest") -> str:
        if not self.api_keys:
            raise HTTPException(status_code=500, detail="GEMINI_API_KEYS not configured on the server.")

        # Try up to twice the number of keys we have available
        max_attempts = len(self.api_keys) * 2
        
        for attempt in range(max_attempts):
            client = self._get_next_client()
            try:
                response = client.models.generate_content(
                    model=model,
                    contents=prompt
                )
                return getattr(response, "text", str(response))
            except Exception as e:
                error_str = str(e)
                # If we hit a rate limit or overloaded server, try the next key
                if "429" in error_str or "503" in error_str or "UNAVAILABLE" in error_str or "RESOURCE_EXHAUSTED" in error_str:
                    if attempt < max_attempts - 1:
                        time.sleep(1) # Brief pause before swapping to next key
                        continue
                else:
                    # If it's a different error (e.g. 400 Bad Request), don't retry, just raise
                    raise HTTPException(status_code=500, detail=f"LLM generation failed: {error_str}")

        # If we exhausted all attempts across all keys, fallback to a different model just in case it's a model-specific outage
        try:
            client = self._get_next_client()
            fallback_resp = client.models.generate_content(
                model="gemini-2.0-flash",
                contents=prompt
            )
            return getattr(fallback_resp, "text", str(fallback_resp))
        except Exception:
            return "AI service is temporarily busy. Please try again."

# Export a singleton instance to be used across the app
llm_manager = LLMManager()
