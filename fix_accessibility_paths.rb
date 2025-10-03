#!/usr/bin/env ruby

require 'xcodeproj'

# Open the Xcode project
project_path = 'Murmur.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Accessibility group
main_group = project.main_group['Murmur']
accessibility_group = main_group['Accessibility']

if accessibility_group.nil?
  puts "Error: Could not find Accessibility group"
  exit 1
end

# Fix the path for each file
accessibility_group.files.each do |file_ref|
  old_path = file_ref.path
  # Set the correct relative path from the group
  file_ref.set_path("Accessibility/#{file_ref.path}")
  puts "Updated path for #{old_path} to #{file_ref.path}"
end

# Save the project
project.save

puts "\nPaths fixed successfully!"