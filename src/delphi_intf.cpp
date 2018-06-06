#include "delphi_intf.h"
namespace embed {
  // internal field count for wrapped delphi object
  const int CLASS_INTERNAL_FIELD_COUNT = 2;
  // index of internal field with stored object classtype
  const int CLASSTYPE_INTERNAL_FIELD_NUMBER = 0;
  // index of internal field with stored pointer to object
  const int OBJECT_INTERNAL_FIELD_NUMBER = 1;

  //indexed property object has one more field for pointer to property
  const int INDEXED_PROP_OBJ_FIELD_COUNT = 3;
  // index of internal field with stored pointer to indexed property
  const int INDEXED_PROP_FIELD_INDEX = 2;

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
      for (auto &templ : classes) {
        v8::Local<v8::FunctionTemplate> classTemplate =
          v8::FunctionTemplate::New(isolate);
        templ->ModifyTemplate(isolate, classTemplate);
        global->PrototypeTemplate()->Set(isolate,
                                        templ->classTypeName.c_str(),
                                        classTemplate);
      }
      // create template for indexed property object
      indexedObjectTemplate = v8::ObjectTemplate::New(isolate);
      indexedObjectTemplate->SetInternalFieldCount(INDEXED_PROP_OBJ_FIELD_COUNT);
      // set handler for indexed property with number index
      indexedObjectTemplate->SetIndexedPropertyHandler(IndexedPropGetter, IndexedPropSetter);
      // set handler for indexed property with string index
      indexedObjectTemplate->SetNamedPropertyHandler(NamedPropGetter, NamedPropSetter);
    }
    auto context = v8::Context::New(isolate, NULL, global->PrototypeTemplate());
    if (globalTemplate) {
      // Entering context is needed to create v8::Object for enumerators
      v8::Context::Scope scope(context);
      auto globalObject = context->Global();
      CHECK(globalObject->InternalFieldCount() == CLASS_INTERNAL_FIELD_COUNT);
      globalObject->SetInternalField(
        CLASSTYPE_INTERNAL_FIELD_NUMBER,
        v8::External::New(isolate, globalTemplate->dClass));
      globalObject->SetInternalField(
        OBJECT_INTERNAL_FIELD_NUMBER,
        v8::Undefined(isolate));
      for (auto &enumerator : enums) {
        if (enumerator->values.size() > 0) {
          auto enumObj = v8::Object::New(isolate);
          for (auto value : enumerator->values)
            enumObj->Set(
              v8::String::NewFromUtf8(isolate, value.second.c_str(),
                v8::NewStringType::kNormal).ToLocalChecked(),
              v8::Integer::New(isolate, value.first));
          globalObject->Set(
            v8::String::NewFromUtf8(isolate, enumerator->name.c_str(),
              v8::NewStringType::kNormal).ToLocalChecked(),
            enumObj);
        }
      }
    }
    return context;
  }

  void IEmbedEngine::PrepareForRun()
  {
    // add global variables
    for (auto &link : objectLinks) {
      auto obj = NewDelphiObject(link->obj, link->classType);
      auto global = Isolate()->GetCurrentContext()->Global();
      global->Set(
        v8::String::NewFromUtf8(Isolate(), link->name.c_str(),
          v8::NewStringType::kNormal).ToLocalChecked(),
        obj->V8Object());
    }

    // execute "pre-code"
    v8::Local<v8::String> source = v8::String::NewFromUtf8(Isolate(),
      preCode.c_str(), v8::NewStringType::kNormal).ToLocalChecked();
    v8::ScriptOrigin origin(v8::String::NewFromUtf8(Isolate(),
      "pre-code", v8::NewStringType::kNormal).ToLocalChecked());
    auto context = Isolate()->GetCurrentContext();
    v8::Local<v8::Script> script;
    if (v8::Script::Compile(context, source, &origin).ToLocal(&script)) {
      script->Run(context);
    }
  }

  void IEmbedEngine::Stop()
  {
    JSDelphiObjects.clear();
    jsValues.clear();
    BaseEngine::Stop();
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
    classes.push_back(std::move(object));
    return result;
  }

  IClassTemplate * IEmbedEngine::GetObjectTemplate(void * classType)
  {
    IClassTemplate * result = nullptr;
    if (globalTemplate && globalTemplate->dClass == classType) {
      result = globalTemplate;
    }
    if (!result) {
      for (auto &templ : classes) {
        if (templ->dClass == classType) {
          result = templ.get();
          break;
        }
      }
    }
    return result;
  }

  IEnumTemplate * IEmbedEngine::AddEnum(char * enumName)
  {
    auto enumerator = std::make_unique<IEnumTemplate>(enumName);
    auto result = enumerator.get();
    enums.push_back(std::move(enumerator));
    return result;
  }

  void IEmbedEngine::AddGlobalVariableObject(char * name, void * objPointer, void * classType)
  {
    auto link = std::make_unique<ObjectVariableLink>();
    link->name = name;
    link->obj = objPointer;
    link->classType = classType;
    objectLinks.push_back(std::move(link));
  }

  void IEmbedEngine::AddPreCode(char * code)
  {
    preCode += code;
    preCode += '\n';
  }

  void IEmbedEngine::RunString(char * code)
  {
    std::vector<const char *> args;
    args.push_back(exeName.c_str());
    args.push_back("-e");
    args.push_back(code);
    Run(args.size(), args.data());
  }

  void IEmbedEngine::RunFile(char * filename)
  {
    //set current directory for nodejs
    std::string filePath = filename;
    size_t pos = filePath.find_last_of("\\/");
    filePath = (std::string::npos == pos) ? "" : filePath.substr(0, pos);
    uv_chdir(filePath.c_str());

    std::vector<const char *> args;
    args.push_back(exeName.c_str());
    args.push_back(filename);
    Run(args.size(), args.data());
  }

  ILaunchArguments * IEmbedEngine::CreateLaunchArguments()
  {
    return new ILaunchArguments();
  }

  void IEmbedEngine::Launch(ILaunchArguments * args)
  {
    auto nodeArgs = args->GetLaunchArguments();
    Run(nodeArgs.size(), nodeArgs.data());
  }

  void IEmbedEngine::ChangeWorkingDir(char * newDir)
  {
    uv_chdir(newDir);
  }

  IJSValue * IEmbedEngine::CallFunction(char * fName, IJSArray * args)
  {
    auto context = Isolate()->GetCurrentContext();
    auto glo = context->Global();
    auto maybe_val = glo->Get(context,
        v8::String::NewFromUtf8(Isolate(), fName, v8::NewStringType::kNormal).ToLocalChecked());
    if (!maybe_val.IsEmpty()) {
      auto val = maybe_val.ToLocalChecked();
      if (val->IsFunction()) {
          auto func = val.As<v8::Function>();
          std::vector<v8::Local<v8::Value>> argv;
          argv.clear(); 
          if (args)
            argv = args->ToVector();
          auto func_result = func->Call(context, glo, argv.size(), argv.data());
          if (!func_result.IsEmpty()) {
            auto result = MakeValue(func_result.ToLocalChecked()); 
            return result;
          }        
      }
    }
    return nullptr;
  }

  void IEmbedEngine::SetFunctionCallBack(TMethodCallBack functionCB)
  {
    functionCallBack = functionCB;
  }

  void IEmbedEngine::SetPropGetterCallBack(TGetterCallBack functionCB)
  {
    propGetterCallBack = functionCB;
  }

  void IEmbedEngine::SetPropSetterCallBack(TSetterCallBack callBack)
  {
    propSetterCallBack = callBack;
  }

  void IEmbedEngine::SetFieldGetterCallBack(TGetterCallBack callback)
  {
    fieldGetterCallBack = callback;
  }

  void IEmbedEngine::SetFieldSetterCallBack(TSetterCallBack callBack)
  {
    fieldSetterCallBack = callBack;
  }

  void IEmbedEngine::SetIndexedGetterCallBack(TIndexedGetterCallBack callBack)
  {
    indexedGetter = callBack;
  }

  void IEmbedEngine::SetIndexedSetterCallBack(TIndexedSetterCallBack callBack)
  {
    indexedSetter = callBack;
  }

  IJSValue * IEmbedEngine::NewInt32(int32_t value)
  {
    IJSValue * result = nullptr;
    if (IsRunning()) {
      auto val = v8::Int32::New(Isolate(), value);
      auto jsVal = std::make_unique<IJSValue>(Isolate(), val);
      result = jsVal.get();
      jsValues.push_back(std::move(jsVal));
    }
    return result;
  }

  IJSValue * IEmbedEngine::NewNumber(double value)
  {
    IJSValue * result = nullptr;
    if (IsRunning()) {
      auto val = v8::Number::New(Isolate(), value);
      auto jsVal = std::make_unique<IJSValue>(Isolate(), val);
      result = jsVal.get();
      jsValues.push_back(std::move(jsVal));
    }
    return result;
  }

  IJSValue * IEmbedEngine::NewBoolean(bool value)
  {
    IJSValue * result = nullptr;
    if (IsRunning()) {
      auto val = v8::Boolean::New(Isolate(), value);
      auto jsVal = std::make_unique<IJSValue>(Isolate(), val);
      result = jsVal.get();
      jsValues.push_back(std::move(jsVal));
    }
    return result;
  }

  IJSValue * IEmbedEngine::NewString(char * value)
  {
    IJSValue * result = nullptr;
    if (IsRunning()) {
      auto val = v8::String::NewFromUtf8(Isolate(), value,
        v8::NewStringType::kNormal).ToLocalChecked();
      auto jsVal = std::make_unique<IJSValue>(Isolate(), val);
      result = jsVal.get();
      jsValues.push_back(std::move(jsVal));
    }
    return result;
  }

  IJSArray * IEmbedEngine::NewArray(int32_t length)
  {
    IJSArray * result = nullptr;
    if (IsRunning()) {
      auto arr = v8::Array::New(Isolate(), length);
      auto resultValue = std::make_unique<IJSArray>(Isolate(), arr);
      result = resultValue.get();
      jsValues.push_back(std::move(resultValue));
    }
    return result;
  }

  IJSObject * IEmbedEngine::NewObject()
  {
    IJSObject * result = nullptr;
    if (IsRunning()) {
      auto obj = v8::Object::New(Isolate());
      auto resultValue = std::make_unique<IJSObject>(Isolate(), obj);
      result = resultValue.get();
      jsValues.push_back(std::move(resultValue));
    }
    return result;
  }

  IJSDelphiObject * IEmbedEngine::NewDelphiObject(void * value, void * cType)
  {
    IJSDelphiObject * result = nullptr;
    uint64_t hash = (uint64_t(value) << 32) + uint32_t(cType);
    {
      auto item = JSDelphiObjects.find(hash);
      if (item != JSDelphiObjects.end())
      {
        result = item->second;
      }
    }
    if (!result) {
      auto templ = GetDelphiClassTemplate(cType);
      if (templ) {
        auto funcTemplate = templ->FunctionTemplate(Isolate());
        if (!funcTemplate.IsEmpty()) {
          auto obj = funcTemplate->InstanceTemplate()->NewInstance();
          if (!obj.IsEmpty()) {
            obj->SetInternalField(CLASSTYPE_INTERNAL_FIELD_NUMBER,
              v8::External::New(Isolate(), cType));
            obj->SetInternalField(OBJECT_INTERNAL_FIELD_NUMBER,
              v8::External::New(Isolate(), value));
            result = IJSValue::MakeValue(Isolate(), obj)->AsDelphiObject();
            if (result)
              JSDelphiObjects.emplace(std::make_pair(hash, result));
          }
        }
      }
    }
    return result;
  }

  IJSValue * IEmbedEngine::MakeValue(v8::Local<v8::Value> value)
  {
    IJSValue * result = nullptr;
    if (IsRunning()) {
      result = IJSValue::MakeValue(Isolate(), value);
      auto jsVal = std::unique_ptr<IJSValue>(result);
      jsValues.push_back(std::move(jsVal));
    }
    return result;
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

  IClassTemplate * IEmbedEngine::GetDelphiClassTemplate(void * classType)
  {
    for (auto &clas : classes) {
      if (clas->dClass == classType)
        return clas.get();
    }
    return nullptr;
  }

  IEmbedEngine * IEmbedEngine::GetEngine(v8::Isolate * isolate)
  {
    if (isolate) {
      return static_cast<IEmbedEngine *>(isolate->GetData(ENGINE_SLOT));
    }
    return nullptr;
  }

  v8::Local<v8::Object> IEmbedEngine::GetIndexedPropertyObject(void * obj,
    void * cType, void * indexedProp)
  {
    v8::Local<v8::Object> result;
    uint64_t hash = (uint64_t(obj) << 32) + uint32_t(indexedProp);
    {
      auto item = jsIndexedPropObjects.find(hash);
      if (item != jsIndexedPropObjects.end())
      {
        result = item->second.Get(Isolate());
      }
    }
    if (result.IsEmpty()) {
      auto templ = indexedObjectTemplate;
      if (!templ.IsEmpty()) {
        auto indexedPropObject = templ->NewInstance();
        if (!indexedPropObject.IsEmpty()) {
          indexedPropObject->SetInternalField(CLASSTYPE_INTERNAL_FIELD_NUMBER,
            v8::External::New(Isolate(), cType));
          indexedPropObject->SetInternalField(OBJECT_INTERNAL_FIELD_NUMBER,
            v8::External::New(Isolate(), obj));
          indexedPropObject->SetInternalField(INDEXED_PROP_FIELD_INDEX,
            v8::External::New(Isolate(), indexedProp));
          v8::Persistent<v8::Object, v8::CopyablePersistentTraits<v8::Object>> obj(
            Isolate(), indexedPropObject);
          jsIndexedPropObjects.emplace(std::make_pair(hash, obj));
          result = obj.Get(Isolate());
        }
      }
    }
    return result;
  }

  void FunctionCallBack(const v8::FunctionCallbackInfo<v8::Value>& args)
  {
    IMethodArgs methodArgs(args);
    auto engine = IEmbedEngine::GetEngine(args.GetIsolate());
    if (engine->functionCallBack)
      engine->functionCallBack(&methodArgs);
  }

  void PropGetter(v8::Local<v8::String> prop,
                  const v8::PropertyCallbackInfo<v8::Value>& info)
  {
    IGetterArgs propArgs(info, prop);
    auto engine = IEmbedEngine::GetEngine(info.GetIsolate());
    if (engine->propGetterCallBack)
      engine->propGetterCallBack(&propArgs);
  }

  void PropSetter(v8::Local<v8::String> prop, v8::Local<v8::Value> value,
    const v8::PropertyCallbackInfo<void>& info)
  {
    ISetterArgs propArgs(info, prop, value);
    auto engine = IEmbedEngine::GetEngine(info.GetIsolate());
    if (engine->propSetterCallBack)
      engine->propSetterCallBack(&propArgs);
  }

  void FieldGetter(v8::Local<v8::String> field, const v8::PropertyCallbackInfo<v8::Value>& info)
  {
    IGetterArgs propArgs(info, field);
    auto engine = IEmbedEngine::GetEngine(info.GetIsolate());
    if (engine->fieldGetterCallBack)
      engine->fieldGetterCallBack(&propArgs);
  }

  void FieldSetter(v8::Local<v8::String> field, v8::Local<v8::Value> value,
    const v8::PropertyCallbackInfo<void>& info)
  {
    ISetterArgs propArgs(info, field, value);
    auto engine = IEmbedEngine::GetEngine(info.GetIsolate());
    if (engine->fieldSetterCallBack)
      engine->fieldSetterCallBack(&propArgs);
  }

  void IndexedPropObjGetter(v8::Local<v8::String> property,
    const v8::PropertyCallbackInfo<v8::Value>& info)
  {
    //check if data contains pointer: it should be pointer to delphi prop
    if (info.Data()->IsExternal()) {
      v8::Isolate * iso = info.GetIsolate();
      auto engine = IEmbedEngine::GetEngine(iso);
      auto holder = info.This();
      void * data = info.Data().As<v8::External>()->Value();
      void * obj = engine->GetDelphiObject(holder);
      void * cType = engine->GetDelphiClasstype(holder);
      auto result = engine->GetIndexedPropertyObject(obj, cType, data);
      info.GetReturnValue().Set(result);
    }
  }

  void IndexedPropGetter(uint32_t index,
    const v8::PropertyCallbackInfo<v8::Value>& info)
  {
    IIndexedGetterArgs propArgs(info, index);
    auto engine = IEmbedEngine::GetEngine(info.GetIsolate());
    if (engine->indexedGetter)
      engine->indexedGetter(&propArgs);
  }

  void IndexedPropSetter(uint32_t index, v8::Local<v8::Value> value,
    const v8::PropertyCallbackInfo<v8::Value>& info)
  {
    IIndexedSetterArgs propArgs(info, index, value);
    auto engine = IEmbedEngine::GetEngine(info.GetIsolate());
    if (engine->indexedSetter)
      engine->indexedSetter(&propArgs);
  }

  void NamedPropGetter(v8::Local<v8::String> property,
    const v8::PropertyCallbackInfo<v8::Value>& info)
  {
    IIndexedGetterArgs propArgs(info, property);
    auto engine = IEmbedEngine::GetEngine(info.GetIsolate());
    if (engine->indexedGetter)
      engine->indexedGetter(&propArgs);
  }

  void NamedPropSetter(v8::Local<v8::String> property,
    v8::Local<v8::Value> value, const v8::PropertyCallbackInfo<v8::Value>& info)
  {
    IIndexedSetterArgs propArgs(info, property, value);
    auto engine = IEmbedEngine::GetEngine(info.GetIsolate());
    if (engine->indexedSetter)
      engine->indexedSetter(&propArgs);
  }

  EMBED_EXTERN IEmbedEngine * NewDelphiEngine(void * dEngine)
  {
    return new IEmbedEngine(dEngine);
  }
  EMBED_EXTERN void InitNode(char * executableName)
  {
    Init();
  }
  EMBED_EXTERN int EmbedMajorVersion()
  {
    return EMBED_MAJOR_VERSION;
  }
  EMBED_EXTERN int EmbedMinorVersion()
  {
    return EMBED_MINOR_VERSION;
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
  void IClassTemplate::SetDefaultIndexedProperty(void * prop)
  {
    defaultIndexedProp = prop;
  }
  void IClassTemplate::SetField(char * fieldName, void * fieldObj)
  {
    auto field = std::make_unique<IClassField>(fieldName, fieldObj);
    fields.push_back(std::move(field));
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
    {
      //dirty way - fix it later;
      templ->InstanceTemplate()->SetInternalFieldCount(CLASS_INTERNAL_FIELD_COUNT);
    }
    for (auto &method : methods) {
      v8::Local<v8::FunctionTemplate> methodCallBack =
        v8::FunctionTemplate::New(isolate,
                                  FunctionCallBack,
                                  v8::External::New(isolate, method->call));
      proto->Set(isolate, method->name.c_str(), methodCallBack);
    }
    for (auto &prop : props) {
      auto propname = v8::String::NewFromUtf8(isolate,
                                              prop->name.c_str(),
                                              v8::NewStringType::kNormal);
      proto->SetAccessor(propname.ToLocalChecked(),
                         prop->read? PropGetter : NULL,
                         prop->write? PropSetter : NULL,
                         v8::External::New(isolate, prop->obj));
    }
    for (auto &field : fields) {
      auto fieldName = v8::String::NewFromUtf8(isolate,
                                               field->name.c_str(),
                                               v8::NewStringType::kNormal);
      if (!fieldName.IsEmpty())
        proto->SetAccessor(fieldName.ToLocalChecked(),
                           FieldGetter,
                           FieldSetter,
                           v8::External::New(isolate, field->obj));
    }
    for (auto &indProp : indexed_props) {
      auto propName = v8::String::NewFromUtf8(isolate,
        indProp->name.c_str(),
        v8::NewStringType::kNormal);
      proto->SetAccessor(propName.ToLocalChecked(), IndexedPropObjGetter,
        NULL, v8::External::New(isolate, indProp->obj));
    }
    if (defaultIndexedProp) {
      proto->SetIndexedPropertyHandler(IndexedPropGetter, IndexedPropSetter,
        NULL, NULL, NULL, v8::External::New(isolate, defaultIndexedProp));
    }
    if (parentTemplate) {
      templ->Inherit(parentTemplate->FunctionTemplate(isolate));
    }
    v8Template.Reset(isolate, templ);
  }
  v8::Local<v8::FunctionTemplate> IClassTemplate::FunctionTemplate(
    v8::Isolate * isolate)
  {
    return v8Template.Get(isolate);
  }
  IMethodArgs::IMethodArgs(const v8::FunctionCallbackInfo<v8::Value>& newArgs)
  {
    args = &newArgs;
    iso = args->GetIsolate();
    engine = IEmbedEngine::GetEngine(iso);
    //setup arguments
    {
      auto length = args->Length();
      auto arr = v8::Array::New(iso, length);
      for (int i = 0; i < length; i++) {
        arr->Set(i, newArgs[i]);
      }
      argv = new IJSArray(iso, arr);
    }
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
      auto holder = args->This();
      result = engine->GetDelphiObject(holder);
    }
    return result;
  }
  void * IMethodArgs::GetDelphiClasstype()
  {
    void * result = nullptr;
    if (engine) {
      auto holder = args->This();
      result = engine->GetDelphiClasstype(holder);
    }
    return result;
  }
  IJSArray * IMethodArgs::GetArguments()
  {
    return argv;
  }
  char * IMethodArgs::GetMethodName()
  {
    v8::Isolate * iso = args->GetIsolate();
    v8::String::Utf8Value str(args->Callee()->GetName());
    run_string_result = *str;
    run_string_result.push_back(0);
    return const_cast<char *>(run_string_result.c_str());
  }
  void IMethodArgs::SetReturnValue(IJSValue * val)
  {
    if (val) {
      args->GetReturnValue().Set(val->V8Value());
    }
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
  IJSValue * IJSValue::MakeValue(v8::Isolate * isolate,
    v8::Local<v8::Value> val)
  {
    IJSValue * result = nullptr;
    if (!val.IsEmpty()) {
      if (val->IsFunction()) {
        result = new IJSFunction(isolate, val);
      }
      else if (val->IsArray()) {
        result = new IJSArray(isolate, val);
      }
      else if (val->IsInt32() || val->IsString() || val->IsNumber() ||
        val->IsBoolean() || val->IsUndefined() || val->IsNull()) {
        result = new IJSValue(isolate, val);
      }
      else if (val->IsObject()) {
        auto obj = val->ToObject();
        if (obj->InternalFieldCount() == CLASS_INTERNAL_FIELD_COUNT) {
          result = new IJSDelphiObject(isolate, val);
        }
        else {
          result = new IJSObject(isolate, val);
        }
      }
    }
    return result;
  }
  v8::Local<v8::Value> IJSValue::V8Value()
  {
    return value.Get(isolate);
  }
  IEmbedEngine * IJSValue::GetEngine()
  {
    return IEmbedEngine::GetEngine(isolate);
  }
  IJSObject::IJSObject(v8::Isolate * iso, v8::Local<v8::Value> val):
    IJSValue(iso, val)
  {
  }
  v8::Local<v8::Object> IJSObject::V8Object()
  {
    return V8Value()->ToObject(isolate);
  }
  bool IJSObject::IsObject()
  {
    return true;
  }
  IJSObject * IJSObject::AsObject()
  {
    return this;
  }
  void IJSObject::SetFieldValue(char * name, IJSValue * val)
  {
    if (val) {
      auto object = V8Object();
      object->CreateDataProperty(isolate->GetCurrentContext(),
        v8::String::NewFromUtf8(isolate, name, v8::NewStringType::kNormal).ToLocalChecked(),
        val->V8Value());
    }
  }
  IJSValue * IJSObject::GetFieldValue(char * name)
  {
    IJSValue * result = nullptr;
    auto fieldValue = v8::Local<v8::Value>();
    auto object = V8Object();
    auto maybeVal = object->GetRealNamedProperty(isolate->GetCurrentContext(),
      v8::String::NewFromUtf8(isolate, name, v8::NewStringType::kNormal).ToLocalChecked());
    if (!maybeVal.IsEmpty())
      fieldValue = maybeVal.ToLocalChecked();
    if (!fieldValue.IsEmpty()) {
      result = IEmbedEngine::GetEngine(isolate)->MakeValue(fieldValue);
    }
    return result;
  }
  bool IJSValue::IsObject()
  {
    return false;
  }
  bool IJSValue::IsDelphiObject()
  {
    return false;
  }
  bool IJSValue::IsArray()
  {
    return false;
  }
  bool IJSValue::IsFunction()
  {
    return false;
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
  double IJSValue::AsNumber()
  {
    return V8Value()->NumberValue();
  }
  IJSObject * IJSValue::AsObject()
  {
    return nullptr;
  }
  IJSDelphiObject * IJSValue::AsDelphiObject()
  {
    return nullptr;
  }
  IJSArray * IJSValue::AsArray()
  {
    return nullptr;
  }
  IJSFunction * IJSValue::AsFunction()
  {
    return nullptr;
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
  bool IJSValue::IsNumber()
  {
    return V8Value()->IsNumber();
  }
  IJSArray::IJSArray(v8::Isolate * iso, v8::Local<v8::Value> val) : IJSValue(
    iso, val)
  {
  }
  IJSArray::~IJSArray()
  {
    values.clear();
  }
  bool IJSArray::IsArray()
  {
    return true;
  }
  IJSArray * IJSArray::AsArray()
  {
    return this;
  }
  int32_t IJSArray::GetCount()
  {
    return V8Array()->Length();
  }
  IJSValue * IJSArray::GetValue(int32_t index)
  {
    IJSValue * result = nullptr;
    auto findresult = values.find(index);
    if (findresult == values.end())
    {
      result = IJSValue::MakeValue(isolate, V8Array()->Get(index));
      values.emplace(index, result);
    }
    else
      result = findresult->second;
    return result;
  }
  void IJSArray::SetValue(IJSValue * value, int32_t index)
  {
    if (value) {
      V8Array()->Set(index, value->V8Value());
    }
  }
  v8::Local<v8::Array> IJSArray::V8Array()
  {
    return V8Value().As<v8::Array>();
  }
  std::vector<v8::Local<v8::Value>> IJSArray::ToVector()
  {
    auto LocalArr = V8Array();
    auto ctx = isolate->GetCurrentContext();
    int vector_length = LocalArr->Length();
    std::vector<v8::Local<v8::Value>> vector_result(vector_length);
    for (int i = 0; i < vector_length; i++) {
      vector_result[i] = LocalArr->Get(ctx, i).ToLocalChecked();
    }
    return vector_result;
  }
  IJSFunction::IJSFunction(v8::Isolate * iso, v8::Local<v8::Value> val) :
    IJSValue(iso, val)
  {
  }
  v8::Local<v8::Function> IJSFunction::V8Function()
  {
    return V8Value().As<v8::Function>();
  }
  bool IJSFunction::IsFunction()
  {
    return true;
  }
  IJSFunction * IJSFunction::AsFunction()
  {
    return this;
  }
  IJSValue * IJSFunction::Call(IJSArray * argv)
  {
    std::vector<v8::Local<v8::Value>> args;
    if (argv) {
      for (int32_t i = 0; i < argv->GetCount(); i++) {
        args.push_back(argv->GetValue(i)->V8Value());
      }
    }
    auto v8result = V8Function()->Call(V8Function(), args.size(), args.data());
    auto result = IJSValue::MakeValue(isolate, v8result);

    return result;
  }
  IJSDelphiObject::IJSDelphiObject(v8::Isolate * iso, v8::Local<v8::Value> val):
    IJSObject(iso, val)
  {
  }
  bool IJSDelphiObject::IsDelphiObject()
  {
    return true;
  }
  IJSDelphiObject * IJSDelphiObject::AsDelphiObject()
  {
    return this;
  }
  void * IJSDelphiObject::GetDelphiObject()
  {
    void * result = nullptr;
    auto engine = IEmbedEngine::GetEngine(isolate);
    if (engine) {
      result = engine->GetDelphiObject(V8Object());
    }
    return result;
  }
  void * IJSDelphiObject::GetDelphiClasstype()
  {
    void * result = nullptr;
    auto engine = IEmbedEngine::GetEngine(isolate);
    if (engine) {
      result = engine->GetDelphiClasstype(V8Object());
    }
    return result;
  }
  IGetterArgs::IGetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info,
                           v8::Local<v8::Value> prop)
  {
    iso = info.GetIsolate();
    propinfo = &info;
    propName.Reset(iso, prop);
    engine = IEmbedEngine::GetEngine(iso);
  }
  IGetterArgs::~IGetterArgs()
  {
    if (propWrapper) {
      delete propWrapper;
    }
  }
  void * IGetterArgs::GetEngine()
  {
    void * result = nullptr;
    if (engine) {
      result = engine->DelphiEngine();
    }
    return result;
  }
  void * IGetterArgs::GetDelphiObject()
  {
    void * result = nullptr;
    if (engine) {
      auto holder = propinfo->This();
      result = engine->GetDelphiObject(holder);
    }
    return result;
  }
  void * IGetterArgs::GetDelphiClasstype()
  {
    void * result = nullptr;
    if (engine) {
      auto holder = propinfo->This();
      result = engine->GetDelphiClasstype(holder);
    }
    return result;
  }
  IJSValue * IGetterArgs::GetPropName()
  {
    if (!propWrapper) {
      propWrapper = new IJSValue(iso, propName.Get(iso));
    }
    return propWrapper;
  }
  void * IGetterArgs::GetPropPointer()
  {
    if (propinfo->Data()->IsExternal()) {
      return propinfo->Data().As<v8::External>()->Value();
    }
    return nullptr;
  }
  void IGetterArgs::SetReturnValue(IJSValue * val)
  {
    if (val)
      propinfo->GetReturnValue().Set(val->V8Value());
  }
  ISetterArgs::ISetterArgs(const v8::PropertyCallbackInfo<void>& info,
                           v8::Local<v8::Value> prop,
                           v8::Local<v8::Value> newValue)
  {
    iso = info.GetIsolate();
    engine = IEmbedEngine::GetEngine(iso);
    propinfo = &info;
    propName = IJSValue::MakeValue(iso, prop);
    propValue = engine->MakeValue(newValue);
  }
  ISetterArgs::~ISetterArgs()
  {
    delete propName;
  }
  void * ISetterArgs::GetEngine()
  {
    void * result = nullptr;
    if (engine) {
      result = engine->DelphiEngine();
    }
    return result;
  }
  void * ISetterArgs::GetDelphiObject()
  {
    void * result = nullptr;
    if (engine) {
      auto holder = propinfo->This();
      result = engine->GetDelphiObject(holder);
    }
    return result;
  }
  void * ISetterArgs::GetDelphiClasstype()
  {
    void * result = nullptr;
    if (engine) {
      auto holder = propinfo->This();
      result = engine->GetDelphiClasstype(holder);
    }
    return result;
  }
  IJSValue * ISetterArgs::GetPropName()
  {
    return propName;
  }
  void * ISetterArgs::GetPropPointer()
  {
    if (propinfo->Data()->IsExternal()) {
      return propinfo->Data().As<v8::External>()->Value();
    }
    return nullptr;
  }
  IJSValue * ISetterArgs::GetValue()
  {
    return propValue;
  }
  void ISetterArgs::SetReturnValue(IJSValue * val)
  {
    propinfo->GetReturnValue().Set(val->V8Value());
  }
  IClassField::IClassField(const char * fName, void * fObj)
  {
    name = fName;
    obj = fObj;
  }
  IEnumTemplate::IEnumTemplate(char * enumName)
  {
    name = enumName;
  }
  void IEnumTemplate::AddValue(char * valueName, int index)
  {
    values.emplace(std::make_pair(index, valueName));
  }
  IIndexedGetterArgs::IIndexedGetterArgs(
    const v8::PropertyCallbackInfo<v8::Value>& info,
    uint32_t propIndex)
  {
    iso = info.GetIsolate();
    propinfo = &info;
    index = IJSValue::MakeValue(iso, v8::Integer::New(iso, propIndex));
    engine = IEmbedEngine::GetEngine(iso);
  }
  IIndexedGetterArgs::IIndexedGetterArgs(
    const v8::PropertyCallbackInfo<v8::Value>& info,
    v8::Local<v8::String> propIndex)
  {
    iso = info.GetIsolate();
    propinfo = &info;
    index = IJSValue::MakeValue(iso, propIndex);
    engine = IEmbedEngine::GetEngine(iso);
  }
  IIndexedGetterArgs::~IIndexedGetterArgs()
  {
  }
  void * IIndexedGetterArgs::GetEngine()
  {
    if (engine)
      return engine->DelphiEngine();
    return nullptr;
  }
  void * IIndexedGetterArgs::GetDelphiObject()
  {
    void * result = nullptr;
    if (engine) {
      auto holder = propinfo->This();
      result = engine->GetDelphiObject(holder);
    }
    return result;
  }
  void * IIndexedGetterArgs::GetDelphiClasstype()
  {
    void * result = nullptr;
    if (engine) {
      auto holder = propinfo->This();
      result = engine->GetDelphiClasstype(holder);
    }
    return result;
  }
  IJSValue * IIndexedGetterArgs::GetPropIndex()
  {
    return index;
  }
  void * IIndexedGetterArgs::GetPropPointer()
  {
    void * result = nullptr;
    auto holder = propinfo->This();
    if (holder->InternalFieldCount() >= INDEXED_PROP_OBJ_FIELD_COUNT) {
      auto internalfield = holder->GetInternalField(
        INDEXED_PROP_FIELD_INDEX);
      if (internalfield->IsExternal()) {
        auto prop = internalfield.As<v8::External>();
        result = prop->Value();
      }
    } //else if we call default indexed property
    else if (propinfo->Data()->IsExternal()){
      auto data = propinfo->Data().As<v8::External>();
      if (!data.IsEmpty()) {
        result = data->Value();
      }
    }
    return result;
  }
  void IIndexedGetterArgs::SetReturnValue(IJSValue * val)
  {
    if (val) {
      propinfo->GetReturnValue().Set(val->V8Value());
    }
  }
  IIndexedSetterArgs::IIndexedSetterArgs(
    const v8::PropertyCallbackInfo<v8::Value>& info,
    uint32_t propIndex, v8::Local<v8::Value> newValue)
  {
    iso = info.GetIsolate();
    propinfo = &info;
    propValue = IJSValue::MakeValue(iso, newValue);
    index = IJSValue::MakeValue(iso, v8::Integer::New(iso, propIndex));
    engine = IEmbedEngine::GetEngine(iso);
  }
  IIndexedSetterArgs::IIndexedSetterArgs(
    const v8::PropertyCallbackInfo<v8::Value>& info,
    v8::Local<v8::String> propIndex, v8::Local<v8::Value> newValue)
  {
    iso = info.GetIsolate();
    propinfo = &info;
    propValue = IJSValue::MakeValue(iso, newValue);
    index = IJSValue::MakeValue(iso, propIndex);
    engine = IEmbedEngine::GetEngine(iso);
  }
  IIndexedSetterArgs::~IIndexedSetterArgs()
  {
    delete propValue;
  }
  void * IIndexedSetterArgs::GetEngine()
  {
    if (engine)
      return engine->DelphiEngine();
    return nullptr;
  }
  void * IIndexedSetterArgs::GetDelphiObject()
  {
    void * result = nullptr;
    if (engine) {
      auto holder = propinfo->This();
      result = engine->GetDelphiObject(holder);
    }
    return result;
  }
  void * IIndexedSetterArgs::GetDelphiClasstype()
  {
    void * result = nullptr;
    if (engine) {
      auto holder = propinfo->This();
      result = engine->GetDelphiClasstype(holder);
    }
    return result;
  }
  IJSValue * IIndexedSetterArgs::GetPropIndex()
  {
    return index;
  }
  void * IIndexedSetterArgs::GetPropPointer()
  {
    void * result = nullptr;
    auto holder = propinfo->This();
    if (holder->InternalFieldCount() >= INDEXED_PROP_OBJ_FIELD_COUNT) {
      auto internalfield = holder->GetInternalField(
        INDEXED_PROP_FIELD_INDEX);
      if (internalfield->IsExternal()) {
        auto prop = internalfield.As<v8::External>();
        result = prop->Value();
      }
    } //else if we call default indexed property
    else if (propinfo->Data()->IsExternal()) {
      auto data = propinfo->Data().As<v8::External>();
      if (!data.IsEmpty()) {
        result = data->Value();
      }
    }
    return result;
  }
  IJSValue * IIndexedSetterArgs::GetValue()
  {
    return propValue;
  }
  void IIndexedSetterArgs::SetReturnValue(IJSValue * val)
  {
    propinfo->GetReturnValue().Set(val->V8Value());
  }
  void ILaunchArguments::AddArgument(char * arg)
  {
    args.push_back(arg);
  }
  std::vector<const char*> ILaunchArguments::GetLaunchArguments()
  {
    std::vector<const char*> result;
    result.reserve(args.size());

    for (size_t i = 0; i < args.size(); ++i)
      result.push_back(args[i].c_str());
    return result;
  }
}
