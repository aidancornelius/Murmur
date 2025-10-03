#!/usr/bin/env ruby

# Script to remove duplicate SeverityBadge.swift references from Xcode project
# This fixes the "Multiple commands produce SeverityBadge.stringsdata" build error

require 'fileutils'

project_file = '/Users/acb/Code/Murmur/Murmur.xcodeproj/project.pbxproj'

# Create backup
backup_file = "#{project_file}.backup.#{Time.now.strftime('%Y%m%d_%H%M%S')}"
FileUtils.cp(project_file, backup_file)
puts "Created backup: #{backup_file}"

# Read the project file
content = File.read(project_file)

# IDs to remove (the incorrect references that place SeverityBadge in Services group)
# These are the first set of duplicates
ids_to_remove = [
  '44108E7F2E8F7613007F6FAB', # PBXFileReference for SeverityBadge.swift
  '44108E822E8F7613007F6FAB'  # PBXBuildFile for SeverityBadge.swift
]

puts "\nRemoving duplicate references..."

# Remove lines containing these IDs
original_lines = content.lines
filtered_lines = original_lines.reject do |line|
  ids_to_remove.any? { |id| line.include?(id) }
end

removed_count = original_lines.length - filtered_lines.length
puts "Removed #{removed_count} lines containing duplicate references"

# Show what was removed
puts "\nRemoved lines:"
original_lines.each_with_index do |line, idx|
  if ids_to_remove.any? { |id| line.include?(id) }
    puts "Line #{idx + 1}: #{line.strip}"
  end
end

# Write back the cleaned content
File.write(project_file, filtered_lines.join)
puts "\nProject file cleaned successfully!"
puts "Backup saved to: #{backup_file}"

# Verify the correct references remain
puts "\nVerifying remaining SeverityBadge references..."
remaining_severity_lines = filtered_lines.select { |line| line.include?('SeverityBadge') }
puts "Remaining references: #{remaining_severity_lines.length}"
remaining_severity_lines.each_with_index do |line, idx|
  puts "  #{idx + 1}. #{line.strip}"
end

# Check that the correct IDs remain (A2B01034 and A2B02033)
correct_file_ref = filtered_lines.any? { |line| line.include?('A2B01034') && line.include?('SeverityBadge') }
correct_build_file = filtered_lines.any? { |line| line.include?('A2B02033') && line.include?('SeverityBadge') }

if correct_file_ref && correct_build_file
  puts "\n✓ Verification passed: Correct references remain (A2B01034 and A2B02033)"
else
  puts "\n⚠ Warning: Expected references not found"
  puts "  File reference (A2B01034): #{correct_file_ref}"
  puts "  Build file (A2B02033): #{correct_build_file}"
end

puts "\nDone! You can now build the project in Xcode."
