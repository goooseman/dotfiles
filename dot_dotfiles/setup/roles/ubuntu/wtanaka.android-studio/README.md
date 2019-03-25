[![Build Status](https://travis-ci.org/wtanaka/ansible-role-android-studio.svg?branch=master)](https://travis-ci.org/wtanaka/ansible-role-android-studio)
[![CircleCI](https://circleci.com/gh/wtanaka/ansible-role-android-studio.svg?style=svg)](https://circleci.com/gh/wtanaka/ansible-role-android-studio)

wtanaka.android-studio
======================

Installs Android Studio

Example Playbook
----------------

    - hosts: servers
      roles:
         - wtanaka.android-studio

Install a specific version

    - hosts: servers
      roles:
         - role: wtanaka.android-studio
           android_studio_version: "2.2.3.0"
           android_studio_build "145.3537739"

License
-------

GPLv2

Author Information
------------------

http://wtanaka.com/
