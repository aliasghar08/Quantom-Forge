import requests
import time

def test_reaction(r_count, p_count, name):
    req = {
        "reactant_xyz": f"{r_count}\nReactant\n" + "\n".join([f"C {i} 0 0" for i in range(r_count)]),
        "product_xyz": f"{p_count}\nProduct\n" + "\n".join([f"C {i} 0 0" for i in range(p_count)]),
        "charge": 0,
        "spin_multiplicity": 1,
        "mlip_model": "tx1-fastapi"
    }

    print(f"\n--- Testing {name} ({r_count} vs {p_count}) ---")
    r = requests.post("http://localhost:8001/reactions/submit", json=req)
    res = r.json()
    rid = res["reaction_id"]
    
    for i in range(5):
        time.sleep(1)
        status = requests.get(f"http://localhost:8001/reactions/{rid}").json()
        if status["state"] in ["completed", "error"]:
            print(f"Result: {status['state']}")
            if status['state'] == 'error':
                print(f"Error: {status.get('error')}")
            break

test_reaction(10, 10, "diels_alder (10 vs 10)")
test_reaction(15, 12, "e2_elimination (15 vs 12)")
test_reaction(29, 38, "ninhydrin_test (29 vs 38)")
