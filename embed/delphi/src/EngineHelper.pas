unit EngineHelper;

interface

uses
  NodeInterface, RTTI, TypInfo, Generics.Collections, Classes, SysUtils,
  ScriptAttributes, Variants;

type
  EScriptEngineException = class(Exception);

  TGarbageCollector = class;

  TValueArray = TArray<TValue>;

  IJSEngine = interface
    function GetEngine: INodeEngine;
    function GetGarbageCollector: TGarbagecollector;
    property Engine: INodeEngine read GetEngine;
    property GC: TGarbageCollector read GetGarbageCollector;
  end;

  // Base helper class. Helpers are used to extend any class - add new methods
  // and props. All public props and methods will be added into JS as props
  // and methods of extended class.
  TJSClassHelper = class(TObject)
  private
    FSource: TObject;
  public
    // Property Source returns object of extended class, which method is called
    property Source: TObject Read FSource Write FSource;
  end;

  TJSHelperType = class of TJSClassHelper;

  // It is used to store mathces between classtype and its helper object
  TJSHelperMap = TDictionary<TClass, TJSClassHelper>;

  TEventWrapper = class(TObject)
  private
    FEngine: IJSEngine;
    FFunction: IJSFunction;
    FMethod: TMethod;
  protected
    procedure SetMethod(NewMethod: TMethod);
    function ConvertFunctionResult(res: IJSValue): TValue;
    function CallFunction(Args: array of TValue): TValue;
  public
    constructor Create(Func: IJSFunction); virtual;
    property Method: TMethod read FMethod;
    property JSFunction: IJSFunction read FFunction;
    procedure SetEngine(Engine: IJSEngine);
  end;

  TEventWrapperClass = class of TEventWrapper;

  TNotifyEventWrapper = class(TEventWrapper)
  public
    constructor Create(Func: IJSFunction); override;
    procedure Event(Sender: TObject);
  end;

  TEventWrapperList = class(TObjectList<TEventWrapper>)
  end;

  // It will collect all objects, were created by script
  TGarbageCollector = class(TObject)
  private
    FObjectList: TObjectList<TObject>;
    FCallbackList: TObjectList<TEventWrapper>;
  public
    constructor Create();
    destructor Destroy; override;
    procedure AddCallback(Event: TEventWrapper);
    function GetCallBack(Method: TValue): TEventWrapper;
    procedure AddObject(Obj: TObject);
    procedure Add(Value: TValue);
  end;

  function HaveScriptSetting(Attributes: TArray<TCustomAttribute>;
    Setting: TScriptAttributeType): boolean; overload;
  function HaveScriptSetting(Attribute: TScriptAttribute;
    Setting: TScriptAttributeType): boolean; overload;

  function TValueToJSValue(value: TValue; Engine: IJSEngine): IJSValue;
  function RecordToJSValue(rec: TValue; Engine: IJSEngine): IJSObject;
  function TValueToJSFunction(value: TValue; Engine: IJSEngine): IJSValue;
  function TValueArrayToJSArray(value: TValueArray; Engine: IJSEngine): IJSArray;
  function TValueToJSArray(value: TValue; Engine: IJSEngine): IJSArray;
  function InterfaceTValueToJSValue(value: TValue; Engine: IJSEngine): IJSValue;
  function ObjectToJSWrappedObject(value: TObject; Engine: IJSEngine): IJSValue;
  function VariantToJSValue(value: Variant; Engine: IJSEngine): IJSValue;

  function JSParametersToTValueArray(Params: TArray<TRttiParameter>;
    JSParams: IJSArray; Engine: IJSEngine): TArray<TValue>;
  procedure CheckConversion(value: IJSValue; typ: TRttiType);
  function JSValueToTValue(value: IJSValue; typ: TRttiType;
    Engine: IJSEngine): TValue;
  function JSValueToVariant(value: IJSValue): Variant;
  function JSValueToRecord(value: IJSValue; typ: TRttiType;
    Engine: IJSEngine): TValue;
  function JSArrayToTValue(value: IJSArray; typ: TRttiType;
    Engine: IJSEngine): TValue;
  function JSValueToMethod(value: IJSValue; typ: TRttiType;
    Engine: IJSEngine): TValue;
  function DefaultTValue(typ: TRttiType): TValue;

  function JSValueToUnknownTValue(value: IJSValue): TValue;

  function CompareType(typ: TRttiType; value: IJSValue): Boolean;

  function RegisterEventWrapper(Event: PTypeInfo;
    Wrapper: TEventWrapperClass): boolean;
  function GetEventWrapper(Event: PTypeInfo): TEventWrapperClass;

