#pragma once
#include "embed.h"

//here will be export functions and classes to use NodeJS in delphi projects

namespace embed {
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

  class IEmbedEngine : public BaseEngine {
  public:
    IEmbedEngine(void * dEng);
    virtual v8::Local<v8::Context> CreateContext(v8::Isolate * isolate);
    virtual IClassTemplate * AddObject(char * className, void * classType);
    virtual void APIENTRY RunString(char * code);
    void * DelphiEngine();
    static IEmbedEngine * GetEngine(v8::Isolate * isolate);
  private:
    //this will be pointer to delphi engine object
    void * dEngine = nullptr;
    std::vector<std::unique_ptr<IClassTemplate>> objects;
  };

  extern "C" {
    EMBED_EXTERN IEmbedEngine * APIENTRY NewDelphiEngine(void * dEngine);
    EMBED_EXTERN void APIENTRY InitNode(char * executableName);
  }
}
