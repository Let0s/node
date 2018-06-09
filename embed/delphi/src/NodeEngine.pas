unit NodeEngine;

interface

uses
  NodeInterface, SysUtils, RTTI, Types, TypInfo, EngineHelper, IOUtils,
  Generics.Collections, Windows, Classes, Contnrs, ScriptAttributes;

type
  TJSEngine = class;

  // Class method info
  TClassMethod = class
  public
    // Link to method, that can be called from JS
    Method: TRttiMethod;
    // If method doesn't belong to classtype, then it is method of helper,
    // that is stored here.
    Helper: TJSClassHelper;
    constructor Create(AMethod: TRttiMethod; AHelper: TJSClassHelper);
  end;

  //Class property info
  TClassProp = class
  public
    // Link to prop, that can be called from JS
    Prop: TRttiProperty;
    // If prop doesn't belong to classtype, then it is prop of helper,
    // that is stored here.
    Helper: TJSClassHelper;
    constructor Create(AProp: TRttiProperty; AHelper: TJSClassHelper);
  end;

  //list of overloaded methods
  TRttiMethodList = class(TObjectList<TClassMethod>)
  private
    FEngine: TJSEngine;
  public
    constructor Create(Engine: TJSEngine);
    // This function tries to guess right method by given arguments.
    // There are a lot of cases, when it can return wrong result, so
    // TODO: make it return correct result (if possible)

    // Expample of undefined behavior. We have two overloaded functions with
    // different implementation and different result:
    // 1. SomeFunc(a: integer)
    // 2. SomeFunc(a: integer; b: string)
    // If JS runs something like "obj.SomeFunc(123)", we dont know, what should
    // we call:
    // 1. SomeFunc(123)
    // or
    // 2. SomeFunc(123, '') //empty string as optional parameter
    function GetMethod(args: IJSArray): TClassMethod;
  end;

  TClassWrapper = class(TObject)
  private
    FType: TClass;
    FTemplate: IClassTemplate;
    FParent: TClassWrapper;
    FMethods: TObjectDictionary<string, TRttiMethodList>;
    FProps: TObjectDictionary<string, TClassProp>;
    FEngine: INodeEngine;

    procedure CheckMethod(Method: TRttiMethod; Engine: TJSEngine);
    // Add all methods to JS tepmlate. Add only methods, that belong to current
    // classtype (parent methods will be inherited from parent JS template)
    //
    // If one method name has many overloaded methods then overload list
    // will contain all the methods - even parent's methods, because current JS
    // method callback will overwrite parent's method callback.
    procedure AddMethods(ClassTyp: TRttiType; Engine: TJSEngine);
    procedure AddProps(ClassTyp: TRttiType; Engine: TJSEngine);
    procedure AddFields(ClassTyp: TRttiType; Engine: TJSEngine);
    procedure AddIndexedProps(ClassTyp: TRttiType; Engine: TJSEngine);

    procedure AddHelperMethods(Helper: TJSClassHelper; Engine: TJSEngine);
    procedure AddHelperProps(Helper: TJSClassHelper; Engine: TJSEngine);
  public
    constructor Create(cType: TClass);
    procedure InitJSTemplate(Parent: TClassWrapper; Engine: TJSEngine;
      IsGlobal: boolean; Helper: TJSClassHelper);
    destructor Destroy; override;
  end;

  TJSEngine = class(TInterfacedObject, IJSEngine)
  private
    FEngine: INodeEngine;
    FGlobal: TObject;
    FClasses: TObjectDictionary<TClass, TClassWrapper>;
    // Store matches "classtype <-> helper object"
    FJSHelperMap: TJSHelperMap;
    // Store helper objects. Any Helper class have only one helper object.
    FJSHelperList: TObjectList;
    FEnumList: TList<PTypeInfo>;
    FGarbageCollector: TGarbageCollector;
    FIgnoredExceptions: TList<TClass>;
    FActive: boolean;
    // param for debugging
    FDebugParam: string;
    // it is used for conversion to PAnsiChar
    FUTF8String: UTF8String;
  protected
    function StringToPAnsiChar(const S: string): PAnsiChar;
    function PAnsiCharToString(P: PAnsiChar): string;
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
    // Use it to match classtype with helper class. Helper will be created
    // automatically (if it wasn't created).
    procedure RegisterHelper(CType: TClass; HelperType: TJSHelperType);
    procedure IgnoreExceptionType(ExceptionType: TClass);
    procedure AddEnum(Enum: TRttiType);
    function AddClass(classType: TClass): TClassWrapper;
    function GetClassWrapper(classType: TClass): TClassWrapper;
    procedure AddGlobal(Global: TObject);
    procedure AddGlobalVariable(Name: string; Variable: TObject);
    procedure SetDebugParam(param: string);
    procedure AddPreCode(code: string);
    procedure RunString(code: string);
    procedure RunFile(filename: string);
    function CallFunction(funcName: string): TValue; overload;
    function CallFunction(funcName: string; args: TValueArray): TValue; overload;
    procedure CheckEventLoop;
    property Active: boolean read FActive;
    property GC: TGarbageCollector read GetGarbageCollector;
  end;

  // unwrap delphi object from js object in arguments
  function GetDelphiObject(Args: IBaseArgs): TObject;
  // set return value to js arguments
  procedure SetReturnValue(Args: IBaseArgs; Value: TValue);

  procedure BaseCallBack(args: IBaseArgs); stdcall;

  procedure MethodCallBack(Args: IMethodArgs); stdcall;
  procedure PropGetterCallBack(Args: IGetterArgs); stdcall;
  procedure PropSetterCallBack(Args: ISetterArgs); stdcall;
  procedure FieldGetterCallBack(Args: IGetterArgs); stdcall;
  procedure FieldSetterCallBack(Args: ISetterArgs); stdcall;
  procedure IndexedPropGetter(Args: IIndexedGetterArgs); stdcall;
  procedure IndexedPropSetter(Args: IIndexedSetterArgs); stdcall;

  // returns content of WritePipe, if it was created;
  // if application had default stdio before node initialization
  //   this function will return empty string
  function GetNodeLog: string;

