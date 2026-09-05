# Apple Watch uygulaması hedefini Xcode projesine ekler. Bir kez çalıştırılır;
# hedef zaten varsa dokunmaz.
#   ruby ios/add_watch_target.rb
#
# Xcode 14+ tek hedefli watch uygulaması: ayrı WatchKit extension yok, SwiftUI
# App doğrudan hedef. Runner onu `$(CONTENTS_FOLDER_PATH)/Watch` altına gömer.
require 'xcodeproj'

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' }
abort 'Runner target not found' unless runner

if project.targets.any? { |t| t.name == 'DayspanWatch' }
  puts 'DayspanWatch target already exists'
  exit 0
end

watch = project.new_target(:application, 'DayspanWatch', :watchos, '10.0')
group = project.main_group.new_group('DayspanWatch', 'DayspanWatch')
%w[DayspanWatchApp.swift BoardStore.swift BoardView.swift].each do |f|
  watch.source_build_phase.add_file_reference(group.new_file(f))
end
group.new_file('Info.plist')
# İkon: watchOS tek boyut (1024) ister, daire maskesini sistem uygular.
watch.resources_build_phase.add_file_reference(group.new_file('Assets.xcassets'))
watch.product_reference.path = 'DayspanWatch.app'
watch.product_reference.name = 'DayspanWatch.app'

# Widget'taki aynı tuzak: FLUTTER_BUILD_NAME / NUMBER yalnızca Flutter'ın
# ürettiği xcconfig'te; alınmazsa CFBundleVersion boş kalır.
generated = project.files.find { |f| f.path.to_s.end_with?('Generated.xcconfig') }
watch.build_configurations.each do |c|
  c.base_configuration_reference = generated
  c.build_settings['SDKROOT'] = 'watchos'
  # Belirtilmezse arşivde saat hedefi iOS SDK'sıyla kuruluyor ve ikon
  # kataloğu "applicable content yok" diye düşüyor.
  c.build_settings['SUPPORTED_PLATFORMS'] = 'watchos watchsimulator'
  c.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '10.0'
  c.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
  c.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  # Apple'ın beklediği son ek: eşlik eden saat uygulaması `.watchkitapp`.
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.batuhanhaymana.dayspan.watchkitapp'
  c.build_settings['INFOPLIST_FILE'] = 'DayspanWatch/Info.plist'
  c.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  c.build_settings['SWIFT_VERSION'] = '5.0'
  c.build_settings['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  c.build_settings['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  c.build_settings['SKIP_INSTALL'] = 'YES'
  c.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  c.build_settings['ENABLE_PREVIEWS'] = 'YES'
  c.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  c.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks']
  # Flutter'ın xcconfig'i iOS ayarları taşıyor; watchOS hedefi bunları ezer.
  c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = nil
end

runner.add_dependency(watch)
embed = runner.new_copy_files_build_phase('Embed Watch Content')
embed.symbol_dst_subfolder_spec = :products_directory
embed.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
embed.add_file_reference(watch.product_reference).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# Gömme, "Thin Binary"den önce olmalı; yoksa Flutter'ın betiği saat
# uygulamasını görmeden koşuyor ve arşiv doğrulaması düşüyor.
phases = runner.build_phases
thin = phases.find { |p| p.respond_to?(:name) && p.name.to_s.include?('Thin Binary') }
if thin
  phases.delete(embed)
  phases.insert(phases.index(thin), embed)
end

project.save
puts 'DayspanWatch target added'
