/* sandbox.h -- minimal Darwin <sandbox.h> declaration set.
 *
 * Abzu normally builds against Apple's SDK, which ships this header. It exists
 * here only so the compatibility layer can be syntax-checked and unit-tested on
 * non-Darwin CI hosts (the Linux builder in .github/workflows/build.yml cannot
 * produce a Mach-O image but can still compile-check this translation unit).
 * Never install it into an image or add -Iinclude to a real build. */

#ifndef _ABZU_SANDBOX_H_
#define _ABZU_SANDBOX_H_

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#define SANDBOX_NAMED          1   /* profile given as a literal .sb string */
#define SANDBOX_NAMED_REFINED  2   /* deprecated upstream; unused by Abzu */

/* Return codes: 0 = confined, -1 = refused (see sandbox_init(3) manpage). */
extern int sandbox_init(const char *profile, uint64_t flags, char **errorbuf);
extern int sandbox_init_with_parameters(const char *profile, uint64_t flags,
    const char *const parameters[], char **errorbuf);
extern int sandbox_check(pid_t pid, const char *operation, int type, ...);
extern const char *sandbox_get_last_error(void);
extern void sandbox_free_error(char *errbuf);

#endif /* _ABZU_SANDBOX_H_ */
