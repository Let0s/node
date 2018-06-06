unit NodeEngine;

interface

uses
  NodeInterface, SysUtils, RTTI, Types, TypInfo, EngineHelper, IOUtils,
  Generics.Collections, Windows, Classes, Contnrs;

type
  TJSEngine = class;

  // Class method info
  TClassMethod = record
    // Link to method, that can be called from JS
    Method: TRttiMethod;
    // If method doesn't belong to classtype, then it is method of helper,
    // that is stored here.
    Helper: TJSClassHelper;
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
  TRttiMethodList = class(TList<TClassMethod>)
  public
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
    FClasses: TDictionary<TClass, TClassWrapper>;
    // Store matches "classtype <-> helper object"
    FJSHelperMap: TJSHelperMap;
    // Store helper objects. Any Helper class have only one helper object.
    FJSHelperList: TObjectList;
    FEnumList: TList<PTypeInfo>;
    FGarbageCollector: TGarbageCollector;
    FActive: boolean;
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
    // Use it to match classtype with helper class. Helper will be created
    // automatically (if it wasn't created).
    procedure RegisterHelper(CType: TClass; HelperType: TJSHelperType);
    procedure AddEnum(Enum: TRttiType);
    function AddClass(classType: TClass): TClassWrapper;
    function GetClassWrapper(classType: TClass): TClassWrapper;
    procedure AddGlobal(Global: TObject);
    procedure AddGlobalVariable(Name: string; Variable: TObject);
    procedure AddPreCode(code: string);
    procedure RunString(code: string);
    procedure RunFile(filename: string);
    function CallFunction(funcName: string): TValue; overload;
    function CallFunction(funcName: string; args: TValueArray): TValue; overload;
    procedure CheckEventLoop;
    property Active: boolean read FActive;
  end;

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
begin
  if not Initialized then
  begin
    // first callling node.dll function. STDIO should exist at this moment
    VersionEqual := (EmbedMajorVersion = EMBED_MAJOR_VERSION) and
      (EmbedMinorVersion >= EMBED_MINOR_VERSION);
    if VersionEqual then
      InitNode(StringToPUtf8Char(ParamStr(0)));
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

procedure MethodCallBack(Args: IMethodArgs);
var
  Engine: TJSEngine;
  Overloads: TRttiMethodList;
  Method: TRttiMethod;
  MethodInfo: TClassMethod;
  Obj: TObject;
  ObjType: TClass;
  Result: TValue;
  JSResult: IJSValue;
  MethodArgs: TArray<TValue>;
  Helper: TJSClassHelper;
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
    MethodInfo := Overloads.GetMethod(Args.GetArgs);
    Method := MethodInfo.Method;
    if Assigned(Method) then
    begin
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
      JSResult := TValueToJSValue(Result, Engine);
      if Assigned(JSResult) then
        Args.SetReturnValue(JSResult);
    end;
  end;
end;

procedure PropGetterCallBack(Args: IGetterArgs); stdcall;
var
  Engine: TJSEngine;
  PropInfo: TClassProp;
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
    JSResult := TValueToJSValue(Result, Engine);
    if Assigned(JSResult) then
      Args.SetReturnValue(JSResult);
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
    //all objects will be stored in JS value when accessor (or function)
    // will be called
    Obj := Args.GetDelphiObject;
    if not Assigned(Obj) then
    begin
      if Args.GetDelphiClasstype = Engine.FGlobal.ClassType then
        Obj := Engine.FGlobal;
    end;
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

procedure IndexedPropGetter(Args: IIndexedGetterArgs); stdcall;
var
  Engine: TJSEngine;
  Prop: TRttiIndexedProperty;
  Obj: TObject;
  Result: TValue;
  JSResult: IJSValue;
