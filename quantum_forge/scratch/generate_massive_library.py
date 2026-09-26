import json
import os
import itertools
from rdkit import Chem
from rdkit.Chem import AllChem
from rdkit.Chem import rdChemReactions

acids = [
    ("Formic acid", "O=CO"),
    ("Acetic acid", "CC(=O)O"),
    ("Propionic acid", "CCC(=O)O"),
    ("Butyric acid", "CCCC(=O)O"),
    ("Valeric acid", "CCCCC(=O)O"),
    ("Hexanoic acid", "CCCCCC(=O)O"),
    ("Benzoic acid", "O=C(O)c1ccccc1"),
    ("Phenylacetic acid", "O=C(O)Cc1ccccc1"),
    ("Toluic acid", "Cc1ccc(C(=O)O)cc1"),
    ("Salicylic acid", "O=C(O)c1ccccc1O"),
]

alcohols = [
    ("Methanol", "CO"),
    ("Ethanol", "CCO"),
    ("Propanol", "CCCO"),
    ("Isopropanol", "CC(C)O"),
    ("Butanol", "CCCCO"),
    ("Isobutanol", "CC(C)CO"),
    ("Cyclohexanol", "OC1CCCCC1"),
    ("Phenol", "Oc1ccccc1"),
    ("Benzyl alcohol", "OCc1ccccc1"),
]

amines = [
    ("Methylamine", "CN"),
    ("Ethylamine", "CCN"),
    ("Propylamine", "CCCN"),
    ("Butylamine", "CCCCN"),
    ("Aniline", "Nc1ccccc1"),
    ("Benzylamine", "NCc1ccccc1"),
    ("Cyclohexylamine", "NC1CCCCC1"),
]

def generate_3d_xyz(smiles, title):
    try:
        mol = Chem.MolFromSmiles(smiles)
        if mol is None: return None
        mol = Chem.AddHs(mol)
        res = AllChem.EmbedMolecule(mol, randomSeed=42)
        if res == -1: return None
        AllChem.MMFFOptimizeMolecule(mol)
        
        conf = mol.GetConformer()
        num_atoms = mol.GetNumAtoms()
        lines = [str(num_atoms), title]
        for i in range(num_atoms):
            atom = mol.GetAtomWithIdx(i)
            pos = conf.GetAtomPosition(i)
            lines.append(f"{atom.GetSymbol()} {pos.x:.4f} {pos.y:.4f} {pos.z:.4f}")
        return "\n".join(lines)
    except Exception as e:
        return None

def combine_xyzs(xyzs, label):
    total_atoms = 0
    lines = []
    for xyz in xyzs:
        parts = xyz.strip().split('\n')
        total_atoms += int(parts[0])
        lines.extend(parts[2:])
    return f"{total_atoms}\n{label}\n" + "\n".join(lines) + "\n"

def build_reactions():
    reactions = []
    
    esterification_rxn = rdChemReactions.ReactionFromSmarts("[C:1](=[O:2])-[OH:3].[OH:4]-[C:5]>>[C:1](=[O:2])-[O:4]-[C:5].[OH2:3]")
    
    for (acid_name, acid_smi), (alc_name, alc_smi) in itertools.product(acids, alcohols):
        acid_mol = Chem.MolFromSmiles(acid_smi)
        alc_mol = Chem.MolFromSmiles(alc_smi)
        
        products = esterification_rxn.RunReactants((acid_mol, alc_mol))
        if products:
            ester_smi = Chem.MolToSmiles(products[0][0])
            
            acid_xyz = generate_3d_xyz(acid_smi, acid_name)
            alc_xyz = generate_3d_xyz(alc_smi, alc_name)
            ester_name = f"{alc_name.replace('ol', 'yl')} {acid_name.replace('ic acid', 'ate')}"
            ester_xyz = generate_3d_xyz(ester_smi, ester_name)
            
            if acid_xyz and alc_xyz and ester_xyz:
                combined_reactant = combine_xyzs([acid_xyz, alc_xyz], "Reactants")
                reactions.append({
                    "id": f"ester_{len(reactions)}",
                    "name": f"{acid_name} + {alc_name} Esterification",
                    "iupacName": f"{acid_name} + {alc_name} Esterification",
                    "description": "Combinatorial esterification library.",
                    "category": "thermal",
                    "reactantXyz": combined_reactant,
                    "productXyz": ester_xyz,
                    "referenceEa": 15.0,
                    "doi": "",
                    "journalRef": ""
                })

    amidation_rxn = rdChemReactions.ReactionFromSmarts("[C:1](=[O:2])-[OH:3].[NH2:4]-[C:5]>>[C:1](=[O:2])-[NH:4]-[C:5].[OH2:3]")
    
    for (acid_name, acid_smi), (amine_name, amine_smi) in itertools.product(acids, amines):
        acid_mol = Chem.MolFromSmiles(acid_smi)
        amine_mol = Chem.MolFromSmiles(amine_smi)
        
        products = amidation_rxn.RunReactants((acid_mol, amine_mol))
        if products:
            amide_smi = Chem.MolToSmiles(products[0][0])
            
            acid_xyz = generate_3d_xyz(acid_smi, acid_name)
            amine_xyz = generate_3d_xyz(amine_smi, amine_name)
            amide_xyz = generate_3d_xyz(amide_smi, f"Amide from {acid_name} and {amine_name}")
            
            if acid_xyz and amine_xyz and amide_xyz:
                combined_reactant = combine_xyzs([acid_xyz, amine_xyz], "Reactants")
                reactions.append({
                    "id": f"amide_{len(reactions)}",
                    "name": f"{acid_name} + {amine_name} Amidation",
                    "iupacName": f"{acid_name} + {amine_name} Amidation",
                    "description": "Combinatorial amidation library.",
                    "category": "thermal",
                    "reactantXyz": combined_reactant,
                    "productXyz": amide_xyz,
                    "referenceEa": 20.0,
                    "doi": "",
                    "journalRef": ""
                })
                
    return reactions

if __name__ == "__main__":
    rxns = build_reactions()
    print(f"Generated {len(rxns)} reactions!")
    
    out_dir = "../assets"
    if not os.path.exists(out_dir):
        os.makedirs(out_dir)
        
    out_file = os.path.join(out_dir, "massive_reactions.json")
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(rxns, f, indent=2)
    print(f"Saved to {out_file}")
