#include "delphi_intf.h"
namespace embed {
  //full path to executable (argv0)
  std::string exeName;

  IEmbedEngine::IEmbedEngine(void * dEng) : BaseEngine()
  {
    dEngine = dEng;
  }

  void IEmbedEngine::RunString(char * code)
  {
    std::vector<const char *> args;
    args.push_back(exeName.c_str());
    args.push_back("-e");
    args.push_back(code);
    Run(args.size(), args.data());
  }

  EMBED_EXTERN IEmbedEngine * NewDelphiEngine(void * dEngine)
  {
    return new IEmbedEngine(dEngine);
  }
  EMBED_EXTERN void InitNode(char * executableName)
  {
    Init();
  }
  IObjectProp::IObjectProp(const char * pName, void * pObj, bool pRead, bool Pwrite)
  {
    name = pName;
    obj = pObj;
    read = pRead;
    write = Pwrite;
  }
  IObjectMethod::IObjectMethod(const char * mName, void * mCall)
  {
    name = mName;
    call = mCall;
  }
  IObjectTemplate::IObjectTemplate(char * objclasstype, void * delphiClass, v8::Isolate * isolate)
  {
    classTypeName = objclasstype;
    dClass = delphiClass;
    iso = isolate;
  }
  void IObjectTemplate::SetMethod(char * methodName, void * methodCall)
  {
    auto method = std::make_unique<IObjectMethod>(methodName, methodCall);
    methods.push_back(std::move(method));
  }
  void IObjectTemplate::SetProperty(char * propName, void * propObj, bool read, bool write)
  {
    auto prop = std::make_unique<IObjectProp>(propName, propObj, read, write);
    props.push_back(std::move(prop));
  }
  void IObjectTemplate::SetIndexedProperty(char * propName, void * propObj, bool read, bool write)
  {
    auto prop = std::make_unique<IObjectProp>(propName, propObj, read, write);
    indexed_props.push_back(std::move(prop));
  }
  void IObjectTemplate::SetField(char * fieldName)
  {
    fields.push_back(fieldName);
  }
  void IObjectTemplate::SetParent(IObjectTemplate * parent)
  {
    parentTemplate = parent;
  }
}
