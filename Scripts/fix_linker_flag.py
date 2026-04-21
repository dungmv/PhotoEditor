import re

pbx_path = 'PhotoEditor.xcodeproj/project.pbxproj'

with open(pbx_path, 'r') as f:
    text = f.read()

# Replace all occurrences of OTHER_METALLINKER_FLAGS with MTLLINKER_FLAGS
text = text.replace('OTHER_METALLINKER_FLAGS', 'MTLLINKER_FLAGS')

with open(pbx_path, 'w') as f:
    f.write(text)

print("Updated Xcode project flags to MTLLINKER_FLAGS.")
