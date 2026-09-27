import json
import requests
import uuid
import sys
from concurrent.futures import ThreadPoolExecutor

API_KEY = "AIzaSyBoYwiQQUo4ToipCD77st_PsTZbYwlfgcY"
PROJECT_ID = "quantom-forge"

# 1. Sign in with email/password
def sign_in():
    email = f"seeder_{uuid.uuid4().hex[:8]}@example.com"
    password = "SuperSecretPassword123!"
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}"
    resp = requests.post(url, json={"email": email, "password": password, "returnSecureToken": True})
    if resp.status_code != 200:
        print("Auth failed:", resp.text)
        sys.exit(1)
    return resp.json()["idToken"]

# 2. Convert standard JSON dict to Firestore Document format
def to_firestore_value(val):
    if isinstance(val, str): return {"stringValue": val}
    if isinstance(val, bool): return {"booleanValue": val}
    if isinstance(val, int): return {"integerValue": str(val)}
    if isinstance(val, float): return {"doubleValue": val}
    if isinstance(val, list): return {"arrayValue": {"values": [to_firestore_value(v) for v in val]}}
    if isinstance(val, dict):
        return {"mapValue": {"fields": {k: to_firestore_value(v) for k, v in val.items()}}}
    return {"nullValue": None}

def build_write(reaction, doc_id):
    return {
        "update": {
            "name": f"projects/{PROJECT_ID}/databases/(default)/documents/library/{doc_id}",
            "fields": {k: to_firestore_value(v) for k, v in reaction.items()}
        }
    }

def get_sync_state(token):
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/library_metadata/sync_state"
    headers = {"Authorization": f"Bearer {token}"}
    resp = requests.get(url, headers=headers)
    if resp.status_code == 200:
        data = resp.json()
        if "fields" in data and "current_index" in data["fields"]:
            return int(data["fields"]["current_index"].get("integerValue", 0))
    return 0

def update_sync_state(token, new_index):
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/library_metadata/sync_state"
    headers = {"Authorization": f"Bearer {token}"}
    payload = {
        "fields": {
            "current_index": {"integerValue": str(new_index)}
        }
    }
    requests.patch(url, json=payload, headers=headers)

def main():
    print("Authenticating...")
    token = sign_in()
    
    current_index = get_sync_state(token)
    print(f"Current sync index: {current_index}")
    
    TARGET = 100000
    if current_index >= TARGET:
        print("Target of 100,000 reactions already reached!")
        return

    print("Loading base reactions...")
    try:
        with open("quantum_forge/assets/massive_reactions.json", "r", encoding="utf-8") as f:
            base_reactions = json.load(f)
    except Exception as e:
        print("Failed to load base reactions:", e)
        sys.exit(1)
        
    # Max safe writes per day for free tier is ~15,000 (leaves 5,000 for users)
    # 15,000 writes / 500 per batch = 30 batches.
    BATCH_LIMIT = 14000
    
    end_index = min(current_index + BATCH_LIMIT, TARGET)
    count = end_index - current_index
    print(f"Generating {count} reactions (from {current_index} to {end_index})...")
    reactions = []
    
    for i in range(current_index, end_index):
        base = base_reactions[i % len(base_reactions)]
        new_rxn = dict(base)
        new_rxn["id"] = f"rxn_{i:06d}_{uuid.uuid4().hex[:6]}"
        new_rxn["name"] = f"{base['name']} - Var {i}"
        new_rxn["referenceEa"] = float(base.get("referenceEa", 15.0)) + (i % 10) * 0.1
        reactions.append(new_rxn)
        
    print("Committing to Firestore in batches of 500...")
    batches = []
    current_batch = []
    for r in reactions:
        current_batch.append(build_write(r, r["id"]))
        if len(current_batch) == 500:
            batches.append(current_batch)
            current_batch = []
    if current_batch:
        batches.append(current_batch)
        
    def send_batch(batch):
        url = f"https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents:commit"
        headers = {"Authorization": f"Bearer {token}"}
        resp = requests.post(url, json={"writes": batch}, headers=headers)
        if resp.status_code != 200:
            return False, resp.text
        return True, ""

    success_count = 0
    with ThreadPoolExecutor(max_workers=5) as executor:
        results = executor.map(send_batch, batches)
        for i, (ok, err) in enumerate(results):
            if ok:
                success_count += len(batches[i])
            else:
                print(f"Batch {i} failed: {err}")
                break # Stop on first failure (e.g., Quota Exceeded)
            if (i+1) % 5 == 0:
                print(f"Progress: {success_count} / {count} uploaded.")
                
    new_index = current_index + success_count
    print(f"Updating sync state to {new_index}...")
    update_sync_state(token, new_index)
    
    print(f"Done! Successfully pushed {success_count} reactions to Firestore today.")

if __name__ == "__main__":
    main()
