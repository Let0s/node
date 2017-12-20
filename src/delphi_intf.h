#pragma once
#include "embed.h"

//here will be export functions and classes to use NodeJS in delphi projects

namespace embed {
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
