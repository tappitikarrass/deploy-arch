# deploy-arch (WIP) 🫠

## :pencil2: Synopsis

Bash script for quick deployment of **MY** scripts, dotfiles and setting to Arch Linux.

It's supposed to be used in WSL, Docker and regular Arch installations (just after `arch-chroot` part).

## Installation

### :package: Docker(not yet tested on Windows)

1. Install `docker` and `make`.
1. Run `make` to build docker image and run a container shell.
1. Then run `./deploy.sh` to start script.

> :duck: The script prompts user to edit `sudoers` file and set a passwords.
> I don't seen much point in changing this behaviour.
> The script takes about 5 minutes, so you can wait and go through all propmts.
> It's faster that manual deployment anyway.

### :monkey: WSL

I'll test it soon.

### :floppy_disk: Plain

I'll test it soon.
