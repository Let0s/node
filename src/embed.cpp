#include "embed.h"
#include "node_platform.h"

namespace embed {
  const int DEFAULT_THREAD_POOL_SIZE = 4;
  bool initialized = false;
  node::NodePlatform* v8_platform;

  void Init() {
    if (!initialized) {

      // Initialize v8.
      v8_platform = new node::NodePlatform(DEFAULT_THREAD_POOL_SIZE,
                                           uv_default_loop(),
                                           nullptr);
      v8::V8::InitializePlatform(v8_platform);
      v8::V8::Initialize();
      node::tracing::TraceEventHelper::SetTracingController(
        new v8::TracingController());

      initialized = true;
    }
  }

  void Fini()
  {
    if (initialized) {
      v8::V8::Dispose();
      v8::V8::ShutdownPlatform();
      delete v8_platform;
      v8_platform = nullptr;
      initialized = false;
    }
  }

  class Finalizer {
  public:
    ~Finalizer() {
      Fini();
    }
  }finalizer;

  BaseEngine::BaseEngine()
  {
  }
  BaseEngine::~BaseEngine()
  {
    Stop();
  }

  v8::Local<v8::Context> BaseEngine::CreateContext(v8::Isolate * isolate)
  {
    v8::Local<v8::Context> context = v8::Context::New(isolate);
    return context;
  }

  void BaseEngine::PrepareForRun()
  {
  }

  bool BaseEngine::IsRunning()
  {
    return running;
  }

  v8::Isolate * BaseEngine::Isolate()
  {
    if (IsRunning())
      return iso;
    return nullptr;
  }

  void BaseEngine::Run(int argc, const char * argv[])
  {
    Stop();

    v8::Isolate::CreateParams params;
    params.array_buffer_allocator = &allocator;
    iso = v8::Isolate::New(params);
    iso->SetData(ENGINE_SLOT, this);
    script_params = new ScriptParams(iso);

    v8::Local<v8::Context> context = CreateContext(iso);
    context->Enter();
    isolate_data = node::CreateIsolateData(iso, uv_default_loop());
    int exec_argc;
    const char ** exec_argv;
    node::Init(&argc, argv, &exec_argc, &exec_argv);
    env = node::CreateEnvironment(isolate_data,
      context,
      argc,
      argv,
      exec_argc,
      exec_argv);
    running = true;
    PrepareForRun();
    {// start inspector for script debugging
      const char* path = argc > 1 ? argv[1] : nullptr;
      CHECK(!env->inspector_agent()->IsStarted());
      env->inspector_agent()->Start(v8_platform, path, node::debug_options);
    }
    node::LoadEnvironment(env);
    //write v8 log messages (e.g. JS error) into stdout
    fflush(stdout);
  }
  void BaseEngine::CheckEventLoop()
  {
    if (running) {
      uv_run(uv_default_loop(), UV_RUN_NOWAIT);
      //dont know if it is needed;
      v8_platform->DrainBackgroundTasks();
        
      EmitBeforeExit(env);
    }
  }
  void BaseEngine::Stop()
  {
    if (running) {
      env->CleanupHandles();
      if (env->inspector_agent()->IsConnected()) {
        env->inspector_agent()->WaitForDisconnect();
      }
      env->inspector_agent()->Stop();
      auto context = iso->GetCurrentContext();
      context->Exit();
      node::FreeEnvironment(env);
      node::FreeIsolateData(isolate_data);
      delete script_params;
      iso->Dispose();
      running = false;
      node::ClearStaticData();
    }
  }
  void IBaseIntf::Delete()
  {
    delete this;
  }
  int IBaseIntf::Test()
  {
    return 101;
  }
}
