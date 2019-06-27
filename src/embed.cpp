#include <io.h>
#include "embed.h"
#include "node_platform.h"

namespace embed {  
  const int DEFAULT_THREAD_POOL_SIZE = 4;
  bool initialized = false;
  node::NodePlatform* v8_platform;
  IGUILogger * logger = nullptr;

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

      // check if std handles exists else create them
      if (GetStdHandle(STD_OUTPUT_HANDLE) <= NULL ||
        GetStdHandle(STD_ERROR_HANDLE) <= NULL)
      {
        logger = new IGUILogger();
      }
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
    node::ResetArguments();

    v8::Isolate::CreateParams params;
    params.array_buffer_allocator = &allocator;
    iso = v8::Isolate::New(params);
    iso->SetData(ENGINE_SLOT, this);
    iso->AddMessageListener(IGUILogger::OnMessage);
    script_params = new ScriptParams(iso);
    v8::Isolate::Scope iso_scope(iso);

    v8::Local<v8::Context> context = CreateContext(iso);
    context->Enter();
    uv_loop_init(&event_loop);
    isolate_data = node::CreateIsolateData(iso, &event_loop);
    int exec_argc;
    const char ** exec_argv;
    node::Init(&argc, argv, &exec_argc, &exec_argv);
    env = node::CreateEnvironment(isolate_data,
      context,
      argc,
      argv,
      exec_argc,
      exec_argv);
    { // copied from InitInspectorBindings function in inspector_js_api.cc 
      auto obj = v8::Object::New(env->isolate());
      auto null = v8::Null(env->isolate());
      CHECK(obj->SetPrototype(context, null).FromJust());
      env->set_inspector_console_api_object(obj);
    }
    running = true;
    PrepareForRun();
    {// start inspector for script debugging
      const char* path = argc > 1 ? argv[1] : nullptr;
      CHECK(!env->inspector_agent()->IsStarted());
      env->inspector_agent()->Start(v8_platform, path, node::debug_options);
    }
    node::LoadEnvironment(env);
  }
  void BaseEngine::CheckEventLoop()
  {
    if (running) {
      v8::Isolate::Scope iso_scope(iso);
      uv_run(env->event_loop(), UV_RUN_NOWAIT);
      //dont know if it is needed;
      v8_platform->DrainBackgroundTasks();
        
      EmitBeforeExit(env);
    }
  }
  void BaseEngine::Stop()
  {
    if (running) {
      {
        v8::Isolate::Scope iso_scope(iso);
        env->CleanupHandles();
        if (env->inspector_agent()->IsConnected()) {
          env->inspector_agent()->WaitForDisconnect();
        }
        auto context = iso->GetCurrentContext();
        context->Exit();
        node::FreeEnvironment(env);
        node::FreeIsolateData(isolate_data);
        delete script_params;
      }
      iso->Dispose();
      running = false;
      uv_loop_close(&event_loop);
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

  void IGUILogger::OnMessage(v8::Local<v8::Message> message, v8::Local<v8::Value> error)
  {
    if (!(error->IsUndefined() || error->IsNull())) {
      v8::String::Utf8Value utf8Value(v8::Isolate::GetCurrent(), error);
      logger->errorLog += *utf8Value;
    }
  }

  IGUILogger::IGUILogger()
  {
    int pipefd[2];
    CreatePipe(&stdOutRead, &stdOutWrite, NULL, 0);
    auto fd = _open_osfhandle((intptr_t)stdOutWrite, 0);
    dup2(fd, 1);
    dup2(fd, 2);
    close(fd);
  }
  IGUILogger::~IGUILogger()
  {
    CloseHandle(stdOutRead);
    CloseHandle(stdOutWrite);
  }
  std::string GetGUILog()
  {
    //write errors first
    std::string result = logger->errorLog;
    logger->errorLog = "";
    if (logger) {
      //write v8 log messages (e.g. JS error) into stdout
      fflush(stdout);
      fflush(stderr);
      const DWORD startSize = 4095;
      DWORD size = 0;
      DWORD bytesRead = 0;
      char * buf = new char[startSize];
      PeekNamedPipe(logger->stdOutRead, buf, startSize, &bytesRead, &size, NULL);
      while (bytesRead > 0) {
        // Reading result may have incorrect encoding, but it is fixed
        // in Delphi code
        ReadFile(logger->stdOutRead, buf, size, &bytesRead, NULL);
        // Increase length of log message for trailing zero symbol
        bytesRead++;
        char * readBuf = new char[bytesRead];
        strncpy(readBuf, buf, bytesRead);
        readBuf[bytesRead - 1] = '\0';
        result += readBuf;
        PeekNamedPipe(logger->stdOutRead, buf, startSize, &bytesRead, &size, NULL);
        delete readBuf;
      }
      delete buf;
    }
    return result;
  }
}
