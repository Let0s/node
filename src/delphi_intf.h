#pragma once
#include "embed.h"

//here will be export functions and classes to use NodeJS in delphi projects

namespace embed {
  class IEmbedEngine;
  class IJSObject;
  class IJSDelphiObject;
  class IJSArray;
  class IJSFunction;


  //wrapper for JS value
  class IJSValue: public IBaseIntf {
  public:
    IJSValue(v8::Isolate * iso, v8::Local<v8::Value> val);
    static IJSValue * MakeValue(v8::Isolate * isolate,
                                v8::Local<v8::Value> val);
    v8::Local<v8::Value> V8Value();
    virtual IEmbedEngine * APIENTRY GetEngine();
    virtual bool APIENTRY IsUndefined();
    virtual bool APIENTRY IsNull();

    virtual bool APIENTRY IsBool();
    virtual bool APIENTRY IsInt32();
    virtual bool APIENTRY IsString();
    virtual bool APIENTRY IsNumber();
    virtual bool APIENTRY IsObject();
    virtual bool APIENTRY IsDelphiObject();
    virtual bool APIENTRY IsArray();
    virtual bool APIENTRY IsFunction();

    virtual bool APIENTRY AsBool();
    virtual int32_t APIENTRY AsInt32();
    virtual char * APIENTRY AsString();
    virtual double APIENTRY AsNumber();
    virtual IJSObject * APIENTRY AsObject();
    virtual IJSDelphiObject * APIENTRY AsDelphiObject();
    virtual IJSArray * APIENTRY AsArray();
    virtual IJSFunction * APIENTRY AsFunction();
  protected:
    v8::Isolate * isolate;
  private:
    v8::Persistent<v8::Value> value;
    //it will stor char*, returned by AsString() method
    std::string runStringResult;
  };

  //wrapper for JS object
  class IJSObject : public IJSValue {
  public:
    IJSObject(v8::Isolate * iso, v8::Local<v8::Value> val);
    v8::Local<v8::Object> V8Object();
    // parent's methods
    virtual bool APIENTRY IsObject();
    virtual IJSObject * APIENTRY AsObject();

    virtual void APIENTRY SetFieldValue(char * name, IJSValue * val);
    virtual IJSValue * APIENTRY GetFieldValue(char * name);

  };

  //wrapper for JS delphi object
  class IJSDelphiObject : public IJSObject {
  public:
    IJSDelphiObject(v8::Isolate * iso, v8::Local<v8::Value> val);
    // parent's methods
    virtual bool APIENTRY IsDelphiObject();
    virtual IJSDelphiObject * APIENTRY AsDelphiObject();

    virtual void * APIENTRY GetDelphiObject();
    virtual void * APIENTRY GetDelphiClasstype();
  };

  //wrapper for JS array
  class IJSArray : public IJSValue {
  public:
    IJSArray(v8::Isolate * iso, v8::Local<v8::Value> val);
    ~IJSArray();
    // parent's methods
    virtual bool APIENTRY IsArray();
    virtual IJSArray * APIENTRY AsArray();

    virtual int32_t APIENTRY GetCount();
    virtual IJSValue * APIENTRY GetValue(int32_t index);
    virtual void APIENTRY SetValue(IJSValue * value, int32_t index);
    v8::Local<v8::Array> V8Array();
    std::unordered_map<int32_t, std::unique_ptr<IJSValue>> values;
    std::vector<v8::Local<v8::Value>> ToVector();
  };

  //wrapper for JS function
  class IJSFunction : public IJSValue {
  public:
    IJSFunction(v8::Isolate * iso, v8::Local<v8::Value> val);
    v8::Local<v8::Function> V8Function();
    // parent's methods
    virtual bool APIENTRY IsFunction();
    virtual IJSFunction * APIENTRY AsFunction();

    virtual IJSValue * APIENTRY Call(IJSArray * argv);
  };

  //wrapper for Delphi class property
  struct IClassProp{
  public:
    IClassProp(const char * pName, void * pObj, bool pRead = true,
      bool Pwrite = true);
    std::string name = "";
    bool read = true;
    bool write = true;
    void * obj;
  };

  //wrapper for Delphi class field
  struct IClassField {
    IClassField(const char * fName, void * fObj);
    std::string name;
    void * obj;
  };

  //wrapper for Delphi class method
  struct IClassMethod{
  public:
    IClassMethod(const char * mName, void * mCall);
    std::string name = "";
    void * call = nullptr;
  };

  //wrapper for Delphi class declaration
  class IClassTemplate : public IBaseIntf {
  public:
    IClassTemplate(char * objclasstype, void * delphiClass);

