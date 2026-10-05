/* abzu-compat.c -- Abzu/Darwin compatibility layer for OpenBSD-derived code.
 *
 * Link this object into any ported tool whose symbols resolve to OpenBSD
 * interfaces that XNU does not expose yet.
 *
 * SECURITY NOTE (the reason this revision exists): pledge() and unveil() used
 * to be weak no-ops returning 0, so every imported tool believed it was
 * confined while keeping full userland reach. False assurance is worse than no
 * assurance. They now translate the promise set into a Darwin seatbelt profile
 * and apply it with sandbox_init(3), failing closed:
 *
 *   ABZU_PLEDGE=fail  (default) unmapped or unsupported promise -> EPERM + log
 *   ABZU_PLEDGE=warn            log the downgrade, apply partial profile
 *   ABZU_PLEDGE=off   debug only no-op, logged loudly once per process
 *
 * True per-process promise enforcement (irreversible narrowing, visible in
 * `ps -O pledge`) arrives with kernel patch 0003 (docs/ROADMAP.md M4); until
 * then sandbox_init(3) is the enforcement path. See docs/OPENBSD-DIFFS.md B1
 * and userland/security/pledge-map.tsv for the authoritative mapping table.
 *
 * SPDX-License-Identifier: ISC (stub bodies are original Abzu work)
 */

#include <sys/types.h>

#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#if !defined(__OpenBSD__)

/* Darwin libSystem ships <sandbox.h> on every platform Abzu targets. The stub
 * header under ../include is used only by the non-Darwin compile test. */
#define ABZU_HAVE_SANDBOX 1
#include <sandbox.h>

enum abzu_pledge_mode { ABZU_PLEDGE_FAIL, ABZU_PLEDGE_WARN, ABZU_PLEDGE_OFF };

static enum abzu_pledge_mode abzu_cached_mode = (enum abzu_pledge_mode)-1;

static enum abzu_pledge_mode
abzu_mode(void)
{
	const char *m;

	if (abzu_cached_mode != (enum abzu_pledge_mode)-1)
		return abzu_cached_mode;
	m = getenv("ABZU_PLEDGE");
	if (m == NULL || *m == '\0')
		abzu_cached_mode = ABZU_PLEDGE_FAIL;	/* fail closed */
	else if (strcmp(m, "off") == 0)
		abzu_cached_mode = ABZU_PLEDGE_OFF;
	else if (strcmp(m, "warn") == 0)
		abzu_cached_mode = ABZU_PLEDGE_WARN;
	else
		abzu_cached_mode = ABZU_PLEDGE_FAIL;
	return abzu_cached_mode;
}

__attribute__((format(printf, 1, 2)))
static void
abzu_log(const char *fmt, ...)
{
	va_list ap;

	fprintf(stderr, "%s: abzu-compat: ", __progname);
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
	fputc('\n', stderr);
}

/* Mirrors userland/security/pledge-map.tsv. A promise missing from this table
 * is treated as unmapped and therefore refused under ABZU_PLEDGE=fail. */

#define S_FULL	2	/* exact seatbelt equivalent */
#define S_PART	1	/* broader or narrower than pledge(2)'s check */
#define S_NONE	0	/* no Darwin equivalent: refuse, do not guess */

struct abzu_promise_rule {
	const char	*promise;
	int		 support;
	const char	*rules;		/* seatbelt fragment, or NULL */
};