implementation
var
  Initialized: Boolean = False;
  // This variable shows if dll is supported:
  // 1. Its Major version equals to this source version
  // 2. Its Minor version is equals or higher than source version
  VersionEqual: Boolean = False;
  STDIOExist: Boolean;
  // If there are not stdio streams, automatically create pipes on app init
  StdInRead, StdInWrite, StdOutRead, StdOutWrite: THandle;

function InitJS: boolean;
var
  utfStr: UTF8String;
begin
  if not Initialized then
  begin
    // first callling node.dll function. STDIO should exist at this moment
    VersionEqual := (EmbedMajorVersion = EMBED_MAJOR_VERSION) and
      (EmbedMinorVersion >= EMBED_MINOR_VERSION);
    if VersionEqual then
    begin
      utfStr := UTF8String(ParamStr(0));
      InitNode(PAnsiChar(utfStr));
    end;
    Initialized := True;
  end;
  Result := VersionEqual;
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
  PeekNamedPipe(StdOutRead, @TextBuffer, PipeSize, @BytesRead, @PipeSize, nil);
  if bytesread > 0 then
  begin
    ReadFile(StdOutRead, TextBuffer, pipesize, bytesread, nil);
    // write all useful bytes to Ansi string
    SlicedBuffer := Copy(TextBuffer, 0, BytesRead);
    // convert Ansi string to utf8 string
    TextString := UTF8ToUnicodeString(RawByteString(SlicedBuffer));
    Result := TextString;
  end;
end;

function GetDelphiObject(Args: IBaseArgs): TObject;
var
  Engine: TJSEngine;
begin
  Result := nil;
  Engine := Args.GetEngine as TJSEngine;
  if Assigned(Engine) then
  begin
    //all objects will be stored in JS value when accessor (or function)
    // will be called
    Result := Args.GetDelphiObject;
    if not Assigned(Result) then
    begin
      if Args.GetDelphiClasstype = Engine.FGlobal.ClassType then
        Result := Engine.FGlobal;
    end;
  end;
end;

procedure SetReturnValue(Args: IBaseArgs; Value: TValue);
var
  Engine: TJSEngine;
  JSResult: IJSValue;
begin
  Engine := Args.GetEngine as TJSEngine;
  if Assigned(Engine) then
  begin
    JSResult := TValueToJSValue(Value, Engine);
    if Assigned(JSResult) then
      Args.SetReturnValue(JSResult);
  end;
end;

procedure BaseCallBack(args: IBaseArgs); stdcall;
var
  Engine: TJSEngine;
