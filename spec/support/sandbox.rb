# frozen_string_literal: true

# The sandbox specs run where bubblewrap is provisioned — CI, and the workstations that
# installed it — and skip where it is not, rather than failing on a machine that never
# claimed to isolate anything. A machine that has both binaries and still cannot start
# the sandbox is misconfigured, and skipping there retires the specs that would say so.
# Asked once: the check builds a sandbox, which costs a fork.
SANDBOX_USABLE =
  begin
    SandboxedCommand.ensure_usable!
    true
  rescue RuntimeError
    raise if [SandboxedCommand::BWRAP, SandboxedCommand::PRLIMIT].all? { File.executable?(it) }

    false
  end
