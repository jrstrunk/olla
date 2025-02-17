# o11a

o11a uses lots of sqlite database files, each needing a file handle from the OS. If a connection to all of them
is always open, we will eventually run out of file handles (1024 by default). This can be increased by Editing /etc/security/limits.conf to set per-user limits.