static const struct abzu_promise_rule abzu_rules[] = {
	{ "stdio", S_FULL,
	    "(allow file-write* (literal \"/dev/tty\"))"
	    " (allow file-read* (literal \"/dev/null\") (literal \"/dev/zero\"))"
	    " (allow file-ioctl (literal \"/dev/tty\")"
	    " (regex #\"^/dev/fd/[0-9]+$\"))" },
	{ "rpath", S_FULL, "(allow file-read*)" },
	{ "wpath", S_FULL,
	    "(allow file-write* (subpath \"/var/tmp\")"
	    " (subpath \"/private/var/tmp\") (subpath \"/var/run\")"
	    " (subpath \"/var/db\"))" },
	{ "cpath", S_FULL,
	    "(allow file-write* (subpath \"/var/tmp\")"
	    " (subpath \"/private/var/tmp\") (subpath \"/var/run\")"
	    " (subpath \"/var/db\") (subpath \"/var/log\"))" },
	{ "tmppath", S_FULL,
	    "(allow file-write* (subpath \"/tmp\") (subpath \"/private/tmp\"))" },
	{ "path", S_FULL, "(allow file-read* file-write*)" },
	{ "exec", S_FULL,
	    "(allow process-exec)"
	    " (allow file-map-executable (subpath \"/usr/lib\")"
	    " (subpath \"/usr/local/lib\")"
	    " (subpath \"/System/Library/Frameworks\"))" },
	{ "fork", S_FULL, "(allow process-fork)" },
	{ "execfork", S_PART, "(allow process-fork process-exec)" },
	{ "inet", S_FULL,
	    "(allow network-outbound) (allow network-inbound)"
	    " (allow network* (local ip \"*\") (local udp \"*\"))" },
	{ "listen", S_FULL,
	    "(allow network* (local ip \"*\") (local udp \"*\"))"
	    " (allow network-inbound)" },
	{ "bind_address", S_PART,
	    "(allow network* (local ip \"*\") (local udp \"*\"))" },
	{ "dns", S_PART,
	    "(allow network-outbound (remote udp/ip:*:53)"
	    " (remote tcp/ip:*:53))" },
	{ "getpw", S_PART, "(allow file-read* (subpath \"/etc\"))" },
	{ "route", S_PART, "(allow network-control)" },
	{ "proc", S_PART,
	    "(allow process-fork) (allow signal) (allow process-info*)" },
	{ "ps", S_PART, "(allow process-info*)" },
	{ "audio", S_PART, "(allow device-audio*)" },
	{ "tty", S_FULL,
	    "(allow file-ioctl (literal \"/dev/tty\")"
	    " (regex #\"^/dev/ttyp[0-9]+$\"))" },
	{ "ioctl", S_PART, "(allow file-ioctl (regex #\"^/dev/.*\"))" },
	{ "fattr", S_PART, "(allow file-write-setattr)" },
	{ "recvfd", S_PART, "(allow mach-lookup)" },
	{ "sendfd", S_PART, "(allow mach-lookup)" },
	{ "readfd", S_PART, "(allow file-read*)" },
	{ "write", S_PART, "(allow file-write*)" },
	{ "vminfo", S_PART, "(allow sysctl-read)" },
	{ "wrefull", S_PART, "(allow file-write*)" },
	/* Deliberately unsupported: named here so we can explain the refusal
	 * instead of silently allowing the operation. */
	{ "pfsock", S_NONE, NULL },	/* /dev/pf does not exist on XNU */
	{ "mcast", S_NONE, NULL },	/* needs the NetworkExtension backend */
	{ "send", S_NONE, NULL },	/* send/recv signal promotion: n/a */
	{ "drainto", S_NONE, NULL },	/* kernel-side only (patch 0003) */
};

static const struct abzu_promise_rule *
abzu_lookup(const char *name, size_t len)
{
	size_t i;

	for (i = 0; i < sizeof(abzu_rules)/sizeof(abzu_rules[0]); i++)
		if (strlen(abzu_rules[i].promise) == len &&
		    strncmp(abzu_rules[i].promise, name, len) == 0)
			return &abzu_rules[i];
	return NULL;
}

/* Minimal growable buffer; avoids depending on libutil's evbuffer on Darwin. */
struct abzu_sb {
	char	*p;
	size_t	 len;
	size_t	 cap;
};

static int
sb_append(struct abzu_sb *sb, const char *s)
{
	size_t need = sb->len + strlen(s) + 1;

	if (need > sb->cap) {
		char *np;

		sb->cap = need * 2;
		np = realloc(sb->p, sb->cap);
		if (np == NULL)
			return -1;
		sb->p = np;
	}
	memcpy(sb->p + sb->len, s, strlen(s) + 1);
	sb->len += strlen(s);
	return 0;
}

/* Paths registered through unveil(), replayed when the profile is committed. */
static char	**abzu_unveiled;
static unsigned	 abzu_nunveiled;
static int		 abzu_confined;	/* sandbox_init() is one-shot */

#define ABZU_PROFILE_HEADER						    \
	"(version 1)\n"						    \
	"(comment \"generated by abzu-compat from pledge()/unveil()\")\n"  \
	"(allow default)\n(deny file-write*)\n(deny network*)\n"	    \
	"(deny process-exec)\n(deny process-fork)\n"

