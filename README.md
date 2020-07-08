# How to crash nginx + Lua module

# Synopsis:
  1. Have Linux Debian 9 or 10 installed.
  2. Install lua-resty-core and lua-resty-lrucache libraries somehow.
  3. Clone
  ```
  git clone https://github.com/amdei/ng-crashit.git
  ```
  4. Run
  ```
  cd ng-crashit
  ./ng-crashit.bash
  ```
  5. Enjoy.

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
  1. ngninx forced to reload configuration third time - use after free happens in worker process. It may crash with SIGSEGV. Master process see it, and spawn another worker process. 1 master and 2 worker processes are running.
  1. ngninx forced to reload configuration fourth time - use-after-free in master process this time. It may crash with SIGSEGV. 0 master and 2 worker process are running.
  1. systemd sees that master process crashes, and restart it. As worker processes still occupy listen-ports it fails.
  1. As a result we have got coplete mess.

  
# For Developers
  1. I've applied no-pool path to nginx to simplify debugging. Issue reproduceable without it too.
  1. It doesn't matter what LuaJIT being used - issue reproduceable both with vanilla LuaJIT and OpenResty's one.
  1. Can't be easily reproduced with vanilla nginx so far.

Sample ps run after 2nd reload:
```
# ps auxwf | grep [n]ginx
root      44174  1.2  2.3 239028 190760 ?       Ss   01:31   0:00 /usr/bin/valgrind.bin --trace-children=yes --track-origins=yes --num-callers=50 --suppressions=valgrind.suppress ./objs/nginx -p ../crashit/t/servroot -c conf/nginx.conf
root      44178  0.9  2.9 284868 237400 ?       S    01:31   0:00  \_ /usr/bin/valgrind.bin --trace-children=yes --track-origins=yes --num-callers=50 --suppressions=valgrind.suppress ./objs/nginx -p ../crashit/t/servroot -c conf/nginx.conf
root      44180  1.0  2.9 284964 237600 ?       S    01:32   0:00  \_ /usr/bin/valgrind.bin --trace-children=yes --track-origins=yes --num-callers=50 --suppressions=valgrind.suppress ./objs/nginx -p ../crashit/t/servroot -c conf/nginx.conf
```
  valgrind logs:
