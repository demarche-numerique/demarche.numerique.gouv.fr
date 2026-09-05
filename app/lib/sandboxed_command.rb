# frozen_string_literal: true

require "open3"

# This file defines SandboxedCommand.run, which uses bwrap to ... sandbox a command.
# The sandbox provides:
# - isolation: no network, no environment, no privileges, no caps, no chips
# - the input file read-only and, when asked, one writable output
# - 60 s of CPU, 4 GB of memory, a 100 MB tmpfs and 1 GB per written file
# - a minimal file hierarchy, with the shared libraries
module SandboxedCommand
  class WrapperFailed < StandardError; end

  ENABLED = ENV.enabled?("BWRAP_ISOLATION")

  BWRAP = "/usr/bin/bwrap"
  PRLIMIT = "/usr/bin/prlimit"

  # Address space, not resident memory: it is what the kernel refuses at allocation
  # time. A 64 megapixel decode allocates 17 MB and reserves close to a gigabyte, so
  # the ceiling has to sit far above what it actually uses.
  MAX_ADDRESS_SPACE = 4.gigabytes
  MAX_CPU_SECONDS = 60
  MAX_FILE_SIZE = 1.gigabyte
  MAX_TMPFS_SIZE = 100.megabytes

  LIMITS = ["--as=#{MAX_ADDRESS_SPACE}", "--cpu=#{MAX_CPU_SECONDS}", "--fsize=#{MAX_FILE_SIZE}"].freeze

  ISOLATION = [
    "--unshare-all",     # no network: the loopback interface is all that remains
    "--clearenv",        # no secrets, no credentials, no configuration
    "--new-session",     # detach from the controlling terminal (TIOCSTI injection)
    "--disable-userns",  # a compromised decoder cannot nest a sandbox of its own
    "--unshare-user",    # required by --disable-userns, and fails where -try degrades
    "--die-with-parent",
    "--cap-drop", "ALL",
    "--uid", "10000",
    "--gid", "10000",
    "--hostname", "rails_sandbox",
    "--size", MAX_TMPFS_SIZE.to_s, # caps the --tmpfs
    "--tmpfs", "/tmp",
    "--chdir", "/",
    "--setenv", "XDG_CACHE_HOME", "/tmp",
  ].freeze

  # /lib64 holds the ELF interpreter, which Debian symlinks into /lib/x86_64-linux-gnu,
  # while a merged-usr loader searches /usr/lib alone: all three, or one host fails.
  LIBRARIES = ["/lib", "/lib64", "/usr/lib"].freeze

  class << self
    def run(argv, readable: [], writable: [], env: {})
      output, error, status = Open3.capture3(*wrapped_argv(argv, readable:, writable:, env:))

      raise WrapperFailed, error.strip if wrapper_failed?(error)

      [output, error, status]
    end

    def wrapped_argv(argv, readable: [], writable: [], env: {})
      prlimit(bwrap(argv, readable:, writable:, env:))
    end

    def ensure_usable!
      raise "#{BWRAP} is missing, install the bubblewrap package" if !File.executable?(BWRAP)
      raise "#{PRLIMIT} is missing, install the util-linux package" if !File.executable?(PRLIMIT)

      _, error, status = Open3.capture3(*bwrap(["/usr/bin/true"]))

      raise "the sandbox will not start: #{error.strip}" if !status.success?
    end

    # Both wrappers prefix their errors
    def wrapper_failed?(output) = output.match?(/(bwrap|prlimit): /)

    private

    # the command must be an absolute path,  it is bound read-only
    # a bare name is left to libc's default PATH=/bin:/usr/bin, where nothing else is
    def bwrap(argv, readable: [], writable: [], env: {})
      # --remount-ro / comes last, no other mounting is possible after.
      [BWRAP, *ISOLATION, *env_args(env), *readable_args([*LIBRARIES, argv.first, *readable]), *writable_args(writable), "--remount-ro", "/", "--", *argv]
    end

    def prlimit(argv) = [PRLIMIT, *LIMITS, "--", *argv]

    def readable_args(paths) = paths.flat_map { ["--ro-bind", it, it] }

    def writable_args(paths) = paths.flat_map { ["--bind", it, it] }

    def env_args(env)
      env.flat_map { |name, value| ["--setenv", name, value.to_s] }
    end
  end
end
