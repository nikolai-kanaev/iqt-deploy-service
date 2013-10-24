require "rubygems"
require "bundler"
Bundler.setup
$: << './'

require 'albacore'
require 'rake/clean'
require 'semver'

require 'buildscripts/utils'
require 'buildscripts/paths'
require 'buildscripts/project_details'
require 'buildscripts/environment'

# to get the current version of the project, type 'SemVer.find.to_s' in this rake file.

desc 'generate the shared assembly info'
assemblyinfo :assemblyinfo => ["env:release"] do |asm|
  data = commit_data() #hash + date
  asm.product_name = asm.title = PROJECTS[:autotx][:title]
  asm.description = PROJECTS[:autotx][:description] + " #{data[0]} - #{data[1]}"
  asm.company_name = PROJECTS[:autotx][:company]
  # This is the version number used by framework during build and at runtime to locate, link and load the assemblies. When you add reference to any assembly in your project, it is this version number which gets embedded.
  asm.version = BUILD_VERSION
  # Assembly File Version : This is the version number given to file as in file system. It is displayed by Windows Explorer. Its never used by .NET framework or runtime for referencing.
  asm.file_version = BUILD_VERSION
  asm.custom_attributes :AssemblyInformationalVersion => "#{BUILD_VERSION}", # disposed as product version in explorer
    :CLSCompliantAttribute => false,
    :AssemblyConfiguration => "#{CONFIGURATION}",
    :Guid => PROJECTS[:autotx][:guid]
  asm.com_visible = false
  asm.copyright = PROJECTS[:autotx][:copyright]
  asm.output_file = File.join(FOLDERS[:src], 'SharedAssemblyInfo.cs')
  asm.namespaces = "System", "System.Reflection", "System.Runtime.InteropServices", "System.Security"
end


desc "build sln file"
msbuild :msbuild do |msb|
  msb.solution   = FILES[:sln]
  msb.properties :Configuration => CONFIGURATION
  msb.targets    :Clean, :Build
end


task :autotx_output => [:msbuild] do
  target = File.join(FOLDERS[:binaries], PROJECTS[:autotx][:id])
  copy_files FOLDERS[:autotx][:out], "*.{xml,config,svc, Release.config, svc.cs}", target
  CLEAN.include(target)
end

zip :do_zip do |zip|
  zip.directories_to_zip File.join(FOLDERS[:src], PROJECTS[:autotx][:dir], "build")
  #zip.additional_files FOLDERS[:autotx][:out], "*.{svc, config}"
  zip.output_file = "#{PROJECTS[:autotx][:title]}-#{SemVer.find.to_s}.zip"
  zip.output_path = "C:/Builds"
end

task :gittask do
  puts 'adding'
  `git add -A`
  puts 'committing'
  `git commit -am "Released version #{BUILD_VERSION}"`
  puts 'pushing'
  `git push origin master`
end

# Deploy
zip :peds_zip => [:app_morph, :nlog_morph, :add_msdeploy_xml] do |zip|
  zip.directories_to_zip FOLDERS[:peds][:out]
  zip.output_file = "#{PROJECTS[:peds][:title]}-#{SemVer.find.to_s}.zip"
  zip.output_path = FOLDERS[:binaries]
end

task :output => [:autotx_output]

task :default  => ["env:release", "assemblyinfo", "msbuild", "output", "do_zip"]
task :release => ["env:release", :msbuild, :output, :gittask]