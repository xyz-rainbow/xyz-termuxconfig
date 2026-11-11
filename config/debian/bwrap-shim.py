#!/usr/bin/env python3
import os, sys

args = sys.argv[1:]
bind_map = {}
cmd_idx = None

two_arg_flags = {
    "--ro-bind", "--bind", "--ro-bind-try", "--bind-try",
    "--dev-bind", "--dev-bind-try", "--symlink", "--setenv",
    "--chmod", "--remount-ro"
}
one_arg_flags = {
    "--proc", "--dev", "--tmpfs", "--mqueue", "--dir",
    "--chdir", "--hostname", "--seccomp", "--add-seccomp-fd",
    "--block-fd", "--userns-block-fd", "--info-fd",
    "--json-status-fd", "--sync-fd", "--unsetenv", "--lock-file",
    "--bind-data", "--ro-bind-data", "--file", "--uid", "--gid",
    "--cap-add", "--cap-drop", "--perms", "--size"
}

i = 0
while i < len(args):
    a = args[i]
    if a == "--":
        cmd_idx = i + 1
        break
    elif a in two_arg_flags:
        if a == "--setenv" and i + 2 < len(args):
            os.environ[args[i+1]] = args[i+2]
        elif a != "--setenv" and i + 2 < len(args):
            src, dst = args[i+1], args[i+2]
            bind_map[dst] = src
        i += 3
        continue
    elif a in one_arg_flags:
        if a == "--unsetenv" and i + 1 < len(args):
            os.environ.pop(args[i+1], None)
        i += 2
        continue
    elif a.startswith("-"):
        i += 1
        continue
    else:
        cmd_idx = i
        break

if cmd_idx is None or cmd_idx >= len(args):
    sys.exit(0)

cmd = args[cmd_idx:]
mapped_cmd = []
for arg in cmd:
    prefix = ""
    val = arg
    if val.startswith("file://"):
        prefix = "file://"
        val = val[7:]
    for dst in sorted(bind_map.keys(), key=len, reverse=True):
        if dst in ("/", "/usr", "/lib", "/lib64", "/bin", "/sbin", "/etc"):
            continue
        if val == dst:
            val = bind_map[dst]
            break
        elif val.startswith(dst + "/"):
            val = bind_map[dst].rstrip("/") + val[len(dst):]
            break
    mapped_cmd.append(prefix + val)

os.execvp(mapped_cmd[0], mapped_cmd)
