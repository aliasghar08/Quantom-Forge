import os

file_path = r"c:\Quantom Forge Repo\Quantom-Forge\quantum_forge\lib\state\reaction_provider.dart"

with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

parts = {
    "reaction_provider_dispatch.dart": lines[69:223],
    "reaction_provider_simulation.dart": lines[223:351],
    "reaction_provider_backend.dart": lines[351:442],
    "reaction_provider_guest.dart": lines[442:543],
    "reaction_provider_firestore.dart": lines[543:556],
}

main_lines = lines[:69] + lines[556:]

import_end = 0
for i, line in enumerate(main_lines):
    if line.startswith("import "):
        import_end = i

part_decls = ["\n"] + [f"part '{p}';\n" for p in parts.keys()] + ["\n"]

new_main_lines = main_lines[:import_end+1] + part_decls + main_lines[import_end+1:]

with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(new_main_lines)

dir_path = os.path.dirname(file_path)

for part_file, part_lines in parts.items():
    ext_name = part_file.replace('.dart', '').replace('_', ' ').title().replace(' ', '') + "Ext"
    full_code = f"// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member\npart of 'reaction_provider.dart';\n\nextension {ext_name} on ReactionNotifier {{\n"
    full_code += "".join(part_lines)
    full_code += "}\n"
    
    with open(os.path.join(dir_path, part_file), "w", encoding="utf-8") as f:
        f.write(full_code)

print("Done")
