#include "embed.h"
#include "node_platform.h"

namespace embed {
  const int DEFAULT_THREAD_POOL_SIZE = 4;
  bool initialized = false;

#if NODE_MAJOR_VERSION <= 8
  node::NodePlatform* v8_platform;
#else
  node::MultiIsolatePlatform* v8_platform;
  v8::TracingController * v8_tracing_controller;
#endif

  void Init() {
    if (!initialized) {

      // Initialize v8.
#if NODE_MAJOR_VERSION <= 8
      v8_platform = new node::NodePlatform(DEFAULT_THREAD_POOL_SIZE, uv_default_loop(), nullptr);
#else
      v8_tracing_controller = new v8::TracingController();
      v8_platform = node::CreatePlatform(DEFAULT_THREAD_POOL_SIZE, v8_tracing_controller);
      node::tracing::TraceEventHelper::SetTracingController(v8_tracing_controller);
#endif      
      v8::V8::InitializePlatform(v8_platform);
      v8::V8::Initialize();

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
    node::LoadEnvironment(env);
    running = true;
  }
  void BaseEngine::Stop()
  {
    if (running) {
      auto context = iso->GetCurrentContext();
      context->Exit();
      node::FreeEnvironment(env);
      node::FreeIsolateData(isolate_data);
      delete script_params;
      iso->Dispose();
      running = false;
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
