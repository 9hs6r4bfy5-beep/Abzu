/* abzu-compat.c — Abzu/Darwin compatibility stubs for OpenBSD-derived code.
 *
 * Link this object into any ported tool whose symbols resolve to OpenBSD
 * kernel interfaces we have not exposed yet. On Darwin these are weak no-ops
 * so binaries run unmodified while we grow real enforcement in XNU
 * (kernel/patches/0002) and sandbox profiles (/etc/sandbox.d on the ISO).
 *
 * SPDX-License-Identifier: ISC (stub bodies are original Abzu work)
 */
#include <sys/types.h>
#include <stddef.h>
#include <unistd.h>

#if !defined(__OpenBSD__)

__attribute__((weak))
int
pledge(const char *promises, const char *paths[])
{
	(void)promises;
	(void)paths;
	/* TODO(abzu): forward to sandbox_init(3) with a generated profile. */
	return 0;
}

__attribute__((weak))
int
unveil(const char *path, const char *permissions)
{
	(void)path;
	(void)permissions;
	/* TODO(abzu): enforce via seatbelt "(allow file-read* (subpath ...))". */
	return 0;
}

__attribute__((weak))
void
explicit_bzero(void *buf, size_t len)
{
	volatile unsigned char *p = buf;
	while (len--)
		*p++ = 0;
}

#endif /* !__OpenBSD__ */
