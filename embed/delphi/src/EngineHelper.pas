unit EngineHelper;

interface

uses
  NodeInterface, EventWrapper, RTTI, TypInfo, Generics.Collections;

type
  // It will collect all objects, were created by script
  TGarbageCollector = class(TObject)
  private
    FObjectList: TObjectList<TObject>;
    FCallbackList: TObjectList<TEventWrapper>;
  public
    constructor Create();
    procedure AddCallback(Event: TEventWrapper);
    procedure AddObject(Obj: TObject);
  end;

  function TValueToJSValue(value: TValue; Engine: INodeEngine): IJSValue;

  function JSParametersToTValueArray(Params: TArray<TRttiParameter>;
    JSParams: IJSArray; GC: TGarbageCollector): TArray<TValue>;
  function JSValueToTValue(value: IJSValue; typ: TRttiType;
    GC: TGarbageCollector): TValue;
  function JSValueToMethod(value: IJSValue; typ: TRttiType;
    GC: TGarbageCollector): TValue;
  function DefaultTValue(typ: TRttiType): TValue;

var
  Context: TRttiContext;

implementation

function JSParametersToTValueArray(Params: TArray<TRttiParameter>;
  JSParams: IJSArray; GC: TGarbageCollector): TArray<TValue>;
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
    Result[i] := JSValueToTValue(JSParams.GetValue(i), Params[i].ParamType, GC);
  end;
  for i := ArrLength to Length(Params) - 1 do
  begin
    Result[i] := DefaultTValue(Params[i].ParamType);
  end;
end;

function TValueToJSValue(value: TValue; Engine: INodeEngine): IJSValue;
begin
  Result := nil;
  case value.Kind of
    tkUnknown: ;
    tkInteger: Result := Engine.NewInt32(value.AsInteger);
    tkChar, tkString, tkWChar, tkLString, tkWString, tkUString:
      Result := Engine.NewString(StringToPUtf8Char(value.ToString));
    tkEnumeration:
      if value.IsType<Boolean> then
        Result := Engine.NewBool(value.AsBoolean)
      else
        Result := Engine.NewInt32(value.AsOrdinal);
    tkFloat: Result := Engine.NewNumber(value.AsExtended);
    tkSet: ;
    tkClass: Result := Engine.NewDelphiObject(value.AsObject,
                                              value.AsObject.ClassType);
    tkMethod: ;
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


function JSValueToTValue(value: IJSValue; typ: TRttiType;
  GC: TGarbageCollector): TValue;
begin
  Result := TValue.Empty;
  case typ.TypeKind of
    tkUnknown: ;
    tkInteger: Result := value.AsInt32;
    tkChar, tkString, tkWChar, tkLString, tkWString, tkUString:
      Result := PUtf8CharToString(value.AsString);
    tkEnumeration:
      if typ.Handle = TypeInfo(Boolean) then
        Result := value.AsBool
      else
        Result := TValue.FromOrdinal(typ.Handle, value.AsInt32);
    tkFloat: Result := value.AsNumber;
    tkSet: ;
    tkClass: Result := value.AsDelphiObject.GetDelphiObject;
    tkMethod: Result := JSValueToMethod(value, typ, GC);
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

function JSValueToMethod(value: IJSValue; typ: TRttiType;
  GC: TGarbageCollector): TValue;
var
  EventWrapper: TEventWrapper;
begin
  Result := TValue.Empty;
  if value.IsFunction then
  begin
    EventWrapper := GetEventWrapper(typ.Handle).Create(value.AsFunction);
    GC.AddCallback(EventWrapper);
    TValue.Make(@EventWrapper.Method, typ.Handle, Result);
  end;
end;

function DefaultTValue(typ: TRttiType): TValue;
begin
  Result := TValue.Empty;
  case typ.TypeKind of
    tkUnknown: ;
    tkInteger: Result := 0;
    tkChar, tkString, tkWChar, tkLString, tkWString, tkUString:
      Result := '';
    tkEnumeration:
      if typ.Handle = TypeInfo(Boolean) then
        Result := false
      else
        Result := TValue.FromOrdinal(typ.Handle, 0);
    tkFloat: Result := 0;
    tkSet: ;
    tkClass: Result := nil;
    tkMethod: Result := nil;
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

initialization
  Context := TRttiContext.Create;

finalization
  Context.Free;

end.
