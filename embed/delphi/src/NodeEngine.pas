unit NodeEngine;

interface

uses
  NodeInterface, SysUtils, RTTI, Types, TypInfo, EngineHelper, IOUtils,
  Generics.Collections;

type
  TJSEngine = class;

  TRttiMethodList = class(TList<TRttiMethod>)
  public
    function GetMethod(args: IJSArray): TRttiMethod;
  end;

  TClassWrapper = class(TObject)
  private
    FType: TClass;
    FTemplate: IClassTemplate;
    FParent: TClassWrapper;
    FMethods: TObjectDictionary<string, TRttiMethodList>;
    FEngine: INodeEngine;
    procedure AddMethods(ClassTyp: TRttiType; Engine: TJSEngine);
    procedure AddProps(ClassTyp: TRttiType; Engine: TJSEngine);
    procedure AddFields(ClassTyp: TRttiType; Engine: TJSEngine);
  public
    constructor Create(cType: TClass);
    procedure InitJSTemplate(Parent: TClassWrapper; Engine: TJSEngine;
      IsGlobal: boolean);
    destructor Destroy; override;
  end;

  TJSEngine = class(TInterfacedObject, IJSEngine)
  private
    FEngine: INodeEngine;
    FGlobal: TObject;
    FClasses: TDictionary<TClass, TClassWrapper>;
    FGarbageCollector: TGarbageCollector;
  protected
    function GetEngine: INodeEngine;
    function GetGarbageCollector: TGarbageCollector;

    // interface support
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: integer; stdcall;
    function _Release: integer; stdcall;
  public
    constructor Create();
    destructor Destroy; override;
    function AddClass(classType: TClass): TClassWrapper;
    procedure AddGlobal(Global: TObject);
    procedure RunString(code: string);
    procedure RunFile(filename: string);
    function CallFunction(funcName: string): TValue; overload;
    function CallFunction(funcName: string; args: TValueArray): TValue; overload;
    procedure CheckEventLoop;
  end;

  procedure MethodCallBack(Args: IMethodArgs); stdcall;
  procedure PropGetterCallBack(Args: IGetterArgs); stdcall;
  procedure PropSetterCallBack(Args: ISetterArgs); stdcall;
  procedure FieldGetterCallBack(Args: IGetterArgs); stdcall;
  procedure FieldSetterCallBack(Args: ISetterArgs); stdcall;

implementation
var
  Initialized: Boolean = False;

procedure InitJS;
begin
  if not Initialized then
  begin
    InitNode(StringToPUtf8Char(ParamStr(0)));
    Initialized := True;
  end;
end;

procedure MethodCallBack(Args: IMethodArgs);
var
  Engine: TJSEngine;
  Overloads: TRttiMethodList;
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
    Overloads := Args.GetDelphiMethod as TRttiMethodList;
    Method := Overloads.GetMethod(Args.GetArgs);
    if Assigned(Method) then
    begin
      MethodArgs := JSParametersToTValueArray(Method.GetParameters, Args.GetArgs,
        Engine);
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
      JSResult := TValueToJSValue(Result, Engine);
      if Assigned(JSResult) then
        Args.SetReturnValue(JSResult);
    end;
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
    JSResult := TValueToJSValue(Result, Engine);
    if Assigned(JSResult) then
      Args.SetReturnValue(JSResult);
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
        JSValueToTValue(JSValue, Prop.PropertyType, Engine));
    Result := Prop.GetValue(Obj);
    JSValue := TValueToJSValue(Result, Engine);
    if Assigned(JSValue) then
      Args.SetReturnValue(JSValue);
  end;
end;


procedure FieldGetterCallBack(Args: IGetterArgs); stdcall;
var
  Engine: TJSEngine;
  Field: TRttiField;
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
    Field := Args.GetProp as TRttiField;
    Result := Field.GetValue(Obj);
    JSResult := TValueToJSValue(Result, Engine);
    if Assigned(JSResult) then
      Args.SetReturnValue(JSResult);
  end;
end;

procedure FieldSetterCallBack(Args: ISetterArgs); stdcall;
var
  Engine: TJSEngine;
  Field: TRttiField;
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
    Field := Args.GetProp as TRttiField;
    JSValue := Args.GetPropValue;
    if Assigned(JSValue) then
      Field.SetValue(Obj,
        JSValueToTValue(JSValue, Field.FieldType, Engine));
    Result := Field.GetValue(Obj);
    JSValue := TValueToJSValue(Result, Engine);
    if Assigned(JSValue) then
      Args.SetReturnValue(JSValue);
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
  if not FClasses.TryGetValue(classType, ClassWrapper) then
  begin
    ClassWrapper := TClassWrapper.Create(classType);
    FClasses.Add(classType, ClassWrapper);
    Parent := classType.ClassParent;
    while Assigned(Parent) and (Parent <> TObject) do
    begin
      AddClass(Parent);
      Parent := Parent.ClassParent;
    end;
    FClasses.TryGetValue(classType.ClassParent, ParentWrapper);
    ClassWrapper.InitJSTemplate(ParentWrapper, Self, False);
  end;
  Result := ClassWrapper;
end;

procedure TJSEngine.AddGlobal(Global: TObject);
var
  GlobalWrapper: TClassWrapper;
begin
  FGlobal := Global;
  GlobalWrapper := TClassWrapper.Create(Global.ClassType);
  FClasses.Add(Global.ClassType, GlobalWrapper);
  GlobalWrapper.InitJSTemplate(nil, Self, True);
end;

function TJSEngine.CallFunction(funcName: string; args: TValueArray): TValue;
var
  JsArgs: IJSArray;
  ResultValue: IJSValue;