    virtual void APIENTRY SetMethod(char * methodName, void * methodCall);
    ////maybe there isn't needed propObj
    virtual void APIENTRY SetProperty(char* propName, void * propObj,
      bool read, bool write);
    virtual void APIENTRY SetIndexedProperty(char* propName,
      void * propObj, bool read, bool write);
    virtual void APIENTRY SetDefaultIndexedProperty(void * prop);
    virtual void APIENTRY SetField(char* fieldName, void * fieldObj);
    virtual void APIENTRY SetParent(IClassTemplate * parent);

    void ModifyTemplate(v8::Isolate * isolate,
      v8::Local<v8::FunctionTemplate> templ);

    v8::Local<v8::FunctionTemplate> FunctionTemplate(v8::Isolate * isolate);
    //pointer to delphi classtype
    void * dClass = nullptr;
    // class name
    std::string classTypeName;
  protected:
    //??
    std::vector<char> runStringResult;
  private:
    // it will be need for type check like:
    // childObject instanceof parentClass
    IClassTemplate * parentTemplate = nullptr;
    // default indexed property
    void * defaultIndexedProp = nullptr;

    v8::Persistent<v8::FunctionTemplate> v8Template;
    std::vector<std::unique_ptr<IClassProp>> props;
    std::vector<std::unique_ptr<IClassProp>> indexed_props;
    std::vector<std::unique_ptr<IClassField>> fields;
    std::vector<std::unique_ptr<IClassMethod>> methods;
  };

  // Class for enumerator. It stores enum name and its values
  class IEnumTemplate : public IBaseIntf {
  public:
    IEnumTemplate(char * enumName);
    virtual void APIENTRY AddValue(char * valueName, int index);
    std::string name;
    // it stores mathes between enum name and its order number
    std::unordered_map<int, std::string> values;
  };

  class IMethodArgs;
  class IGetterArgs;
  class ISetterArgs;
  class IIndexedGetterArgs;
  class IIndexedSetterArgs;

  class IBaseArgs : public IBaseIntf {
  public:
    virtual void * APIENTRY GetEngine();
    virtual void * APIENTRY GetDelphiObject();
    virtual void * APIENTRY GetDelphiClasstype();
    virtual void APIENTRY SetReturnValue(IJSValue * val) abstract;
    virtual bool APIENTRY IsMethodArgs();
    virtual bool APIENTRY IsGetterArgs();
    virtual bool APIENTRY IsSetterArgs();
    virtual bool APIENTRY IsIndexedGetterArgs();
    virtual bool APIENTRY IsIndexedSetterArgs();
    virtual IMethodArgs * APIENTRY AsMethodArgs();
    virtual IGetterArgs * APIENTRY AsGetterArgs();
    virtual ISetterArgs * APIENTRY AsSetterArgs();
    virtual IIndexedGetterArgs * APIENTRY AsIndexedGetterArgs();
    virtual IIndexedSetterArgs * APIENTRY AsIndexedSetterArgs();

    void SetupArgs(v8::Isolate * isolate, v8::Local<v8::Object> holderObj);
    v8::Isolate * Isolate();
  private:
    v8::Isolate * iso = nullptr;
    IEmbedEngine * engine = nullptr;
    // object, which property/function is called
    v8::Local<v8::Object> holder = v8::Local<v8::Object>();
  };

  class IMethodArgs : public IBaseArgs {
  public:
    IMethodArgs(const v8::FunctionCallbackInfo<v8::Value>& newArgs);
    ~IMethodArgs();
    virtual bool APIENTRY IsMethodArgs();
    virtual IMethodArgs * APIENTRY AsMethodArgs();
    virtual IJSArray * APIENTRY GetArguments();

    virtual char * APIENTRY GetMethodName();

    virtual void APIENTRY SetReturnValue(IJSValue * val);

    virtual void * APIENTRY GetDelphiMethod();
  private:
    const v8::FunctionCallbackInfo<v8::Value>* args = nullptr;
    IJSArray * argv;
    std::string run_string_result;
  };

  class IGetterArgs : public IBaseArgs {
  public:
    IGetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info,
      v8::Local<v8::Value> prop);
    ~IGetterArgs();
    virtual bool APIENTRY IsGetterArgs();
    virtual IGetterArgs * APIENTRY AsGetterArgs();
    virtual IJSValue * APIENTRY GetPropName();
    virtual void * APIENTRY GetPropPointer();

