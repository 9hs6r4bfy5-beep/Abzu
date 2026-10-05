/* compat-shim.c -- non-Darwin compile/smoke harness for abzu-compat.c.
 *
 * Purpose: prove the translation unit is valid C and that pledge()/unveil()
 * behave as documented (fail closed) even where no seatbelt exists. Run by
 * `make check` and by CI's Linux builder, which cannot build the real image.
 *
 *   cc -I../include -o compat-shim compat-shim.c        # uses stub sandbox.h
 *   ./compat-shim                                       # expects exit 0
 *
 * On a Darwin host use tests/compat-darwin.sh instead, which links against the
 * real <sandbox.h>/libSystem and asserts actual confinement. */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures;

static void
expect(int cond, const char *what)
{
printf("%-58s %s\n", what, cond ? "ok" : "FAIL");
if (!cond)
failures++;
}

/* explicit_bzero(3) is in Darwin libSystem since 10.9 but not always visible to
 * glibc; provide it before including the translation unit under test. */
#ifndef __APPLE__
# ifndef explicit_bzero
static void
explicit_bzero_shim(void *p, size_t n)
{
volatile unsigned char *q = p;

while (n--)
*q++ = 0;
}
#define __progname program_invocation_short_name
#endif

#include "../abzu-compat.c"

int
main(void)
{
int r;

/* default mode must fail closed on promises we cannot honour */
unsetenv("ABZU_PLEDGE");
errno = 0;
r = pledge("pfsock", NULL);
expect(r == -1 && errno == EPERM, "pledge(pfsock) refused in fail mode");

errno = 0;
r = pledge("totally-made-up", NULL);
expect(r == -1 && errno == EPERM, "pledge(<unmapped>) refused in fail mode");

/* warn mode degrades loudly but keeps going */
setenv("ABZU_PLEDGE", "warn", 1);
errno = 0;
r = pledge("pfsock", NULL);
expect(r == 0, "pledge(pfsock) allowed (logged) in warn mode");

/* off mode is an explicit escape hatch, still logged */
setenv("ABZU_PLEDGE", "off", 1);
errno = 0;
r = pledge("stdio rpath", NULL);
expect(r == 0, "pledge(off mode) returns success");

/* unveil() accumulates paths without touching the kernel until commit */
unsetenv("ABZU_PLEDGE");
expect(unveil("/etc/ntp.conf", "r") == 0, "unveil(path) records grant");
expect(unveil("/var/db/ntp.drift", "rw") == 0, "unveil(second path)");

/* constant-time helpers */
expect(timingsafe_bcmp("abc", "abc", 3) == 0, "timingsafe_bcmp equal -> 0");
expect(timingsafe_bcmp("abc", "abd", 3) != 0, "timingsafe_bcmp differ -> nonzero");
expect(timingsafe_memcmp("abc", "abc", 3) == 0, "timingsafe_memcmp equal -> 0");

/* recallocarray must preserve data and reject overflow */
{
char *p = calloc(4, 8);

memcpy(p, "abcdefgh", 8);
p = recallocarray(p, 4, 8, 8);
expect(p != NULL && memcmp(p, "abcdefgh", 8) == 0,
    "recallocarray preserves contents");
free(p);
expect(recallocarray(NULL, 0, SIZE_MAX, 2) == NULL,
    "recallocarray rejects size overflow");
}

printf("\n%s (%d failure%s)\n", failures ? "FAILED" : "PASSED",
    failures, failures == 1 ? "" : "s");
return failures ? 1 : 0;
}
