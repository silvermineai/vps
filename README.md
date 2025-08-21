# VPS
Inspired by https://github.com/MarcoWorms/vibecoder-fullstack-vps-quickstart.

Security:
1. Sets up new user 
1. Enable ufp
1. Relies on pre-configured hetzner firewall

Other benefits
1. Sets up ssh key (pre-installed on hetzner)
1. sets up tailscale ssh
1. installs claude code and omnara

```
curl -sSL https://raw.githubusercontent.com/silvermineai/vps/main/startup.sh | sudo bash
```

# First-time, One-tie Hetzner Setup
1. Open console.hetzner.com: create a new dashboard.
1. Create SSH key on computer (or in 1password). Then download as OpenSSH and save as `~/.ssh/hetzner`.
1. Upload public key to https://console.hetzner.com/projects/11620163/security/sshkeys, nanme it "Hetzner"
1. Set up firewalls: https://console.hetzner.com/projects/11620163/firewalls. Only allow 22.
1. Go to security/api tokens to get an api token: https://console.hetzner.com/projects/11620163/security/tokens
1. `brew install hcloud`
1. Create context for hcloud:
```
➤ hcloud context create silvermineai
Token:
```
1. gh tokens: https://github.com/settings/personal-access-tokens/new
    1. token-name: gh-auth
    1. resouce owner: silvermine ai
    1. expiration: 90d
    1. all repositories
    1. Permissions: 
        Contents > read & write
        Pull requests> read & write


# Manual creation
1. Go to https://console.hetzner.com/projects/11620163/servers
1. Create new 2 GB, 2 CPU instance, ipv6 only (no ipv4), defaults: [firewall, ssh key]

# Programmatic Creation
1. Create new vps
```
hcloud server create \
  --name wfp \
  --type cpx11 \
  --image ubuntu-22.04 \
  --location hil \
  --firewall firewall-1 \
  --ssh-key Hetzner 

# can add this if you don't need gh auth login ()
  <!-- --without-ipv4 -->
```
1. SSH in: `ssh -i ~/.ssh/hetzner root@{ip_address}`
1. Run bash script (startup.sh)
1. Set up [tailscale ssh](https://tailscale.com/kb/1193/tailscale-ssh)
1. Log in with `ssh root@ubuntu-2gb-hil-1` (change the name and what not).

# Fastest mode (using my own)
```
export name=wfp
hnew ${name}
export IP=5.78.41.48
ssh-add-host ${name} root@${IP} ~/.ssh/hetzner
# clean up the ip address
ssh-keygen -R ${IP}
ssh wfp
curl -sSL https://raw.githubusercontent.com/silvermineai/vps/main/startup.sh | sudo bash
```


1. sudo tailscale up --ssh


## Troubleshooting

cat ~/.ssh/authorized_keys