begin
  Engine := Args.GetEngine as TJSEngine;
  if Assigned(Engine) then
  begin
    Obj := Args.GetDelphiObject;
    if not Assigned(Obj) then
    begin
      if Args.GetDelphiClasstype = Engine.FGlobal.ClassType then
        Obj := Engine.FGlobal;
    end;
    Prop := Args.GetPropPointer as TRttiIndexedProperty;
    if Assigned(Prop) then
    begin
      Result := Prop.GetValue(Obj, [JSValueToUnknownTValue(args.GetPropIndex)]);
      JSResult := TValueToJSValue(Result, Engine);
      if Assigned(JSResult) then
        Args.SetReturnValue(JSResult);
    end;
  end;
end;

procedure IndexedPropSetter(Args: IIndexedSetterArgs); stdcall;
var
  Engine: TJSEngine;
  Prop: TRttiIndexedProperty;
  Obj: TObject;
  Result: TValue;
  JSResult: IJSValue;
begin
  Engine := Args.GetEngine as TJSEngine;
  if Assigned(Engine) then
  begin
    Obj := Args.GetDelphiObject;
    if not Assigned(Obj) then
    begin
      if Args.GetDelphiClasstype = Engine.FGlobal.ClassType then
        Obj := Engine.FGlobal;
    end;
    Prop := Args.GetPropPointer as TRttiIndexedProperty;
    if Assigned(Prop) then
    begin
      Prop.SetValue(Obj, [args.GetPropIndex],
        JSValueToTValue(args.GetValue, Prop.PropertyType, Engine));
      Result := Prop.GetValue(Obj, [JSValueToUnknownTValue(args.GetPropIndex)]);
      JSResult := TValueToJSValue(Result, Engine);
      if Assigned(JSResult) then
        Args.SetReturnValue(JSResult);
    end;
  end;
end;

{ TJSEngine }

function TJSEngine.AddClass(classType: TClass): TClassWrapper;
var
  ClassWrapper: TClassWrapper;
  ParentWrapper: TClassWrapper;
  Parent: TClass;
  Helper: TJSClassHelper;
begin
  Result := nil;
  if Active then
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
  FEngine.AddGlobalVariableObject(StringToPUtf8Char(Name), Variable, CType);
end;

procedure TJSEngine.AddPreCode(code: string);
begin
  if Active then
    FEngine.AddPreCode(StringToPUtf8Char(code));
end;

function TJSEngine.CallFunction(funcName: string; args: TValueArray): TValue;
var
  JsArgs: IJSArray;
  ResultValue: IJSValue;
begin
  if Active then
  begin
    JsArgs := TValueArrayToJSArray(args, Self);
    ResultValue := FEngine.CallFunction(StringToPUtf8Char(funcName), JsArgs);
    Result := JSValueToUnknownTValue(ResultValue)
  end;
end;

function TJSEngine.CallFunction(funcName: string): TValue;
var
  ResultValue: IJSValue;
begin
  if Active then
  begin
    ResultValue := FEngine.CallFunction(StringToPUtf8Char(funcName), nil);
    Result := JSValueToUnknownTValue(ResultValue)
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
      FEngine.SetMethodCallBack(MethodCallBack);
      FEngine.SetPropGetterCallBack(PropGetterCallBack);
      FEngine.SetPropSetterCallBack(PropSetterCallBack);
      FEngine.SetFieldGetterCallBack(FieldGetterCallBack);
      FEngine.SetFieldSetterCallBack(FieldSetterCallBack);
      FEngine.SetIndexedGetterCallBack(IndexedPropGetter);
      FEngine.SetIndexedSetterCallBack(IndexedPropSetter);
      FClasses := TDictionary<TClass, TClassWrapper>.Create;
      FJSHelperMap := TJSHelperMap.Create;
      FJSHelperList := TObjectList.Create;
      FGarbageCollector := TGarbageCollector.Create;
      FEnumList := TList<PTypeInfo>.Create;
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
begin
  if Active then
    FEngine.RunFile(StringToPUtf8Char(TPath.GetFullPath(filename)));
end;

procedure TJSEngine.RunString(code: string);
begin
  if Active then
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

procedure TClassWrapper.AddHelperMethods(Helper: TJSClassHelper;
  Engine: TJSEngine);
