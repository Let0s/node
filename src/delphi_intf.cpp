#include "delphi_intf.h"
namespace embed {
  const int CLASS_INTERNAL_FIELD_COUNT = 2;
  const int CLASSTYPE_INTERNAL_FIELD_NUMBER = 0;
  const int OBJECT_INTERNAL_FIELD_NUMBER = 1;

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
    if (globalTemplate) {
      auto globalObject = context->Global();
      CHECK(globalObject->InternalFieldCount() == CLASS_INTERNAL_FIELD_COUNT);
      globalObject->SetInternalField(
        CLASSTYPE_INTERNAL_FIELD_NUMBER,
        v8::External::New(isolate, globalTemplate->dClass));
      globalObject->SetInternalField(
        OBJECT_INTERNAL_FIELD_NUMBER,
        v8::Undefined(isolate));
    }
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

  void IEmbedEngine::SetFunctionCallBack(TMethodCallBack functionCB)
  {
    functionCallBack = functionCB;
  }

  void * IEmbedEngine::DelphiEngine()
  {
    return dEngine;
  }

  void * IEmbedEngine::GetDelphiObject(v8::Local<v8::Object> holder)
  {
    void* result = nullptr;
    if (holder->InternalFieldCount() > OBJECT_INTERNAL_FIELD_NUMBER) {
      auto internalfield = holder->GetInternalField(
        OBJECT_INTERNAL_FIELD_NUMBER);
      if (internalfield->IsExternal()) {
        auto classtype = internalfield.As<v8::External>();
        result = classtype->Value();
      }
    }
    return result;
  }

  void * IEmbedEngine::GetDelphiClasstype(v8::Local<v8::Object> obj)
  {
    void * result = nullptr;
    if ((obj->InternalFieldCount() > CLASSTYPE_INTERNAL_FIELD_NUMBER)) {
      auto internalfield = obj->GetInternalField(
        CLASSTYPE_INTERNAL_FIELD_NUMBER);
      if (internalfield->IsExternal()) {
        auto classtype = internalfield.As<v8::External>();
        result = classtype->Value();
      }
    }
    return result;
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
    IMethodArgs methodArgs(args);
    auto engine = IEmbedEngine::GetEngine(args.GetIsolate());
    engine->functionCallBack(&methodArgs);
  }