var
  Context: TRttiContext;
  EventWrapperClassList: TDictionary<PTypeInfo, TEventWrapperClass>;

implementation

function HaveScriptSetting(Attributes: TArray<TCustomAttribute>;
  Setting: TScriptAttributeType): boolean;
var
  Attr: TCustomAttribute;
begin
  Result := false;
  for Attr in Attributes do
    if Attr is TScriptAttribute then
      if HaveScriptSetting(Attr as TScriptAttribute, Setting) then
      begin
        Result := True;
        break;
      end;
end;

function HaveScriptSetting(Attribute: TScriptAttribute;
  Setting: TScriptAttributeType): boolean;
begin
  Result := Attribute.HaveSetting(Setting);
end;

function JSParametersToTValueArray(Params: TArray<TRttiParameter>;
  JSParams: IJSArray; Engine: IJSEngine): TArray<TValue>;
var
  ArrLength: Int32;
  i: Integer;
begin
  ArrLength := JSParams.GetCount;
  SetLength(Result, Length(Params));
  for i := 0 to ArrLength - 1 do
  begin
    if i >= Length(Params) then
      break;
    Result[i] := JSValueToTValue(JSParams.GetValue(i),
      Params[i].ParamType, Engine);
  end;
  for i := ArrLength to Length(Params) - 1 do
  begin
    Result[i] := DefaultTValue(Params[i].ParamType);
  end;
end;

function TValueToJSValue(value: TValue; Engine: IJSEngine): IJSValue;
var
  NodeEngine: INodeEngine;
begin
  Result := nil;
  NodeEngine := Engine.Engine;
  if Assigned(NodeEngine) then
  begin
    case value.Kind of
      tkUnknown: ;
      tkInteger: Result := NodeEngine.NewInt32(value.AsInteger);
      tkChar, tkString, tkWChar, tkLString, tkWString, tkUString:
        Result := NodeEngine.NewString(StringToPUtf8Char(value.ToString));
      tkEnumeration:
        if value.IsType<Boolean> then
          Result := NodeEngine.NewBool(value.AsBoolean)
        else
          Result := NodeEngine.NewInt32(value.AsOrdinal);
      tkFloat: Result := NodeEngine.NewNumber(value.AsExtended);
      tkSet: ;
      tkClass: Result := ObjectToJSWrappedObject(value.AsObject, Engine);
      tkMethod: Result := TValueToJSFunction(value, Engine);
      tkVariant: Result := VariantToJSValue(value.AsVariant, Engine);
      tkArray: Result := TValueToJSArray(value, Engine);
      tkRecord: Result := RecordToJSValue(value, Engine);
      tkInterface: Result := InterfaceTValueToJSValue(value, Engine);
      tkInt64: Result := NodeEngine.NewNumber(value.AsInt64);
      tkDynArray: Result := TValueToJSArray(value, Engine);
      tkClassRef: ;
      tkPointer: ;
      tkProcedure: ;
    end;
  end;
end;

function RecordToJSValue(rec: TValue; Engine: IJSEngine): IJSObject;
var
  FieldArr: TArray<TRttiField>;
  Field: TRttiField;
  PropArr: TArray<TRttiProperty>;
  Prop: TRttiProperty;
  RecDescr: TRttiType;