begin
  Engine := args.GetEngine as TJSEngine;
  try
    if args.IsMethodArgs then
      MethodCallBack(args.AsMethodArgs)
    else if args.IsGetterArgs then
    begin
      if args.AsGetterArgs.GetProp is TClassProp then
        PropGetterCallback(args.AsGetterArgs);
      if args.AsGetterArgs.GetProp is TRttiField then
        FieldGetterCallback(args.AsGetterArgs);
    end
    else if args.IsSetterArgs then
    begin
      if args.AsSetterArgs.GetProp is TClassProp then
        PropSetterCallback(args.AsSetterArgs);
      if args.AsSetterArgs.GetProp is TRttiField then
        FieldSetterCallback(args.AsSetterArgs);
    end
    else if args.IsIndexedGetterArgs then
      IndexedPropGetter(args.AsIndexedGetterArgs)
    else if args.IsIndexedSetterArgs then
      IndexedPropSetter(args.AsIndexedSetterArgs);
  except
    on E: EInvalidCast do
    begin
      args.ThrowTypeError(Engine.StringToPAnsiChar(E.Message));
    end;
    on E: EAccessViolation do
    begin
      args.ThrowError(Engine.StringToPAnsiChar(E.Message));
    end;
    on E: Exception do
    begin
      if Engine.FIgnoredExceptions.IndexOf(E.ClassType) < 0 then
      begin
        args.ThrowError(Engine.StringToPAnsiChar(E.Message));
      end
    end;
  end;
end;

procedure MethodCallBack(Args: IMethodArgs);
var
  Engine: TJSEngine;
  Overloads: TRttiMethodList;
  Method: TRttiMethod;
  MethodInfo: TClassMethod;
  Obj: TObject;
  ObjType: TClass;
  Result: TValue;
  MethodArgs: TArray<TValue>;
  Helper: TJSClassHelper;
begin
  Engine := Args.GetEngine as TJSEngine;
  if Assigned(Engine) then
  begin
    Obj := GetDelphiObject(Args);
    {$IFDEF DEBUG}
    Assert(Assigned(Obj), 'Obj is not assigned at method callback');
    {$ENDIF}
    if Assigned(Obj) then
    begin
      Overloads := Args.GetDelphiMethod as TRttiMethodList;
      MethodInfo := Overloads.GetMethod(Args.GetArgs);
      if Assigned(MethodInfo) then
      begin
        Method := MethodInfo.Method;
        MethodArgs := JSParametersToTValueArray(Method.GetParameters, Args.GetArgs,
          Engine);
        //if method has helper, then we call method of helper with given object
        if Assigned(MethodInfo.Helper) then
        begin
          Helper := MethodInfo.Helper;
          Helper.Source := Obj;
          Result := Method.Invoke(Helper, MethodArgs);
          Helper.Source := nil;
        end
        else
        begin
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
        end;
        if HaveScriptSetting(Method.GetAttributes, satGarbage) then
          Engine.GC.Add(Result);
        SetReturnValue(Args, Result);
      end;
    end;
  end;
end;

procedure PropGetterCallBack(Args: IGetterArgs); stdcall;
var
  Engine: TJSEngine;
  PropInfo: TClassProp;
  Obj: TObject;
  Result: TValue;
begin
  Engine := Args.GetEngine as TJSEngine;
  if Assigned(Engine) then
  begin
    Obj := GetDelphiObject(Args);
    {$IFDEF DEBUG}
    Assert(Assigned(Obj), 'Obj is not assigned at prop getter callback');
    {$ENDIF}
    if Assigned(Obj) then
    begin
      PropInfo := Args.GetProp as TClassProp;
      //if prop has helper, then we call prop of helper with given object
      if Assigned(PropInfo.Helper) then
      begin
        PropInfo.Helper.Source := Obj;
        Obj := PropInfo.Helper;
      end;
      Result := PropInfo.Prop.GetValue(Obj);
      if Assigned(PropInfo.Helper) then
        PropInfo.Helper.Source := nil;
      SetReturnValue(Args, Result);
    end;
  end;
end;

procedure PropSetterCallBack(Args: ISetterArgs); stdcall;
var
  Engine: TJSEngine;
  PropInfo: TClassProp;
  Prop: TRttiProperty;
  Obj: TObject;
  Result: TValue;
  JSValue: IJSValue;