begin
  JsArgs := TValueArrayToJSArray(args, Self);
  ResultValue := FEngine.CallFunction(StringToPUtf8Char(funcName), JsArgs);
  Result := JSValueToUnknownTValue(ResultValue)
end;

function TJSEngine.CallFunction(funcName: string): TValue;
var
  ResultValue: IJSValue;
begin
  ResultValue := FEngine.CallFunction(StringToPUtf8Char(funcName), nil);
  Result := JSValueToUnknownTValue(ResultValue)
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
    InitJS;
    FEngine := NewDelphiEngine(Self);
    FEngine.SetMethodCallBack(MethodCallBack);
    FEngine.SetPropGetterCallBack(PropGetterCallBack);
    FEngine.SetPropSetterCallBack(PropSetterCallBack);
    FEngine.SetFieldGetterCallBack(FieldGetterCallBack);
    FEngine.SetFieldSetterCallBack(FieldSetterCallBack);
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

function TJSEngine.GetEngine: INodeEngine;
begin
  Result := FEngine;
end;

function TJSEngine.GetGarbageCollector: TGarbageCollector;
begin
  Result := FGarbageCollector;
end;

function TJSEngine.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := 0
  else
    Result := E_NOINTERFACE;
end;

procedure TJSEngine.RunFile(filename: string);
begin
  FEngine.RunFile(StringToPUtf8Char(TPath.GetFullPath(filename)));
end;

procedure TJSEngine.RunString(code: string);
begin
  FEngine.RunString(StringToPUtf8Char(code));
end;

function TJSEngine._AddRef: integer;
begin
  Result := 0;
end;

function TJSEngine._Release: integer;
begin
  Result := 0;
end;

{ TClassWrapper }

procedure TClassWrapper.AddFields(ClassTyp: TRttiType; Engine: TJSEngine);
var
  Field: TRttiField;
begin
  for Field in Classtyp.GetFields do
  begin
    if (Field.Visibility = mvPublic) and
      (Field.Parent.Handle = Classtyp.Handle) then
    begin
      if Field.FieldType.TypeKind = tkClass then
        Engine.AddClass(Field.FieldType.Handle.TypeData.ClassType);
      FTemplate.SetField(StringToPUtf8Char(Field.Name), Field);
    end;
  end;
end;

procedure TClassWrapper.AddMethods(ClassTyp: TRttiType; Engine: TJSEngine);
var
  Method: TRttiMethod;
  Overloads: TRttiMethodList;
begin
  for Method in ClassTyp.GetMethods do
  begin
    if (Method.Visibility = mvPublic) and
      (not (Method.IsConstructor or Method.IsDestructor)) and
      (Method.Parent.Handle = ClassTyp.Handle) then
    begin
      if Assigned(Method.ReturnType) and
        (Method.ReturnType.TypeKind = tkClass) then
          Engine.AddClass(Method.ReturnType.Handle.TypeData.ClassType);
      if not FMethods.TryGetValue(Method.Name, Overloads) then
      begin
        Overloads := TRttiMethodList.Create;
        FMethods.Add(Method.Name, Overloads);
        FTemplate.SetMethod(StringToPUtf8Char(Method.Name), Overloads);
      end;
      Overloads.Add(Method);
    end;
  end;
end;

procedure TClassWrapper.AddProps(ClassTyp: TRttiType; Engine: TJSEngine);
var
  Prop: TRttiProperty;
begin
  for Prop in ClassTyp.GetProperties do
  begin
    if (Prop.Visibility = mvPublic) and
      (Prop.Parent.Handle = ClassTyp.Handle) then
    begin
      if Prop.PropertyType.TypeKind = tkClass then
        Engine.AddClass(Prop.PropertyType.Handle.TypeData.ClassType);
      FTemplate.SetProperty(StringToPUtf8Char(Prop.Name), Prop,
        Prop.IsReadable, Prop.IsWritable);
    end;
  end;
end;

constructor TClassWrapper.Create(cType: TClass);
begin
  FType := cType;
  FMethods := TObjectDictionary<string, TRttiMethodList>.Create;
end;

destructor TClassWrapper.Destroy;
begin
  FreeAndNil(FMethods);
  inherited;
end;

procedure TClassWrapper.InitJSTemplate(Parent: TClassWrapper;
  Engine: TJSEngine; IsGlobal: boolean);
var
  ClassTyp: TRttiType;
begin
  FEngine := Engine.FEngine;
  ClassTyp := Context.GetType(FType);
  if IsGlobal then
    FTemplate := FEngine.AddGlobal(FType)
  else
    FTemplate := FEngine.AddObject(StringToPUtf8Char(FType.ClassName), FType);
  AddMethods(ClassTyp, Engine);
  AddProps(ClassTyp, Engine);
  AddFields(ClassTyp, Engine);
  if Assigned(FParent) then
    FTemplate.SetParent(FParent.FTemplate);
end;

{ TRttiMethodList }

function TRttiMethodList.GetMethod(args: IJSArray): TRttiMethod;
var
  i, j: Integer;
  Params: TArray<TRttiParameter>;
begin
  Result := nil;
  for i := 0 to Count - 1 do
  begin
    Result := Items[i];
    Params := Result.GetParameters;
    for j := 0 to Length(Params) - 1 do
    begin
      if j >= args.GetCount then
        break;
      if not CompareType(Params[j].ParamType, args.GetValue(j)) then
      begin
        Result := nil;
        break;
      end;
    end;
    if Assigned(Result) then
      break;
  end;
end;

end.