begin
  Result := Engine.Engine.NewObject;
  RecDescr := TRttiContext.Create.GetType(rec.TypeInfo);
  FieldArr := RecDescr.GetFields;
  for Field in FieldArr do
  begin
    if (Field.Visibility = mvPublic) and (Assigned(Field.FieldType)) then
      Result.SetField(PAnsiChar(UTF8String(Field.Name)),
        TValueToJSValue(Field.GetValue(rec.GetReferenceToRawData), Engine));
  end;

  PropArr := RecDescr.GetProperties;
  for Prop in PropArr do
  begin
    if (Prop.Visibility = mvPublic) and (Assigned(Prop.PropertyType)) then
      Result.SetField(PAnsiChar(UTF8String(Prop.Name)),
        TValueToJSValue(Prop.GetValue(rec.GetReferenceToRawData), Engine));
  end;
end;

function TValueToJSFunction(value: TValue; Engine: IJSEngine): IJSValue;
var
  EventWrapper: TEventWrapper;
  GC: TGarbageCollector;
begin
  Result := nil;
  GC := Engine.GC;
  if Assigned(GC) and not (value.IsEmpty) then
  begin
    EventWrapper := GC.GetCallBack(value);
    if Assigned(EventWrapper) then
      Result := EventWrapper.JSFunction;
  end;
end;


function TValueArrayToJSArray(value: TValueArray; Engine: IJSEngine): IJSArray;
var
  count, i: integer;
begin
  count := Length(value);
  Result := Engine.Engine.NewArray(count);
  for i := 0 to count - 1 do
  begin
    Result.SetValue(TValueToJSValue(value[i], Engine), i);
  end;
end;

function TValueToJSArray(value: TValue; Engine: IJSEngine): IJSArray;
var
  count, i: integer;
begin
  Result := nil;
  if value.IsArray then
  begin
    count := value.GetArrayLength;
    Result := Engine.Engine.NewArray(count);
    for i := 0 to count - 1 do
    begin
      Result.SetValue(TValueToJSValue(value.GetArrayElement(i), Engine), i);
    end;
  end
end;

function InterfaceTValueToJSValue(value: TValue; Engine: IJSEngine): IJSValue;
var
  Obj: TObject;
begin
  Result := nil;
  Obj := TObject(value.AsInterface);
  if Assigned(Obj) then
  begin
    Result := ObjectToJSWrappedObject(Obj, Engine);
  end;
end;

function ObjectToJSWrappedObject(value: TObject; Engine: IJSEngine): IJSValue;
var
  cType: TClass;
  NodeEngine: INodeEngine;
begin
  // Check for first registered class from original to parent
  // and wrap object with registered class (can contain less properties)

  // To think: maybe make ability to register class dynamically?
  Result := nil;
  if Assigned(value) then
  begin
    cType := value.ClassType;
    NodeEngine := Engine.Engine;
    while Assigned(cType) and
      not Assigned(NodeEngine.GetObjectTemplate(cType)) do
    begin
      cType := cType.ClassParent;
    end;
    if Assigned(cType) then
      Result := NodeEngine.NewDelphiObject(value, cType);
  end;
end;

function VariantToJSValue(value: Variant; Engine: IJSEngine): IJSValue;
var
  NodeEngine: INodeEngine;
begin
  Result := nil;
  NodeEngine := Engine.Engine;
  if VarType(value) = varBoolean then
    Result := NodeEngine.NewBool(Boolean(value))
  else
  begin
    if VarIsNumeric(value) then
      Result := NodeEngine.NewNumber(Double(value))
    else if VarIsStr(value) then
      Result := NodeEngine.NewString(StringToPUtf8Char(value));
  end;
end;

procedure CheckConversion(value: IJSValue; typ: TRttiType);
begin
  if not (value.IsUndefined or value.IsNull) then
  begin
    if not CompareType(typ, value) then
      raise EInvalidCast.Create('Type mismatch. Expected ' + typ.Name);
  end;
end;

function JSValueToTValue(value: IJSValue; typ: TRttiType;
  Engine: IJSEngine): TValue;
