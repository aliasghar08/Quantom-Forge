import os

target_file = r'lib\features\reaction_library\data\reaction_templates.dart'
source_file = r'scratch\gen_more_templates.py'

with open(source_file, 'r', encoding='utf-8') as f:
    new_templates = f.read()

with open(target_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the closing `];` with the new templates + `];`
if '];\n\n' in content:
    content = content.replace('];\n\n', new_templates + '\n];\n\n')
else:
    # try single newline
    content = content.replace('];', new_templates + '\n];')

with open(target_file, 'w', encoding='utf-8') as f:
    f.write(content)
print("Successfully appended templates")
