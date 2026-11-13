$:.push File.expand_path("../lib", __FILE__)

require "administrate/version"

Gem::Specification.new do |s|
  s.name = "administrate"
  s.version = Administrate::VERSION
  s.authors = ["Nick Charlton"]
  s.email = ["nick@nickcharlton.net"]
  s.homepage = "https://administrate-demo.herokuapp.com/"
  s.summary = "A Rails engine for creating super-flexible admin dashboards"
  s.license = "MIT"

  s.files = Dir["{app,lib,docs}/**/*", "config/locales/**/*", "LICENSE", "Rakefile"]

  s.add_dependency "actionpack", ">= 6.0", "< 9.0"
  s.add_dependency "actionview", ">= 6.0", "< 9.0"
  s.add_dependency "activerecord", ">= 6.0", "< 9.0"
  # RINSED: upstream pins `~> 1.2.2` (still the case on upstream main).
  # rinsed-web locks kaminari 1.3.2, so the upstream constraint would force a
  # downgrade of a gem the whole app paginates with. Drop this once upstream
  # allows 1.3.
  s.add_dependency "kaminari", ">= 1.2.2", "< 2"
  # END RINSED

  s.description = <<~DESCRIPTION
    Administrate is a library for Rails that generates admin dashboards. These
    give users clean interfaces that allow them to create, edit, search, and
    delete records for any model in the application. Administrate aims to
    provide the best user experience, and doing as much work as possible for
    you, whilst also being flexible to customise.
  DESCRIPTION
end
