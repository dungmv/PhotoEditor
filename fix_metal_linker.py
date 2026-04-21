import re

pbx_path = 'PhotoEditor.xcodeproj/project.pbxproj'

with open(pbx_path, 'r') as f:
    text = f.read()

# MTLLINKER_FLAGS was correct for standard metal, but Core Image requires OTHER_METALLINKER_FLAGS with BOTH CoreImage framework and -cikernel
# Let's replace any existing MTLLINKER_FLAGS or OTHER_METALLINKER_FLAGS with the correct one

text = re.sub(r'MTLLINKER_FLAGS\s*=\s*"-cikernel";', r'OTHER_METALLINKER_FLAGS = ( "-framework", "CoreImage", "-cikernel" );', text)
text = re.sub(r'OTHER_METALLINKER_FLAGS\s*=\s*"-cikernel";', r'OTHER_METALLINKER_FLAGS = ( "-framework", "CoreImage", "-cikernel" );', text)

with open(pbx_path, 'w') as f:
    f.write(text)

print("Updated Xcode right format for Other Metal Linker Flags")
