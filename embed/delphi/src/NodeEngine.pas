unit NodeEngine;

interface

uses
  NodeInterface, SysUtils, RTTI, Types, TypInfo, EngineHelper,
  Generics.Collections;

type
  TJSEngine = class;

  TClassWrapper = class(TObject)
  private
    FType: TClass;
    FTemplate: IClassTemplate;
    FParent: TClassWrapper;
    FEngine: INodeEngine;
  public
    constructor Create(cType: TClass; Engine: TJSEngine; Parent: TClassWrapper;
      IsGlobal: boolean = False);
    destructor Destroy; override;
  end;

  TJSEngine = class(TObject)
  private
    FEngine: INodeEngine;
    FGlobal: TObject;
    FClasses: TDictionary<TClass, TClassWrapper>;
    FGarbageCollector: TGarbageCollector;
  public
    constructor Create();
    destructor Destroy; override;
    function AddClass(classType: TClass): TClassWrapper;
    procedure AddGlobal(Global: TObject);
    procedure RunString(code: string);
    procedure RunFile(filename: string);
    procedure CheckEventLoop;
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
  ObjType: TClass;
  Result: TValue;
  JSResult: IJSValue;
  MethodArgs: TArray<TValue>;
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
    MethodArgs := JSParametersToTValueArray(Method.GetParameters, Args.GetArgs,
      Engine.FGarbageCollector);
    if Assigned(Obj) and (not Method.IsClassMethod) then
      Result := Method.Invoke(Obj, MethodArgs)
    else if Method.IsClassMethod then
    begin
      if Assigned(Obj) then
        ObjType := Obj.ClassType
      else
        ObjType := Method.Parent.Handle.TypeData.ClassType;
      Result := Method.Invoke(ObjType, MethodArgs);
    end;
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
        JSValueToTValue(JSValue, Prop.PropertyType, Engine.FGarbageCollector));
    Result := Prop.GetValue(Obj);
    JSValue := TValueToJSValue(Result, Engine.FEngine);
    if Assigned(JSValue) then
      Args.SetSetterResult(JSValue);
  end;
end;

{ TJSEngine }

function TJSEngine.AddClass(classType: TClass): TClassWrapper;
var
  ClassWrapper: TClassWrapper;
  ParentWrapper: TClassWrapper;
  Parent: TClass;
begin
  Result := nil;
//  if Inactive then
//    Exit;
  if (classType = FGlobal.ClassType) or (classType = TObject) then
    Exit;
  Parent := classType.ClassParent;
  while Assigned(Parent) and (Parent <> TObject) do
  begin
    AddClass(Parent);
    Parent := Parent.ClassParent;
  end;
  if not FClasses.TryGetValue(classType, ClassWrapper) then
  begin
    FClasses.TryGetValue(classType.ClassParent, ParentWrapper);
    ClassWrapper := TClassWrapper.Create(classType, Self, ParentWrapper);
    FClasses.Add(classType, ClassWrapper);
  end;
  Result := ClassWrapper;
end;

procedure TJSEngine.AddGlobal(Global: TObject);
var
  GlobalWrapper: TClassWrapper;
begin
  FGlobal := Global;
  GlobalWrapper := TClassWrapper.Create(Global.ClassType, Self, nil, True);
  FClasses.Add(Global.ClassType, GlobalWrapper);
end;

procedure TJSEngine.CheckEventLoop;
begin
  FEngine.CheckEventLoop;
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
    FClasses := TDictionary<TClass, TClassWrapper>.Create;
    FGarbageCollector := TGarbageCollector.Create;
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
  FClasses.Free;
  FGarbageCollector.Free;
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

{ TClassWrapper }

constructor TClassWrapper.Create(cType: TClass; Engine: TJSEngine;
  Parent: TClassWrapper; IsGlobal: Boolean);
var
  ClasslTyp: TRttiType;
  Method: TRttiMethod;
  Prop: TRttiProperty;
begin
  FType := cType;
  FParent := Parent;
  FEngine := Engine.FEngine;
  ClasslTyp := Context.GetType(FType);
  if IsGlobal then
    FTemplate := FEngine.AddGlobal(FType)
  else
    FTemplate := FEngine.AddObject(StringToPUtf8Char(cType.ClassName), cType);
  for Method in ClasslTyp.GetMethods do
  begin
    if (Method.Visibility = mvPublic) and
      (not (Method.IsConstructor or Method.IsDestructor)) and
      (Method.Parent.Handle = ClasslTyp.Handle) then
    begin
      if Assigned(Method.ReturnType) and
        (Method.ReturnType.TypeKind = tkClass) then
          Engine.AddClass(Method.ReturnType.Handle.TypeData.ClassType);
      FTemplate.SetMethod(StringToPUtf8Char(Method.Name), Method);
    end;
  end;
  for Prop in ClasslTyp.GetProperties do
  begin
    if (Prop.Visibility = mvPublic) and
      (Prop.Parent.Handle = ClasslTyp.Handle) then
    begin
      if Prop.PropertyType.TypeKind = tkClass then
        Engine.AddClass(Prop.PropertyType.Handle.TypeData.ClassType);
      FTemplate.SetProperty(StringToPUtf8Char(Prop.Name), Prop,
        Prop.IsReadable, Prop.IsWritable);
    end;
  end;
  if Assigned(FParent) then
    FTemplate.SetParent(FParent.FTemplate);
end;

destructor TClassWrapper.Destroy;
begin
  inherited;
end;

end.