begin
  Result := TValue.Empty;
  if Assigned(value) then
  begin
    CheckConversion(value, typ);
    case typ.TypeKind of
      tkUnknown: ;
      tkInteger:
        Result := value.AsInt32;
      tkChar, tkString, tkWChar, tkLString, tkWString, tkUString:
        Result := PUtf8CharToString(value.AsString);
      tkEnumeration:
        if typ.Handle = TypeInfo(Boolean) then
          Result := value.AsBool
        else
          Result := TValue.FromOrdinal(typ.Handle, value.AsInt32);
      tkFloat:
        Result := value.AsNumber;
      tkSet: ;
      tkClass, tkInterface:
        if value.IsDelphiObject then
          Result := value.AsDelphiObject.GetDelphiObject;
      tkMethod:
        Result := JSValueToMethod(value, typ, Engine);
      tkVariant:
        Result := TValue.From<Variant>(JsValueToVariant(value));
      tkArray:
        Result := JSArrayToTValue(value.AsArray, typ as TRttiArrayType, Engine);
      tkRecord: Result := JsValueToRecord(value, typ, Engine);
      tkInt64:
        Result := Round(value.AsNumber);
      tkDynArray:
        Result := JSArrayToTValue(value.AsArray, typ, Engine);
      tkClassRef: ;
      tkPointer: ;
      tkProcedure: ;
    end;
  end;
end;

function JSValueToVariant(value: IJSValue): Variant;
begin
  Result := Unassigned;
  if not assigned(value) or (value.IsUndefined) then
    Exit;
  //checking for type
  if value.IsBool then
    Result := value.AsBool
  else if value.IsInt32 then
    Result := value.AsInt32
  else if value.IsNumber then
    Result := value.AsNumber
  else if value.IsString then
    Result := PUtf8CharToString(value.AsString);
end;

function JSValueToRecord(value: IJSValue; typ: TRttiType;
  Engine: IJSEngine): TValue;
var
  FieldsArr: TArray<TRttiField>;
  Field: TRttiField;
  PropsArr: TArray<TRttiProperty>;
  Prop: TRttiProperty;
  Rec: IJSObject;
  ref: Pointer;
begin
  if typ.TypeKind <> tkRecord then
    Exit;
  Rec := value.AsObject;
  TValue.Make(nil, typ.Handle, Result);
  if Assigned(Rec) then
  begin
    ref := Result.GetReferenceToRawData;
    FieldsArr := typ.GetFields;
    for Field in FieldsArr do
    begin
      if not Assigned(Field.FieldType) or (Field.Visibility <> mvPublic) then
        Continue;
      Field.SetValue(ref,
        JSValueToTValue(Rec.GetField(StringToPUtf8Char(Field.Name)),
                        Field.FieldType,
                        Engine));
    end;
    PropsArr := typ.GetProperties;
    for Prop in PropsArr do
    begin
      if not Assigned(Prop.PropertyType) or (Prop.Visibility <> mvPublic) then
        Continue;
      Prop.SetValue(ref,
        JSValueToTValue(Rec.GetField(StringToPUtf8Char(Prop.Name)),
                        Prop.PropertyType,
                        Engine));
    end;
  end;
end;

function JSArrayToTValue(value: IJSArray; typ: TRttiType;
  Engine: IJSEngine): TValue;
var
  TValueArr: array of TValue;
  i, count, arrTypeLength: Int32;
  ElemType: TRttiType;
begin
  Result := TValue.Empty;
  if Assigned(value) then
  begin
    count := value.GetCount;
    if typ is TRttiArrayType then
    begin
      ElemType := TRttiArrayType(typ).ElementType;
      arrTypeLength := TRttiArrayType(typ).TotalElementCount;
    end
    else if typ is TRttiDynamicArrayType then
    begin
      ElemType := TRttiDynamicArrayType(typ).ElementType;
      arrTypeLength := count;
    end
    else
      Exit;
    SetLength(TValueArr, arrTypeLength);
    for i := 0 to arrTypeLength - 1 do
    begin
      if i < count then
        TValueArr[i] := JSValueToTValue(value.GetValue(i), ElemType, Engine)
      else
        TValueArr[i] := DefaultTValue(ElemType);
    end;
    Result := TValue.FromArray(typ.Handle, TValueArr);
  end;
end;

function JSValueToMethod(value: IJSValue; typ: TRttiType;
  Engine: IJSEngine): TValue;
var
  EventWrapper: TEventWrapper;
  EventClass: TEventWrapperClass;
  GC: TGarbageCollector;
