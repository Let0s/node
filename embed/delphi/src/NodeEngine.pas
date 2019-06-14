unit NodeEngine;

interface

uses
  NodeInterface, SysUtils, RTTI, Types, TypInfo, EngineHelper, IOUtils,
  Generics.Collections, Windows, Classes, Contnrs, ScriptAttributes,
  Generics.Defaults, Math;

type
  TJSEngine = class;

  // Class method info
  [TScriptAttribute([satForbidden])]
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
  [TScriptAttribute([satForbidden])]
  TClassProp = class
  public
    // Link to prop, that can be called from JS
    Prop: TRttiProperty;
    // If prop doesn't belong to classtype, then it is prop of helper,
    // that is stored here.
    Helper: TJSClassHelper;
    constructor Create(AProp: TRttiProperty; AHelper: TJSClassHelper);
  end;

  [TScriptAttribute([satForbidden])]
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
    // Returns true if list already contains method with the same arguments
    // count and type (high chance to detect method overrides)
    function CheckDuplicate(Method: TRttiMethod): boolean;
  end;

  [TScriptAttribute([satForbidden])]
  TClassWrapper = class(TObject)
  private
    FType: TClass;
    FTemplate: IClassTemplate;
    FParent: TClassWrapper;
    FMethods: TObjectDictionary<string, TRttiMethodList>;
    FProps: TObjectDictionary<string, TClassProp>;
    FEngine: INodeEngine;
    FIsGlobal: boolean;

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

  [TScriptAttribute([satForbidden])]
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
    // additional arguments for nodejs
    FPostArgs, FPreArgs: TStrings;
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
    procedure AddPreCode(code: string);
    procedure RunString(code, filename: string);
    // If DebugParam is empty string then debugging will be disabled
    // Else DebugParam should be the same as nodejs' debug parameter
    procedure RunFile(filename: string; DebugParam: string = '');
    procedure ClearAdditionalArguments;
    // True PreArg flag means that arg will be before file/code argument
    // False PreArg flag means that arg will be after file/code argument
    // e.g. '-r' argument should be before file argument
    procedure AddAdditionalArgument(arg: string; PreArg: boolean);
    function RunIncludeFile(filename: string): TValue;
    function RunIncludeCode(code: string; filename: string = ''): TValue;
    function CallFunction(funcName: string): TValue; overload;
    function CallFunction(funcName: string; args: TValueArray): TValue; overload;
    procedure CheckEventLoop;
    procedure TerminateExecution;
    procedure Stop;
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

function InitJS: boolean;
var
  utfStr: UTF8String;
begin
  if not Initialized then
  begin
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
  Log: PAnsiChar;
begin
  Log := NodeInterface.GetNodeLog;
  Result := UTF8ToUnicodeString(RawByteString(Log));
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

procedure TJSEngine.ClearAdditionalArguments;
begin
  FPreArgs.Clear;
  FPostArgs.Clear;
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
      FPostArgs := TStringList.Create;
      FPreArgs := TStringList.Create;
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
  FPostArgs.Free;
  FPreArgs.Free;
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

procedure TJSEngine.RunFile(filename: string; DebugParam: string);
var
  Args: ILaunchArguments;
  FullName: string;
  i: integer;
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
      for i := 0 to FPreArgs.Count - 1 do
      begin
        Args.AddArgument(StringToPAnsiChar(FPreArgs[i]));
      end;
      if (DebugParam <> '') then
        Args.AddArgument(StringToPAnsiChar(DebugParam));
      Args.AddArgument(StringToPAnsiChar(FullName));
      for i := 0 to FPostArgs.Count - 1 do
      begin
        Args.AddArgument(StringToPAnsiChar(FPostArgs[i]));
      end;
      FEngine.Launch(Args);
    finally
      Args.Delete
    end;
  end;
end;

function TJSEngine.RunIncludeCode(code, filename: string): TValue;
begin
  if Active then
  begin
    Result := JSValueToUnknownTValue(
      FEngine.ExecAdditonalCode(StringToPAnsiChar(code),
        StringToPAnsiChar(filename)),
      Self);
  end;
end;

function TJSEngine.RunIncludeFile(filename: string): TValue;
begin
  if Active then
    Result := JSValueToUnknownTValue(
      FEngine.ExecAdditionalFile(StringToPAnsiChar(filename)),
      Self);
end;

procedure TJSEngine.RunString(code, filename: string);
var
  Args: ILaunchArguments;
  FullName: string;
  i: Integer;
