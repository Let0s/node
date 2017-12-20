#pragma once
#include "embed.h"

//here will be export functions and classes to use NodeJS in delphi projects

namespace embed {
  struct IObjectProp{
  public:
    IObjectProp(const char * pName, void * pObj, bool pRead = true,
      bool Pwrite = true);
    std::string name = "";
    bool read = true;
    bool write = true;
    void * obj;
  };

  struct IObjectMethod{
  public:
    IObjectMethod(const char * mName, void * mCall);
    std::string name = "";
    void * call = nullptr;
  };

  class IObjectTemplate : public IBaseIntf {
  public:
    IObjectTemplate(char * objclasstype, void * delphiClass, v8::Isolate * isolate);

    virtual void APIENTRY SetMethod(char * methodName, void * methodCall);
    ////maybe there isn't needed propObj
    virtual void APIENTRY SetProperty(char* propName, void * propObj,
      bool read, bool write);
    virtual void APIENTRY SetIndexedProperty(char* propName,
      void * propObj, bool read, bool write);
    virtual void APIENTRY SetField(char* fieldName);
    virtual void APIENTRY SetParent(IObjectTemplate * parent);

    //pointer to delphi classtype
    void * dClass = nullptr;
    // class name
    std::string classTypeName;

    // it will be need for type check like:
    // childObject instanceof parentClass
    IObjectTemplate * parentTemplate = nullptr;
  protected:
    //??
    std::vector<char> runStringResult;
  private:
    //result object template for JS
    v8::Local<v8::FunctionTemplate> objTempl;

    std::vector<std::unique_ptr<IObjectProp>> props;
    std::vector<std::unique_ptr<IObjectProp>> indexed_props;
    std::vector<std::string> fields;
    std::vector<std::unique_ptr<IObjectMethod>> methods;

    v8::Isolate * iso = nullptr;
  };

  class IEmbedEngine : public BaseEngine {
  private:
    //this will be pointer to delphi engine object
    void * dEngine = nullptr;
  public:
    IEmbedEngine(void * dEng);
    virtual void APIENTRY RunString(char * code);
  };

  extern "C" {
    EMBED_EXTERN IEmbedEngine * APIENTRY NewDelphiEngine(void * dEngine);
    EMBED_EXTERN void APIENTRY InitNode(char * executableName);
  }
}