```
 ==44174== Invalid read of size 8
==44174==    at 0x690014: ngx_ssl_cleanup_ctx (ngx_event_openssl.c:4043)
==44174==    by 0x559E88: ngx_destroy_pool (ngx_palloc.c:48)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Address 0x5ba4578 is 24 bytes inside a block of size 648 free'd
==44174==    at 0x48369AB: free (vg_replace_malloc.c:530)
==44174==    by 0x55A176: ngx_destroy_pool (ngx_palloc.c:76)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Block was alloc'd at
==44174==    at 0x483577F: malloc (vg_replace_malloc.c:299)
==44174==    by 0x646CDE: ngx_alloc (ngx_alloc.c:22)
==44174==    by 0x55A626: ngx_malloc (ngx_palloc.c:137)
==44174==    by 0x55A54B: ngx_palloc (ngx_palloc.c:120)
==44174==    by 0x55ADBB: ngx_pcalloc (ngx_palloc.c:215)
==44174==    by 0x5BECB7: ngx_init_cycle (ngx_cycle.c:75)
==44174==    by 0x54B68C: main (nginx.c:298)
==44174==
==44174== Invalid read of size 8
==44174==    at 0x55593B: ngx_log_error_core (ngx_log.c:126)
==44174==    by 0x69008C: ngx_ssl_cleanup_ctx (ngx_event_openssl.c:4043)
==44174==    by 0x559E88: ngx_destroy_pool (ngx_palloc.c:48)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Address 0x5ba4588 is 40 bytes inside a block of size 648 free'd
==44174==    at 0x48369AB: free (vg_replace_malloc.c:530)
==44174==    by 0x55A176: ngx_destroy_pool (ngx_palloc.c:76)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Block was alloc'd at
==44174==    at 0x483577F: malloc (vg_replace_malloc.c:299)
==44174==    by 0x646CDE: ngx_alloc (ngx_alloc.c:22)
==44174==    by 0x55A626: ngx_malloc (ngx_palloc.c:137)
==44174==    by 0x55A54B: ngx_palloc (ngx_palloc.c:120)
==44174==    by 0x55ADBB: ngx_pcalloc (ngx_palloc.c:215)
==44174==    by 0x5BECB7: ngx_init_cycle (ngx_cycle.c:75)
==44174==    by 0x54B68C: main (nginx.c:298)
==44174==
==44174== Invalid read of size 8
==44174==    at 0x555C58: ngx_log_error_core (ngx_log.c:159)
==44174==    by 0x69008C: ngx_ssl_cleanup_ctx (ngx_event_openssl.c:4043)
==44174==    by 0x559E88: ngx_destroy_pool (ngx_palloc.c:48)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Address 0x5ba4578 is 24 bytes inside a block of size 648 free'd
==44174==    at 0x48369AB: free (vg_replace_malloc.c:530)
==44174==    by 0x55A176: ngx_destroy_pool (ngx_palloc.c:76)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Block was alloc'd at
==44174==    at 0x483577F: malloc (vg_replace_malloc.c:299)
==44174==    by 0x646CDE: ngx_alloc (ngx_alloc.c:22)
==44174==    by 0x55A626: ngx_malloc (ngx_palloc.c:137)
==44174==    by 0x55A54B: ngx_palloc (ngx_palloc.c:120)
==44174==    by 0x55ADBB: ngx_pcalloc (ngx_palloc.c:215)
==44174==    by 0x5BECB7: ngx_init_cycle (ngx_cycle.c:75)
==44174==    by 0x54B68C: main (nginx.c:298)
==44174==
==44174== Invalid read of size 8
==44174==    at 0x555CA7: ngx_log_error_core (ngx_log.c:163)
==44174==    by 0x69008C: ngx_ssl_cleanup_ctx (ngx_event_openssl.c:4043)
==44174==    by 0x559E88: ngx_destroy_pool (ngx_palloc.c:48)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Address 0x5ba4578 is 24 bytes inside a block of size 648 free'd
==44174==    at 0x48369AB: free (vg_replace_malloc.c:530)
==44174==    by 0x55A176: ngx_destroy_pool (ngx_palloc.c:76)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Block was alloc'd at
==44174==    at 0x483577F: malloc (vg_replace_malloc.c:299)
==44174==    by 0x646CDE: ngx_alloc (ngx_alloc.c:22)
==44174==    by 0x55A626: ngx_malloc (ngx_palloc.c:137)
==44174==    by 0x55A54B: ngx_palloc (ngx_palloc.c:120)
==44174==    by 0x55ADBB: ngx_pcalloc (ngx_palloc.c:215)
==44174==    by 0x5BECB7: ngx_init_cycle (ngx_cycle.c:75)
==44174==    by 0x54B68C: main (nginx.c:298)
==44174==
==44174== Invalid read of size 8
==44174==    at 0x555D1A: ngx_log_error_core (ngx_log.c:167)
==44174==    by 0x69008C: ngx_ssl_cleanup_ctx (ngx_event_openssl.c:4043)
==44174==    by 0x559E88: ngx_destroy_pool (ngx_palloc.c:48)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Address 0x5ba45a8 is 72 bytes inside a block of size 648 free'd
==44174==    at 0x48369AB: free (vg_replace_malloc.c:530)
==44174==    by 0x55A176: ngx_destroy_pool (ngx_palloc.c:76)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Block was alloc'd at
==44174==    at 0x483577F: malloc (vg_replace_malloc.c:299)
==44174==    by 0x646CDE: ngx_alloc (ngx_alloc.c:22)
==44174==    by 0x55A626: ngx_malloc (ngx_palloc.c:137)
==44174==    by 0x55A54B: ngx_palloc (ngx_palloc.c:120)
==44174==    by 0x55ADBB: ngx_pcalloc (ngx_palloc.c:215)
==44174==    by 0x5BECB7: ngx_init_cycle (ngx_cycle.c:75)
==44174==    by 0x54B68C: main (nginx.c:298)
==44174==
==44174== Invalid read of size 8
==44174==    at 0x555E3F: ngx_log_error_core (ngx_log.c:172)
==44174==    by 0x69008C: ngx_ssl_cleanup_ctx (ngx_event_openssl.c:4043)
==44174==    by 0x559E88: ngx_destroy_pool (ngx_palloc.c:48)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Address 0x5ba4590 is 48 bytes inside a block of size 648 free'd
==44174==    at 0x48369AB: free (vg_replace_malloc.c:530)
==44174==    by 0x55A176: ngx_destroy_pool (ngx_palloc.c:76)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Block was alloc'd at
==44174==    at 0x483577F: malloc (vg_replace_malloc.c:299)
==44174==    by 0x646CDE: ngx_alloc (ngx_alloc.c:22)
==44174==    by 0x55A626: ngx_malloc (ngx_palloc.c:137)
==44174==    by 0x55A54B: ngx_palloc (ngx_palloc.c:120)
==44174==    by 0x55ADBB: ngx_pcalloc (ngx_palloc.c:215)
==44174==    by 0x5BECB7: ngx_init_cycle (ngx_cycle.c:75)
==44174==    by 0x54B68C: main (nginx.c:298)
==44174==
==44174== Invalid read of size 8
==44174==    at 0x555EBC: ngx_log_error_core (ngx_log.c:183)
==44174==    by 0x69008C: ngx_ssl_cleanup_ctx (ngx_event_openssl.c:4043)
==44174==    by 0x559E88: ngx_destroy_pool (ngx_palloc.c:48)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Address 0x5ba4580 is 32 bytes inside a block of size 648 free'd
==44174==    at 0x48369AB: free (vg_replace_malloc.c:530)
==44174==    by 0x55A176: ngx_destroy_pool (ngx_palloc.c:76)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Block was alloc'd at
==44174==    at 0x483577F: malloc (vg_replace_malloc.c:299)
==44174==    by 0x646CDE: ngx_alloc (ngx_alloc.c:22)
==44174==    by 0x55A626: ngx_malloc (ngx_palloc.c:137)
==44174==    by 0x55A54B: ngx_palloc (ngx_palloc.c:120)
==44174==    by 0x55ADBB: ngx_pcalloc (ngx_palloc.c:215)
==44174==    by 0x5BECB7: ngx_init_cycle (ngx_cycle.c:75)
==44174==    by 0x54B68C: main (nginx.c:298)
==44174==
==44174== Invalid read of size 4
==44174==    at 0x555EE2: ngx_log_error_core (ngx_log.c:183)
==44174==    by 0x69008C: ngx_ssl_cleanup_ctx (ngx_event_openssl.c:4043)
==44174==    by 0x559E88: ngx_destroy_pool (ngx_palloc.c:48)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Address 0x5ba4cc0 is 0 bytes inside a block of size 800 free'd
==44174==    at 0x48369AB: free (vg_replace_malloc.c:530)
==44174==    by 0x55A176: ngx_destroy_pool (ngx_palloc.c:76)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Block was alloc'd at
==44174==    at 0x483577F: malloc (vg_replace_malloc.c:299)
==44174==    by 0x646CDE: ngx_alloc (ngx_alloc.c:22)
==44174==    by 0x55A626: ngx_malloc (ngx_palloc.c:137)
==44174==    by 0x55A54B: ngx_palloc (ngx_palloc.c:120)
==44174==    by 0x5BDEFB: ngx_list_init (ngx_list.h:39)
==44174==    by 0x5BFFC9: ngx_init_cycle (ngx_cycle.c:148)
==44174==    by 0x54B68C: main (nginx.c:298)
==44174==
==44174== Invalid read of size 8
==44174==    at 0x556027: ngx_log_error_core (ngx_log.c:189)
==44174==    by 0x69008C: ngx_ssl_cleanup_ctx (ngx_event_openssl.c:4043)
==44174==    by 0x559E88: ngx_destroy_pool (ngx_palloc.c:48)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Address 0x5ba4580 is 32 bytes inside a block of size 648 free'd
==44174==    at 0x48369AB: free (vg_replace_malloc.c:530)
==44174==    by 0x55A176: ngx_destroy_pool (ngx_palloc.c:76)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Block was alloc'd at
==44174==    at 0x483577F: malloc (vg_replace_malloc.c:299)
==44174==    by 0x646CDE: ngx_alloc (ngx_alloc.c:22)
==44174==    by 0x55A626: ngx_malloc (ngx_palloc.c:137)
==44174==    by 0x55A54B: ngx_palloc (ngx_palloc.c:120)
==44174==    by 0x55ADBB: ngx_pcalloc (ngx_palloc.c:215)
==44174==    by 0x5BECB7: ngx_init_cycle (ngx_cycle.c:75)
==44174==    by 0x54B68C: main (nginx.c:298)
==44174==
==44174== Invalid read of size 4
==44174==    at 0x55604D: ngx_log_error_core (ngx_log.c:189)
==44174==    by 0x69008C: ngx_ssl_cleanup_ctx (ngx_event_openssl.c:4043)
==44174==    by 0x559E88: ngx_destroy_pool (ngx_palloc.c:48)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Address 0x5ba4cc0 is 0 bytes inside a block of size 800 free'd
==44174==    at 0x48369AB: free (vg_replace_malloc.c:530)
==44174==    by 0x55A176: ngx_destroy_pool (ngx_palloc.c:76)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Block was alloc'd at
==44174==    at 0x483577F: malloc (vg_replace_malloc.c:299)
==44174==    by 0x646CDE: ngx_alloc (ngx_alloc.c:22)
==44174==    by 0x55A626: ngx_malloc (ngx_palloc.c:137)
==44174==    by 0x55A54B: ngx_palloc (ngx_palloc.c:120)
==44174==    by 0x5BDEFB: ngx_list_init (ngx_list.h:39)
==44174==    by 0x5BFFC9: ngx_init_cycle (ngx_cycle.c:148)
==44174==    by 0x54B68C: main (nginx.c:298)
==44174==
==44174== Invalid read of size 8
==44174==    at 0x5560BE: ngx_log_error_core (ngx_log.c:195)
==44174==    by 0x69008C: ngx_ssl_cleanup_ctx (ngx_event_openssl.c:4043)
==44174==    by 0x559E88: ngx_destroy_pool (ngx_palloc.c:48)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Address 0x5ba45c0 is 96 bytes inside a block of size 648 free'd
==44174==    at 0x48369AB: free (vg_replace_malloc.c:530)
==44174==    by 0x55A176: ngx_destroy_pool (ngx_palloc.c:76)
==44174==    by 0x5C73E6: ngx_init_cycle (ngx_cycle.c:761)
==44174==    by 0x65D4A7: ngx_master_process_cycle (ngx_process_cycle.c:235)
==44174==    by 0x54C23F: main (nginx.c:389)
==44174==  Block was alloc'd at
==44174==    at 0x483577F: malloc (vg_replace_malloc.c:299)
==44174==    by 0x646CDE: ngx_alloc (ngx_alloc.c:22)
==44174==    by 0x55A626: ngx_malloc (ngx_palloc.c:137)
==44174==    by 0x55A54B: ngx_palloc (ngx_palloc.c:120)
==44174==    by 0x55ADBB: ngx_pcalloc (ngx_palloc.c:215)
==44174==    by 0x5BECB7: ngx_init_cycle (ngx_cycle.c:75)
==44174==    by 0x54B68C: main (nginx.c:298)
==44174==

```
