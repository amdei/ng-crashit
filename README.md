# How to crash nginx + Lua module
TOC
# Synopsis:
  1. Have Linux Debian 9 or 10 installed.
  2. Clone
  ```
  git clone https://github.com/amdei/ng-crashit.git
  ```
  3. Run
  ```
  cd ng-crashit
  ./ng-crashit.bash
  ```
  4. Enjoy.

# TL;RD
  Issue is VERY fragile - if log-files names being changed it may disappears.
  So up to now **I wasn't able to make simple reproducer**, and this repo is a preliminary set of scripts intended to show how to start with it reproduction.

# Long story:
  Recently I run into a strange issue: use-after-free in nginx on reload configuration when lua-nginx-module used.
  It happens only if:
  1. Nginx 1.18.0 only. Can't be reproduced on 1.16.1
  1. SSL module is compiled with nginx.
  1. There are **two** servers in nginx config
  1. Only on 3-rd reload (and subsequent reloads too)
    
  Sequense in my case is the following:
  
  1. ngninx being run - everything is Ok. 1 master and 1 worker process is running.
  1. ngninx forced to reload configuration - everything is Ok. 1 master and 1 worker process is running.
  1. ngninx forced to reload configuration second time - everything is Ok. 1 master and 1 worker process is running.
  1. ngninx forced to reload configuration third time - use after free happens in worker process. It may crash. Master process see it, and spawn another worker process. 1 master and 2 worker processes are running.
  1. ngninx forced to reload configuration fourth time - use-after-free in master process this time. It may crash. 0 master and 2 worker process are running.
  1. systemd sees that master process crashes, and restart it. As worker processes still occupy listen-ports it fails.
  1. As a result we have got coplete mess.

  
  
