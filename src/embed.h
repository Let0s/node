#pragma once

//version defines (based on code from node_version.h)

#define EMBED_MAJOR_VERSION 0
#define EMBED_MINOR_VERSION 1
#define EMBED_PATCH_VERSION 0

#define EMBED_VERSION_IS_RELEASE 0

#ifndef EMBED_STRINGIFY
#define EMBED_STRINGIFY(n) EMBED_STRINGIFY_HELPER(n)
#define EMBED_STRINGIFY_HELPER(n) #n
#endif

#ifndef EMBED_TAG
# if EMBED_VERSION_IS_RELEASE
#  define EMBED_TAG ""
# else
#  define EMBED_TAG "-pre"
# endif
#else
// NODE_TAG is passed without quotes when rc.exe is run from msbuild
# define EMBED_EXE_VERSION EMBED_STRINGIFY(EMBED_MAJOR_VERSION) "." \
                          EMBED_STRINGIFY(EMBED_MINOR_VERSION) "." \
                          EMBED_STRINGIFY(EMBED_PATCH_VERSION)     \
                          EMBED_STRINGIFY(EMBED_TAG)
#endif

# define EMBED_VERSION_STRING  EMBED_STRINGIFY(EMBED_MAJOR_VERSION) "." \
                               EMBED_STRINGIFY(EMBED_MINOR_VERSION) "." \
                               EMBED_STRINGIFY(EMBED_PATCH_VERSION)     \
                               EMBED_TAG
#ifndef EMBED_EXE_VERSION
# define EMBED_EXE_VERSION EMBED_VERSION_STRING
#endif

#define EMBED_VERSION "v" EMBED_VERSION_STRING

#define EMBED_EXTERN _declspec(dllexport)
