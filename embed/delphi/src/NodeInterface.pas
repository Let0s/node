unit NodeInterface;

interface
  const LIB_NAME = 'node.dll';
  //these version consts will use to check node.dll
  const EMBED_MAJOR_VERSION = 0;
  const EMBED_MINOR_VERSION = 1;

type
  IJSObject = class;
  IJSDelphiObject = class;
  IJSArray = class;
  IJSFunction = class;

  IBaseInterface = class
    // do not call!
    // here because implementation needs virtual C++ destructor
    procedure _Destructor; virtual; abstract;
    procedure Delete; virtual; stdcall; abstract;
    function Test: Integer; virtual; stdcall; abstract;
  end;

  IBaseEngine = class(IBaseInterface)
    //do not call
    function _CreateContext(param: Pointer): Pointer; virtual; abstract;
    procedure Stop(); virtual; stdcall; abstract;
  end;

  IJSValue = class(IBaseInterface)
    function IsUndefined: boolean; virtual; stdcall; abstract;
    function IsNull: boolean; virtual; stdcall; abstract;

    function IsBool: boolean; virtual; stdcall; abstract;
    function IsInt32: boolean; virtual; stdcall; abstract;
    function IsString: boolean; virtual; stdcall; abstract;
    function IsNumber: boolean; virtual; stdcall; abstract;
    function IsObject: boolean; virtual; stdcall; abstract;
    function IsDelphiObject: boolean; virtual; stdcall; abstract;
    function IsArray: boolean; virtual; stdcall; abstract;
    function IsFunction: boolean; virtual; stdcall; abstract;

    function AsBool: boolean; virtual; stdcall; abstract;
    function AsInt32: Int32; virtual; stdcall; abstract;
    function AsString: PAnsiChar; virtual; stdcall; abstract;
    function AsNumber: double; virtual; stdcall; abstract;
    function AsObject: IJSObject; virtual; stdcall; abstract;
    function AsDelphiObject: IJSDelphiObject; virtual; stdcall; abstract;
    function AsArray: IJSArray; virtual; stdcall; abstract;
    function AsFunction: IJSFunction; virtual; stdcall; abstract;
  end;

  IJSObject = class(IJSValue)

  end;

  IJSDelphiObject = class(IJSObject)
    function GetDelphiObject: TObject; virtual; stdcall; abstract;
    function GetDelphiClasstype: TClass; virtual; stdcall; abstract;
  end;

  IJSArray = class(IJSValue)

  end;

  IJSFunction = class(IJSValue)

  end;

  // delphi class wrapper
  IClassTemplate = class(IBaseInterface)
    procedure SetMethod(name: PAnsiChar; method: Pointer); virtual;
      stdcall; abstract;
    procedure SetProperty(name: PAnsiChar; prop: Pointer;
      read, write: Boolean); virtual; stdcall; abstract;
    procedure SetIndexedProperty(name: PAnsiChar; prop: Pointer;
      read, write: Boolean); virtual; stdcall; abstract;
    procedure SetField(name: PAnsiChar); virtual; stdcall; abstract;
    procedure SetParent(parent: IClassTemplate); virtual; stdcall; abstract;
  end;

  IMethodArgs = class (IBaseInterface)
    function GetEngine: TObject; virtual; stdcall; abstract;
    function GetDelphiObject: TObject; virtual; stdcall; abstract;
    function GetDelphiClasstype: TClass; virtual; stdcall; abstract;

    function GetMethodName: PAnsiChar; virtual; stdcall; abstract;

    procedure SetReturnValue(val: IJSValue); virtual; stdcall; abstract;

    function GetDelphiMethod: TObject; virtual; stdcall; abstract;
  end;

  TMethodCallBack = procedure(args: IMethodArgs); stdcall;

  // Engine class;
  INodeEngine = class(IBaseEngine)
    function AddGlobal(classType: Pointer): IClassTemplate;
      virtual; stdcall; abstract;
    function AddObject(className: PAnsiChar; classType: Pointer): IClassTemplate;
      virtual; stdcall; abstract;
    procedure RunString(code: PAnsiChar); virtual; stdcall; abstract;
    procedure RunFile(filename: PAnsiChar); virtual; stdcall; abstract;
    procedure SetMethodCallBack(callBack: TMethodCallBack);
      virtual; stdcall; abstract;

    // if no script running it will return nil;
    function NewInt32(value: Int32): IJSValue; virtual; stdcall; abstract;
    function NewNumber(value: double): IJSValue; virtual; stdcall; abstract;
    function NewBool(value: Boolean): IJSValue; virtual; stdcall; abstract;
    function NewString(value: PAnsiChar): IJSValue; virtual; stdcall; abstract;
    function NewDelphiObject(value: TObject;
      classType: TClass): IJSDelphiObject; virtual; stdcall; abstract;

  end;

  function NewDelphiEngine(DEngine: TObject): INodeEngine stdcall;
    external LIB_NAME delayed;
  procedure InitNode(executableName: PAnsiChar); stdcall;
    external LIB_NAME delayed;


  function PUtf8CharToString(s: PAnsiChar): string;
  function StringToPUtf8Char(s: string): PAnsiChar;

implementation

function PUtf8CharToString(s: PAnsiChar): string;
begin
  Result := UTF8ToUnicodeString(RawByteString(s));
end;

function StringToPUtf8Char(s: string): PAnsiChar;
begin
  Result := PAnsiChar(UTF8String(s));
end;
end.