var
  Method: TRttiMethod;
  MethodInfo: TClassMethod;
  Overloads: TRttiMethodList;
  ClassTyp: TRttiType;
begin
  ClassTyp := EngineHelper.Context.GetType(Helper.ClassType);
  for Method in ClassTyp.GetMethods do
  begin
    // Add only public methods from full class hierarchy
    // (exclude TObject's methods)
    if (Method.Visibility = mvPublic) and
      (method.Parent.Handle.TypeData.ClassType.InheritsFrom(TJSClassHelper)) and
      (Method.MethodKind in [mkProcedure, mkFunction]) then
    begin
      Engine.CheckType(Method.ReturnType);
      if not FMethods.TryGetValue(Method.Name, Overloads) then
      begin
        Overloads := TRttiMethodList.Create;
        FMethods.Add(Method.Name, Overloads);
        FTemplate.SetMethod(StringToPUtf8Char(Method.Name), Overloads);
      end;
      MethodInfo.Method := Method;
      MethodInfo.Helper := Helper;
      Overloads.Add(MethodInfo);
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
    // Add only public props from full class hierarchy
    // (exclude TObject's props)
    if (Prop.Visibility = mvPublic) and
      (Prop.Parent.Handle.TypeData.ClassType.InheritsFrom(TJSClassHelper)) and
      not FProps.ContainsKey(Prop.Name) then
    begin
      Engine.CheckType(Prop.PropertyType);
      PropInfo := TClassProp.Create(Prop, Helper);
      FProps.Add(Prop.Name, PropInfo);
      FTemplate.SetProperty(StringToPUtf8Char(Prop.Name), PropInfo,
        Prop.IsReadable, Prop.IsWritable);
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
    if (Prop.Visibility = mvPublic) and
      (Prop.Parent.Handle = ClassTyp.Handle) then
    begin
      Engine.CheckType(Prop.PropertyType);
      if Prop.IsDefault then
        DefaultProp := Prop;
      FTemplate.SetIndexedProperty(StringToPUtf8Char(Prop.Name), Prop,
        Prop.IsReadable, Prop.IsWritable);
    end;
  end;
  if Assigned(DefaultProp) then
    FTemplate.SetDefaultIndexedProperty(DefaultProp);
end;

procedure TClassWrapper.AddMethods(ClassTyp: TRttiType; Engine: TJSEngine);
var
  Method: TRttiMethod;
  MethodInfo: TClassMethod;
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
      MethodInfo.Method := Method;
      MethodInfo.Helper := nil;
      Overloads.Add(MethodInfo);
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
      MethodInfo.Method := Method;
      MethodInfo.Helper := nil;
      Overloads.Add(MethodInfo);
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
    if (Prop.Visibility = mvPublic) and
      (Prop.Parent.Handle = ClassTyp.Handle) then
    begin
      Engine.CheckType(Prop.PropertyType);
      PropInfo := TClassProp.Create(Prop, nil);
      FProps.Add(Prop.Name, PropInfo);
      FTemplate.SetProperty(StringToPUtf8Char(Prop.Name), PropInfo,
        Prop.IsReadable, Prop.IsWritable);
    end;
  end;
end;

constructor TClassWrapper.Create(cType: TClass);
begin
  FType := cType;
  FMethods := TObjectDictionary<string, TRttiMethodList>.Create;
  FProps := TObjectDictionary<string, TClassProp>.Create;
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
    FTemplate := FEngine.AddObject(StringToPUtf8Char(FType.ClassName), FType);
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

function TRttiMethodList.GetMethod(args: IJSArray): TClassMethod;
var
  i, j: Integer;
  Params: TArray<TRttiParameter>;
  MethodInfo: TClassMethod;
begin
  Result.Method := nil;
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
        if not CompareType(Params[j].ParamType, args.GetValue(j)) then
        begin
          MethodInfo.Method := nil;
          break;
        end;
      end;
      if Assigned(MethodInfo.Method) then
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
