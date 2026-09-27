import os
import subprocess

env_path = "/Users/thedas/Desktop/Projects/R26-IT-060/backend/.env"
settings = []
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
