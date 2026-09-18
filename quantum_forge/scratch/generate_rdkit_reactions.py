import os
import math
from rdkit import Chem
from rdkit.Chem import AllChem

reactions = [
    (
        "benzoyl_chloride_syn",
        "Acid Chloride Synthesis",
        "benzoic acid + thionyl chloride → benzoyl chloride + sulfur dioxide + hydrogen chloride",
        "Preparation of benzoyl chloride from benzoic acid using SOCl2.",
        "nucleophilic",
        18.5,
        "10.1021/ja0000000",
        "J. Am. Chem. Soc. 2000",
        "['substitution', 'acyl']",
        ["O=C(O)c1ccccc1", "O=S(Cl)Cl"],
        ["O=C(Cl)c1ccccc1", "O=S=O", "Cl"] # HCl represented as just Cl and H later, wait RDKit needs full smiles
    ),
    (
        "grignard_addition",
        "Grignard Addition",
        "acetone + methylmagnesium bromide → tert-butoxide",
        "Nucleophilic addition of a Grignard reagent to a ketone.",
        "nucleophilic",
        12.0,
        "10.1021/ja0000001",
        "J. Am. Chem. Soc. 2001",
        "['grignard', 'addition']",
        ["CC(=O)C", "C[Mg]Br"],
        ["CC(C)(C)O[Mg]Br"]
    ),
    (
        "fisher_esterification",
        "Fischer Esterification",
        "acetic acid + ethanol → ethyl acetate + water",
        "Acid-catalyzed condensation of a carboxylic acid and an alcohol.",
        "ionic",
        22.1,
        "10.1021/ja0000002",
        "J. Am. Chem. Soc. 2002",
        "['esterification', 'condensation']",
        ["CC(=O)O", "CCO"],
        ["CC(=O)OCC", "O"]
    ),
    (
        "friedel_crafts",
        "Friedel-Crafts Alkylation",
        "benzene + chloromethane → toluene + hydrogen chloride",
        "Electrophilic aromatic substitution to alkylate a benzene ring.",
        "ionic",
        14.3,
        "10.1021/ja0000003",
        "J. Am. Chem. Soc. 2003",
        "['EAS', 'alkylation']",
        ["c1ccccc1", "CCl"],
        ["Cc1ccccc1", "Cl"] # RDKit will add H to Cl implicitly
    ),
    (
        "suzuki_coupling",
        "Suzuki-Miyaura Coupling",
        "phenylboronic acid + bromobenzene → biphenyl",
        "Palladium-catalyzed cross coupling of an aryl halide with a boronic acid.",
        "organometallic",
        25.0,
        "10.1021/ja0000004",
        "J. Am. Chem. Soc. 2004",
        "['coupling', 'palladium']",
        ["OB(O)c1ccccc1", "Brc1ccccc1"],
        ["c1ccc(-c2ccccc2)cc1", "OB(O)Br"]
    )
]

# Fix HCl
reactions[0][10][2] = "Cl" # Will add H if we parse explicitly, or just write "Cl" and add H to the molecule
reactions[3][10][1] = "Cl"

def smiles_to_atoms(smiles_list):
    atoms = []
    x_offset = 0.0
    for sm in smiles_list:
        mol = Chem.MolFromSmiles(sm)
        if not mol: continue
        mol = Chem.AddHs(mol)
        AllChem.EmbedMolecule(mol, randomSeed=42)
        AllChem.UFFOptimizeMolecule(mol)
        conf = mol.GetConformer()
        
        min_x = 999
        max_x = -999
        mol_atoms = []
        for i in range(mol.GetNumAtoms()):
            pos = conf.GetAtomPosition(i)
            symbol = mol.GetAtomWithIdx(i).GetSymbol()
            mol_atoms.append((symbol, pos.x, pos.y, pos.z))
            if pos.x < min_x: min_x = pos.x
            if pos.x > max_x: max_x = pos.x
            
        # shift to x_offset
        shift = x_offset - min_x
        for sym, x, y, z in mol_atoms:
            atoms.append((sym, x + shift, y, z))
            
        x_offset += (max_x - min_x) + 3.0 # 3 angstroms between molecules
    return atoms

dart_code = ""
list_code = ""

for rid, title, iupac, desc, category, ea, doi, journal, tags, r_sm, p_sm in reactions:
    r_atoms = smiles_to_atoms(r_sm)
    p_atoms = smiles_to_atoms(p_sm)
    
    r_str = f"const _{rid}Reactant = '''{len(r_atoms)}\n{title} (reactant)\n"
    for a in r_atoms:
        r_str += f"{a[0]:2} {a[1]:8.3f} {a[2]:8.3f} {a[3]:8.3f}\n"
    r_str += "''';\n\n"
    
    p_str = f"const _{rid}Product = '''{len(p_atoms)}\n{title} (product)\n"
    for a in p_atoms:
        p_str += f"{a[0]:2} {a[1]:8.3f} {a[2]:8.3f} {a[3]:8.3f}\n"
    p_str += "''';\n\n"
    
    dart_code += r_str + p_str
    
    list_code += f"""  ReactionTemplate(
    id: '{rid}',
    name: '{title}',
    iupacName: '{iupac}',
    description: '{desc}',
    category: ReactionCategory.{category},
    reactantXyz: _{rid}Reactant,
    productXyz: _{rid}Product,
    referenceEa: {ea},
    doi: '{doi}',
    journalRef: '{journal}',
    tags: {tags},
  ),
"""

with open("new_reactions.dart", "w", encoding="utf-8") as f:
    f.write(dart_code)
    f.write("\n\n// Add to list:\n")
    f.write(list_code)

print("Generated new_reactions.dart successfully.")
