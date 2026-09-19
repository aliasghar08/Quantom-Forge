import os
import time
import threading
import firebase_admin
from firebase_admin import credentials, firestore

from .dmf_worker import run_dmf, compute_imaginary_frequencies

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


def _read_xyz(doc: dict, key_inline: str, key: str) -> str:
    """Prefer the inline XYZ (templates); fall back to the stored field."""
    return doc.get(key_inline) or doc.get(key) or ""


def process_reaction(doc_snapshot):
    reaction_id = doc_snapshot.id
    data = doc_snapshot.to_dict() or {}
    doc_ref = db.collection('queues/ts_searches').document(reaction_id)

    print(f"Processing reaction {reaction_id} via DMF/UMA...")
    doc_ref.update({
        'state': 'optimizing',
        'message': 'Interpolating initial path (FB-ENM)…',
        'progress': 0.05,
    })

    reactant_xyz = _read_xyz(data, 'reactant_xyz_inline', 'reactant_xyz')
    product_xyz = _read_xyz(data, 'product_xyz_inline', 'product_xyz')

    try:
        result = run_dmf(
            reactant_xyz=reactant_xyz,
            product_xyz=product_xyz,
            charge=int(data.get('charge') or 0),
            spin_multiplicity=int(data.get('spin_multiplicity') or data.get('mult') or 1),
            nmove=int(data.get('nmove') or 20),
            update_teval=bool(data.get('update_teval') or False),
            convergence=str(data.get('convergence') or 'tight').lower(),
            mlip_model=str(data.get('mlip_model') or 'UMA-SM'),
            hf_token=data.get('hf_token'),
        )

        modes = compute_imaginary_frequencies(
            result['trajectory_frames'][result['max_energy_index']],
            charge=int(data.get('charge') or 0),
            spin_multiplicity=int(data.get('spin_multiplicity') or data.get('mult') or 1),
            mlip_model=str(data.get('mlip_model') or 'UMA-SM'),
            hf_token=data.get('hf_token'),
        )

        doc_ref.update({
            'state': 'completed',
            'progress': 1.0,
            'message': 'Transition state isolated via DMF/UMA.',
            'energy_profile': result['energy_profile'],       # ΔE vs reactant, kcal/mol
            'energy_profile_ev': result['energy_profile_ev'],
            'trajectory_frames': result['trajectory_frames'],
            'max_energy_index': result['max_energy_index'],
            'vibrational_modes': [
                {'frequency': m['frequency'], 'vectors': m['vectors']} for m in modes
            ],
        })
        print(f"Reaction {reaction_id} completed.")
    except Exception as e:
        print(f"Reaction {reaction_id} failed: {e}")
        doc_ref.update({
            'state': 'error',
            'progress': 1.0,
            'message': f'DMF/UMA optimisation failed: {e}',
        })


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

