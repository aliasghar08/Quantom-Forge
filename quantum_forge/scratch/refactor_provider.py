import os

file_path = r"c:\Quantom Forge Repo\Quantom-Forge\quantum_forge\lib\state\reaction_provider.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

parts = {
    "reaction_provider_backend.dart": ["_dispatchToBackend"],
    "reaction_provider_guest.dart": ["_simulateGuestReaction"],
    "reaction_provider_simulation.dart": ["_simulateReactionProcessing"],
    "reaction_provider_dispatch.dart": ["dispatchReaction", "dispatchFromTemplate"],
    "reaction_provider_firestore.dart": ["_listenToReactionUpdates"],
}

extracted_methods = {}

def extract_method(name, code):
    sig_start = code.find(" " + name + "(")
    if sig_start == -1:
        # try without space
        sig_start = code.find(name + "(")
        if sig_start == -1:
            return code, ""
            
    # Backtrack to find the start of the line (or close to it)
    start = code.rfind("\n", 0, sig_start)
    if start == -1:
        start = 0
    else:
        start += 1
        
    brace_start = code.find("{", sig_start)
    if brace_start == -1:
        return code, ""
        
    brace_count = 0
    idx = brace_start
    
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

dir_path = os.path.dirname(file_path)

import_end = content.rfind("import ")
if import_end != -1:
    import_end = content.find(";", import_end) + 1
else:
    import_end = 0

imports = content[:import_end]
rest = content[import_end:]

part_decls = "\n\n" + "\n".join(f"part '{p}';" for p in parts.keys()) + "\n"

new_content = imports + part_decls + rest

with open(file_path, "w", encoding="utf-8") as f:
    f.write(new_content)

for part_file, code in extracted_methods.items():
    ext_name = "_" + part_file.replace('.dart', '').replace('_', ' ').title().replace(' ', '') + "Ext"
    full_code = f"// ignore_for_file: invalid_use_of_protected_member\npart of 'reaction_provider.dart';\n\nextension {ext_name} on ReactionNotifier {{\n"
    indented = "\n".join("  " + line if line else line for line in code.split("\n"))
    full_code += indented + "}\n"
    with open(os.path.join(dir_path, part_file), "w", encoding="utf-8") as f:
        f.write(full_code)

print("Done")
