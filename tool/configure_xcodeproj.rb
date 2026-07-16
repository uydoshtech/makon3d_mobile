# One-shot project configuration: registers localized .strings files and sets
# bundle id + deployment target.
#
# Room-scan / floor-plan / sun-simulation Swift sources now come from the
# room_scan_kit CocoaPod — do not re-register them in the Runner target.
#
# Run from the repo root:  ruby tool/configure_xcodeproj.rb
require 'xcodeproj'

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

runner_target = project.targets.find { |t| t.name == 'Runner' }
tests_target = project.targets.find { |t| t.name == 'RunnerTests' }
runner_group = project.main_group['Runner']

# Localized InfoPlist.strings / Localizable.strings variant groups.
%w[InfoPlist.strings Localizable.strings].each do |strings_name|
  next if runner_group.children.any? { |c| c.display_name == strings_name }
  variant = runner_group.new_variant_group(strings_name)
  %w[en ru uz].each do |lang|
    file_path = File.expand_path("../ios/Runner/#{lang}.lproj/#{strings_name}", __dir__)
    next unless File.exist?(file_path)
    ref = variant.new_reference("#{lang}.lproj/#{strings_name}")
    ref.name = lang
  end
  runner_target.resources_build_phase.add_file_reference(variant, true)
  puts "added variant group #{strings_name}"
end

project.root_object.known_regions |= %w[en ru uz Base]

project.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
end
runner_target.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.makon3d.app'
end
tests_target&.build_configurations&.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.makon3d.app.RunnerTests'
end

project.save
puts 'project saved'
