unit NodeEngine;

interface

uses
  NodeInterface, SysUtils, RTTI, Types, TypInfo;

type
  TJSEngine = class(TObject)
  private
    FEngine: INodeEngine;
  public
    constructor Create();
    procedure AddGlobal(Global: TObject);
    procedure RunString(code: string);
    procedure RunFile(filename: string);
    destructor Destroy; override;
  end;

implementation

var
  Context: TRttiContext;

{ TJSEngine }

procedure TJSEngine.AddGlobal(Global: TObject);
var
  GlobalTemplate: IClassTemplate;
  GlobalTyp: TRttiType;
  Method: TRttiMethod;
begin
  GlobalTyp := Context.GetType(Global.ClassType);
  GlobalTemplate := FEngine.AddGlobal(Global.ClassType);
  for Method in GlobalTyp.GetMethods do
  begin
    if (Method.Visibility = mvPublic) and
      (Method.Parent.Handle = GlobalTyp.Handle) then
    begin
      GlobalTemplate.SetMethod(StringToPUtf8Char(Method.Name), nil);
    end;
  end;
end;

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

initialization
  Context := TRttiContext.Create;

finalization
  Context.Free;

end.
