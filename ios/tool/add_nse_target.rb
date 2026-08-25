#!/usr/bin/env ruby
# Adds the NotificationService App Extension target to Runner.xcodeproj.
# Idempotent: skips if a target named "NotificationService" already exists.

require "xcodeproj"

PROJECT_PATH   = File.expand_path("../Runner.xcodeproj", __dir__)
NSE_NAME       = "NotificationService"
NSE_DIR        = File.expand_path("../NotificationService", __dir__)
BUNDLE_ID      = "com.featherpeakfury.featherpeakfurygame.NotificationService"
TEAM_ID        = "BHS6CTJ53R"
DEPLOY_TARGET  = "15.0"
SWIFT_VERSION  = "5.0"

project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.any? { |t| t.name == NSE_NAME }
  puts "Target '#{NSE_NAME}' already exists — nothing to do."
  exit 0
end

runner_target = project.targets.find { |t| t.name == "Runner" } or
  raise "Runner target not found"

nse_target = project.new_target(
  :app_extension,
  NSE_NAME,
  :ios,
  DEPLOY_TARGET,
  project.products_group,
  :swift
)

group = project.main_group.find_subpath(NSE_NAME, true)
group.set_source_tree("<group>")
group.set_path(NSE_NAME)

swift_ref = group.new_reference("NotificationService.swift")
swift_ref.last_known_file_type = "sourcecode.swift"
info_ref = group.new_reference("Info.plist")
info_ref.last_known_file_type = "text.plist.xml"

nse_target.source_build_phase.add_file_reference(swift_ref)

nse_target.build_configurations.each do |config|
  s = config.build_settings
  s["PRODUCT_BUNDLE_IDENTIFIER"]   = BUNDLE_ID
  s["PRODUCT_NAME"]                = "$(TARGET_NAME)"
  s["INFOPLIST_FILE"]              = "#{NSE_NAME}/Info.plist"
  s["IPHONEOS_DEPLOYMENT_TARGET"]  = DEPLOY_TARGET
  s["SWIFT_VERSION"]               = SWIFT_VERSION
  s["DEVELOPMENT_TEAM"]            = TEAM_ID
  s["CODE_SIGN_STYLE"]             = "Automatic"
  s["TARGETED_DEVICE_FAMILY"]      = "1,2"
  s["SKIP_INSTALL"]                = "YES"
  s["ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES"] = "NO"
  s["CLANG_ENABLE_MODULES"]        = "YES"
  s["ENABLE_BITCODE"]              = "NO"
  s["MTL_ENABLE_DEBUG_INFO"]       = "INCLUDE_SOURCE" if config.name != "Release"
  s["MTL_FAST_MATH"]               = "YES"
  s["GCC_C_LANGUAGE_STANDARD"]     = "gnu11"
  s["CLANG_CXX_LANGUAGE_STANDARD"] = "gnu++17"
  s["CLANG_CXX_LIBRARY"]           = "libc++"
  s["DEBUG_INFORMATION_FORMAT"]    = (config.name == "Debug" ? "dwarf" : "dwarf-with-dsym")
  s["ONLY_ACTIVE_ARCH"]            = (config.name == "Debug" ? "YES" : "NO")
  s["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
end

runner_target.add_dependency(nse_target)

embed_phase = runner_target.copy_files_build_phases.find do |p|
  p.symbol_dst_subfolder_spec == :plug_ins
end
unless embed_phase
  embed_phase = runner_target.new_copy_files_build_phase("Embed App Extensions")
  embed_phase.symbol_dst_subfolder_spec = :plug_ins
  embed_phase.run_only_for_deployment_postprocessing = "0"
end

appex_ref = nse_target.product_reference
build_file = embed_phase.add_file_reference(appex_ref)
build_file.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }

project.save
puts "Added NotificationService target."
