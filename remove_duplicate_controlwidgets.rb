#!/usr/bin/env ruby

require 'xcodeproj'

# Open the Xcode project
project_path = 'Murmur.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
main_target = project.targets.find { |t| t.name == 'Murmur' }

if main_target.nil?
  puts "Error: Could not find 'Murmur' target"
  exit 1
end

# Find build phase
build_phase = main_target.source_build_phase

# Find all ControlWidgets references
control_widgets_refs = build_phase.files.select do |file|
  file.file_ref && file.file_ref.path && file.file_ref.path.include?('ControlWidgets.swift')
end

puts "Found #{control_widgets_refs.count} ControlWidgets.swift references"

# Remove duplicates, keeping only the first one
if control_widgets_refs.count > 1
  control_widgets_refs[1..-1].each do |file|
    build_phase.remove_file_reference(file)
    puts "Removed duplicate: #{file.file_ref.path}"
  end
end

# Save the project
project.save

puts "\nProject updated successfully!"