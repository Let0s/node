unit NodeEngine;

interface

uses
  NodeInterface, SysUtils, RTTI, Types, TypInfo, EngineHelper;

type
  TJSEngine = class(TObject)
  private
    FEngine: INodeEngine;
    FGlobal: TObject;
  public
    constructor Create();
    destructor Destroy; override;
    procedure AddGlobal(Global: TObject);
    procedure RunString(code: string);
    procedure RunFile(filename: string);
  end;

  procedure MethodCallBack(Args: IMethodArgs); stdcall;
  procedure PropGetterCallBack(Args: IGetterArgs); stdcall;
  procedure PropSetterCallBack(Args: ISetterArgs); stdcall;

implementation


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
    Result := Method.Invoke(Obj, []);
    JSResult := TValueToJSValue(Result, Engine.FEngine);
    if Assigned(JSResult) then
      Args.SetReturnValue(JSResult);
  end;
end;

procedure PropGetterCallBack(Args: IGetterArgs); stdcall;
var
  Engine: TJSEngine;
  Prop: TRttiProperty;
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
    Prop := Args.GetProp as TRttiProperty;
    Result := Prop.GetValue(Obj);
    JSResult := TValueToJSValue(Result, Engine.FEngine);
    if Assigned(JSResult) then
      Args.SetGetterResult(JSResult);
  end;
end;

procedure PropSetterCallBack(Args: ISetterArgs); stdcall;
var
  Engine: TJSEngine;
  Prop: TRttiProperty;
  Obj: TObject;
  Result: TValue;
  JSValue: IJSValue;
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
    Prop := Args.GetProp as TRttiProperty;
    JSValue := Args.GetPropValue;
    if Assigned(JSValue) then
      Prop.SetValue(Obj,
        JSValueToTValue(JSValue, Prop.PropertyType, Engine.FEngine));
    Result := Prop.GetValue(Obj);
    JSValue := TValueToJSValue(Result, Engine.FEngine);
    if Assigned(JSValue) then
      Args.SetSetterResult(JSValue);
  end;
end;

{ TJSEngine }

procedure TJSEngine.AddGlobal(Global: TObject);
var
  GlobalTemplate: IClassTemplate;
  GlobalTyp: TRttiType;
  Method: TRttiMethod;
  Prop: TRttiProperty;
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
  for Prop in GlobalTyp.GetProperties do
  begin
    if (Prop.Visibility = mvPublic) and
      (Prop.Parent.Handle = GlobalTyp.Handle) then
    begin
      GlobalTemplate.SetProperty(StringToPUtf8Char(Prop.Name), Prop,
        Prop.IsReadable, Prop.IsWritable);
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
    FEngine.SetPropGetterCallBack(PropGetterCallBack);
    FEngine.SetPropSetterCallBack(PropSetterCallBack);
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
  FEngine.Delete;
  inherited;
end;

procedure TJSEngine.RunFile(filename: string);
begin
  FEngine.RunFile(StringToPUtf8Char(filename));
end;

procedure TJSEngine.RunString(code: string);
begin
  FEngine.RunString(StringToPUtf8Char(code));
end;

end.