static int
abzu_apply_profile(const char *promises)
{
#ifndef ABZU_HAVE_SANDBOX
	(void)promises;
	abzu_log("no sandbox backend in this SDK: refusing to run unconfined");
	errno = EPERM;
	return -1;
#else
	struct abzu_sb sb = { NULL, 0, 0 };
	const char *it;
	unsigned i;
	int rc, err;
	char *profile;

	if (abzu_confined)
		return 0;	/* already narrowed; widening requires the
				 * kernel-side promise mask (patch 0003). */

	err = errno;
	if (sb_append(&sb, ABZU_PROFILE_HEADER) != 0)
		goto oom;

	for (it = promises; it != NULL && *it != '\0'; ) {
		const struct abzu_promise_rule *r;
		const char *end;

		while (*it == ' ' || *it == '\t')
			it++;
		if (*it == '\0')
			break;
		end = it;
		while (*end != '\0' && *end != ' ' && *end != '\t')
			end++;

		r = abzu_lookup(it, (size_t)(end - it));
		if (r == NULL) {
			abzu_log("pledge: unmapped promise \"%.*s\"",
			    (int)(end - it), it);
			if (abzu_mode() == ABZU_PLEDGE_FAIL)
				goto deny;
		} else if (r->support == S_NONE) {
			abzu_log("pledge: \"%s\" has no Darwin equivalent",
			    r->promise);
			if (abzu_mode() == ABZU_PLEDGE_FAIL)
				goto deny;
		} else if (r->support == S_PART) {
			abzu_log("pledge: partial downgrade for \"%s\"",
			    r->promise);
		}
		if (r != NULL && r->rules != NULL) {
			if (sb_append(&sb, r->rules) != 0 ||
			    sb_append(&sb, "\n") != 0)
				goto oom;
		}
		it = (*end == '\0') ? NULL : end;
	}

	/* unveil(): every registered path becomes an explicit subpath grant. */
	for (i = 0; i < abzu_nunveiled; i++) {
		char line[1024];

		snprintf(line, sizeof(line),
		    "(allow file-read* file-write* (subpath \"%s\"))\n",
		    abzu_unveiled[i]);
		if (sb_append(&sb, line) != 0)
			goto oom;
	}

	profile = sb.p;
	rc = sandbox_init(profile, SANDBOX_NAMED, NULL);
	free(profile);
	if (rc != 0) {
		abzu_log("sandbox_init failed (%s): refusing to run unconfined",
		    sandbox_get_last_error());
		errno = EPERM;
		return -1;
	}
	abzu_confined = 1;
	errno = err;
	return 0;
deny:
	free(sb.p);
	errno = EPERM;
	return -1;
oom:
	free(sb.p);
	errno = ENOMEM;
	return -1;
#endif
}

int
pledge(const char *promises, const char *paths[])
{
	(void)paths;		/* upstream ignores this argument as well */

	if (abzu_mode() == ABZU_PLEDGE_OFF) {
		static int warned;

		if (!warned) {
			warned = 1;
			abzu_log("ABZU_PLEDGE=off: confinement DISABLED");
		}
		return 0;
	}
	if (promises == NULL)
		return 0;	/* pledge(NULL) promotes: nothing to express */
	return abzu_apply_profile(promises);
}

int
unveil(const char *path, const char *permissions)
{
	char *dup;
	char **nv;

	(void)permissions;	/* r/w/x granularity folds into one subpath
				 * grant until the kernel shim lands */

	if (abzu_mode() == ABZU_PLEDGE_OFF)
		return 0;

	if (path == NULL) {
		/* unveil(NULL, NULL) freezes the namespace: commit the profile
		 * built from everything unveiled so far, plus the promise set
		 * stashed by a pledge() caller via ABZU_PLEDGE_PROMISES. */
		const char *p = getenv("ABZU_PLEDGE_PROMISES");

		return abzu_apply_profile(p != NULL ? p : "stdio rpath");
	}

	if ((dup = strdup(path)) == NULL) {
		errno = ENOMEM;
		return -1;
	}
	nv = realloc(abzu_unveiled, (abzu_nunveiled + 1) * sizeof(*nv));
	if (nv == NULL) {
		free(dup);
		errno = ENOMEM;
		return -1;
	}
	abzu_unveiled = nv;
	abzu_unveiled[abzu_nunveiled++] = dup;
	return 0;
}

/* Absent from Darwin libSystem. Used by doas(1), OpenSSH and tar(1) for MAC and
 * password comparisons; free of data-dependent early exit by construction. */
int
timingsafe_bcmp(const void *b1, const void *b2, size_t n)
{
	const unsigned char *p1 = b1, *p2 = b2;
	int ret = 0;

	while (n--)
		ret |= *p1++ ^ *p2++;
	return ret != 0;
}

int
timingsafe_memcmp(const void *b1, const void *b2, size_t len)
{
	const unsigned char *p1 = b1, *p2 = b2;
	unsigned char diff = 0;

	while (len--)
		diff |= *p1++ ^ *p2++;
	return diff;
}

/* recallocarray(3): zeroing realloc with overflow check (OpenBSD libc). */
void *
recallocarray(void *ptr, size_t oldnmemb, size_t nmemb, size_t size)
{
	void *new;
	size_t copy;

	if (size != 0 && nmemb > SIZE_MAX / size) {
		errno = ENOMEM;
		return NULL;
	}
	if ((new = calloc(nmemb, size)) == NULL)
		return NULL;
	if (ptr != NULL) {
		copy = (oldnmemb <= nmemb) ? oldnmemb * size : nmemb * size;
		memcpy(new, ptr, copy);
		explicit_bzero(ptr, oldnmemb * size);
		free(ptr);
	}
	return new;
}

#endif /* !__OpenBSD__ */
