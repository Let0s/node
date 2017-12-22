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
    v8::Local<v8::Value> V8Value();
    virtual bool APIENTRY IsUndefined();
    virtual bool APIENTRY IsNull();

    virtual bool APIENTRY IsBool();
    virtual bool APIENTRY IsInt32();
    virtual bool APIENTRY IsString();
    virtual bool APIENTRY IsFloat();
    virtual bool APIENTRY IsObject();
    virtual bool APIENTRY IsDelphiObject();
    virtual bool APIENTRY IsArray();
    virtual bool APIENTRY IsFunction();

    virtual bool APIENTRY AsBool();
    virtual int32_t APIENTRY AsInt32();
    virtual char * APIENTRY AsString();
    virtual double APIENTRY AsFloat();
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
    v8::Local<v8::Object> V8Object();
  };

  //wrapper for JS delphi object
  class IJSDelphiObject : public IJSObject {
  };

  //wrapper for JS array
  class IJSArray : public IJSValue {
    v8::Local<v8::Array> V8Array();
  };

  //wrapper for JS function
  class IJSFunction : public IJSValue {

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
    virtual void APIENTRY SetField(char* fieldName);
    virtual void APIENTRY SetParent(IClassTemplate * parent);

    void ModifyTemplate(v8::Isolate * isolate,
      v8::Local<v8::FunctionTemplate> templ);

    //pointer to delphi classtype
    void * dClass = nullptr;
    // class name
    std::string classTypeName;

    // it will be need for type check like:
    // childObject instanceof parentClass
    IClassTemplate * parentTemplate = nullptr;
  protected:
    //??
    std::vector<char> runStringResult;
  private:
    std::vector<std::unique_ptr<IClassProp>> props;
    std::vector<std::unique_ptr<IClassProp>> indexed_props;
    std::vector<std::string> fields;
    std::vector<std::unique_ptr<IClassMethod>> methods;
  };

  class IMethodArgs : public IBaseIntf {
  public:
    IMethodArgs(const v8::FunctionCallbackInfo<v8::Value>& newArgs);
    virtual void * APIENTRY GetEngine();
    virtual void * APIENTRY GetDelphiObject();
    virtual void * APIENTRY GetDelphiClasstype();

    virtual char * APIENTRY GetMethodName();

    virtual void APIENTRY SetReturnValueInt(int32_t val);
    virtual void APIENTRY SetReturnValueBool(bool val);
    virtual void APIENTRY SetReturnValueString(char * val);
    virtual void APIENTRY SetReturnValueDouble(double val);

    virtual void * APIENTRY GetDelphiMethod();
  private:
    v8::Isolate * iso = nullptr;
    IEmbedEngine * engine = nullptr;
    const v8::FunctionCallbackInfo<v8::Value>* args = nullptr;
    std::string run_string_result;
  };

  typedef void(APIENTRY *TMethodCallBack) (IMethodArgs * args);

  class IEmbedEngine : public BaseEngine {
  public:
    IEmbedEngine(void * dEng);
    ~IEmbedEngine();
    virtual v8::Local<v8::Context> CreateContext(v8::Isolate * isolate);
    virtual IClassTemplate * APIENTRY AddGlobal(void * dClass);
    virtual IClassTemplate * APIENTRY AddObject(char * className,
      void * classType);
    virtual void APIENTRY RunString(char * code);
    virtual void APIENTRY SetFunctionCallBack(TMethodCallBack functionCB);

    void * DelphiEngine();
    void* GetDelphiObject(v8::Local<v8::Object> holder);
    void* GetDelphiClasstype(v8::Local<v8::Object> obj);
    static IEmbedEngine * GetEngine(v8::Isolate * isolate);

    TMethodCallBack functionCallBack;
  private:
    //this will be pointer to delphi engine object
    void * dEngine = nullptr;
    //global template, which is used for creating context
    IClassTemplate * globalTemplate = nullptr;
    std::vector<std::unique_ptr<IClassTemplate>> objects;
  };

  void FunctionCallBack(const v8::FunctionCallbackInfo<v8::Value>& args);

  extern "C" {
    EMBED_EXTERN IEmbedEngine * APIENTRY NewDelphiEngine(void * dEngine);
    EMBED_EXTERN void APIENTRY InitNode(char * executableName);
  }
}
