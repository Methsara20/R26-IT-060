import requests

routes = [
    "/", "/dropdown-data", "/product-store-info", "/products", 
    "/profile/", "/profile/create", "/profile/login", 
    "/test-crash", "/test-ml-crash", "/zone/all"
]

base_url = "https://r26-it-060.onrender.com"

print("| Endpoint | Status Code | Result |")
print("|---|---|---|")

for route in routes:
    url = base_url + route
    try:
        res = requests.get(url, timeout=5)
        if res.status_code == 405:
            res = requests.post(url, json={}, timeout=5)
        
        status = res.status_code
        if status == 500:
            result = "❌ Crash"
        elif status == 200:
            result = "✅ OK"
        elif status == 401:
            result = "✅ OK (Unauthorized)"
        elif status == 405:
            result = "✅ OK (Method Not Allowed)"
        elif status == 422:
            result = "✅ OK (Validation Error)"
        elif status == 404:
            result = "✅ OK (Not Found)"
        else:
            result = f"✅ OK ({status})"
            
        print(f"| `{route}` | {status} | {result} |")
    except Exception as e:
        print(f"| `{route}` | ERROR | ❌ Timeout/Fail |")

