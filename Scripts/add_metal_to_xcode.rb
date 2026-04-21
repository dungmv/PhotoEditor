require 'xcodeproj'

project_path = 'PhotoEditor.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

canvas_group = project.main_group.find_subpath('PhotoEditor/Canvas', true)
shaders_group = canvas_group['Shaders'] || canvas_group.new_group('Shaders')

file_path = 'PhotoEditor/Canvas/Shaders/ImageFilters.metal'
file_ref = shaders_group.files.find { |f| f.path == file_path } || shaders_group.new_reference('Shaders/ImageFilters.metal')

# We want to add it to Copy Bundle Resources so it can be loaded at runtime
resources_phase = target.resources_build_phase
unless resources_phase.files_references.include?(file_ref)
  resources_phase.add_file_reference(file_ref)
  puts 'Added ImageFilters.metal to Copy Bundle Resources.'
else
  puts 'ImageFilters.metal is already in Copy Bundle Resources.'
end

# Make sure it's NOT in the compile sources phase
compile_phase = target.source_build_phase
if compile_phase.files_references.include?(file_ref)
  compile_phase.remove_file_reference(file_ref)
  puts 'Removed ImageFilters.metal from Compile Sources.'
end

project.save
puts 'Xcode project updated successfully.'
