class RepoTender < Formula
  desc "Keep your local git clones forever evergreen — clean, on default branch, fetched"
  homepage "https://github.com/jetpks/repo-tender"
  url "https://rubygems.org/downloads/repo-tender-1.0.0.gem"
  sha256 "a13a27d9415bedebf4fcd92e4f4354d9e34ec39f7ebf5bb9563d321ce6f69a25"
  license "MIT"

  depends_on "gh"
  depends_on "ruby"

  def install
    ENV["GEM_HOME"] = libexec
    system "gem", "install", "--no-document", "--install-dir", libexec, cached_download
    # Only the gem's own binstub: dependency gems also drop binstubs into
    # libexec/bin, which would collide with other formulae at `brew link`.
    bin.install libexec/"bin/repo-tender"
    # Native-extension build logs embed Homebrew's build-time shims paths,
    # which `brew audit --new` rejects; they are not needed at runtime.
    Pathname.glob(libexec/"extensions/**/{mkmf.log,gem_make.out}").each(&:unlink)
    # No PATH env: capturing ENV["PATH"] at build time embeds Homebrew's
    # shims dir into the wrapper (brew audit --new rejects it). The binstub's
    # absolute brew-ruby shebang is the interpreter pin, and the user's PATH
    # flows through for subprocesses (git, gh).
    bin.env_script_all_files libexec/"bin", GEM_HOME: ENV.fetch("GEM_HOME")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/repo-tender --version")
  end
end
