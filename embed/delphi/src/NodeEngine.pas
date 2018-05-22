unit NodeEngine;

interface

uses
  NodeInterface, SysUtils, RTTI, Types, TypInfo, EngineHelper, IOUtils,
  Generics.Collections, Windows;

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
    // Add all methods to JS tepmlate. Add only methods, that belong to current
    // classtype (parent methods will be inherited from parent JS template)
    //
    // If one method name has many overloaded methods then overload list
    // will contain all the methods - even parent's methods, because current JS
    // method callback will overwrite parent's method callback.
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
    FEnumList: TList<PTypeInfo>;
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
    procedure CheckType(typ: TRttiType);
    procedure AddEnum(Enum: TRttiType);
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

  // returns content of WritePipe, if it was created;
  // if application had default stdio before node initialization
  //   this function will return empty string
  function GetNodeLog: string;

implementation
var
  Initialized: Boolean = False;
  STDIOExist: Boolean;
  // these pipes are dummy for application without default std(input/output/error)
  //   so functions log/warn/error of console in Node.js will not work
  // TODO: add callbacks for read/write from stdio
  ReadPipe, WritePipe: THandle;

procedure InitJS;
begin
  if not Initialized then
  begin
    STDIOExist := not ((GetStdHandle(STD_INPUT_HANDLE) = 0) or
                       (GetStdHandle(STD_OUTPUT_HANDLE) = 0) or
                       (GetStdHandle(STD_ERROR_HANDLE) = 0));
    if not STDIOExist then
    begin
      CreatePipe(ReadPipe, WritePipe, nil, 0);
      SetStdHandle(STD_INPUT_HANDLE, ReadPipe);
      SetStdHandle(STD_OUTPUT_HANDLE, WritePipe);
      SetStdHandle(STD_ERROR_HANDLE, WritePipe);
    end;
    InitNode(StringToPUtf8Char(ParamStr(0)));
    Initialized := True;
  end;
end;

function GetNodeLog: string;
var
  TextBuffer: array[1..32767] of AnsiChar;
  SlicedBuffer: AnsiString;
  TextString: String;
  BytesRead: Cardinal;
  PipeSize: Integer;
begin
  Result := '';
  if STDIOExist then
    Exit;
  PipeSize := Sizeof(TextBuffer);
  // check if there is something to read in pipe
  PeekNamedPipe(ReadPipe, @TextBuffer, PipeSize, @BytesRead, @PipeSize, nil);
  if bytesread > 0 then
  begin
    ReadFile(ReadPipe, TextBuffer, pipesize, bytesread, nil);
    // write all useful bytes to Ansi string
    SlicedBuffer := Copy(TextBuffer, 0, BytesRead);
    // convert Ansi string to utf8 string
    TextString := UTF8ToUnicodeString(RawByteString(SlicedBuffer));
    Result := TextString;
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

procedure TJSEngine.AddEnum(Enum: TRttiType);
var
  i, enumNum: integer;
  typInfo: PTypeInfo;
  EnumName: string;
  EnumTemplate: IEnumTemplate;
begin
  typInfo := Enum.Handle;
  if FEnumList.IndexOf(typInfo) < 0 then
  begin
    i := 0;
    EnumName := '';
    EnumTemplate := FEngine.AddEnum(StringToPUtf8Char(Enum.Handle.Name));
    // TODO: find better way
    while true do
    begin
      EnumName := GetEnumName(typInfo, i);
      enumNum := GetEnumValue(typInfo, EnumName);
      if enumNum <> i then
        break;
      EnumTemplate.AddValue(StringToPUtf8Char(EnumName), i);
      inc(i);
    end;
    FEnumList.Add(typInfo);
  end;
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

procedure TJSEngine.CheckType(typ: TRttiType);
begin
  if Assigned(typ) then
  begin
    case typ.TypeKind of
      tkUnknown: ;
      tkEnumeration: AddEnum(typ);
      tkSet: ;
      tkClass: AddClass(typ.Handle.TypeData.ClassType);
      tkInterface: ;
      tkClassRef: ;
    end;
  end;
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
    FEnumList := TList<PTypeInfo>.Create;
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
  FEnumList.Free;
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
      Engine.CheckType(Field.FieldType);
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
    //check if method belongs to given class type (not to the parent)
    if (Method.Visibility = mvPublic) and
      (not (Method.IsConstructor or Method.IsDestructor)) and
      (Method.Parent.Handle = ClassTyp.Handle) then
    begin
      Engine.CheckType(Method.ReturnType);
      if not FMethods.TryGetValue(Method.Name, Overloads) then
      begin
        Overloads := TRttiMethodList.Create;
        FMethods.Add(Method.Name, Overloads);
        FTemplate.SetMethod(StringToPUtf8Char(Method.Name), Overloads);
      end;
      Overloads.Add(Method);
    end;
  end;

  for Method in ClassTyp.GetMethods do
  begin
    //check if method belongs to parent class type
    //  and current class type have an overloaded method
    if (Method.Parent.Handle <> ClassTyp.Handle) and
      (Method.Visibility = mvPublic) and
      (not (Method.IsConstructor or Method.IsDestructor)) and
      FMethods.TryGetValue(Method.Name, Overloads) then
    begin
      Engine.CheckType(Method.ReturnType);
      // TODO: think about overrided methods, that can be added as overloads
      // Check by parameter count and types?
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
      Engine.CheckType(Prop.PropertyType);
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
  ClassTyp := EngineHelper.Context.GetType(FType);
  if IsGlobal then
    FTemplate := FEngine.AddGlobal(FType)
  else
    FTemplate := FEngine.AddObject(StringToPUtf8Char(FType.ClassName), FType);
  AddMethods(ClassTyp, Engine);
  AddProps(ClassTyp, Engine);
  AddFields(ClassTyp, Engine);
  FParent := Parent;
  if Assigned(FParent) then
    FTemplate.SetParent(FParent.FTemplate);
end;

{ TRttiMethodList }

function TRttiMethodList.GetMethod(args: IJSArray): TRttiMethod;
var
  i, j: Integer;
  Params: TArray<TRttiParameter>;
  Method: TRttiMethod;
begin
  Result := nil;
  if Count > 0 then
  begin
    Result := Items[0];
    for i := 0 to Count - 1 do
    begin
      Method := Items[i];
      Params := Method.GetParameters;
      for j := 0 to Length(Params) - 1 do
      begin
        if j >= args.GetCount then
          break;
        if not CompareType(Params[j].ParamType, args.GetValue(j)) then
        begin
          Method := nil;
          break;
        end;
      end;
      if Assigned(Method) then
      begin
        Result := Method;
        break;
      end;
    end;
  end;
end;

initialization

finalization
  if (Initialized) then
  begin
    if not STDIOExist then
    begin
      CloseHandle(ReadPipe);
      CloseHandle(WritePipe);
    end;
    Initialized := False;
  end;

end.
