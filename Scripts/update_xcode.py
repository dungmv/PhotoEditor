import re
import sys

pbx_path = 'PhotoEditor.xcodeproj/project.pbxproj'

with open(pbx_path, 'r') as f:
    text = f.read()

# Replace any existing OTHER_METALCOMPILER_FLAGS or add it under MTL_FAST_MATH
if 'OTHER_METALCOMPILER_FLAGS' in text:
    print("Already has OTHER_METALCOMPILER_FLAGS")
else:
    # Add after MTL_FAST_MATH = YES;
    text = re.sub(r'(MTL_FAST_MATH\s*=\s*YES;)', r'\1\n\t\t\t\tOTHER_METALCOMPILER_FLAGS = "-fcikernel";', text)
    with open(pbx_path, 'w') as f:
        f.write(text)
    print("Added OTHER_METALCOMPILER_FLAGS = -fcikernel")