begin
  Engine := Args.GetEngine as TJSEngine;
  if Assigned(Engine) then
  begin
    Obj := GetDelphiObject(Args);
    {$IFDEF DEBUG}
    Assert(Assigned(Obj), 'Obj is not assigned at prop setter callback');
    {$ENDIF}
    if Assigned(Obj) then
    begin
      PropInfo := Args.GetProp as TClassProp;
      Prop := PropInfo.Prop;
      //if prop has helper, then we call prop of helper with given object
      if Assigned(PropInfo.Helper) then
      begin
        PropInfo.Helper.Source := Obj;
        Obj := PropInfo.Helper;
      end;
      JSValue := Args.GetPropValue;
      if Assigned(JSValue) then
        Prop.SetValue(Obj,
          JSValueToTValue(JSValue, Prop.PropertyType, Engine));
      Result := Prop.GetValue(Obj);
      if Assigned(PropInfo.Helper) then
        PropInfo.Helper.Source := nil;
      SetReturnValue(Args, Result);
    end;
  end;
end;


procedure FieldGetterCallBack(Args: IGetterArgs); stdcall;
var
  Engine: TJSEngine;
  Field: TRttiField;
  Obj: TObject;
  Result: TValue;
begin
  Engine := Args.GetEngine as TJSEngine;
  if Assigned(Engine) then
  begin
    Obj := GetDelphiObject(Args);
    {$IFDEF DEBUG}
    Assert(Assigned(Obj), 'Obj is not assigned at field getter callback');
    {$ENDIF}
    if Assigned(Obj) then
    begin
      Field := Args.GetProp as TRttiField;
      Result := Field.GetValue(Obj);
      SetReturnValue(Args, Result);
    end;
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
    Obj := GetDelphiObject(Args);
    {$IFDEF DEBUG}
    Assert(Assigned(Obj), 'Obj is not assigned at field setter callback');
    {$ENDIF}
    if Assigned(Obj) then
    begin
      Field := Args.GetProp as TRttiField;
      JSValue := Args.GetPropValue;
      if Assigned(JSValue) then
        Field.SetValue(Obj,
          JSValueToTValue(JSValue, Field.FieldType, Engine));
      Result := Field.GetValue(Obj);
      SetReturnValue(Args, Result);
    end;
  end;
end;

procedure IndexedPropGetter(Args: IIndexedGetterArgs); stdcall;
var
  Engine: TJSEngine;
  Prop: TRttiIndexedProperty;
  Obj: TObject;
  Result: TValue;
begin
  Engine := Args.GetEngine as TJSEngine;
  if Assigned(Engine) then
  begin
    Obj := GetDelphiObject(Args);
    {$IFDEF DEBUG}
    Assert(Assigned(Obj), 'Obj is not assigned at indexed prop getter callback');
    {$ENDIF}
    if Assigned(Obj) then
    begin
      Prop := Args.GetPropPointer as TRttiIndexedProperty;
      if Assigned(Prop) then
      begin
        Result := Prop.GetValue(Obj,
          [JSValueToUnknownTValue(args.GetPropIndex, Engine)]);
        SetReturnValue(Args, Result);
      end;
    end;
  end;
end;

procedure IndexedPropSetter(Args: IIndexedSetterArgs); stdcall;
var
  Engine: TJSEngine;
  Prop: TRttiIndexedProperty;
  Obj: TObject;
  Result: TValue;
begin
  Engine := Args.GetEngine as TJSEngine;
  if Assigned(Engine) then
  begin
    Obj := GetDelphiObject(Args);
    {$IFDEF DEBUG}
    Assert(Assigned(Obj), 'Obj is not assigned at indexed prop setter callback');
    {$ENDIF}
    if Assigned(Obj) then
    begin
      Prop := Args.GetPropPointer as TRttiIndexedProperty;
      if Assigned(Prop) then
      begin
        Prop.SetValue(Obj, [args.GetPropIndex],
          JSValueToTValue(args.GetValue, Prop.PropertyType, Engine));
        Result := Prop.GetValue(Obj,
          [JSValueToUnknownTValue(args.GetPropIndex, Engine)]);
        SetReturnValue(Args, Result);
      end;
    end;
  end;
end;

{ TJSEngine }

function TJSEngine.AddClass(classType: TClass): TClassWrapper;

  function ClassIsForbidden(cl: TClass): boolean;
  var
    Typ: TRttiType;
  begin
    Typ := EngineHelper.Context.GetType(cl);
    Result := HaveScriptSetting(Typ.GetAttributes, satForbidden);
  end;

