import os
import subprocess

env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
settings = ["WEBSITES_PORT=80"]
with open(env_path, "r") as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("=", 1)
        if len(parts) == 2:
            key = parts[0].strip()
            val = parts[1].strip()
            if val.startswith('"') and val.endswith('"'):
                val = val[1:-1]
            if val.startswith("'") and val.endswith("'"):
                val = val[1:-1]
            if key == "MARKETING_INVENTORY_PLANNING_BASE_URL" and "8000" in val:
                val = val.replace("8000", "80")
            settings.append(f"{key}={val}")

cmd = ["az", "webapp", "config", "appsettings", "set", "-g", "SmartOmniRetail-RG", "-n", "smartomniretailr26-api", "--settings"] + settings
print("Setting Azure AppSettings...")
res = subprocess.run(cmd, capture_output=True, text=True)
if res.returncode == 0:
    print("Successfully set secrets in Azure!")
    subprocess.run(["az", "webapp", "restart", "-g", "SmartOmniRetail-RG", "-n", "smartomniretailr26-api"])
    print("Web App restarted successfully!")
else:
    print("Failed to set secrets:", res.stderr)
