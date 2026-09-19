import os
import glob

replacements = {
    'package:quantum_forge/features/reaction_runner/providers': 'package:quantum_forge/state',
    'package:quantum_forge/features/reaction_runner/presentation/viewmodels/dashboard_viewmodel.dart': 'package:quantum_forge/state/dashboard_viewmodel.dart'
}

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = content
    for old, new in replacements.items():
        new_content = new_content.replace(old, new)
        
    if content != new_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
            
for root, _, files in os.walk('test'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
