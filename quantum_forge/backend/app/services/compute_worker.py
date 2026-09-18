import os
import time
import threading
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase Admin
# NOTE: In production, supply a service account JSON path or use Application Default Credentials
if not firebase_admin._apps:
    try:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
    except Exception as e:
        print(f"Using default init: {e}")
        firebase_admin.initialize_app()

db = firestore.client()

def process_reaction(doc_snapshot):
    reaction_id = doc_snapshot.id
    doc_ref = db.collection('queues/ts_searches').document(reaction_id)
    
    print(f"Processing reaction {reaction_id}...")
    doc_ref.update({
        'state': 'optimizing',
        'message': 'Starting optimization via Modal Labs...',
        'progress': 0.1
    })

    # Simulate Optimization Loop (would be Papermill + Modal execution)
    for i in range(1, 11):
        time.sleep(1)
        doc_ref.update({
            'progress': i / 10.0,
            'message': f"Optimizing iteration {i}/10. Evaluating PyDMF forces..."
        })
        
    # Mock data for H2O -> OH + H
    mock_energy = [0.0, 15.2, 35.5, 62.1, 80.4, 78.1, 55.0, 32.2, 10.5, -5.2]
    mock_frames = []
    for index in range(10):
        oX, oY, oZ = 0.0, 0.0, 0.0
        h1X, h1Y, h1Z = 0.0, 0.76, 0.58
        stretch = (index / 9.0) * 2.0
        h2X, h2Y, h2Z = 0.0, -0.76 - stretch, 0.58 + stretch
        
        frame = f"3\nFrame {index}\nO {oX} {oY} {oZ}\nH {h1X} {h1Y} {h1Z}\nH {h2X} {h2Y} {h2Z}"
        mock_frames.append(frame)
        
    # Mock vibrational modes (Top 3 imaginary modes for TS)
    mock_vibrations = [
        {
            "frequency": -452.1,
            "vectors": [
                [0.0, 0.0, 0.0],         # O
                [0.0, -0.4, 0.5],        # H1
                [0.0, -0.6, -0.3]        # H2
            ]
        },
        {
            "frequency": -120.5,
            "vectors": [
                [0.0, 0.0, 0.0],
                [0.2, 0.1, 0.0],
                [-0.2, -0.1, 0.0]
            ]
        },
        {
            "frequency": -50.8,
            "vectors": [
                [0.0, 0.1, -0.1],
                [0.0, -0.1, 0.2],
                [0.0, 0.2, -0.1]
            ]
        }
    ]

    doc_ref.update({
        'state': 'completed',
        'progress': 1.0,
        'message': "Transition state successfully isolated.",
        'energy_profile': mock_energy,
        'trajectory_frames': mock_frames,
        'vibrational_modes': mock_vibrations
    })
    print(f"Reaction {reaction_id} completed.")

def on_snapshot(col_snapshot, changes, read_time):
    for change in changes:
        if change.type.name == 'ADDED' or change.type.name == 'MODIFIED':
            doc = change.document
            data = doc.to_dict()
            if data and data.get('state') == 'pending':
                # Process in a background thread so we don't block the listener
                threading.Thread(target=process_reaction, args=(doc,)).start()

def start_worker():
    print("Starting compute worker listener...")
    col_query = db.collection('queues/ts_searches').where('state', '==', 'pending')
    
    # Watch the query
    query_watch = col_query.on_snapshot(on_snapshot)
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Stopping worker...")

if __name__ == "__main__":
    start_worker()
