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

//includes
#include "v8.h"
#include "node_internals.h"
namespace embed {

  //
  void Init();
  void Fini();

  class IBaseIntf {
  public:
    virtual ~IBaseIntf() {};
    virtual void APIENTRY Delete();
    virtual int APIENTRY Test();
  };

  //keeps isolate locked and entered
  class ScriptParams {
  public:
    inline ScriptParams(v8::Isolate * iso) : locker(iso),
                                             h_scope(iso) {};
    ~ScriptParams() {
    };
  private:
    v8::Locker locker;
    v8::HandleScope h_scope;
  };

  //base class for JS engine 
  class BaseEngine : public IBaseIntf {
  private:
    ScriptParams * script_params;
    v8::Isolate* iso;
    node::ArrayBufferAllocator allocator;
    bool running = false;

    node::IsolateData* isolate_data = nullptr;
    node::Environment* env;
    uv_loop_t event_loop;

  public:
    BaseEngine();
    ~BaseEngine();

    // Create default context. child classes can override this method
    // and create their own context with custom global object,
    // additional properties and class templates
    virtual v8::Local<v8::Context> CreateContext(v8::Isolate * isolate);

    //do nothing, but child classes can do almost everything:
    // 1. Create custom JS values
    // 2. Execute some code (native V8 wtihout additional node variables)
    virtual void PrepareForRun();

    bool IsRunning();
    v8::Isolate * Isolate();
    //runs script and keep it alive
    // to allow application send callbacks
    void Run(int argc, const char * argv[]);
    // it will check if there is some node actions to execute
    // e.g. result of async functions
    virtual void APIENTRY CheckEventLoop();
    //stops script execution
    virtual void APIENTRY Stop();
  };

  // index of isolate's data slot, where engine is stored
  const uint32_t ENGINE_SLOT = 0;
}
