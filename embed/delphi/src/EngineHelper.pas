unit EngineHelper;

interface

uses
  NodeInterface, RTTI, TypInfo, Generics.Collections, Classes, SysUtils;

type
  EScriptEngineException = class(Exception);

  TGarbageCollector = class;

  IJSEngine = interface
    function GetEngine: INodeEngine;
    function GetGarbageCollector: TGarbagecollector;
    property Engine: INodeEngine read GetEngine;
    property GC: TGarbageCollector read GetGarbageCollector;
  end;

  TEventWrapper = class(TObject)
  private
    FEngine: IJSEngine;
    FFunction: IJSFunction;
    FMethod: TMethod;
  protected
    procedure SetMethod(NewMethod: TMethod);
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
    procedure AddCallback(Event: TEventWrapper);
    function GetCallBack(Method: TValue): TEventWrapper;
    procedure AddObject(Obj: TObject);
  end;

  function TValueToJSValue(value: TValue; Engine: IJSEngine): IJSValue;
  function TValueToJSFunction(value: TValue; Engine: IJSEngine): IJSValue;

  function JSParametersToTValueArray(Params: TArray<TRttiParameter>;
    JSParams: IJSArray; Engine: IJSEngine): TArray<TValue>;
  function JSValueToTValue(value: IJSValue; typ: TRttiType;
    Engine: IJSEngine): TValue;
  function JSArrayToTValue(value: IJSArray; typ: TRttiArrayType;
    Engine: IJSEngine): TValue;
  function JSValueToMethod(value: IJSValue; typ: TRttiType;
    Engine: IJSEngine): TValue;
  function DefaultTValue(typ: TRttiType): TValue;

  function RegisterEventWrapper(Event: PTypeInfo;
    Wrapper: TEventWrapperClass): boolean;
  function GetEventWrapper(Event: PTypeInfo): TEventWrapperClass;

var
  Context: TRttiContext;
  EventWrapperClassList: TDictionary<PTypeInfo, TEventWrapperClass>;

implementation

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
      tkClass: Result := NodeEngine.NewDelphiObject(value.AsObject,
                                                value.AsObject.ClassType);
      tkMethod: Result := TValueToJSFunction(value, Engine);
      tkVariant: ;
      tkArray: ;
      tkRecord: ;
      tkInterface: ;
      tkInt64: ;
      tkDynArray: ;
      tkClassRef: ;
      tkPointer: ;
      tkProcedure: ;
    end;
  end;
end;

function TValueToJSFunction(value: TValue; Engine: IJSEngine): IJSValue;
var
  EventWrapper: TEventWrapper;
  Event: TMethod;
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


function JSValueToTValue(value: IJSValue; typ: TRttiType;
  Engine: IJSEngine): TValue;
begin
  Result := TValue.Empty;
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
    tkClass:
      Result := value.AsDelphiObject.GetDelphiObject;
    tkMethod:
      Result := JSValueToMethod(value, typ, Engine);
    tkVariant: ;
    tkArray:
      Result := JSArrayToTValue(value.AsArray, typ as TRttiArrayType, Engine);
    tkRecord: ;
    tkInterface: ;
    tkInt64: ;
    tkDynArray:
      Result := JSArrayToTValue(value.AsArray, typ as TRttiArrayType, Engine);
    tkClassRef: ;
    tkPointer: ;
    tkProcedure: ;
  end;
end;

function JSArrayToTValue(value: IJSArray; typ: TRttiArrayType;
  Engine: IJSEngine): TValue;
var
  TValueArr: array of TValue;
  i, count: Int32;
begin
  Result := TValue.Empty;
  if Assigned(value) then
  begin
    count := value.GetCount;
    SetLength(TValueArr, count);
    for i := 0 to count - 1 do
    begin
      TValueArr[i] := JSValueToTValue(value.GetValue(i), typ.ElementType, Engine);
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
//  ResultValue: IJSValue;
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
    FFunction.Call(ArgArray);
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
