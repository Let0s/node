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
  INodeEngine = class;
  IMethodArgs = class;
  IGetterArgs = class;
  ISetterArgs = class;
  IIndexedGetterArgs = class;
  IIndexedSetterArgs = class;

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
    procedure _PrepareForRun; virtual; abstract;

    //check for result of async node actions if event loop is alive
    procedure CheckEventLoop(); virtual; stdcall; abstract;
    procedure Stop(); virtual; stdcall; abstract;
  end;

  IJSValue = class(IBaseInterface)
    function GetEngine: INodeEngine; virtual; stdcall; abstract;
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
    procedure SetField(name: PAnsiChar; value: IJSValue); virtual; stdcall; abstract;
    function GetField(name: PAnsiChar): IJSValue; virtual; stdcall; abstract;
  end;

  IJSDelphiObject = class(IJSObject)
    function GetDelphiObject: TObject; virtual; stdcall; abstract;
    function GetDelphiClasstype: TClass; virtual; stdcall; abstract;
  end;

  IJSArray = class(IJSValue)
    function GetCount: Int32; virtual; stdcall; abstract;
    function GetValue(index: Int32): IJSValue; virtual; stdcall; abstract;
    procedure SetValue(Value: IJSValue; index: Int32);
      virtual; stdcall; abstract;
  end;

  IJSFunction = class(IJSValue)
    function Call(Args: IJSArray): IJSValue; virtual; stdcall; abstract;
  end;

  // delphi class wrapper
  IClassTemplate = class(IBaseInterface)
    procedure SetMethod(name: PAnsiChar; method: Pointer); virtual;
      stdcall; abstract;
    procedure SetProperty(name: PAnsiChar; prop: Pointer;
      read, write: Boolean); virtual; stdcall; abstract;
    procedure SetIndexedProperty(name: PAnsiChar; prop: Pointer;
      read, write: Boolean); virtual; stdcall; abstract;
    procedure SetDefaultIndexedProperty(prop: TObject);
      virtual; stdcall; abstract;
    procedure SetField(name: PAnsiChar; field: Pointer); virtual; stdcall; abstract;
    procedure SetParent(parent: IClassTemplate); virtual; stdcall; abstract;
  end;

  IEnumTemplate = class(IBaseInterface)
    procedure AddValue(name: PAnsiChar; index: Integer);
      virtual; stdcall; abstract;
  end;

  IBaseArgs = class (IBaseInterface)
    function GetEngine: TObject; virtual; stdcall; abstract;
    function GetDelphiObject: TObject; virtual; stdcall; abstract;
    function GetDelphiClasstype: TClass; virtual; stdcall; abstract;
    procedure SetReturnValue(val: IJSValue); virtual; stdcall; abstract;
    procedure ThrowError(msg: PAnsiChar); virtual; stdcall; abstract;
    procedure ThrowTypeError(msg: PAnsiChar); virtual; stdcall; abstract;
    function IsMethodArgs(): boolean; virtual; stdcall; abstract;
    function IsGetterArgs(): boolean; virtual; stdcall; abstract;
    function IsSetterArgs(): boolean; virtual; stdcall; abstract;
    function IsIndexedGetterArgs(): boolean; virtual; stdcall; abstract;
    function IsIndexedSetterArgs(): boolean; virtual; stdcall; abstract;
    function AsMethodArgs(): IMethodArgs; virtual; stdcall; abstract;
    function AsGetterArgs(): IGetterArgs; virtual; stdcall; abstract;
    function AsSetterArgs(): ISetterArgs; virtual; stdcall; abstract;
    function AsIndexedGetterArgs(): IIndexedGetterArgs; virtual; stdcall; abstract;
    function AsIndexedSetterArgs(): IIndexedSetterArgs; virtual; stdcall; abstract;
  end;

  IMethodArgs = class (IBaseArgs)
    function GetArgs: IJSArray; virtual; stdcall; abstract;

    function GetMethodName: PAnsiChar; virtual; stdcall; abstract;

    function GetDelphiMethod: TObject; virtual; stdcall; abstract;
  end;

  IGetterArgs = class (IBaseArgs)
    function GetPropName: IJSValue; virtual; stdcall; abstract;
    function GetProp: TObject; virtual; stdcall; abstract;
  end;

  ISetterArgs = class (IBaseArgs)
    function GetPropName: IJSValue; virtual; stdcall; abstract;
    function GetProp: TObject; virtual; stdcall; abstract;

    function GetPropValue: IJSValue; virtual; stdcall; abstract;
  end;

  IIndexedGetterArgs = class (IBaseArgs)
    function GetPropIndex: IJSValue; virtual; stdcall; abstract;
    function GetPropPointer: TObject; virtual; stdcall; abstract;
  end;

  IIndexedSetterArgs = class (IBaseArgs)
    function GetPropIndex: IJSValue; virtual; stdcall; abstract;
    function GetPropPointer: TObject; virtual; stdcall; abstract;
    function GetValue: IJSValue; virtual; stdcall; abstract;
  end;

  TBaseCallBack = procedure(args: IBaseArgs); stdcall;

  ILaunchArguments = class(IBaseInterface)
    procedure AddArgument(arg: PAnsiChar); virtual; stdcall; abstract;
  end;

  // Engine class;
  INodeEngine = class(IBaseEngine)
    function AddGlobal(classType: Pointer): IClassTemplate;
      virtual; stdcall; abstract;
    function AddObject(className: PAnsiChar; classType: Pointer): IClassTemplate;
      virtual; stdcall; abstract;
    function GetObjectTemplate(classType: TClass): IClassTemplate;
      virtual; stdcall; abstract;
    function AddEnum(enumName: PAnsiChar): IEnumTemplate;
      virtual; stdcall; abstract;
    procedure AddGlobalVariableObject(name: PAnsiChar; obj: TObject;
      classType: TClass); virtual; stdcall; abstract;
    procedure AddPreCode(code: PAnsiChar); virtual; stdcall; abstract;
    function CreateLaunchArguments: ILaunchArguments; virtual; stdcall; abstract;
    procedure Launch(args: ILaunchArguments); virtual; stdcall; abstract;
    procedure ChangeWorkingDir(newDir: PAnsiChar); virtual; stdcall; abstract;
    function CallFunction(funcName: PAnsiChar; args: IJSArray): IJSValue;
      virtual; stdcall; abstract;
    procedure SetExternalCallback(cb: TBaseCallBack); virtual; stdcall; abstract;

    // if no script running it will return nil;
    function NewInt32(value: Int32): IJSValue; virtual; stdcall; abstract;
    function NewNumber(value: double): IJSValue; virtual; stdcall; abstract;
    function NewBool(value: Boolean): IJSValue; virtual; stdcall; abstract;
    function NewString(value: PAnsiChar): IJSValue; virtual; stdcall; abstract;
    function NewArray(length: Int32): IJSArray; virtual; stdcall; abstract;
    function NewObject(): IJSObject; virtual; stdcall; abstract;
    function NewDelphiObject(value: TObject;
      classType: TClass): IJSDelphiObject; virtual; stdcall; abstract;

  end;

  function NewDelphiEngine(DEngine: TObject): INodeEngine cdecl;
    external LIB_NAME delayed;
  procedure InitNode(executableName: PAnsiChar); cdecl;
    external LIB_NAME delayed;
  function EmbedMajorVersion: integer; cdecl; external LIB_NAME delayed;
  function EmbedMinorVersion: integer; cdecl; external LIB_NAME delayed;


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