var
  ClassWrapper: TClassWrapper;
  ParentWrapper: TClassWrapper;
  Parent: TClass;
  Helper: TJSClassHelper;
begin
  Result := nil;
  if Active and (not ClassIsForbidden(classType)) then
  begin
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
      if not FJSHelperMap.TryGetValue(classType, Helper) then
        Helper := nil;
      ClassWrapper.InitJSTemplate(ParentWrapper, Self, False, Helper);
    end;
    Result := ClassWrapper;
  end;
end;

procedure TJSEngine.AddEnum(Enum: TRttiType);
var
  i, enumNum: integer;
  typInfo: PTypeInfo;
  EnumName: string;
  EnumTemplate: IEnumTemplate;
begin
  if Active then
  begin
    typInfo := Enum.Handle;
    if FEnumList.IndexOf(typInfo) < 0 then
    begin
      i := 0;
      EnumName := '';
      EnumTemplate := FEngine.AddEnum(
        StringToPAnsiChar(String(Enum.Handle.Name)));
      // TODO: find better way
      while true do
      begin
        EnumName := GetEnumName(typInfo, i);
        enumNum := GetEnumValue(typInfo, EnumName);
        if enumNum <> i then
          break;
        EnumTemplate.AddValue(StringToPAnsiChar(EnumName), i);
        inc(i);
      end;
      FEnumList.Add(typInfo);
    end;
  end;
end;

procedure TJSEngine.AddGlobal(Global: TObject);
var
  GlobalWrapper: TClassWrapper;
begin
  if Active then
  begin
    FGlobal := Global;
    GlobalWrapper := TClassWrapper.Create(Global.ClassType);
    FClasses.Add(Global.ClassType, GlobalWrapper);
    GlobalWrapper.InitJSTemplate(nil, Self, True, nil);
  end;
end;

procedure TJSEngine.AddGlobalVariable(Name: string; Variable: TObject);
var
  CType: TClass;
begin
  CType := Variable.ClassType;
  AddClass(CType);
  FEngine.AddGlobalVariableObject(StringToPAnsiChar(Name), Variable, CType);
end;

procedure TJSEngine.AddPreCode(code: string);
begin
  if Active then
    FEngine.AddPreCode(StringToPAnsiChar(code));
end;

function TJSEngine.CallFunction(funcName: string; args: TValueArray): TValue;
var
  JsArgs: IJSArray;
  ResultValue: IJSValue;
begin
  if Active then
  begin
    JsArgs := TValueArrayToJSArray(args, Self);
    ResultValue := FEngine.CallFunction(StringToPAnsiChar(funcName), JsArgs);
    Result := JSValueToUnknownTValue(ResultValue, Self)
  end;
end;

function TJSEngine.CallFunction(funcName: string): TValue;
var
  ResultValue: IJSValue;
begin
  if Active then
  begin
    ResultValue := FEngine.CallFunction(StringToPAnsiChar(funcName), nil);
    Result := JSValueToUnknownTValue(ResultValue, Self)
  end;
end;

procedure TJSEngine.CheckEventLoop;
begin
  if Active then
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
    if InitJS then
    begin
      FEngine := NewDelphiEngine(Self);
      FEngine.SetExternalCallback(BaseCallBack);
      FClasses := TObjectDictionary<TClass, TClassWrapper>.Create([doOwnsValues]);
      FJSHelperMap := TJSHelperMap.Create;
      FJSHelperList := TObjectList.Create;
      FGarbageCollector := TGarbageCollector.Create;
      FEnumList := TList<PTypeInfo>.Create;
      FIgnoredExceptions := TList<TClass>.Create;
      FActive := True;
    end;
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
  FJSHelperMap.Free;
  FJSHelperList.Free;
  FIgnoredExceptions.Free;
  FEngine.Delete;
  inherited;
end;

function TJSEngine.GetClassWrapper(classType: TClass): TClassWrapper;
begin
  if not FClasses.TryGetValue(classType, Result) then
    Result := nil;
end;

function TJSEngine.GetEngine: INodeEngine;
begin
  Result := FEngine;
end;

function TJSEngine.GetGarbageCollector: TGarbageCollector;
begin
  Result := FGarbageCollector;
end;

procedure TJSEngine.IgnoreExceptionType(ExceptionType: TClass);
begin
  FIgnoredExceptions.Add(ExceptionType);
end;

function TJSEngine.PAnsiCharToString(P: PAnsiChar): string;
begin
  Result := UTF8ToUnicodeString(RawByteString(P));