    virtual void APIENTRY SetReturnValue(IJSValue * val);
  private:
    v8::Persistent<v8::Value> propName;
    IJSValue * propWrapper = nullptr;
    const v8::PropertyCallbackInfo<v8::Value> * propinfo = nullptr;
  };

  class ISetterArgs : public IBaseArgs {
  public:
    ISetterArgs(const v8::PropertyCallbackInfo<void>& info,
                v8::Local<v8::Value> prop,
                v8::Local<v8::Value> newValue);
    ~ISetterArgs();
    virtual bool APIENTRY IsSetterArgs();
    virtual ISetterArgs * APIENTRY AsSetterArgs();
    virtual IJSValue * APIENTRY GetPropName();
    virtual void * APIENTRY GetPropPointer();

    virtual IJSValue * APIENTRY GetValue();

    virtual void APIENTRY SetReturnValue(IJSValue * val);
  private:
    IJSValue * propName = nullptr;
    IJSValue * propValue = nullptr;
    const v8::PropertyCallbackInfo<void> * propinfo = nullptr;
  };

  class IIndexedGetterArgs : public IBaseArgs {
  public:
    IIndexedGetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info,
      uint32_t propIndex);
    IIndexedGetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info,
      v8::Local<v8::String> propIndex);
    ~IIndexedGetterArgs();
    virtual bool APIENTRY IsIndexedGetterArgs();
    virtual IIndexedGetterArgs * APIENTRY AsIndexedGetterArgs();
    virtual IJSValue * APIENTRY GetPropIndex();
    virtual void * APIENTRY GetPropPointer();
    virtual void APIENTRY SetReturnValue(IJSValue * val);
  private:
    IJSValue * index;
    const v8::PropertyCallbackInfo<v8::Value> * propinfo = nullptr;
  };

  class IIndexedSetterArgs : public IBaseArgs {
  public:
    IIndexedSetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info,
      uint32_t propIndex,
      v8::Local<v8::Value> newValue);
    IIndexedSetterArgs(const v8::PropertyCallbackInfo<v8::Value>& info,
      v8::Local<v8::String> propIndex,
      v8::Local<v8::Value> newValue);
    ~IIndexedSetterArgs();
    virtual bool APIENTRY IsIndexedSetterArgs();
    virtual IIndexedSetterArgs * APIENTRY AsIndexedSetterArgs();
    virtual IJSValue * APIENTRY GetPropIndex();
    virtual void * APIENTRY GetPropPointer();
    virtual IJSValue * APIENTRY GetValue();
    virtual void APIENTRY SetReturnValue(IJSValue * val);
  private:
    IJSValue * index;
    IJSValue * propValue = nullptr;
    const v8::PropertyCallbackInfo<v8::Value> * propinfo = nullptr;
  };

  typedef void(APIENTRY *TBaseCallBack) (IBaseArgs * args);

  // Store link to Delphi object and classtype. Need for creation additional
  // global properties, that do not described in global template
  class ObjectVariableLink{
  public:
    std::string name;
    void * obj;
    void * classType;
  };

  class ILaunchArguments : IBaseIntf {
  public:
    virtual void APIENTRY AddArgument(char * arg);
    std::vector<const char *> GetLaunchArguments();
  private:
    std::vector<std::string> args;
  };

  class IEmbedEngine : public BaseEngine {
  public:
    IEmbedEngine(void * dEng);
    ~IEmbedEngine();
    //parent functions
    virtual v8::Local<v8::Context> CreateContext(v8::Isolate * isolate);
    // Overrided parent function. Creates additional global variables and
    // executes "pre-code"
    virtual void PrepareForRun();
    virtual void APIENTRY Stop();

    virtual IClassTemplate * APIENTRY AddGlobal(void * dClass);
    virtual IClassTemplate * APIENTRY AddObject(char * className,
      void * classType);
    // Get class template by delphi's classtype. Returns nullptr if tepmlate
    // wasn't created
    virtual IClassTemplate * APIENTRY GetObjectTemplate(void * classType);
    virtual IEnumTemplate * APIENTRY AddEnum(char * enumName);
    // Add Delphi object as global variable. In JS it has no difference with
    // global template's protperty, but here it will return wrapped Delphi
    // object without any callbacks (but global variable can be rewrited
    // by any JS value)
    virtual void APIENTRY AddGlobalVariableObject(char * name,
      void * objPointer, void * classType);
    // Add "pre-code": JS code, that will be executed before runnning
    // main script. It can contain any helpful functions and variables.
    virtual void APIENTRY AddPreCode(char * code);
    virtual ILaunchArguments * APIENTRY CreateLaunchArguments();
    virtual void APIENTRY Launch(ILaunchArguments * args);
    virtual void APIENTRY ChangeWorkingDir(char * newDir);
    virtual IJSValue * APIENTRY CallFunction(char * fName, IJSArray * args);
    virtual void APIENTRY SetExternalCallback(TBaseCallBack callback);

    //these functions avaliable only when script running
    virtual IJSValue * APIENTRY NewInt32(int32_t value);
    virtual IJSValue * APIENTRY NewNumber(double value);
    virtual IJSValue * APIENTRY NewBoolean(bool value);
    virtual IJSValue * APIENTRY NewString(char * value);
    virtual IJSArray * APIENTRY NewArray(int32_t length);
    virtual IJSObject * APIENTRY NewObject();
    virtual IJSDelphiObject * APIENTRY NewDelphiObject(void * value, void * cType);
    // it will create correct value wrapper and store it
    IJSValue * MakeValue(v8::Local<v8::Value> value);


    void * DelphiEngine();
    void* GetDelphiObject(v8::Local<v8::Object> holder);
    void* GetDelphiClasstype(v8::Local<v8::Object> obj);
    IClassTemplate * GetDelphiClassTemplate(void * classType);
    static IEmbedEngine * GetEngine(v8::Isolate * isolate);
    v8::Local<v8::Object> GetIndexedPropertyObject(void * obj,
      void * cType, void * indexedProp);

    TBaseCallBack externalCallback = nullptr;
  private:
    //this will be pointer to delphi engine object
    void * dEngine = nullptr;
    //global template, which is used for creating context
    IClassTemplate * globalTemplate = nullptr;
    //object template for indexed property
    v8::Local<v8::ObjectTemplate> indexedObjectTemplate;
    std::vector<std::unique_ptr<IClassTemplate>> classes;
    std::vector<std::unique_ptr<IEnumTemplate>> enums;
    std::unordered_map<int64_t, std::unique_ptr<IJSDelphiObject>> JSDelphiObjects;
    std::unordered_map<int64_t, v8::Persistent<v8::Object,
      v8::CopyablePersistentTraits<v8::Object>>> jsIndexedPropObjects;
    std::vector<std::unique_ptr<ObjectVariableLink>> objectLinks;
    std::vector<std::unique_ptr<IJSValue>> jsValues;
    // code, that will be executed before script execution (without NodeJS features)
    std::string preCode;
  };

  void FunctionCallBack(const v8::FunctionCallbackInfo<v8::Value>& args);
  void PropGetter(v8::Local<v8::String> prop,
    const v8::PropertyCallbackInfo<v8::Value>& info);
  void PropSetter(v8::Local<v8::String> prop,
                  v8::Local<v8::Value> value,
                  const v8::PropertyCallbackInfo<void>& info);
  void FieldGetter(v8::Local<v8::String> field,
    const v8::PropertyCallbackInfo<v8::Value>& info);
  void FieldSetter(v8::Local<v8::String> field,
    v8::Local<v8::Value> value,
    const v8::PropertyCallbackInfo<void>& info);
  // Getter for indexed property object. For example:
  // if we have object with indexed property "Items",
  // then full accessor is "Items[i]".
  // At first JS call accessor for "Items" property -
  // it will be handled by IndexedPropObjGetter.
  // But accessor for "Items[i]" property will be handled
  // by IndexedPropGetter or IndexedPropSetter
  void IndexedPropObjGetter(v8::Local<v8::String> property,
    const v8::PropertyCallbackInfo<v8::Value>& info);
  // getter for indexed props
  void IndexedPropGetter(uint32_t index,
    const v8::PropertyCallbackInfo<v8::Value>& info);
  // setter for indexed props
  void IndexedPropSetter(uint32_t index,
    v8::Local<v8::Value> value,
    const v8::PropertyCallbackInfo<v8::Value>& info);

  // NamedPropGetter and NamedPropSetter are used for getting/setting
  // value to indexed property where index is string.
  // Getter for indexed property, where index is string
  static void NamedPropGetter(v8::Local<v8::String> property,
    const v8::PropertyCallbackInfo<v8::Value>& info);
  // Setter for indexed property, where index is string
  static void NamedPropSetter(v8::Local<v8::String> property,
    v8::Local<v8::Value> value,
    const v8::PropertyCallbackInfo<v8::Value>& info);

  extern "C" {
    EMBED_EXTERN IEmbedEngine * WINAPIV NewDelphiEngine(void * dEngine);
    EMBED_EXTERN void WINAPIV InitNode(char * executableName);
    EMBED_EXTERN int WINAPIV EmbedMajorVersion();
    EMBED_EXTERN int WINAPIV EmbedMinorVersion();
  }
}
