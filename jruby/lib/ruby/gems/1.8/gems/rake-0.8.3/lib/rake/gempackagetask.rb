#!/usr/bin/env ruby

# Define a package task library to aid in the definition of GEM
# packages.

require 'rubygems'
require 'rake'
require 'rake/packagetask'
require 'rubygems/user_interaction'
require 'rubygems/builder'

begin
  Gem.manage_gems
rescue NoMethodError => ex
  # Using rubygems prior to 0.6.1
end

module Rake

  # Create a package based upon a Gem spec.  Gem packages, as well as
  # zip files and tar/gzipped packages can be produced by this task.
  #
  # In addition to the Rake targets generated by PackageTask, a
  # GemPackageTask will also generate the following tasks:
  #
  # [<b>"<em>package_dir</em>/<em>name</em>-<em>version</em>.gem"</b>]
  #   Create a Ruby GEM package with the given name and version.
  #
  # Example using a Ruby GEM spec:
  #
  #   require 'rubygems'
  #
  #   spec = Gem::Specification.new do |s|
  #     s.platform = Gem::Platform::RUBY
  #     s.summary = "Ruby based make-like utility."
  #     s.name = 'rake'
  #     s.version = PKG_VERSION
  #     s.requirements << 'none'
  #     s.require_path = 'lib'
  #     s.autorequire = 'rake'
  #     s.files = PKG_FILES
  #     s.description = <<EOF
  #   Rake is a Make-like program implemented in Ruby. Tasks
  #   and dependencies are specified in standard Ruby syntax. 
  #   EOF
  #   end
  #   
  #   Rake::GemPackageTask.new(spec) do |pkg|
  #     pkg.need_zip = true
  #     pkg.need_tar = true
  #   end
  #
  class GemPackageTask < PackageTask
    # Ruby GEM spec containing the metadata for this package.  The
    # name, version and package_files are automatically determined
    # from the GEM spec and don't need to be explicitly provided.
    attr_accessor :gem_spec

    # Create a GEM Package task library.  Automatically define the gem
    # if a block is given.  If no block is supplied, then +define+
    # needs to be called to define the task.
    def initialize(gem_spec)
      init(gem_spec)
      yield self if block_given?
      define if block_given?
    end

    # Initialization tasks without the "yield self" or define
    # operations.
    def init(gem)
      super(gem.name, gem.version)
      @gem_spec = gem
      @package_files += gem_spec.files if gem_spec.files
    end

    # Create the Rake tasks and actions specified by this
    # GemPackageTask.  (+define+ is automatically called if a block is
    # given to +new+).
    def define
      super
      task :package => [:gem]
      desc "Build the gem file #{gem_file}"
      task :gem => ["#{package_dir}/#{gem_file}"]
      file "#{package_dir}/#{gem_file}" => [package_dir] + @gem_spec.files do
        when_writing("Creating GEM") {
          Gem::Builder.new(gem_spec).build
          verbose(true) {
            mv gem_file, "#{package_dir}/#{gem_file}"
          }
        }
      end
    end
    
    def gem_file
      if @gem_spec.platform == Gem::Platform::RUBY
        "#{package_name}.gem"
      else
        "#{package_name}-#{@gem_spec.platform}.gem"
      end
    end
    
  end
end