end;

function TJSEngine.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := 0
  else
    Result := E_NOINTERFACE;
end;

procedure TJSEngine.RegisterHelper(CType: TClass;
  HelperType: TJSHelperType);
var
  HelperObj: TJSClassHelper;
  objind: integer;
begin
  if Active then
  begin
    if not FJSHelperMap.ContainsKey(CType) then
    begin
      objind := FJSHelperList.FindInstanceOf(HelperType);
      if objind < 0 then
      begin
        HelperObj := HelperType.Create;
        FJSHelperList.Add(HelperObj);
      end
      else
        HelperObj := TJSClassHelper(FJSHelperList[objind]);
      FJSHelperMap.Add(CType, HelperObj);
    end;
  end;
end;

procedure TJSEngine.RunFile(filename: string);
var
  Args: ILaunchArguments;
  FullName: string;
begin
  if Active then
  begin
    Args := FEngine.CreateLaunchArguments;
    try
      //get absolute path to script file
      FullName := ExpandFileName(filename);
      // set nodejs cwd to script path
      FEngine.ChangeWorkingDir(StringToPAnsiChar(
        ExtractFileDir(FullName)));
      Args.AddArgument(StringToPAnsiChar(ParamStr(0)));
      Args.AddArgument(StringToPAnsiChar(ParamStr(0)));
      if FDebugParam <> '' then
        Args.AddArgument(StringToPAnsiChar(FDebugParam));
      Args.AddArgument(StringToPAnsiChar(FullName));
      FEngine.Launch(Args);
    finally
      Args.Delete
    end;
  end;
end;

procedure TJSEngine.RunString(code: string);
var
  Args: ILaunchArguments;
begin
  if Active then
  begin
    Args := FEngine.CreateLaunchArguments;
    try
      Args.AddArgument(StringToPAnsiChar(ParamStr(0)));
      Args.AddArgument(StringToPAnsiChar('-e'));
      Args.AddArgument(StringToPAnsiChar(code));
      FEngine.Launch(Args);
    finally
      Args.Delete
    end;
  end;
end;

function TJSEngine.StringToPAnsiChar(const S: string): PAnsiChar;
begin
  FUTF8String := UTF8String(S);
  Result := PAnsiChar(FUTF8String);
end;

procedure TJSEngine.SetDebugParam(param: string);
begin
  FDebugParam := param;
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
    // check if field is not forbidden for JS
    if not HaveScriptSetting(Field.GetAttributes, satForbidden) then
    begin
      if (Field.Visibility = mvPublic) and
        (Field.Parent.Handle = Classtyp.Handle) then
      begin
        Engine.CheckType(Field.FieldType);
        FTemplate.SetField(Engine.StringToPAnsiChar(Field.Name), Field);
      end;
    end;
  end;
end;

procedure TClassWrapper.AddHelperMethods(Helper: TJSClassHelper;
  Engine: TJSEngine);
var
  Method: TRttiMethod;
  Overloads: TRttiMethodList;
  ClassTyp: TRttiType;
begin
  ClassTyp := EngineHelper.Context.GetType(Helper.ClassType);
  for Method in ClassTyp.GetMethods do
  begin
    // check if method is not forbidden for JS
    if not HaveScriptSetting(Method.GetAttributes, satForbidden) then
    begin
      // Add only public methods from full class hierarchy
      // (exclude TObject's methods)
      if (Method.Visibility = mvPublic) and
        (method.Parent.Handle.TypeData.ClassType.InheritsFrom(TJSClassHelper)) and
        (Method.MethodKind in [mkProcedure, mkFunction]) then
      begin
        CheckMethod(Method, Engine);
        if not FMethods.TryGetValue(Method.Name, Overloads) then
        begin
          Overloads := TRttiMethodList.Create(Engine);
          FMethods.Add(Method.Name, Overloads);
          FTemplate.SetMethod(Engine.StringToPAnsiChar(Method.Name), Overloads);
        end;
        Overloads.Add(TClassMethod.Create(Method, Helper));
      end;
    end;
  end;
end;

procedure TClassWrapper.AddHelperProps(Helper: TJSClassHelper;
  Engine: TJSEngine);
var
  Prop: TRttiProperty;
  PropInfo: TClassProp;
  ClassTyp: TRttiType;
