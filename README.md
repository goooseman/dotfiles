# Goooseman's dotfiles

> .dotfiles and ansible setup playbook for nodejs, js and even react-native developer working on MacOS/Ubuntu/ElementaryOS

This project consists of two parts:

- `.dotfiles` for zsh including for oh-my-zsh with some custom aliases, boot scripts and path variables additions
- Ansible setup playbook which you need to run on a fresh install of the system which will automatically install everything you need for a comfortable work, such as:
    - 🔤 [Firacode font](https://app.programmingfonts.org/#firacode) - cool font for developers with ligatures.
    - ⌨️ [fnm](https://github.com/Schniz/fnm) - `nvm` replacement. Installs different nodejs on your machine. Ansible will install nodejs 10.14 automatically and make it default.
    - ⌨️ [zsh](https://ohmyz.sh/) - `bash` replacement. `.dotfiles` folder includes a lot of additional stuff for `zsh`.
    - 💻 [VS Code](https://code.visualstudio.com/) - development IDE. Includes `code` cli tool.
    Following settings will automatically applied:
        - font changed to Fira Code
        - ligatures enabled
        - rulers at width 80, 100, 120 are added
        - preview mode disabled (clicking the file opens it in a persistant editor)
        - extentions automatically installed:
            - Gitlens
            - Tslint
            - Eslint
            - Prettier
    - 💻 [Sublime Text](https://www.sublimetext.com/) - text editor. Includes `subl` cli tool.
    - 💻 [Sublime Merge](https://www.sublimemerge.com/) - GIT client from the authors of Sublime Text. Includes `smerge` cli tool.
    - 💻 [Robo 3T](https://robomongo.org/) - MongoDB explorer tool
    - 💻 [Reactotron](https://github.com/infinitered/reactotron) - inspector for React Native projects.
    - 💻 [Postman](https://www.getpostman.com/) - API development and testing tool.
    - 💻 [Android Studio](https://developer.android.com/studio) - development IDE for Android developers (needed for `react-native` development).
    - ⌨️ [Docker](https://www.docker.com/) - application containerization.
    - ⌨️ [git-flow-avh](https://github.com/petervanderdoes/gitflow-avh) - git extension to work with [Git Flow](https://danielkummer.github.io/git-flow-cheatsheet/) branching model easily.
    - ️️⌨️ [micro](https://github.com/zyedidia/micro) - terminal-based text editor.
    - ⌨️ [wifi-password](https://github.com/rauchg/wifi-password) - cli to get the password of currently connected to WiFi network. **MacOS only**
    - Additional tweaks:
        - `git` name and email are asked and set up using `chezmoi` templates.
    - Additional **Ubuntu** tweaks:
        - `fs.inotify.max_user_watches` is set to 524288 to prevent problems with `Jest`, `Webpack` and `react-native` because of watchers number.

**Legend** 
  - 💻 For GUI tools (can be launched using Applications)
  - ⌨️ For CLI tools (can be launched in the Terminal)
  - 🔤 For fonts

## Installation

1. Install [chezmoi](https://github.com/twpayne/chezmoi)
  - On Mac OS:
    - `/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`
    - `brew install twpayne/taps/chezmoi`
  - On Ubuntu:
    - `sudo apt install git`
    - `wget https://github.com/twpayne/chezmoi/releases/download/v1.4.1/chezmoi_1.4.1-527_linux_amd64.deb`
    - `sudo dpkg -i chezmoi_1.4.1-527_linux_amd64.deb`
2. Init dotfiles
  - `chezmoi init --apply https://github.com/goooseman/dotfiles.git`
3. If you want to set up your computer automatically
  - On Mac:
    - `~/.dotfiles/setup/osx.sh`
  - On Ubuntu
    - `~/.dotfiles/setup/ubuntu.sh`

Provide your user account password if BECOME password is asked.

## WIP

Current features are still **WIP**, help will be appreciated:
- ⌨️ [Android SDK](https://developer.android.com/studio/releases/sdk-tools) - mandatory SDK for `react-native` development. Includes `adb`, `android`, `emulator` cli tools. 
- Android emulators automatic set up:
  - Nexus 5
  - Nexus 7
  - Nexus 10

## Raspberry Pi

This project contains my configuration of raspberry pi headless media server including plex, qbittorrent, aria2 with web interface.

### Setup

1. Download `Raspbian Stretch Lite` image from [official website](https://www.raspberrypi.org/downloads/raspbian/) and burn it to SD card. Create an empty `ssh` or `ssh.txt` file in the boot partition of the sd card.
1. Boot raspberry, connect with ssh from other computer: `ssh -o PubkeyAuthentication=no pi@raspberrypi.local` (password: `raspberry`)
1. Change user password: `sudo passwd pi`
1. Install chezmoi:
  - `sudo apt-get install git`
  - `wget https://github.com/twpayne/chezmoi/releases/download/v1.4.2/chezmoi_1.4.2-621_linux_armel.deb`
  - `sudo dpkg -i chezmoi_1.4.2-621_linux_armel.deb`
1. Init dotfiles: `chezmoi init --apply https://github.com/goooseman/dotfiles.git`
1. Generate ssh key to access your Raspberry and copy them (on your local machine):
  - `ssh-copy-id -i ~/.ssh/pi.pub -o PubkeyAuthentication=no pi@raspberrypi.local`
1. Run setup script: `~/.dotfiles/setup/pi.sh`
1. `sudo connectd_installer`
1. Reboot `sudo reboot`


### TODO

- [Plex](https://github.com/jaymoulin/docker-plex)
