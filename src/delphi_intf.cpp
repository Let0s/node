#include "delphi_intf.h"
namespace embed {
  //full path to executable (argv0)
  std::string exeName;

  IEmbedEngine::IEmbedEngine(void * dEng) : BaseEngine()
  {
    dEngine = dEng;
  }

  IEmbedEngine::~IEmbedEngine()
  {
    if (globalTemplate) {
      delete globalTemplate;
    }
  }

  v8::Local<v8::Context> IEmbedEngine::CreateContext(v8::Isolate * isolate)
  {
    v8::Local<v8::FunctionTemplate> global = v8::FunctionTemplate::New(isolate);
    if (globalTemplate) {
      globalTemplate->ModifyTemplate(isolate, global);
    }
    auto context = v8::Context::New(isolate, NULL, global->PrototypeTemplate());
    return context;
  }

  IClassTemplate * IEmbedEngine::AddGlobal(void * dClass)
  {
    if (globalTemplate) {
      delete globalTemplate;
    }
    globalTemplate = new IClassTemplate("global", dClass);
    return globalTemplate;
  }

  IClassTemplate * IEmbedEngine::AddObject(char * className, void * classType)
  {
    auto object = std::make_unique<IClassTemplate>(className, classType);
    auto result = object.get();
    objects.push_back(std::move(object));
    return result;
  }

  void IEmbedEngine::RunString(char * code)
  {
    std::vector<const char *> args;
    args.push_back(exeName.c_str());
    args.push_back("-e");
    args.push_back(code);
    Run(args.size(), args.data());
  }

  void * IEmbedEngine::DelphiEngine()
  {
    return dEngine;
  }

  IEmbedEngine * IEmbedEngine::GetEngine(v8::Isolate * isolate)
  {
    if (isolate) {
      return static_cast<IEmbedEngine *>(isolate->GetData(ENGINE_SLOT));
    }
    return nullptr;
  }

  void FunctionCallBack(const v8::FunctionCallbackInfo<v8::Value>& args)
  {
    auto result = v8::String::NewFromUtf8(args.GetIsolate(), "function called",
      v8::NewStringType::kNormal).ToLocalChecked();
    args.GetReturnValue().Set(result);
  }

  EMBED_EXTERN IEmbedEngine * NewDelphiEngine(void * dEngine)
  {
    return new IEmbedEngine(dEngine);
  }
  EMBED_EXTERN void InitNode(char * executableName)
  {
    Init();
  }
  IClassProp::IClassProp(const char * pName, void * pObj, bool pRead, bool Pwrite)
  {
    name = pName;
    obj = pObj;
    read = pRead;
    write = Pwrite;
  }
  IClassMethod::IClassMethod(const char * mName, void * mCall)
  {
    name = mName;
    call = mCall;
  }
  IClassTemplate::IClassTemplate(char * objclasstype, void * delphiClass)
  {
    classTypeName = objclasstype;
    dClass = delphiClass;
  }
  void IClassTemplate::SetMethod(char * methodName, void * methodCall)
  {
    auto method = std::make_unique<IClassMethod>(methodName, methodCall);
    methods.push_back(std::move(method));
  }
  void IClassTemplate::SetProperty(char * propName, void * propObj, bool read, bool write)
  {
    auto prop = std::make_unique<IClassProp>(propName, propObj, read, write);
    props.push_back(std::move(prop));
  }
  void IClassTemplate::SetIndexedProperty(char * propName, void * propObj, bool read, bool write)
  {
    auto prop = std::make_unique<IClassProp>(propName, propObj, read, write);
    indexed_props.push_back(std::move(prop));
  }
  void IClassTemplate::SetField(char * fieldName)
  {
    fields.push_back(fieldName);
  }
  void IClassTemplate::SetParent(IClassTemplate * parent)
  {
    parentTemplate = parent;
  }
  void IClassTemplate::ModifyTemplate(v8::Isolate * isolate,
    v8::Local<v8::FunctionTemplate> templ)
  {
    auto proto = templ->PrototypeTemplate();
    for (auto &method : methods) {
      v8::Local<v8::FunctionTemplate> methodCallBack = v8::FunctionTemplate::New(isolate, FunctionCallBack, v8::External::New(isolate, method->call));
      proto->Set(isolate, method->name.c_str(), methodCallBack);
    }
  }
}
