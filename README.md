# o11a

o11a uses lots of sqlite database files, each needing a file handle from the OS. If a connection to all of them
is always open, we will eventually run out of file handles (1024 by default). This can be increased by Editing /etc/security/limits.conf to set per-user limits.

# Performance considerations

The client components of o11a are lazily rendered, so when the server component gets a new message, only the client components that need to display it are re-rendered. This is good! The server component does have to completely re-render the entire page, however, for every new message. Since each server component is subscribed to the entire audit discussion, every new message causes all pages of an audit to re-render. This is wasteful most of the time. To improve performance, this could either be disabled, or we could have each page subscribe to a topic (probably of their own page), so that they only get updates for the messages they are interested in (probably messages that mention a line on their page).
