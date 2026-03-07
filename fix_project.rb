
require 'fileutils'

path = 'ios/Runner.xcodeproj/project.pbxproj'
content = File.read(path)

# Remove Pods_Runner.framework from PBXBuildFile section
content.gsub!(/^\s*[A-Z0-9]+\s\/\*\sPods_Runner\.framework\sin\sFrameworks\s\*\/.*$/, '')

# Remove Pods_Runner.framework from PBXFileReference section
content.gsub!(/^\s*[A-Z0-9]+\s\/\*\sPods_Runner\.framework\s\*\/.*$/, '')

# Remove Pods_Runner.framework from PBXFrameworksBuildPhase
content.gsub!(/^\s*[A-Z0-9]+\s\/\*\sPods_Runner\.framework\sin\sFrameworks\s\*\/,$/, '')

# Remove Pods_Runner.framework from PBXGroup (Frameworks)
content.gsub!(/^\s*[A-Z0-9]+\s\/\*\sPods_Runner\.framework\s\*\/,$/, '')

File.write(path, content)
puts "Cleaned project.pbxproj from Pods_Runner.framework references."
