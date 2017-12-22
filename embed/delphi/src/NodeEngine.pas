unit NodeEngine;

interface

uses
  NodeInterface, SysUtils, RTTI, Types, TypInfo;

type
  TJSEngine = class(TObject)
  private
    FEngine: INodeEngine;
    FGlobal: TObject;
  public
    constructor Create();
    procedure AddGlobal(Global: TObject);
    procedure RunString(code: string);
    procedure RunFile(filename: string);
    destructor Destroy; override;
  end;

  procedure MethodCallBack(Args: IMethodArgs); stdcall;

implementation

var
  Context: TRttiContext;

procedure MethodCallBack(Args: IMethodArgs);
var
  Engine: TJSEngine;
  Method: TRttiMethod;
  Obj: TObject;
  Result: TValue;
  JSResult: IJSValue;
begin
  Engine := Args.GetEngine as TJSEngine;
  if Assigned(Engine) then
  begin
    //all objects will be stored in JS value when accessor (or function)
    // will be called
    Obj := Args.GetDelphiObject;
    if not Assigned(Obj) then
    begin
      if Args.GetDelphiClasstype = Engine.FGlobal.ClassType then
        Obj := Engine.FGlobal;
    end;
    Method := Args.GetDelphiMethod as TRttiMethod;
    JSResult := nil;
    Result := Method.Invoke(Obj, []);
    case Result.Kind of
      tkInteger: JSResult := Engine.FEngine.NewInt32(Result.AsInteger);
      tkInt64: ;//Args.SetReturnValue(Result.AsInt64);
      tkEnumeration: JSResult := Engine.FEngine.NewInt32(Result.AsOrdinal);
      tkChar, tkString, tkWChar, tkLString, tkWString, tkUString:
        JSResult := Engine.FEngine.NewString(StringToPUtf8Char(Result.AsString));
      tkFloat: JSResult := Engine.FEngine.NewNumber(Result.AsExtended);
      tkSet: ;
      tkClass: JSResult := Engine.FEngine.NewDelphiObject(Result.AsObject,
        Result.AsObject.ClassType);
      tkMethod: ;
      tkVariant: ;
      tkArray: ;
      tkRecord: ;
      tkInterface: ;
      tkDynArray: ;
      tkClassRef: ;
      tkPointer: ;
      tkProcedure: ;
    end;
    if Assigned(JSResult) then
      Args.SetReturnValue(JSResult);
  end;
end;

{ TJSEngine }

procedure TJSEngine.AddGlobal(Global: TObject);
var
  GlobalTemplate: IClassTemplate;
  GlobalTyp: TRttiType;
  Method: TRttiMethod;
begin
  FGlobal := Global;
  GlobalTyp := Context.GetType(Global.ClassType);
  GlobalTemplate := FEngine.AddGlobal(Global.ClassType);
  for Method in GlobalTyp.GetMethods do
  begin
    if (Method.Visibility = mvPublic) and
      (Method.Parent.Handle = GlobalTyp.Handle) then
    begin
      GlobalTemplate.SetMethod(StringToPUtf8Char(Method.Name), Method);
    end;
  end;
end;

constructor TJSEngine.Create;
begin
  try
    //TODO: CheckNodeversion and raise exception if major_ver mismatch
//      Format('Failed to intialize node.dll. ' +
//        'Incorrect version. Required %d version', [NODE_AVAILABLE_VER]);
    FEngine := NewDelphiEngine(Self);
    FEngine.SetMethodCallBack(MethodCallBack);
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