  EMBED_EXTERN IEmbedEngine * NewDelphiEngine(void * dEngine)
  {
    return new IEmbedEngine(dEngine);
  }
  EMBED_EXTERN void InitNode(char * executableName)
  {
    Init();
  }
  IClassProp::IClassProp(const char * pName, void * pObj,
    bool pRead, bool Pwrite)
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
  void IClassTemplate::SetProperty(char * propName, void * propObj,
    bool read, bool write)
  {
    auto prop = std::make_unique<IClassProp>(propName, propObj, read, write);
    props.push_back(std::move(prop));
  }
  void IClassTemplate::SetIndexedProperty(char * propName, void * propObj,
    bool read, bool write)
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
    proto->SetInternalFieldCount(CLASS_INTERNAL_FIELD_COUNT);
    for (auto &method : methods) {
      v8::Local<v8::FunctionTemplate> methodCallBack =
        v8::FunctionTemplate::New(isolate,
                                  FunctionCallBack,
                                  v8::External::New(isolate, method->call));
      proto->Set(isolate, method->name.c_str(), methodCallBack);
    }
  }
  IMethodArgs::IMethodArgs(const v8::FunctionCallbackInfo<v8::Value>& newArgs)
  {
    args = &newArgs;
    iso = args->GetIsolate();
    engine = IEmbedEngine::GetEngine(iso);
  }
  void * IMethodArgs::GetEngine()
  {
    void * result = nullptr;
    if (engine) {
      result = engine->DelphiEngine();
    }
    return result;
  }
  void * IMethodArgs::GetDelphiObject()
  {
    void * result = nullptr;
    if (engine) {
      auto holder = args->Holder();
      result = engine->GetDelphiObject(holder);
    }
    return result;
  }
  void * IMethodArgs::GetDelphiClasstype()
  {
    void * result = nullptr;
    if (engine) {
      auto holder = args->Holder();
      result = engine->GetDelphiClasstype(holder);
    }
    return result;
  }
  char * IMethodArgs::GetMethodName()
  {
    v8::Isolate * iso = args->GetIsolate();
    v8::String::Utf8Value str(args->Callee()->GetName());
    run_string_result = *str;
    run_string_result.push_back(0);
    return const_cast<char *>(run_string_result.c_str());
  }
  void IMethodArgs::SetReturnValueInt(int32_t val)
  {
    args->GetReturnValue().Set(val);
  }
  void IMethodArgs::SetReturnValueBool(bool val)
  {
    args->GetReturnValue().Set(val);
  }
  void IMethodArgs::SetReturnValueString(char * val)
  {
    auto value = v8::String::NewFromUtf8(iso, val,
      v8::NewStringType::kNormal).ToLocalChecked();
    args->GetReturnValue().Set(value);
  }
  void IMethodArgs::SetReturnValueDouble(double val)
  {
    args->GetReturnValue().Set(val);
  }
  void * IMethodArgs::GetDelphiMethod()
  {
    if (args->Data()->IsExternal()) {
      return args->Data().As<v8::External>()->Value();
    }
    return nullptr;
  }
  IJSValue::IJSValue(v8::Isolate * iso, v8::Local<v8::Value> val)
  {
    isolate = iso;
    value.Reset(iso, val);
  }
  v8::Local<v8::Value> IJSValue::V8Value()
  {
    return value.Get(isolate);
  }
  v8::Local<v8::Object> IJSObject::V8Object()
  {
    return V8Value()->ToObject(isolate);
  }
  bool IJSValue::IsObject()
  {
    return !(dynamic_cast<IJSObject *>(this) == nullptr);
  }
  bool IJSValue::IsDelphiObject()
  {
    return !(dynamic_cast<IJSDelphiObject *>(this) == nullptr);
  }
  bool IJSValue::IsArray()
  {
    return !(dynamic_cast<IJSArray *>(this) == nullptr);
  }
  bool IJSValue::IsFunction()
  {
    return !(dynamic_cast<IJSFunction *>(this) == nullptr);
  }
  bool IJSValue::AsBool()
  {
    return V8Value()->BooleanValue();
  }
  int32_t IJSValue::AsInt32()
  {
    return V8Value()->Int32Value();
  }
  char * IJSValue::AsString()
  {
    v8::String::Utf8Value str(V8Value());
    runStringResult = *str;
    return const_cast<char *>(runStringResult.c_str());
  }
  double IJSValue::AsFloat()
  {
    return V8Value()->NumberValue();
  }
  IJSObject * IJSValue::AsObject()
  {
    return dynamic_cast<IJSObject *>(this);
  }
  IJSDelphiObject * IJSValue::AsDelphiObject()
  {
    return dynamic_cast<IJSDelphiObject *>(this);
  }
  IJSArray * IJSValue::AsArray()
  {
    return dynamic_cast<IJSArray *>(this);
  }
  IJSFunction * IJSValue::AsFunction()
  {
    return dynamic_cast<IJSFunction *>(this);
  }
  bool IJSValue::IsUndefined()
  {
    return V8Value()->IsUndefined();
  }
  bool IJSValue::IsNull()
  {
    return V8Value()->IsNull();
  }
  bool IJSValue::IsBool()
  {
    return V8Value()->IsBoolean();
  }
  bool IJSValue::IsInt32()
  {
    return V8Value()->IsInt32();
  }
  bool IJSValue::IsString()
  {
    return V8Value()->IsString();
  }
  bool IJSValue::IsFloat()
  {
    return V8Value()->IsNumber();
  }
  v8::Local<v8::Array> IJSArray::V8Array()
  {
    return V8Value().As<v8::Array>();
  }
}
