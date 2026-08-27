# frozen_string_literal: true

# The sandbox specs run where the sandbox starts — CI, and the workstations that can —
# and skip where it does not, rather than failing on a machine that never claimed to
# isolate anything. Asked once: the check builds a sandbox, which costs a fork.
SANDBOX_USABLE =
  begin
    SandboxedCommand.ensure_usable!
    true
  rescue RuntimeError => error
    # Said out loud rather than raised: a workstation may carry bubblewrap (flatpak pulls
    # it in) under a kernel that refuses it user namespaces, and that is no reason to
    # lose the whole suite. CI, which provisions the sandbox, has a spec that fails.
    warn "sandbox specs skipped: #{error.message}"
    false
  end
