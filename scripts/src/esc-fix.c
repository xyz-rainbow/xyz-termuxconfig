#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pty.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

static int master_fd = -1;
static pid_t child_pid = -1;
static struct termios orig_termios;
static int termios_saved = 0;

static void restore_term(void) {
    if (termios_saved) {
        tcsetattr(STDIN_FILENO, TCSANOW, &orig_termios);
    }
}

static void sigwinch_handler(int sig) {
    (void)sig;
    if (master_fd >= 0) {
        struct winsize ws;
        if (ioctl(STDIN_FILENO, TIOCGWINSZ, &ws) == 0) {
            ioctl(master_fd, TIOCSWINSZ, &ws);
        }
    }
}

// Mapea Ctrl+Alt+[1..¡] (recibido como \x1b seguido del carácter/código de control) a F1..F12
static const char *ctrl_alt_to_f(unsigned char c) {
    switch (c) {
        case '1':  return "\x1bOP";    // Ctrl+Alt+1 -> F1
        case 0x00:
        case '2':  return "\x1bOQ";    // Ctrl+Alt+2 -> F2
        case '3':  return "\x1bOR";    // Ctrl+Alt+3 -> F3
        case 0x1c:
        case '4':  return "\x1bOS";    // Ctrl+Alt+4 -> F4
        case 0x1d:
        case '5':  return "\x1b[15~";  // Ctrl+Alt+5 -> F5
        case 0x1e:
        case '6':  return "\x1b[17~";  // Ctrl+Alt+6 -> F6
        case 0x1f:
        case '7':  return "\x1b[18~";  // Ctrl+Alt+7 -> F7
        case 0x7f:
        case '8':  return "\x1b[19~";  // Ctrl+Alt+8 -> F8
        case '9':  return "\x1b[20~";  // Ctrl+Alt+9 -> F9
        case '0':  return "\x1b[21~";  // Ctrl+Alt+0 -> F10
        case '\'':
        case '?':  return "\x1b[23~";  // Ctrl+Alt+' -> F11
        default:   return NULL;
    }
}

int main(int argc, char *argv[]) {
    if (getenv("ESC_FIX_ACTIVE") != NULL || !isatty(STDIN_FILENO)) {
        if (argc > 1) {
            execvp(argv[1], &argv[1]);
            perror("execvp");
            return 1;
        }
        return 0;
    }

    struct winsize ws;
    struct winsize *wsp = NULL;
    if (ioctl(STDIN_FILENO, TIOCGWINSZ, &ws) == 0) {
        wsp = &ws;
    }

    if (tcgetattr(STDIN_FILENO, &orig_termios) == 0) {
        termios_saved = 1;
        atexit(restore_term);
    }

    child_pid = forkpty(&master_fd, NULL, termios_saved ? &orig_termios : NULL, wsp);
    if (child_pid < 0) {
        perror("forkpty");
        return 1;
    }

    if (child_pid == 0) {
        setenv("ESC_FIX_ACTIVE", "1", 1);
        if (argc > 1) {
            execvp(argv[1], &argv[1]);
        } else {
            const char *shell = getenv("SHELL");
            if (!shell) shell = "/data/data/com.termux/files/usr/bin/bash";
            execl(shell, shell, "-l", NULL);
        }
        perror("exec");
        _exit(1);
    }

    if (termios_saved) {
        struct termios raw = orig_termios;
        cfmakeraw(&raw);
        tcsetattr(STDIN_FILENO, TCSANOW, &raw);
    }

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = sigwinch_handler;
    sigaction(SIGWINCH, &sa, NULL);

    struct pollfd fds[2];
    fds[0].fd = STDIN_FILENO;
    fds[0].events = POLLIN;
    fds[1].fd = master_fd;
    fds[1].events = POLLIN;

    unsigned char buf[4096];
    int pending_c2 = 0;
    int pending_esc = 0;

    while (1) {
        int timeout = pending_esc ? 50 : -1;
        int ret = poll(fds, 2, timeout);
        if (ret < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (ret == 0 && pending_esc) {
            pending_esc = 0;
            ssize_t w = write(master_fd, "\x1b", 1);
            (void)w;
            continue;
        }

        if (fds[0].revents & POLLIN) {
            ssize_t n = read(STDIN_FILENO, buf, sizeof(buf));
            if (n <= 0) break;
            for (ssize_t i = 0; i < n; i++) {
                unsigned char b = buf[i];
                if (pending_c2) {
                    pending_c2 = 0;
                    if (pending_esc && (b == 0xA1 || b == 0xBF)) {
                        // Ctrl+Alt+¡ (\x1b seguido de UTF-8 '¡' 0xC2 0xA1) -> F12
                        pending_esc = 0;
                        ssize_t w = write(master_fd, "\x1b[24~", 5);
                        (void)w;
                    } else if (b == 0xBA) {
                        // Tecla física Esc sola ('º' = 0xC2 0xBA) -> Escape real (0x1B)
                        if (pending_esc) {
                            // Ctrl+Alt+Esc -> escribe 'º' literal por si se necesita
                            pending_esc = 0;
                            ssize_t w = write(master_fd, "\xc2\xba", 2);
                            (void)w;
                        } else {
                            ssize_t w = write(master_fd, "\x1b", 1);
                            (void)w;
                        }
                    } else {
                        // Cualquier otro carácter UTF-8 0xC2 (como Shift+Esc = 'ª' 0xC2 0xAA) pasa intacto
                        if (pending_esc) {
                            pending_esc = 0;
                            ssize_t w1 = write(master_fd, "\x1b", 1);
                            (void)w1;
                        }
                        unsigned char pair[2] = {0xC2, b};
                        ssize_t w2 = write(master_fd, pair, 2);
                        (void)w2;
                    }
                } else if (b == 0xC2) {
                    pending_c2 = 1;
                } else if (pending_esc) {
                    pending_esc = 0;
                    const char *seq = ctrl_alt_to_f(b);
                    if (seq) {
                        ssize_t w = write(master_fd, seq, strlen(seq));
                        (void)w;
                    } else {
                        unsigned char pair[2] = {0x1B, b};
                        ssize_t w = write(master_fd, pair, 2);
                        (void)w;
                    }
                } else if (b == 0x1B) {
                    pending_esc = 1;
                } else {
                    ssize_t w = write(master_fd, &b, 1);
                    (void)w;
                }
            }
        }

        if (fds[1].revents & (POLLIN | POLLHUP | POLLERR)) {
            ssize_t n = read(master_fd, buf, sizeof(buf));
            if (n <= 0) break;
            ssize_t w = write(STDOUT_FILENO, buf, n);
            (void)w;
        }
    }

    restore_term();
    int status = 0;
    waitpid(child_pid, &status, 0);
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    return 0;
}