begin
  if Active then
  begin
    if filename <> '' then
    begin
      //get absolute path to script file
      FullName := ExpandFileName(filename);
      // set nodejs cwd to script path
      FEngine.ChangeWorkingDir(StringToPAnsiChar(
        ExtractFileDir(FullName)));
    end;
    Args := FEngine.CreateLaunchArguments;
    try
      Args.AddArgument(StringToPAnsiChar(ParamStr(0)));
      for i := 0 to FPreArgs.Count - 1 do
      begin
        Args.AddArgument(StringToPAnsiChar(FPreArgs[i]));
      end;
      Args.AddArgument(StringToPAnsiChar('-e'));
      Args.AddArgument(StringToPAnsiChar(code));
      for i := 0 to FPostArgs.Count - 1 do
      begin
        Args.AddArgument(StringToPAnsiChar(FPostArgs[i]));
      end;
      FEngine.Launch(Args);
    finally
      Args.Delete
    end;
  end;
end;

procedure TJSEngine.Stop;
begin
  FEngine.Stop;
end;

function TJSEngine.StringToPAnsiChar(const S: string): PAnsiChar;
begin
  FUTF8String := UTF8String(S);
  Result := PAnsiChar(FUTF8String);
end;

procedure TJSEngine.TerminateExecution;
begin
  if FActive then
    FEngine.TerminateExecution;
end;

procedure TJSEngine.AddAdditionalArgument(arg: string; PreArg: boolean);
begin
  if PreArg then
    FPreArgs.Add(arg)
  else
    FPostArgs.Add(arg);
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
        (FIsGlobal or (Field.Parent.Handle = Classtyp.Handle)) then
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
      // Check if method is public and belongs to given class type (not to
      // the parent).
      // Global class should have all properties of child classes
      if (Method.Visibility = mvPublic) and
        (not (Method.IsConstructor or Method.IsDestructor)) and
        (FIsGlobal or (Method.Parent.Handle = ClassTyp.Handle)) then
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
        // check if method is possible virtual method of parent class
        if not Overloads.CheckDuplicate(Method) then
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
        (FIsGlobal or (Prop.Parent.Handle = ClassTyp.Handle)) then
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
  FIsGlobal := IsGlobal;
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

function TRttiMethodList.CheckDuplicate(Method: TRttiMethod): boolean;
var
  i, ArgCount: integer;
  ItemMethod: TRttiMethod;
  ItemParams, MethodParams: TArray<TRttiParameter>;
  ItemParam, MethodParam: TRttiParameter;
  k: Integer;
begin
  Result := False;
  for i := 0 to Count - 1 do
  begin
    ItemMethod := Items[i].Method;
    ItemParams := ItemMethod.GetParameters;
    MethodParams := Method.GetParameters;
    ArgCount := Length(ItemParams);
    if ArgCount = Length(MethodParams) then
    begin
      Result := True;
      for k := 0 to ArgCount - 1 do
      begin
        MethodParam := MethodParams[k];
        ItemParam := ItemParams[k];
        if not Assigned(MethodParam.ParamType) then
        begin
          if not Assigned(ItemParam.ParamType) then
            continue
          else
          begin
            Result := False;
            break;
          end;
        end
        else if not Assigned(ItemParam.ParamType) then
        begin
          Result := False;
          break;
        end;
        if MethodParam.ParamType.TypeKind <>
          ItemParam.ParamType.TypeKind then
        begin
          Result := False;
          break;
        end;
      end;
      if Result then
        break;
    end;
  end;
end;

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
  MethodArray: TArray<TClassMethod>;
  ArgCount: Integer;
begin
  Result := nil;
  if Count > 0 then
  begin
    SetLength(MethodArray, Count);
    for i := 0 to Count - 1 do
      MethodArray[i] := Items[i];
    ArgCount := args.GetCount;
    // Sort algorythm is following:
    // 1. Check if passed args count less than method param count
    // 2. If success, this method should be shifted to end of array
    // 3. Else shift method to its place in descending order
    TArray.Sort<TClassMethod>(MethodArray, TComparer<TClassMethod>.Construct(
      function(const Left, Right: TClassMethod): Integer
      var
        LeftResult, RightResult: Integer;
      begin
        LeftResult := CompareValue(Length(Left.Method.GetParameters),
          ArgCount);
        RightResult := CompareValue(Length(Right.Method.GetParameters),
          ArgCount);
        if (RightResult = LessThanValue) xor (LeftResult = LessThanValue) then
        begin
          // left have less args, than was passed
          if LeftResult = LessThanValue then
            Result := GreaterThanValue
          // right have less args, than was passed
          else
            Result := LessThanValue;
        end
        else
          if (RightResult = LessThanValue) and (LeftResult = LessThanValue) then
            Result := CompareValue(Length(Left.Method.GetParameters),
              Length(Right.Method.GetParameters))
          else
            Result := CompareValue(Length(Right.Method.GetParameters),
              Length(Left.Method.GetParameters));
      end
    ));
    for i := 0 to Count - 1 do
    begin
      MethodInfo := MethodArray[i];
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

end.
