# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{sinatra}
  s.version = "0.3.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Blake Mizerany"]
  s.date = %q{2008-11-02}
  s.description = %q{Classy web-development dressed in a DSL}
  s.extra_rdoc_files = ["README.rdoc", "LICENSE"]
  s.files = ["ChangeLog", "LICENSE", "README.rdoc", "Rakefile", "images/404.png", "images/500.png", "lib/sinatra.rb", "lib/sinatra/test/methods.rb", "lib/sinatra/test/rspec.rb", "lib/sinatra/test/spec.rb", "lib/sinatra/test/unit.rb", "sinatra.gemspec", "test/app_test.rb", "test/application_test.rb", "test/builder_test.rb", "test/custom_error_test.rb", "test/erb_test.rb", "test/event_context_test.rb", "test/events_test.rb", "test/filter_test.rb", "test/haml_test.rb", "test/helper.rb", "test/mapped_error_test.rb", "test/pipeline_test.rb", "test/public/foo.xml", "test/sass_test.rb", "test/sessions_test.rb", "test/streaming_test.rb", "test/sym_params_test.rb", "test/template_test.rb", "test/use_in_file_templates_test.rb", "test/views/foo.builder", "test/views/foo.erb", "test/views/foo.haml", "test/views/foo.sass", "test/views/foo_layout.erb", "test/views/foo_layout.haml", "test/views/layout_test/foo.builder", "test/views/layout_test/foo.erb", "test/views/layout_test/foo.haml", "test/views/layout_test/foo.sass", "test/views/layout_test/layout.builder", "test/views/layout_test/layout.erb", "test/views/layout_test/layout.haml", "test/views/layout_test/layout.sass", "test/views/no_layout/no_layout.builder", "test/views/no_layout/no_layout.haml"]
  s.has_rdoc = true
  s.homepage = %q{http://sinatra.rubyforge.org}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Sinatra", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{sinatra}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Classy web-development dressed in a DSL}
  s.test_files = ["test/app_test.rb", "test/application_test.rb", "test/builder_test.rb", "test/custom_error_test.rb", "test/erb_test.rb", "test/event_context_test.rb", "test/events_test.rb", "test/filter_test.rb", "test/haml_test.rb", "test/mapped_error_test.rb", "test/pipeline_test.rb", "test/sass_test.rb", "test/sessions_test.rb", "test/streaming_test.rb", "test/sym_params_test.rb", "test/template_test.rb", "test/use_in_file_templates_test.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rack>, [">= 0.4.0"])
    else
      s.add_dependency(%q<rack>, [">= 0.4.0"])
    end
  else
    s.add_dependency(%q<rack>, [">= 0.4.0"])
  end
end
