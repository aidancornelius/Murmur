#!/usr/bin/env ruby

require 'xcodeproj'
require 'pathname'

# Open the Xcode project
project_path = 'Murmur.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
main_target = project.targets.find { |t| t.name == 'Murmur' }

if main_target.nil?
  puts "Error: Could not find 'Murmur' target"
  exit 1
end

# Find the main group
main_group = project.main_group['Murmur']

if main_group.nil?
  puts "Error: Could not find 'Murmur' group"
  exit 1
end

# Create or find Accessibility group
accessibility_group = main_group['Accessibility']
if accessibility_group.nil?
  puts "Creating Accessibility group..."
  accessibility_group = main_group.new_group('Accessibility')
end

# Files to add
accessibility_files = [
  'AccessibilityExtensions.swift',
  'AccessibilityRotor.swift',
  'AudioGraphs.swift',
  'SwitchControlSupport.swift',
  'VoiceCommandController.swift'
]

# Add each file to the project
accessibility_files.each do |filename|
  file_path = "Murmur/Accessibility/#{filename}"

  # Check if file exists
  unless File.exist?(file_path)
    puts "Warning: File #{file_path} does not exist"
    next
  end

  # Check if already in project
  existing_ref = accessibility_group.files.find { |f| f.path == filename }

  if existing_ref
    puts "File #{filename} already in project"
  else
    puts "Adding #{filename} to project..."

    # Create file reference
    file_ref = accessibility_group.new_reference(filename)
    file_ref.set_path(filename)
    file_ref.set_source_tree('<group>')

    # Add to build phase
    build_phase = main_target.source_build_phase
    build_phase.add_file_reference(file_ref)

    puts "  Added to Accessibility group and build phase"
  end
end

# Save the project
project.save

puts "\nProject updated successfully!"
puts "Added #{accessibility_files.count} files to the Accessibility group"