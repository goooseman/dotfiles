# Goooseman's dotfiles

> .dotfiles and ansible setup playbook for nodejs, js and even react-native developer working on MacOSX/Ubuntu (ElementaryOS)

This project consists of two parts:

- .dotfiles for zsh including for oh-my-zsh with some custom aliases, boot scripts and path variables additions
- Ansible setup playbook which you need to run on a fresh install of the system which will automatically install everything you need for a comfortable work, such as:
    - 🔤 [Firacode font](https://app.programmingfonts.org/#firacode) - cool font for developers with ligatures.
    - ⌨️ [fnm](https://github.com/Schniz/fnm) - `nvm` replacement. Installs different nodejs on your machine. Ansible will install nodejs 10.14 automatically and make it default.
    - ⌨️ [zsh](https://ohmyz.sh/) - `bash` replacement. `.dotfiles` folder includes a lot of additional stuff for `zsh`.
    - 💻 [VS Code](https://code.visualstudio.com/) - development IDE. 
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
    - 💻 [Sublime Text](https://www.sublimetext.com/) - text editor.
    - 💻 [Sublime Merge](https://www.sublimemerge.com/) - GIT client from the authors of Sublime Text.
    - 💻 [Robo 3T](https://robomongo.org/) - MongoDB explorer tool
    - 💻 [Reactotron](https://github.com/infinitered/reactotron) - inspector for React Native projects.
    - 💻 [Postman](https://www.getpostman.com/) - API development and testing tool.
    - ⌨️ [Android SDK](https://developer.android.com/studio/releases/sdk-tools) - mandatory SDK for `react-native` development. Includes `adb`, `android`, `emulator` cli tools.
    - 💻 [Android Studio](https://developer.android.com/studio) - development IDE for Android developers (needed for `react-native` development).

**Legend** 
  - 💻 For GUI tools (can be launched using Applications)
  - ⌨️ For CLI tools (can be launched in the Terminal)
  - 🔤 For fonts