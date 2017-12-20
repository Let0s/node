unit NodeEngine;

interface

uses
  NodeInterface, SysUtils;

type
  TJSEngine = class(TObject)
  private
    FEngine: INodeEngine;
  public
    constructor Create();
    procedure RunString(code: string);
    procedure RunFile(filename: string);
    destructor Destroy; override;
  end;

implementation

{ TJSEngine }

constructor TJSEngine.Create;
begin
  try
    //TODO: CheckNodeversion and raise exception if major_ver mismatch
//      Format('Failed to intialize node.dll. ' +
//        'Incorrect version. Required %d version', [NODE_AVAILABLE_VER]);
    FEngine := NewDelphiEngine(Self)
  except
    on E: EExternalException do
    begin
      //TODO: Raise special exception
      // := 'Failed to initialize node.dll';
    end;
  end;
end;

destructor TJSEngine.Destroy;
begin

  inherited;
end;

procedure TJSEngine.RunFile(filename: string);
begin
  //TODO:
end;

procedure TJSEngine.RunString(code: string);
begin
  FEngine.RunString(StringToPUtf8Char(code));
end;

end.
