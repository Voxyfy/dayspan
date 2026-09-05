# Widget extension hedefini Xcode projesine ekler. Bir kez çalıştırılır;
# tekrar çalıştırılırsa hedef zaten varsa dokunmaz.
#   ruby ios/add_widget_target.rb
require 'xcodeproj'

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' }
abort 'Runner target not found' unless runner

if project.targets.any? { |t| t.name == 'DayspanWidget' }
  puts 'DayspanWidget target already exists'
  exit 0
end

widget = project.new_target(:app_extension, 'DayspanWidget', :ios, '17.0')
group = project.main_group.new_group('DayspanWidget', 'DayspanWidget')
swift = group.new_file('DayspanWidget.swift')
group.new_file('Info.plist')
group.new_file('DayspanWidget.entitlements')
widget.source_build_phase.add_file_reference(swift)
widget.product_reference.path = 'DayspanWidget.appex'
widget.product_reference.name = 'DayspanWidget.appex'

# FLUTTER_BUILD_NAME / NUMBER yalnızca Flutter'ın ürettiği xcconfig'te var;
# widget bunu almazsa CFBundleVersion boş kalıyor ve simülatör yüklemeyi
# reddediyor.
generated = project.files.find { |f| f.path.to_s.end_with?('Generated.xcconfig') }
widget.build_configurations.each do |c|
  c.base_configuration_reference = generated
  c.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.batuhanhaymana.dayspan.widget'
  c.build_settings['INFOPLIST_FILE'] = 'DayspanWidget/Info.plist'
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'DayspanWidget/DayspanWidget.entitlements'
  c.build_settings['SWIFT_VERSION'] = '5.0'
  c.build_settings['TARGETED_DEVICE_FAMILY'] = '1'
  c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0' # containerBackground iOS 17 ister; uygulama 16'da kalır
  c.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  c.build_settings['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  c.build_settings['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  c.build_settings['SKIP_INSTALL'] = 'YES'
  c.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  c.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
end

# Runner: entitlements + widget'ı gömme.
runner.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end
runner_group = project.main_group['Runner']
runner_group.new_file('Runner.entitlements') unless runner_group.files.any? { |f| f.path == 'Runner.entitlements' }
runner.add_dependency(widget)
embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(widget.product_reference).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save
puts 'DayspanWidget target added'
