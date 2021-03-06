#include <inttypes.h>

#ifndef NETDATA_COMMON_H
#define NETDATA_COMMON_H 1

#define abs(x) ((x < 0)? -x : x)
#define usecdiff(now, last) (((((now)->tv_sec * 1000000ULL) + (now)->tv_usec) - (((last)->tv_sec * 1000000ULL) + (last)->tv_usec)))

extern uint32_t simple_hash(const char *name);
extern void strreverse(char* begin, char* end);
extern char *mystrsep(char **ptr, char *s);
extern char *trim(char *s);

extern void *mymmap(const char *filename, unsigned long size, int flags);
extern int savememory(const char *filename, void *mem, unsigned long size);

extern int fd_is_valid(int fd);

extern char *global_host_prefix;

#ifdef __GNUC__
// gcc branch optimization
// #warning "Using GCC branch optimizations"
#define likely(x)       __builtin_expect(!!(x), 1)
#define unlikely(x)     __builtin_expect(!!(x), 0)
#else
#define likely(x)       (x)
#define unlikely(x)     (x)
#endif

#endif /* NETDATA_COMMON_H */
