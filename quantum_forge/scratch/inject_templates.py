import re

with open("combined_reactions.txt", "r", encoding="utf-8") as f:
    text = f.read()

# Split into constants and templates based on "// Add to list:" and "// --- OBJS ---"
parts = re.split(r'// Add to list:|// --- OBJS ---', text)

constants = parts[0]
templates = "".join(parts[1:])

with open("lib/features/reaction_library/data/reaction_templates.dart", "r", encoding="utf-8") as f:
    dart = f.read()

# Insert constants before TEMPLATE 1
target_const = "// ============================================================================\n// TEMPLATE 1: Diels-Alder Cycloaddition"
if target_const in dart:
    dart = dart.replace(target_const, constants + "\n\n" + target_const)

# Insert templates before ];
target_list_end = "];\n"
if target_list_end in dart:
    dart = dart.replace(target_list_end, templates + "\n];\n")

with open("lib/features/reaction_library/data/reaction_templates.dart", "w", encoding="utf-8") as f:
    f.write(dart)

print("Injected templates into reaction_templates.dart successfully.")
