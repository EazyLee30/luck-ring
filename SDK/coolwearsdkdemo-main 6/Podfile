source 'https://mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs.git'
platform :ios, '12.0'

inhibit_all_warnings!
use_frameworks!
use_modular_headers!
install! 'cocoapods',
           disable_input_output_paths: true,
          generate_multiple_pod_projects: true

target 'sdkdemo' do
  pod 'SDWebImage', '~> 5.7.3'
  pod 'MJExtension'
  pod 'SwiftyJSON'
  pod 'SnapKit'
  
#  pod 'CLBluetoothModule', :path=>'../CLBluetoothModule'
end

post_install do |installer|
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
       end
    end
  end
end
