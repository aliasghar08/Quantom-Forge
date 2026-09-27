import requests
import time

req = {
    "reactant_xyz": "24\nReactant\n" + "\n".join([f"C {i} 0 0" for i in range(24)]),
    "product_xyz": "21\nProduct\n" + "\n".join([f"C {i} 0 0" for i in range(21)]),
    "charge": 0,
    "spin_multiplicity": 1,
    "mlip_model": "tx1-fastapi"
}

r = requests.post("http://localhost:8001/reactions/submit", json=req)
res = r.json()
print("Submit:", res)
rid = res["reaction_id"]

for i in range(5):
    time.sleep(1)
    status = requests.get(f"http://localhost:8001/reactions/{rid}").json()
    print("Status:", status)
    if status["state"] in ["completed", "error"]:
        break
