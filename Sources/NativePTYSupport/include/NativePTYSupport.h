#include <sys/types.h>
#include <sys/ioctl.h>
pid_t native_pty_spawn(const char *executable, char *const argv[], char *const environment[],
                       const struct winsize *size, int *descriptor);
