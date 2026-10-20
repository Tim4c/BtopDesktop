#include "./include/NativePTYSupport.h"
#include <util.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>

pid_t native_pty_spawn(const char *executable, char *const argv[], char *const environment[],
                       const struct winsize *size, int *descriptor) {
    // Restore signal delivery inherited from Swift concurrency worker threads.
    // Only async-signal-safe operations run after fork in this multithreaded app.
    pid_t child = forkpty(descriptor, NULL, NULL, (struct winsize *)size);
    if (child == 0) {
        sigset_t empty;
        sigemptyset(&empty);
        sigprocmask(SIG_SETMASK, &empty, NULL);
        signal(SIGINT, SIG_DFL);
        signal(SIGTERM, SIG_DFL);
        signal(SIGWINCH, SIG_DFL);
        signal(SIGPIPE, SIG_DFL);
        execve(executable, argv, environment);
        _exit(127);
    }
    if (child > 0) {
        int flags = fcntl(*descriptor, F_GETFL);
        fcntl(*descriptor, F_SETFL, flags | O_NONBLOCK);
        fcntl(*descriptor, F_SETFD, FD_CLOEXEC);
    }
    return child;
}
