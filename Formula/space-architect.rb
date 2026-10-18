class SpaceArchitect < Formula
  desc "Architect Loop: structured judgment-and-build cycles for humans and AI builders"
  homepage "https://github.com/jetpks/space-architect"
  url "https://rubygems.org/downloads/space-architect-9.5.0.gem"
  sha256 "16dcb0888cac134f82608e5991a78f875c59c97875aa17cfb519a5cf356db03a"
  license "MIT"

  depends_on "ruby"
  depends_on "space-cadet"

  def install
    ENV["GEM_HOME"] = libexec
    ENV["GEM_PATH"] = "#{Formula["space-cadet"].libexec}:#{libexec}"
    system "gem", "install", "--no-document", "--install-dir", libexec, cached_download
    # Only the gem's own binstub: dependency gems also drop binstubs into
    # libexec/bin, which would collide with other formulae at `brew link`.
    bin.install libexec/"bin/architect"
    # Native-extension build logs embed Homebrew's build-time shims paths,
    # which `brew audit --new` rejects; they are not needed at runtime.
    Pathname.glob(libexec/"extensions/**/{mkmf.log,gem_make.out}").each(&:unlink)
    # No PATH env: capturing ENV["PATH"] at build time embeds Homebrew's
    # shims dir into the wrapper (brew audit --new rejects it). The binstub's
    # absolute brew-ruby shebang is the interpreter pin, and the user's PATH
    # flows through for subprocesses (git, gh).
    bin.env_script_all_files libexec/"bin",
                             GEM_HOME: ENV.fetch("GEM_HOME"),
                             GEM_PATH: ENV.fetch("GEM_PATH")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/architect --version")
  end
end
