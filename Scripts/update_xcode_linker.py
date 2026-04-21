import re

pbx_path = 'PhotoEditor.xcodeproj/project.pbxproj'

with open(pbx_path, 'r') as f:
    text = f.read()

if 'OTHER_METALLINKER_FLAGS' in text:
    print("Already has OTHER_METALLINKER_FLAGS")
else:
    # Add after OTHER_METALCOMPILER_FLAGS = "-fcikernel";
    text = re.sub(r'(OTHER_METALCOMPILER_FLAGS\s*=\s*"-fcikernel";)', r'\1\n\t\t\t\tOTHER_METALLINKER_FLAGS = "-cikernel";', text)
    with open(pbx_path, 'w') as f:
        f.write(text)
    print("Added OTHER_METALLINKER_FLAGS = -cikernel")