begin
  ClassTyp := EngineHelper.Context.GetType(Helper.ClassType);
  for Prop in ClassTyp.GetProperties do
  begin
    // check if prop is not forbidden for JS
    if not HaveScriptSetting(Prop.GetAttributes, satForbidden) then
    begin
      // Add only public props from full class hierarchy
      // (exclude TObject's props)
      if (Prop.Visibility = mvPublic) and
        (Prop.Parent.Handle.TypeData.ClassType.InheritsFrom(TJSClassHelper)) and
        not FProps.ContainsKey(Prop.Name) then
      begin
        Engine.CheckType(Prop.PropertyType);
        PropInfo := TClassProp.Create(Prop, Helper);
        FProps.Add(Prop.Name, PropInfo);
        FTemplate.SetProperty(Engine.StringToPAnsiChar(Prop.Name), PropInfo,
          Prop.IsReadable, Prop.IsWritable);
      end;
    end;
  end;
end;

procedure TClassWrapper.AddIndexedProps(ClassTyp: TRttiType; Engine: TJSEngine);
var
  Prop: TRttiIndexedProperty;
  DefaultProp: TRttiIndexedProperty;
begin
  DefaultProp := nil;
  for Prop in ClassTyp.GetIndexedProperties do
  begin
    // check if prop is not forbidden for JS
    if not HaveScriptSetting(Prop.GetAttributes, satForbidden) then
    begin
      if (Prop.Visibility = mvPublic) and
        (Prop.Parent.Handle = ClassTyp.Handle) then
      begin
        Engine.CheckType(Prop.PropertyType);
        if Prop.IsDefault then
          DefaultProp := Prop;
        FTemplate.SetIndexedProperty(Engine.StringToPAnsiChar(Prop.Name), Prop,
          Prop.IsReadable, Prop.IsWritable);
      end;
    end;
  end;
  if Assigned(DefaultProp) then
    FTemplate.SetDefaultIndexedProperty(DefaultProp);
end;

procedure TClassWrapper.AddMethods(ClassTyp: TRttiType; Engine: TJSEngine);
var
  Method: TRttiMethod;
  Overloads: TRttiMethodList;
begin
  for Method in ClassTyp.GetMethods do
  begin
    // check if method is not forbidden for JS
    if not HaveScriptSetting(Method.GetAttributes, satForbidden) then
    begin
      //check if method belongs to given class type (not to the parent)
      if (Method.Visibility = mvPublic) and
        (not (Method.IsConstructor or Method.IsDestructor)) and
        (Method.Parent.Handle = ClassTyp.Handle) then
      begin
        CheckMethod(Method, Engine);
        if not FMethods.TryGetValue(Method.Name, Overloads) then
        begin
          Overloads := TRttiMethodList.Create(Engine);
          FMethods.Add(Method.Name, Overloads);
          FTemplate.SetMethod(Engine.StringToPAnsiChar(Method.Name), Overloads);
        end;
        Overloads.Add(TClassMethod.Create(Method, nil));
      end;
    end;
  end;

  for Method in ClassTyp.GetMethods do
  begin
    // check if method is not forbidden for JS
    if not HaveScriptSetting(Method.GetAttributes, satForbidden) then
    begin
      //check if method belongs to parent class type
      //  and current class type have an overloaded method
      if (Method.Parent.Handle <> ClassTyp.Handle) and
        (Method.Visibility = mvPublic) and
        (not (Method.IsConstructor or Method.IsDestructor)) and
        FMethods.TryGetValue(Method.Name, Overloads) then
      begin
        CheckMethod(Method, Engine);
        // TODO: think about overrided methods, that can be added as overloads
        // Check by parameter count and types?
        Overloads.Add(TClassMethod.Create(Method, nil));
      end;
    end;
  end;
end;

procedure TClassWrapper.AddProps(ClassTyp: TRttiType; Engine: TJSEngine);
var
  Prop: TRttiProperty;
  PropInfo: TClassProp;
begin
  for Prop in ClassTyp.GetProperties do
  begin
    // check if prop is not forbidden for JS
    if not HaveScriptSetting(Prop.GetAttributes, satForbidden) then
    begin
      if (Prop.Visibility = mvPublic) and
        (Prop.Parent.Handle = ClassTyp.Handle) then
      begin
        Engine.CheckType(Prop.PropertyType);
        PropInfo := TClassProp.Create(Prop, nil);
        FProps.Add(Prop.Name, PropInfo);
        FTemplate.SetProperty(Engine.StringToPAnsiChar(Prop.Name), PropInfo,
          Prop.IsReadable, Prop.IsWritable);
      end;
    end;
  end;
