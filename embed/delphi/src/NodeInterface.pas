unit NodeInterface;

interface
  const LIB_NAME = 'node.dll';
  //these version consts will use to check node.dll
  const EMBED_MAJOR_VERSION = 0;
  const EMBED_MINOR_VERSION = 1;

type
  IBaseInterface = class
    // do not call!
    // here because implementation needs virtual C++ destructor
    procedure _Destructor; virtual; abstract;
    procedure Delete; virtual; stdcall; abstract;
    function Test: Integer; virtual; stdcall; abstract;
  end;

  // don't use functions from this class
  //   these functions are virtual for its child classes
  IBaseEngine = class(IBaseInterface)
    function CreateContext(): Pointer; virtual; stdcall; abstract;
  end;

  // delphi class wrapper
  IClassTemplate = class(IBaseEngine)
    procedure SetMethod(name: PAnsiChar; method: Pointer); virtual;
      stdcall; abstract;
    procedure SetProperty(name: PAnsiChar; prop: Pointer;
      read, write: Boolean); virtual; stdcall; abstract;
    procedure SetIndexedProperty(name: PAnsiChar; prop: Pointer;
      read, write: Boolean); virtual; stdcall; abstract;
    procedure SetField(name: PAnsiChar); virtual; stdcall; abstract;
    procedure SetParent(parent: IClassTemplate); virtual; stdcall; abstract;
  end;

  // Engine class;
  INodeEngine = class(IBaseEngine)
    function AddObject(className: PAnsiChar; classType: Pointer): IClassTemplate;
      virtual; stdcall; abstract;
    procedure RunString(code: PAnsiChar); virtual; stdcall; abstract;
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
