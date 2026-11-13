Pod::Spec.new do |s|
  s.name             = 'pocketdesk_ios'
  s.version          = '0.1.0'
  s.summary          = "PocketDesk's iPhone-only native side."
  s.description      = <<-DESC
The "pocketdesk/files" channel on iPhone: choosing files, keeping received
files in the Files app, Quick Look, and pocketdesk:// pairing links.
                       DESC
  s.homepage         = 'https://github.com/LapaluLiyanage/pocketdesk'
  s.license          = { :type => 'GPL-3.0-or-later' }
  s.author           = { 'Lapalu Liyanage' => 'https://github.com/LapaluLiyanage' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDE_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'
  s.frameworks       = 'QuickLook', 'UniformTypeIdentifiers'
end
