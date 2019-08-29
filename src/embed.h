#pragma once

//version defines (based on code from node_version.h)

#define EMBED_MAJOR_VERSION 0
#define EMBED_MINOR_VERSION 2
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

  class IV8Error : IBaseIntf {
  public:
    IV8Error(v8::Local<v8::Message> message, v8::Local<v8::Value> error);
    virtual const char * APIENTRY GetV8Error();
    virtual const char * APIENTRY GetScriptName();
    virtual int APIENTRY GetLine();
    virtual int APIENTRY GetColumn();
  private:
    std::string v8Error;
    int line;
    int column;
    std::string scriptName;
  };

  class IV8ErrorList : IBaseIntf {
  public:
    virtual int APIENTRY GetCount();
    virtual IV8Error * APIENTRY GetError(int index);
    virtual void APIENTRY Clear();

    IV8Error * AddError(v8::Local<v8::Message> message, v8::Local<v8::Value> error);
  private:
    std::vector<std::unique_ptr<IV8Error>> list;
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
    IV8ErrorList v8ErrorList;
    // V8 checks for valid output handle and if handle is valid it writes
    // output (e.g js errors) to stdout, else it uses OutputDebugString.
    // Check VPrintHelper and HasConsole functions in platform-win32.cc
    // SetStdHandle has some bugs with GUI in windows, so this function
    // captures V8 error messages and add them to engine's log.
    static void OnMessage(v8::Local<v8::Message> message,
      v8::Local<v8::Value> error);

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
    virtual IV8ErrorList * APIENTRY GetV8ErrorList();
  };

  // index of isolate's data slot, where engine is stored
  const uint32_t ENGINE_SLOT = 0;

  // Is used to redirect stdout, stderr if these handles are not exist
  class IGUILogger : public IBaseIntf {
  public:
    HANDLE /*stdInRead, stdInWrite, */stdOutRead, stdOutWrite;
    IGUILogger();
    ~IGUILogger();
  };

  std::string GetGUILog();
  
}
