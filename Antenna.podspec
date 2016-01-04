Pod::Spec.new do |spec|
	spec.name = 'Antenna'
	spec.version = '0.1.0'
	spec.summary = 'A simple BLE sample code'
	spec.homepage = 'https://github.com/1amageek/Antenna'
	spec.license = { :type => 'MIT', :file => 'LICENSE' }
	spec.author = { 'Norikazu Muramoto' => 'tmy0x3@icloud.com' }
	spec.social_media_url = 'http://twitter.com/1_am_a_geek'
	spec.source = { :git => 'https://github.com/1amageek/Antenna.git', :tag => "#{spec.version}" }
	spec.source_files = 'Antenna/Antenna.swift'
	spec.frameworks = 'CoreBluetooth'
	spec.ios.deployment_target = '8.0'
	spec.osx.deployment_target = '10.10'
	spec.tvos.deployment_target = '9.0'
	spec.requires_arc = true
	spec.module_name = 'Antenna'
end
