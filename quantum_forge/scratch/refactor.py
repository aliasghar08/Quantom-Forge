import re
import os

file_path = r"c:\Quantom Forge Repo\Quantom-Forge\quantum_forge\lib\core\widgets\reaction_animation_widget.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# We will extract methods into extensions in part files.

parts = {
    "reaction_animation_header.dart": ["_buildHeader", "_phaseChip", "_fragmentChip", "_displayTypePicker", "_palettePicker"],
    "reaction_animation_canvas.dart": ["_buildCanvasSlotUnbounded", "_buildCanvasSlotBounded", "_buildCanvas"],
    "reaction_animation_timeline.dart": ["_buildTimeline"],
    "reaction_animation_readout.dart": ["_buildReadout", "_infoItem", "_bondsForCurrentFrame"],
    "reaction_animation_player.dart": ["_buildPlayerControls", "_stepButton"],
    "reaction_animation_bond_energies.dart": ["_buildBondEnergiesPanel", "_buildBondList", "_buildEmptyBondMessage"],
}

# Find SpinBox class manually since it's at the end
spinbox_match = re.search(r"class _SpinBox extends StatefulWidget \{.*", content, re.DOTALL)
spinbox_content = ""
if spinbox_match:
    spinbox_content = spinbox_match.group(0)
    content = content[:spinbox_match.start()]

extracted_methods = {}

def extract_method(name, code):
    # Matches Widget name(...) { ... } or String name(...) { ... }
    # Since dart has nested braces, we must balance them.
    pattern = rf"(?:Widget|String|void|List<PerceivedBond>)\s+{name}\s*\([^)]*\)\s*\{{"
    match = re.search(pattern, code)
    if not match:
        return code, ""
    
    start = match.start()
    brace_count = 0
    idx = match.end() - 1
    
    # We found the opening brace '{'
    in_string = False
    string_char = ''
    while idx < len(code):
        c = code[idx]
        if in_string:
            if c == '\\':
                idx += 2
                continue
            if c == string_char:
                in_string = False
        else:
            if c in ("'", '"'):
                in_string = True
                string_char = c
            elif c == '{':
                brace_count += 1
            elif c == '}':
                brace_count -= 1
                if brace_count == 0:
                    break
        idx += 1
        
    end = idx + 1
    method_code = code[start:end]
    new_code = code[:start] + code[end:]
    return new_code, method_code

for part_file, methods in parts.items():
    part_code = ""
    for m in methods:
        content, m_code = extract_method(m, content)
        if m_code:
            part_code += m_code + "\n\n"
    extracted_methods[part_file] = part_code

# Replace _t1, _t2, _t3 with qualified names
for part_file in extracted_methods:
    extracted_methods[part_file] = extracted_methods[part_file].replace("_t1", "_ReactionAnimationWidgetState._t1")
    extracted_methods[part_file] = extracted_methods[part_file].replace("_t2", "_ReactionAnimationWidgetState._t2")
    extracted_methods[part_file] = extracted_methods[part_file].replace("_t3", "_ReactionAnimationWidgetState._t3")

# Write part files
dir_path = os.path.dirname(file_path)

# Insert part declarations right after imports
# find the last import statement
import_matches = list(re.finditer(r"^import\s+.*;$", content, re.MULTILINE))
if import_matches:
    last_import = import_matches[-1]
    import_end = last_import.end()
else:
    import_end = 0

imports = content[:import_end]
rest = content[import_end:]

part_decls = "\n\n" + "\n".join(f"part '{p}';" for p in parts.keys()) + "\npart 'reaction_animation_spinbox.dart';\n"

new_content = imports + part_decls + rest

with open(file_path, "w", encoding="utf-8") as f:
    f.write(new_content)

for part_file, code in extracted_methods.items():
    ext_name = "_" + part_file.replace('.dart', '').replace('_', ' ').title().replace(' ', '') + "Ext"
    full_code = f"// ignore_for_file: invalid_use_of_protected_member\npart of 'reaction_animation_widget.dart';\n\nextension {ext_name} on _ReactionAnimationWidgetState {{\n"
    # indent code
    indented = "\n".join("  " + line if line else line for line in code.split("\n"))
    full_code += indented + "}\n"
    with open(os.path.join(dir_path, part_file), "w", encoding="utf-8") as f:
        f.write(full_code)

# write spinbox
with open(os.path.join(dir_path, "reaction_animation_spinbox.dart"), "w", encoding="utf-8") as f:
    f.write("part of 'reaction_animation_widget.dart';\n\n" + spinbox_content)

print("Done")
