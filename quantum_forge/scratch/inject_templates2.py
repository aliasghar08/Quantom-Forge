import re

def parse_file(filename, sep):
    with open(filename, "r", encoding="utf-8") as f:
        text = f.read()
    parts = text.split(sep)
    return parts[0], parts[1]

c1, t1 = parse_file("scratch/new_reactions.dart", "// Add to list:\n")
c2, t2 = parse_file("templates_out.dart", "// --- OBJS ---\n")

constants = c1 + "\n" + c2
templates = t1 + "\n" + t2

with open("lib/features/reaction_library/data/reaction_templates.dart", "r", encoding="utf-8") as f:
    dart = f.read()

target_const = "// ============================================================================\n// TEMPLATE 1: Diels-Alder Cycloaddition"
if target_const in dart:
    dart = dart.replace(target_const, constants + "\n\n" + target_const)

target_list_end = "];\n"
if target_list_end in dart:
    dart = dart.replace(target_list_end, templates + "\n];\n")

with open("lib/features/reaction_library/data/reaction_templates.dart", "w", encoding="utf-8") as f:
    f.write(dart)

print("Injected safely.")
