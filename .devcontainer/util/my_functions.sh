#!/bin/bash
# ======================================================================
#          ------- Custom Functions -------                            #
#  Space for adding custom functions so each repo can customize as.    # 
#  needed.                                                             #
# ======================================================================


customFunction(){
  printInfoSection "This is a custom function that calculates 1 + 1"

  printInfo "1 + 1 = $(( 1 + 1 ))"

}

# Dynamically install + ready an OpenSSH server inside the container.
# Why: `gh codespace ssh` (used by the Enablement App to relay an in-app terminal
# into a user-owned Codespace) needs an sshd binary in the container. The stock
# framework image `shinojosa/dt-enablement` ships none, so GitHub fails with
# "failed to start SSH server". This proves we can add the tool on demand from
# a per-repo override; if it works we fold openssh-server into the image or into
# the framework functions.sh. Idempotent; never logs secrets.
sshd(){
  printInfoSection "Enabling OpenSSH server (for gh codespace ssh terminal relay)"

  # Detect via the binary path / package, NOT `command -v sshd` — this function is
  # itself named `sshd` and would shadow the lookup.
  if [ -x /usr/sbin/sshd ]; then
    printInfo "openssh-server already present"
  else
    printInfo "Installing openssh-server..."
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server
  fi

  # Host keys + privilege-separation dir so GitHub's agent can start sshd on demand.
  sudo ssh-keygen -A >/dev/null 2>&1
  sudo mkdir -p /run/sshd

  if [ -x /usr/sbin/sshd ]; then
    printInfo "OpenSSH server ready — gh codespace ssh can now attach"
  else
    printWarn "openssh-server install did not produce /usr/sbin/sshd"
  fi
}