begin
  Result := TValue.Empty;
  GC := Engine.GC;
  if value.IsFunction then
  begin
    EventClass := GetEventWrapper(typ.Handle);
    if Assigned(EventClass) then
    begin
      EventWrapper := EventClass.Create(value.AsFunction);
      EventWrapper.SetEngine(Engine);
      if Assigned(GC) then
        GC.AddCallback(EventWrapper);
      TValue.Make(@EventWrapper.Method, typ.Handle, Result);
    end;
  end;
end;

function DefaultTValue(typ: TRttiType): TValue;
begin
  Result := TValue.Empty;
  if not Assigned(typ) then
    Exit;
  case typ.TypeKind of
    tkUnknown: ;
    tkInteger: Result := 0;
    tkChar: Result := '';
    tkEnumeration: Result := TValue.FromOrdinal(typ.Handle, 0);
    tkFloat: Result := 0.0;
    tkString: Result := '';
    tkSet: ;
    tkClass: Result := nil;
    tkMethod: Result := nil;
    tkWChar: Result := '';
    tkLString: Result := '';
    tkWString: Result := '';
    tkVariant: Result := '';
    tkArray: ;
    tkRecord: ;
    tkInterface: Result := nil;
    tkInt64: Result := 0;
    tkDynArray: ;
    tkUString: Result := '';
    tkClassRef: ;
    tkPointer: Result := nil;
    tkProcedure: Result := nil;
  end;
end;

function JSValueToUnknownTValue(value: IJSValue): TValue;
begin
  Result := TValue.Empty;
  if not assigned(value) then
    Exit;
  //checking for type
  if value.IsBool then
    Result := value.AsBool
  else if value.IsInt32 then
    Result := value.AsInt32
  else if value.IsNumber then
    Result := value.AsNumber
  else if (value.IsDelphiObject) then
    Result := TValue.From<TObject>(value.AsDelphiObject)
  else if value.IsString then
    Result := PUtf8CharToString(value.AsString);
end;

function CompareType(typ: TRttiType; value: IJSValue): Boolean;
var
  IntValue: Integer;
  Int64Value: Int64;
  FloatValue: Double;
begin
  Result := False;
  case typ.TypeKind of
    tkUnknown: ;
    tkInteger, tkEnumeration: Result := value.IsInt32 or value.IsBool or
      TryStrToInt(PUtf8CharToString(value.AsString), IntValue);
    tkChar, tkString, tkWChar, tkLString, tkWString, tkUString:
      Result := True; // we can transform any data to string;
    tkFloat: Result := value.IsNumber or
      TryStrToFloat(PUtf8CharToString(value.AsString), FloatValue);
    tkSet: ;
    tkClass: Result := value.IsDelphiObject;
    tkMethod: Result := value.IsFunction;
    tkVariant: Result := True;
    tkArray, tkDynArray: Result := value.IsArray;
    tkRecord: Result := value.IsObject;
    tkInterface: ;
    tkInt64: Result := value.IsNumber or
      TryStrToInt64(PUtf8CharToString(value.AsString), Int64Value);
    tkClassRef: ;
    tkPointer: Result :=
    {$IFDEF WIN32}
      value.IsInt32 or
      TryStrToInt(PUtf8CharToString(value.AsString), IntValue);
    {$ELSE}
      value.IsNumber or
      TryStrToInt64(PUtf8CharToString(value.AsString), Int64Value);
    {$ENDIF}
    tkProcedure: ;
  end;
end;

function RegisterEventWrapper(Event: PTypeInfo;
  Wrapper: TEventWrapperClass): boolean;
begin
  Result := False;
  if not EventWrapperClassList.ContainsKey(Event) then
  begin
    EventWrapperClassList.Add(Event, Wrapper);
    Result := True;
  end;
end;

function GetEventWrapper(Event: PTypeInfo): TEventWrapperClass;
begin
  if not EventWrapperClassList.TryGetValue(Event, Result) then
    Result := nil;
end;

{ TEventWrapper }

function TEventWrapper.CallFunction(Args: array of TValue): TValue;
var
  Engine: INodeEngine;
  ArgLength: Int32;
  i: Integer;
  ArgArray: IJSArray;