end;

procedure TClassWrapper.CheckMethod(Method: TRttiMethod; Engine: TJSEngine);
var
  Param: TRttiParameter;
begin
  Engine.CheckType(Method.ReturnType);
  for Param in Method.GetParameters do
    Engine.CheckType(Param.ParamType);
end;

constructor TClassWrapper.Create(cType: TClass);
begin
  FType := cType;
  FMethods := TObjectDictionary<string, TRttiMethodList>.Create([doOwnsValues]);
  FProps := TObjectDictionary<string, TClassProp>.Create([doOwnsValues]);
end;

destructor TClassWrapper.Destroy;
begin
  FreeAndNil(FMethods);
  FreeAndNil(FProps);
  inherited;
end;

procedure TClassWrapper.InitJSTemplate(Parent: TClassWrapper;
  Engine: TJSEngine; IsGlobal: boolean; Helper: TJSClassHelper);
var
  ClassTyp: TRttiType;
begin
  FEngine := Engine.FEngine;
  ClassTyp := EngineHelper.Context.GetType(FType);
  if IsGlobal then
    FTemplate := FEngine.AddGlobal(FType)
  else
    FTemplate := FEngine.AddObject(Engine.StringToPAnsiChar(FType.ClassName), FType);
  AddMethods(ClassTyp, Engine);
  AddProps(ClassTyp, Engine);
  AddFields(ClassTyp, Engine);
  AddIndexedProps(ClassTyp, Engine);
  // If assigned helper object, add its props and methods as props and methods
  // of this classtype
  if Assigned(Helper) then
  begin
    AddHelperMethods(Helper, Engine);
    AddHelperProps(Helper, Engine);
  end;
  FParent := Parent;
  if Assigned(FParent) then
    FTemplate.SetParent(FParent.FTemplate);
end;

{ TRttiMethodList }

constructor TRttiMethodList.Create(Engine: TJSEngine);
begin
  inherited Create;
  FEngine := Engine;
end;

function TRttiMethodList.GetMethod(args: IJSArray): TClassMethod;
var
  i, j: Integer;
  Params: TArray<TRttiParameter>;
  MethodInfo: TClassMethod;
begin
  Result := nil;
  if Count > 0 then
  begin
    Result := Items[0];
    for i := 0 to Count - 1 do
    begin
      MethodInfo := Items[i];
      Params := MethodInfo.Method.GetParameters;
      for j := 0 to Length(Params) - 1 do
      begin
        if j >= args.GetCount then
          break;
        if not CompareType(Params[j].ParamType, args.GetValue(j), FEngine) then
        begin
          MethodInfo := nil;
          break;
        end;
      end;
      if Assigned(MethodInfo) then
      begin
        Result := MethodInfo;
        break;
      end;
    end;
  end;
end;

{ TClassProp }

constructor TClassProp.Create(AProp: TRttiProperty; AHelper: TJSClassHelper);
begin
  Prop := AProp;
  Helper := AHelper;
end;

{ TClassMethod }

constructor TClassMethod.Create(AMethod: TRttiMethod; AHelper: TJSClassHelper);
begin
  Method := AMethod;
  Helper := AHelper;
end;

initialization
  // Create STDIO if it is not exist. Nodejs will not work without STDIO
  // (It should be fixed soon: https://github.com/nodejs/node/pull/20640)
  STDIOExist := not ((GetStdHandle(STD_INPUT_HANDLE) = 0) or
                     (GetStdHandle(STD_OUTPUT_HANDLE) = 0) or
                     (GetStdHandle(STD_ERROR_HANDLE) = 0));
  if not STDIOExist then
  begin
    CreatePipe(StdInRead, StdInWrite, nil, 0);
    CreatePipe(StdOutRead, StdOutWrite, nil, 0);
    SetStdHandle(STD_INPUT_HANDLE, StdInRead);
    SetStdHandle(STD_OUTPUT_HANDLE, StdOutWrite);
    SetStdHandle(STD_ERROR_HANDLE, StdOutWrite);
  end;

finalization
  if not STDIOExist then
  begin
    CloseHandle(StdInRead);
    CloseHandle(StdInWrite);
    CloseHandle(StdOutRead);
    CloseHandle(StdOutWrite);
  end;

end.
