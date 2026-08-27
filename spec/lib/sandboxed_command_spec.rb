# frozen_string_literal: true

describe SandboxedCommand, :external_deps do
  # Asserts on what the sandbox actually denies rather than on the flags we passed:
  # the argv is a means, the confinement is the contract. Both streams, since a denial
  # is announced on stderr and the output it was denied would have been on stdout.
  # The sandbox binds the command it runs and nothing else, so a spec that shells out to
  # a second binary declares that one itself.
  def run(argv, readable: [], writable: [], env: {})
    output, error, _ = described_class.run(argv, readable:, writable:, env:)

    output + error
  end

  # The rest of this file skips when bubblewrap is missing, which on CI would quietly
  # retire the whole sandbox from the suite. It is also what an application asked to
  # isolate its decoders checks at boot before refusing to start.
  it "is usable wherever the suite provisions it" do
    skip "bubblewrap is provisioned on CI, not necessarily on a workstation" if ENV["CI"] != "true"

    expect { described_class.ensure_usable! }.not_to raise_error
  end

  context "when bwrap is usable", if: SANDBOX_USABLE do
    # ensure_usable! runs the wrapper the way run does, prlimit included: a limit the host
    # will not grant — a systemd hard limit below what prlimit asks for — fails the boot,
    # not the first decode. A one-byte address space stands in for it here.
    it "refuses to start under limits nothing can run under" do
      stub_const("SandboxedCommand::LIMITS", ["--as=1"])

      expect { described_class.ensure_usable! }.to raise_error(RuntimeError, /\Athe sandbox will not start/)
    end

    # A tool quotes back the path it failed on, and the path carries the upload's name:
    # bytes that are not UTF-8 in it must not turn one error into another.
    # bwrap turns a signal into an exit of 128 + its number: the name is put back for
    # the message, since "exit 137" says nothing to whoever reads Sentry.
    it "names the signal a killed command died of" do
      _, _, status = described_class.run(["/bin/sh", "-c", "kill -9 $$"])

      expect(described_class.status_message(status)).to eq("exit 137, SIGKILL")
    end

    it "reports a plain failure as its exit code" do
      _, _, status = described_class.run(["/bin/sh", "-c", "exit 3"])

      expect(described_class.status_message(status)).to eq("exit 3")
    end

    # 128 is signal zero, which Signal.signame calls "EXIT": not a death.
    it "does not read 128 as a signal" do
      _, _, status = described_class.run(["/bin/sh", "-c", "exit 128"])

      expect(described_class.status_message(status)).to eq("exit 128")
    end

    it "hands back what a command printed, even where it is not UTF-8" do
      expect(run(["/bin/cat", "/nowhere/\xFF".b])).to include("No such file or directory")
    end

    let(:input) { Tempfile.new(["input", ".txt"]).tap { it.write("readable"); it.flush } }

    after { input.close! }

    it "runs the command and returns its output" do
      expect(run(["/bin/echo", "hello"])).to eq("hello\n")
    end

    # At its own path, so the command line the caller built stays valid inside.
    it "reads what the caller declared readable" do
      expect(run(["/bin/cat", input.path], readable: [input.path])).to eq("readable")
    end

    it "hides a file the caller did not declare, even when the argv names it" do
      expect(run(["/bin/cat", input.path])).to include("No such file or directory")
    end

    it "passes on nothing of the environment but what it sets itself" do
      environment = run(["/usr/bin/env"]).lines.to_h { it.chomp.split("=", 2) }

      expect(environment).to eq("XDG_CACHE_HOME" => "/tmp", "PWD" => "/")
    end

    it "hands the decoder its own configuration through env:" do
      expect(run(["/usr/bin/env"], env: { "VIPS_BLOCK_UNTRUSTED" => "1" })).to include("VIPS_BLOCK_UNTRUSTED=1")
    end

    it "hides files the argv does not name" do
      expect(run(["/bin/sh", "-c", "/usr/bin/cat /etc/passwd"], readable: ["/usr/bin/cat"])).to include("No such file or directory")
    end

    it "hides the home directory" do
      expect(run(["/bin/sh", "-c", "/usr/bin/ls /home"], readable: ["/usr/bin/ls"])).to include("No such file or directory")
    end

    it "refuses writes outside the output directory" do
      expect(run(["/bin/sh", "-c", "echo produced > /usr/pwned"])).to include("Read-only file system")
    end

    # Asserted as the command sees them, since that is what stops a runaway decoder —
    # ulimit reports the address space in kilobytes, the cpu time in seconds, a file's
    # size in 512-byte blocks.
    it "bounds what the command may allocate, how long it may compute and what it may write" do
      expect(run(["/bin/sh", "-c", "ulimit -v; ulimit -t; ulimit -f"]).split).to eq(["4194304", "60", "2097152"])
    end

    it "hides the name of the host" do
      expect(run(["/usr/bin/uname", "-n"])).to eq("rails_sandbox\n")
    end

    it "leaves no network interface but the loopback" do
      ip = ["/usr/bin/ip", "/bin/ip", "/usr/sbin/ip", "/sbin/ip"].find { File.executable?(it) }

      interfaces = run([ip, "-o", "link"]).lines.map { it.split(":")[1].strip }

      expect(interfaces).to eq(["lo"])
    end

    it "writes into the output directory when one is given" do
      Dir.mktmpdir do |output|
        run(["/bin/sh", "-c", "echo produced > #{output}/out.txt"], writable: [output])

        expect(File.read("#{output}/out.txt")).to eq("produced\n")
      end
    end

    # Asserted on the directory rather than on what the shell says about it: a failed
    # redirection reads "No such file or directory" under bash and "Directory
    # nonexistent" under dash, and what matters is that nothing was written.
    it "refuses writes to the output directory when none is given" do
      Dir.mktmpdir do |output|
        run(["/bin/sh", "-c", "echo produced > #{output}/out.txt"])

        expect(File).not_to exist("#{output}/out.txt")
      end
    end
  end
end