begin
  Result := TValue.Empty;
  Engine := FFunction.GetEngine;
  if Assigned(Engine) then
  begin
    ArgLength := Length(Args);
    ArgArray := Engine.NewArray(ArgLength);
    for i := 0 to ArgLength - 1 do
    begin
      ArgArray.SetValue(TValueToJSValue(Args[i], FEngine), 0);
    end;
    Result := ConvertFunctionResult(FFunction.Call(ArgArray));
  end;
end;

function TEventWrapper.ConvertFunctionResult(res: IJSValue): TValue;
var
  ObjType: TRttiType;
  ObjMethod: TRttiMethod;
  ReturnType: TRttiType;
begin
  ReturnType := nil;
  if Assigned(res) then
  begin
    ObjType := Context.GetType(Self.ClassType);
    for ObjMethod in ObjType.GetMethods do
      if ObjMethod.CodeAddress = Method.Code then
      begin
        ReturnType := ObjMethod.ReturnType;
        break;
      end;
    if Assigned(ReturnType) then
      Result := JSValueToTValue(res, ReturnType, FEngine)
    else
      Result := JSValueToUnknownTValue(res);
  end;
end;

constructor TEventWrapper.Create(Func: IJSFunction);
begin
  FFunction := Func;
end;

procedure TEventWrapper.SetEngine(Engine: IJSEngine);
begin
  FEngine := Engine;
end;

procedure TEventWrapper.SetMethod(NewMethod: TMethod);
begin
  FMethod := NewMethod;
end;

{ TNotifyEventWrapper }

constructor TNotifyEventWrapper.Create(Func: IJSFunction);
var
  TempMethod: TMethod;
begin
  inherited;
  TempMethod.Code := @TNotifyEventWrapper.Event;
  TempMethod.Data := Self;
  SetMethod(TempMethod);
end;

procedure TNotifyEventWrapper.Event(Sender: TObject);
begin
  CallFunction([Sender]);
end;

{ TGarbageCollector }

procedure TGarbageCollector.Add(Value: TValue);
var
  i, count: integer;
begin
  case Value.Kind of
    tkClass:
      AddObject(Value.AsObject);
    tkInterface: ;
    tkArray, tkDynArray:
    begin
      count := Value.GetArrayLength;
      for i := 0 to count - 1 do
        Add(Value.GetArrayElement(i));
    end;
  end;
end;

procedure TGarbageCollector.AddCallback(Event: TEventWrapper);
begin
  FCallbackList.Add(Event);
end;

procedure TGarbageCollector.AddObject(Obj: TObject);
begin
  FObjectList.Add(Obj);
end;

constructor TGarbageCollector.Create;
begin
  FObjectList := TObjectList<TObject>.Create;
  FCallbackList := TObjectList<TEventWrapper>.Create;
end;

destructor TGarbageCollector.Destroy;
begin
  FObjectList.Free;
  FCallbackList.Free;
  inherited;
end;

function TGarbageCollector.GetCallBack(Method: TValue): TEventWrapper;
var
  i: Integer;
  MethodValue: TValue;
  MethodPointer: Pointer;
  CallBack: TEventWrapper;
begin
  Result := nil;
  // Convert from <TCustomEvent> (any event type) to Pointer TValue
  TValue.Make(Method.GetReferenceToRawData, TypeInfo(Pointer), MethodValue);
  // Convert from TValue to Pointer
  MethodPointer := MethodValue.AsType<Pointer>;
  if Assigned(MethodPointer) then
  begin
    for i := 0 to FCallbackList.Count - 1 do
    begin
      CallBack := FCallbackList[i];
      // Check if method pointer equals to EventWrapper method code
      if CallBack.FMethod.Code = MethodPointer then
      begin
        Result := CallBack;
        break;
      end;
    end;
  end;
end;

initialization
  Context := TRttiContext.Create;
  EventWrapperClassList := TDictionary<PTypeInfo, TEventWrapperClass>.Create;
  RegisterEventWrapper(TypeInfo(TNotifyEvent), TNotifyEventWrapper);

finalization
  Context.Free;
  EventWrapperClassList.Free;

end.
